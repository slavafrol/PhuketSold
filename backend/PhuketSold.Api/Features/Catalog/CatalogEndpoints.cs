namespace PhuketSold.Api.Features.Catalog;

public static class CatalogEndpoints
{
  public static IEndpointRouteBuilder MapCatalogEndpoints(this IEndpointRouteBuilder endpoints)
  {
    endpoints.MapGet("/api/catalog", async (CatalogService service, HttpContext context, CancellationToken cancellationToken) =>
    {
      var catalog = await service.GetAsync(cancellationToken);
      context.Response.Headers.CacheControl = "public, max-age=60";
      return TypedResults.Ok(catalog);
    }).AllowAnonymous().Produces<CatalogResponse>().ProducesProblem(StatusCodes.Status503ServiceUnavailable);
    return endpoints;
  }
}
