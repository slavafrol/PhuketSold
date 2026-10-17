namespace PhuketSold.Api.Features.Catalog;

public sealed record LocalizedName(string En, string Th, string Ru);
public sealed record CatalogItem(Guid Id, string Slug, LocalizedName Name);
public sealed record DevelopmentItem(Guid Id, Guid AreaId, string Slug, string Kind, LocalizedName Name);
public sealed record CatalogResponse(
    IReadOnlyList<CatalogItem> Categories,
    IReadOnlyList<CatalogItem> Areas,
    IReadOnlyList<DevelopmentItem> Developments);
