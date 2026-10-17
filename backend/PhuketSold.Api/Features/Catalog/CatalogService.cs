using Microsoft.EntityFrameworkCore;
using PhuketSold.Api.Data;

namespace PhuketSold.Api.Features.Catalog;

public sealed class CatalogService(PhuketSoldDbContext database)
{
  public async Task<CatalogResponse> GetAsync(CancellationToken cancellationToken)
  {
    // Curated reference data is deliberately returned together for runtime
    // language switching. Inventory browsing gets separate keyset pagination.
    var categories = await database.Categories.AsNoTracking().Where(x => x.IsActive)
        .OrderBy(x => x.SortOrder).ThenBy(x => x.Slug).ThenBy(x => x.Id)
        .Select(x => new CatalogItem(x.Id, x.Slug, new LocalizedName(x.NameEn, x.NameTh, x.NameRu)))
        .ToListAsync(cancellationToken);
    var areas = await database.Areas.AsNoTracking().Where(x => x.IsActive)
        .OrderBy(x => x.SortOrder).ThenBy(x => x.Slug).ThenBy(x => x.Id)
        .Select(x => new CatalogItem(x.Id, x.Slug, new LocalizedName(x.NameEn, x.NameTh, x.NameRu)))
        .ToListAsync(cancellationToken);
    var developments = await database.Developments.AsNoTracking()
        .Where(x => x.IsActive && database.Areas.Any(area => area.Id == x.AreaId && area.IsActive))
        .OrderBy(x => x.Slug).ThenBy(x => x.Id)
        .Select(x => new DevelopmentItem(x.Id, x.AreaId, x.Slug, x.Kind, new LocalizedName(x.NameEn, x.NameTh, x.NameRu)))
        .ToListAsync(cancellationToken);

    return new CatalogResponse(categories, areas, developments);
  }
}
