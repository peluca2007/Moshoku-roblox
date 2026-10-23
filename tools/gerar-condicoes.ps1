# Gera src/shared/Condicoes.luau a partir do site (somente leitura).
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$site = if ($env:MOSHOKU_SITE) { $env:MOSHOKU_SITE } else { Join-Path (Split-Path $projectRoot -Parent) 'Moshoku tensei rpg' }
$site = (Resolve-Path -LiteralPath $site).Path
$env:MOSHOKU_SITE = $site
$script = Join-Path $PSScriptRoot 'gerar-condicoes.mts'
Push-Location -LiteralPath $site
try {
    & node (Join-Path $site 'node_modules\tsx\dist\cli.mjs') --tsconfig (Join-Path $site 'tsconfig.json') $script
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally { Pop-Location }
