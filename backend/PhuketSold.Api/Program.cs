using PhuketSold.Api.Data;
using PhuketSold.Api.Features.Catalog;
using PhuketSold.Api.Infrastructure;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddMarketplaceDatabase(builder.Configuration);
builder.Services.AddScoped<CatalogService>();
builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<DatabaseExceptionHandler>();
builder.Services.AddHealthChecks().AddCheck<DatabaseReadinessCheck>("database", tags: ["ready"]);

var app = builder.Build();

app.UseExceptionHandler();
app.MapHealthEndpoints();
app.MapCatalogEndpoints();

app.Run();

// Allows the integration test host to use the real application composition.
public partial class Program;
