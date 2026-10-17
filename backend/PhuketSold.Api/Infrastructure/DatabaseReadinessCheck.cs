using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using PhuketSold.Api.Data;

namespace PhuketSold.Api.Infrastructure;

public sealed class DatabaseReadinessCheck(IServiceScopeFactory scopeFactory) : IHealthCheck
{
  public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
  {
    using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
    timeout.CancelAfter(TimeSpan.FromSeconds(5));
    try
    {
      await using var scope = scopeFactory.CreateAsyncScope();
      var database = scope.ServiceProvider.GetRequiredService<PhuketSoldDbContext>();
      // Check schema/SELECT permission as well as connectivity, including
      // when the catalog is empty. Do not probe with an administrator role.
      await database.Database.SqlQueryRaw<int>("""
                SELECT 1 AS "Value"
                WHERE EXISTS (SELECT 1 FROM marketplace.categories) OR
                      EXISTS (SELECT 1 FROM marketplace.areas) OR
                      EXISTS (SELECT 1 FROM marketplace.developments)
                """).ToListAsync(timeout.Token);
      return HealthCheckResult.Healthy();
    }
    catch (Exception) when (!cancellationToken.IsCancellationRequested)
    {
      // Health middleware must never serialize/log provider diagnostics.
      return HealthCheckResult.Unhealthy("Database is unavailable.");
    }
  }
}
