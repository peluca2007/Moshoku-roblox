# Gera tools/fixtures/ficha-v2-aria.json com o exportador do site (ficha fictícia).
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$site = if ($env:MOSHOKU_SITE) { $env:MOSHOKU_SITE } else { Join-Path (Split-Path $projectRoot -Parent) 'Moshoku tensei rpg' }
$site = (Resolve-Path -LiteralPath $site).Path
$env:MOSHOKU_SITE = $site
$script = Join-Path $PSScriptRoot 'ficha-v2-aria.mts'
Push-Location -LiteralPath $site
try {
    & node (Join-Path $site 'node_modules\tsx\dist\cli.mjs') --tsconfig (Join-Path $site 'tsconfig.json') $script @args
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally { Pop-Location }
