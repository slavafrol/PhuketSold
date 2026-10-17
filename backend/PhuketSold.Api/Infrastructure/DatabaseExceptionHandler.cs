using Microsoft.AspNetCore.Diagnostics;
using Npgsql;

namespace PhuketSold.Api.Infrastructure;

public sealed class DatabaseExceptionHandler(IConfiguration configuration, ILogger<DatabaseExceptionHandler> logger) : IExceptionHandler
{
  public async ValueTask<bool> TryHandleAsync(HttpContext context, Exception exception, CancellationToken cancellationToken)
  {
    var missingConfiguration = exception is InvalidOperationException &&
        string.IsNullOrWhiteSpace(configuration.GetConnectionString("Marketplace"));
    var providerFailure = exception is NpgsqlException or TimeoutException or
        InvalidOperationException { InnerException: NpgsqlException or TimeoutException };
    if (!providerFailure && !missingConfiguration) return false;

    logger.LogWarning("Database request failed ({FailureType}); trace {TraceId}", exception.GetType().Name, context.TraceIdentifier);
    context.Response.Headers.CacheControl = "no-store";
    await Results.Problem(statusCode: StatusCodes.Status503ServiceUnavailable,
        title: "Database is unavailable.").ExecuteAsync(context);
    return true;
  }
}
