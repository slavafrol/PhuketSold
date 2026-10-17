using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace PhuketSold.Api.Data;

public static class DatabaseRegistration
{
  public static IServiceCollection AddMarketplaceDatabase(this IServiceCollection services, IConfiguration configuration)
  {
    var connectionString = configuration.GetConnectionString("Marketplace");
    if (!string.IsNullOrWhiteSpace(connectionString))
    {
      var settings = new NpgsqlConnectionStringBuilder(connectionString)
      {
        IncludeErrorDetail = false,
        LogParameters = false,
        PersistSecurityInfo = false
      };
      connectionString = settings.ConnectionString;
    }

    services.AddDbContext<PhuketSoldDbContext>(options => options
        .UseNpgsql(connectionString, postgres => postgres.SetPostgresVersion(17, 11).CommandTimeout(5))
        .UseQueryTrackingBehavior(QueryTrackingBehavior.NoTracking));
    return services;
  }
}
