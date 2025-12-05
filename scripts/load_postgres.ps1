# scripts/load_postgres.ps1
$ErrorActionPreference = "Stop"

docker compose up -d db

# Wait for healthcheck to pass
Write-Host "Waiting for Postgres to become ready..."
$ready = $false
for ($i=0; $i -lt 30; $i++) {
  $out = docker compose exec -T db bash -lc "pg_isready -U health -d healthcare" 2>$null
  if ($LASTEXITCODE -eq 0) { $ready = $true; break }
  Start-Sleep -Seconds 2
}
if (-not $ready) { throw "Postgres did not become ready in time." }

Write-Host "Applying schema..."
docker compose exec -T db psql -U health -d healthcare -f /workspace/sql/schema_postgres.sql

Write-Host "Loading CSV data..."
docker compose exec -T db psql -U health -d healthcare -f /workspace/sql/load_data.psql

Write-Host "Running sanity checks..."
docker compose exec -T db psql -U health -d healthcare -f /workspace/sql/sanity_checks.sql

Write-Host "Done ✅"
