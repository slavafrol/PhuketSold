using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace PhuketSold.Api.Infrastructure;

public static class HealthEndpoints
{
  public static IEndpointRouteBuilder MapHealthEndpoints(this IEndpointRouteBuilder endpoints)
  {
    endpoints.MapGet("/health", () => Results.Ok(new { status = "healthy" })).AllowAnonymous();
    endpoints.MapHealthChecks("/health/ready", new HealthCheckOptions
    {
      Predicate = check => check.Tags.Contains("ready"),
      ResponseWriter = async (context, report) =>
      {
        context.Response.Headers.CacheControl = "no-store";
        if (report.Status == HealthStatus.Healthy)
          await context.Response.WriteAsJsonAsync(new { status = "ready" }, context.RequestAborted);
        else
          await Results.Problem(statusCode: StatusCodes.Status503ServiceUnavailable,
                    title: "Database is unavailable.").ExecuteAsync(context);
      }
    }).AllowAnonymous();
    return endpoints;
  }
}
