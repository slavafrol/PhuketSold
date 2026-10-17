using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace PhuketSold.Api.Data;

// Runtime mapping only. SQL migrations own constraints, indexes, triggers and RLS.
public sealed class PhuketSoldDbContext(DbContextOptions<PhuketSoldDbContext> options) : DbContext(options)
{
  public DbSet<Profile> Profiles => Set<Profile>();
  public DbSet<Category> Categories => Set<Category>();
  public DbSet<Area> Areas => Set<Area>();
  public DbSet<Development> Developments => Set<Development>();
  public DbSet<ListingGroup> ListingGroups => Set<ListingGroup>();
  public DbSet<Listing> Listings => Set<Listing>();
  public DbSet<ListingImage> ListingImages => Set<ListingImage>();
  public DbSet<ListingEvent> ListingEvents => Set<ListingEvent>();

  protected override void OnModelCreating(ModelBuilder modelBuilder)
  {
    var profiles = Versioned<Profile>(modelBuilder, "profiles");
    // Identity belongs to auth.users, which this application does not manage.
    profiles.Property(x => x.Id).ValueGeneratedNever();

    Reference<Category>(modelBuilder, "categories");
    Reference<Area>(modelBuilder, "areas");
    var developments = Reference<Development>(modelBuilder, "developments");
    developments.Property(x => x.Kind).HasDefaultValue("development");
    developments.HasAlternateKey(x => new { x.Id, x.AreaId });
    developments.HasOne<Area>().WithMany().HasForeignKey(x => x.AreaId).OnDelete(DeleteBehavior.Restrict);

    var groups = Versioned<ListingGroup>(modelBuilder, "listing_groups");
    groups.HasAlternateKey(x => new { x.Id, x.OwnerId, x.ListingType });
    groups.HasOne<Profile>().WithMany().HasForeignKey(x => x.OwnerId).OnDelete(DeleteBehavior.Restrict);
    groups.HasOne<Area>().WithMany().HasForeignKey(x => x.AreaId).OnDelete(DeleteBehavior.Restrict);
    groups.HasOne<Development>().WithMany().HasForeignKey(x => new { x.DevelopmentId, x.AreaId })
        .HasPrincipalKey(x => new { x.Id, x.AreaId }).OnDelete(DeleteBehavior.Restrict);

    var listings = Versioned<Listing>(modelBuilder, "listings");
    listings.HasOne<Profile>().WithMany().HasForeignKey(x => x.OwnerId).OnDelete(DeleteBehavior.Restrict);
    listings.HasOne<Category>().WithMany().HasForeignKey(x => x.CategoryId).OnDelete(DeleteBehavior.Restrict);
    listings.HasOne<Area>().WithMany().HasForeignKey(x => x.AreaId).OnDelete(DeleteBehavior.Restrict);
    listings.HasOne<ListingGroup>().WithMany().HasForeignKey(x => new { x.GroupId, x.OwnerId, x.ListingType })
        .HasPrincipalKey(x => new { x.Id, x.OwnerId, x.ListingType }).OnDelete(DeleteBehavior.Restrict);
    listings.HasOne<Development>().WithMany().HasForeignKey(x => new { x.DevelopmentId, x.AreaId })
        .HasPrincipalKey(x => new { x.Id, x.AreaId }).OnDelete(DeleteBehavior.Restrict);
    // The lifecycle trigger assigns first publication time, expiry and archive time.
    listings.Property(x => x.PublishedAt).ValueGeneratedOnAddOrUpdate();
    listings.Property(x => x.ExpiresAt).ValueGeneratedOnAddOrUpdate();
    listings.Property(x => x.ArchivedAt).ValueGeneratedOnAddOrUpdate();

    var images = Versioned<ListingImage>(modelBuilder, "listing_images");
    images.HasOne<Listing>().WithMany().HasForeignKey(x => x.ListingId).OnDelete(DeleteBehavior.Restrict);

    var events = modelBuilder.Entity<ListingEvent>();
    events.ToTable("listing_events", "marketplace", table => table.ExcludeFromMigrations());
    events.HasKey(x => x.Id);
    events.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
    events.Property(x => x.CreatedAt).HasDefaultValueSql("statement_timestamp()");
    events.Property(x => x.ChangedFields).HasColumnType("text[]");
    events.HasOne<Listing>().WithMany().HasForeignKey(x => x.ListingId).OnDelete(DeleteBehavior.Restrict);
    events.HasOne<Profile>().WithMany().HasForeignKey(x => x.ActorId).OnDelete(DeleteBehavior.Restrict);

    foreach (var entity in modelBuilder.Model.GetEntityTypes())
    {
      foreach (var property in entity.GetProperties())
      {
        property.SetColumnName(Regex.Replace(property.Name, "([a-z0-9])([A-Z])", "$1_$2").ToLowerInvariant());
        // SQL uses text + CHECKs, not varchar or provider enum types.
        if (property.ClrType == typeof(string)) property.SetColumnType("text");
      }
    }
  }

  private static EntityTypeBuilder<T> Versioned<T>(ModelBuilder modelBuilder, string tableName)
      where T : class, IVersionedRow
  {
    var entity = modelBuilder.Entity<T>();
    entity.ToTable(tableName, "marketplace", table => table.ExcludeFromMigrations());
    entity.HasKey(x => x.Id);
    entity.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
    entity.Property(x => x.CreatedAt).HasDefaultValueSql("statement_timestamp()");
    entity.Property(x => x.UpdatedAt).ValueGeneratedOnAddOrUpdate();
    entity.Property(x => x.Version).IsConcurrencyToken().ValueGeneratedOnAddOrUpdate();
    return entity;
  }

  private static EntityTypeBuilder<T> Reference<T>(ModelBuilder modelBuilder, string tableName)
      where T : class, ILocalizedReference
  {
    var entity = Versioned<T>(modelBuilder, tableName);
    entity.Property(x => x.IsActive).HasDefaultValue(true);
    return entity;
  }
}
