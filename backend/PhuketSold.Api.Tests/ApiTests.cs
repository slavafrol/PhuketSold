using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;
using PhuketSold.Api.Data;
using PhuketSold.Api.Features.Catalog;

namespace PhuketSold.Api.Tests;

public sealed class ApiTests
{
  [Fact]
  public async Task Liveness_does_not_depend_on_database_configuration()
  {
    await using var factory = CreateFactory("");
    using var client = factory.CreateClient();
    var response = await client.GetAsync("/health");
    Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    Assert.Equal("{\"status\":\"healthy\"}", await response.Content.ReadAsStringAsync());
  }

  [Theory]
  [InlineData("")]
  [InlineData("Host=127.0.0.1;Port=1;Database=postgres;Username=unavailable;Password=never-print-this;Timeout=1")]
  public async Task Missing_or_unreachable_database_returns_safe_problems(string connection)
  {
    await using var factory = CreateFactory(connection);
    using var client = factory.CreateClient();
    foreach (var path in new[] { "/health/ready", "/api/catalog" })
    {
      var response = await client.GetAsync(path);
      Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
      Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
      Assert.True(response.Headers.CacheControl?.NoStore);
      var body = await response.Content.ReadAsStringAsync();
      Assert.Contains("Database is unavailable.", body);
      Assert.DoesNotContain("never-print-this", body);
      Assert.DoesNotContain("Npgsql", body);
      Assert.DoesNotContain("marketplace", body);
      Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/health")).StatusCode);
    }
  }

  [LocalDatabaseFact]
  [Trait("Category", "LocalDatabase")]
  public async Task Anonymous_catalog_and_readiness_use_real_local_database()
  {
    await using var factory = CreateFactory(LocalConnection);
    using var client = factory.CreateClient();
    var ready = await client.GetAsync("/health/ready");
    Assert.Equal(HttpStatusCode.OK, ready.StatusCode);

    var response = await client.GetAsync("/api/catalog");
    Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    Assert.True(response.Headers.CacheControl?.Public);
    var catalog = await response.Content.ReadFromJsonAsync<CatalogResponse>();
    Assert.NotNull(catalog);
    var furniture = Assert.Single(catalog.Categories, x => x.Slug == "demo-furniture");
    Assert.Equal("เฟอร์นิเจอร์ (ตัวอย่าง)", furniture.Name.Th);
    Assert.Equal("Мебель (демо)", furniture.Name.Ru);
    Assert.All(catalog.Developments, development => Assert.Contains(catalog.Areas, area => area.Id == development.AreaId));
    var body = await response.Content.ReadAsStringAsync();
    Assert.DoesNotContain("version", body);
    Assert.DoesNotContain("createdAt", body);
    Assert.DoesNotContain("ownerId", body);
    Assert.DoesNotContain("isActive", body);

    // The seed gives these fixtures sort orders 10, 20 and 30. Check their
    // relative API order without reconstructing the service's SQL query.
    var demoSlugs = new[] { "demo-furniture", "demo-electronics", "demo-household" };
    Assert.Equal(demoSlugs, catalog.Categories.Where(x => demoSlugs.Contains(x.Slug)).Select(x => x.Slug));
  }

  [LocalDatabaseFact]
  [Trait("Category", "LocalDatabase")]
  public async Task Runtime_login_has_no_inventory_or_write_privileges_even_without_read_only_default()
  {
    await using var connection = new NpgsqlConnection(LocalConnection);
    await connection.OpenAsync();
    Assert.Equal("17.11", connection.PostgreSqlVersion.ToString());
    await using (var command = new NpgsqlCommand("""
            select current_user = 'phuketsold_catalog_local'
                and not (rolsuper or rolcreatedb or rolcreaterole or rolreplication or rolbypassrls)
            from pg_roles where rolname = current_user
            """, connection))
    {
      Assert.Equal(true, await command.ExecuteScalarAsync());
    }
    await using (var command = new NpgsqlCommand("set default_transaction_read_only = off", connection))
      await command.ExecuteNonQueryAsync();

    foreach (var sql in new[] {
            "update marketplace.categories set name_en = name_en where false",
            "select 1 from marketplace.profiles limit 0",
            "select 1 from marketplace.listing_groups limit 0",
            "select 1 from marketplace.listings limit 0",
            "select 1 from marketplace.listing_images limit 0",
            "select 1 from marketplace.listing_events limit 0",
            "set role phuketsold_api"
        })
    {
      await using var command = new NpgsqlCommand(sql, connection);
      var error = await Assert.ThrowsAsync<PostgresException>(() => command.ExecuteNonQueryAsync());
      Assert.Equal(PostgresErrorCodes.InsufficientPrivilege, error.SqlState);
    }
  }

  [LocalDatabaseFact]
  [Trait("Category", "LocalDatabase")]
  public async Task EF_mappings_match_actual_SQL_columns_types_and_nullability()
  {
    await using var factory = CreateFactory(LocalConnection);
    await using var scope = factory.Services.CreateAsyncScope();
    var database = scope.ServiceProvider.GetRequiredService<PhuketSoldDbContext>();
    await using var connection = new NpgsqlConnection(LocalConnection);
    await connection.OpenAsync();
    foreach (var entity in database.Model.GetEntityTypes())
    {
      Assert.Equal("marketplace", entity.GetSchema());
      var table = StoreObjectIdentifier.Table(entity.GetTableName()!, entity.GetSchema());
      await using var command = new NpgsqlCommand("""
                select a.attname, format_type(a.atttypid, a.atttypmod), not a.attnotnull
                from pg_attribute a join pg_class c on c.oid = a.attrelid
                join pg_namespace n on n.oid = c.relnamespace
                where n.nspname = 'marketplace' and c.relname = @table and a.attnum > 0 and not a.attisdropped
                """, connection);
      command.Parameters.AddWithValue("table", table.Name);
      await using var reader = await command.ExecuteReaderAsync();
      var columns = new Dictionary<string, (string Type, bool Nullable)>();
      while (await reader.ReadAsync())
        columns.Add(reader.GetString(0), (reader.GetString(1), reader.GetBoolean(2)));
      Assert.Equal(columns.Keys.Order(), entity.GetProperties().Select(x => x.GetColumnName(table)!).Order());
      foreach (var property in entity.GetProperties())
      {
        var actual = columns[property.GetColumnName(table)!];
        Assert.Equal(actual.Type, property.GetColumnType());
        Assert.Equal(actual.Nullable, property.IsNullable);
      }
    }
  }

  private static string LocalConnection
  {
    get
    {
      var connection = Environment.GetEnvironmentVariable("PHUKETSOLD_TEST_CONNECTION")!;
      var settings = new NpgsqlConnectionStringBuilder(connection);
      Assert.Equal("127.0.0.1", settings.Host);
      Assert.Equal(54322, settings.Port);
      Assert.Equal("postgres", settings.Database);
      Assert.Equal("phuketsold_catalog_local", settings.Username);
      return connection;
    }
  }

  private static WebApplicationFactory<Program> CreateFactory(string connection) =>
      new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
      {
        builder.UseEnvironment("Testing");
        builder.UseSetting("ConnectionStrings:Marketplace", connection);
      });
}

public sealed class LocalDatabaseFactAttribute : FactAttribute
{
  public LocalDatabaseFactAttribute()
  {
    if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("PHUKETSOLD_TEST_CONNECTION")))
      Skip = "Run npm run api:check to verify against local Supabase.";
  }
}
