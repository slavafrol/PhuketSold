namespace PhuketSold.Api.Data;

public interface IVersionedRow
{
  Guid Id { get; set; }
  DateTimeOffset CreatedAt { get; set; }
  DateTimeOffset UpdatedAt { get; set; }
  long Version { get; set; }
}

public interface ILocalizedReference : IVersionedRow
{
  string Slug { get; set; }
  string NameEn { get; set; }
  string NameTh { get; set; }
  string NameRu { get; set; }
  bool IsActive { get; set; }
}

public sealed class Profile : IVersionedRow
{
  public Guid Id { get; set; }
  public string DisplayName { get; set; } = "";
  public string PreferredLanguage { get; set; } = "en";
  public DateTimeOffset? ArchivedAt { get; set; }
  public DateTimeOffset CreatedAt { get; set; }
  public DateTimeOffset UpdatedAt { get; set; }
  public long Version { get; set; }
}

public sealed class Category : ILocalizedReference
{
  public Guid Id { get; set; }
  public string Slug { get; set; } = "";
  public string NameEn { get; set; } = "";
  public string NameTh { get; set; } = "";
  public string NameRu { get; set; } = "";
  public bool IsActive { get; set; }
  public int SortOrder { get; set; }
  public DateTimeOffset CreatedAt { get; set; }
  public DateTimeOffset UpdatedAt { get; set; }
  public long Version { get; set; }
}

public sealed class Area : ILocalizedReference
{
  public Guid Id { get; set; }
  public string Slug { get; set; } = "";
  public string NameEn { get; set; } = "";
  public string NameTh { get; set; } = "";
  public string NameRu { get; set; } = "";
  public bool IsActive { get; set; }
  public int SortOrder { get; set; }
  public DateTimeOffset CreatedAt { get; set; }
  public DateTimeOffset UpdatedAt { get; set; }
  public long Version { get; set; }
}

public sealed class Development : ILocalizedReference
{
  public Guid Id { get; set; }
  public Guid AreaId { get; set; }
  public string Slug { get; set; } = "";
  public string NameEn { get; set; } = "";
  public string NameTh { get; set; } = "";
  public string NameRu { get; set; } = "";
  public string Kind { get; set; } = "development";
  public bool IsActive { get; set; }
  public DateTimeOffset CreatedAt { get; set; }
  public DateTimeOffset UpdatedAt { get; set; }
  public long Version { get; set; }
}

public sealed class ListingGroup : IVersionedRow
{
  public Guid Id { get; set; }
  public Guid OwnerId { get; set; }
  public string ListingType { get; set; } = "";
  public string? Slug { get; set; }
  public string Title { get; set; } = "";
  public string Description { get; set; } = "";
  public string SourceLanguage { get; set; } = "en";
  public Guid? AreaId { get; set; }
  public Guid? DevelopmentId { get; set; }
  public DateTimeOffset? AvailableUntil { get; set; }
  public DateTimeOffset? ArchivedAt { get; set; }
  public DateTimeOffset CreatedAt { get; set; }
  public DateTimeOffset UpdatedAt { get; set; }
  public long Version { get; set; }
}

public sealed class Listing : IVersionedRow
{
  public Guid Id { get; set; }
  public Guid OwnerId { get; set; }
  public string ListingType { get; set; } = "";
  public Guid? GroupId { get; set; }
  public string? Slug { get; set; }
  public string? Title { get; set; }
  public string Description { get; set; } = "";
  public string SourceLanguage { get; set; } = "en";
  public Guid? CategoryId { get; set; }
  public long? PriceThb { get; set; }
  public string? ItemCondition { get; set; }
  public Guid? AreaId { get; set; }
  public Guid? DevelopmentId { get; set; }
  public string Status { get; set; } = "draft";
  public DateTimeOffset? PublishedAt { get; set; }
  public DateTimeOffset? ExpiresAt { get; set; }
  public DateTimeOffset? ArchivedAt { get; set; }
  public DateTimeOffset? HiddenAt { get; set; }
  public DateTimeOffset CreatedAt { get; set; }
  public DateTimeOffset UpdatedAt { get; set; }
  public long Version { get; set; }
}

public sealed class ListingImage : IVersionedRow
{
  public Guid Id { get; set; }
  public Guid ListingId { get; set; }
  public short Position { get; set; }
  public bool IsCover { get; set; }
  public string StorageBucket { get; set; } = "";
  public string StoragePath { get; set; } = "";
  public string? ThumbnailPath { get; set; }
  public string? CardPath { get; set; }
  public string? DisplayPath { get; set; }
  public string ContentType { get; set; } = "";
  public int Width { get; set; }
  public int Height { get; set; }
  public long ByteSize { get; set; }
  public string ProcessingStatus { get; set; } = "pending";
  public DateTimeOffset CreatedAt { get; set; }
  public DateTimeOffset UpdatedAt { get; set; }
  public long Version { get; set; }
}

public sealed class ListingEvent
{
  public Guid Id { get; set; }
  public Guid ListingId { get; set; }
  public Guid? ActorId { get; set; }
  public string EventType { get; set; } = "";
  public string? OldStatus { get; set; }
  public string NewStatus { get; set; } = "";
  public long ListingVersion { get; set; }
  public string[] ChangedFields { get; set; } = [];
  public DateTimeOffset CreatedAt { get; set; }
}
