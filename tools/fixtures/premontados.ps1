# Gera src/server/Premontados.luau com o exportador do site (personagens fictícios).
param([switch]$SemEsbuild)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$site = if ($env:MOSHOKU_SITE) { $env:MOSHOKU_SITE } else { Join-Path (Split-Path $projectRoot -Parent) 'Moshoku tensei rpg' }
$site = (Resolve-Path -LiteralPath $site).Path
$env:MOSHOKU_SITE = $site
$script = Join-Path $PSScriptRoot 'premontados.mts'
Push-Location -LiteralPath $site
try {
    if ($SemEsbuild) {
        # Sandbox Windows pode recusar o subprocesso de transformação (spawn EPERM).
        $loaderA17 = [Uri]::new((Join-Path $projectRoot 'tools\playtest\a17_loader.mjs')).AbsoluteUri
        & node --import $loaderA17 $script @args
    } else {
        & node (Join-Path $site 'node_modules\tsx\dist\cli.mjs') --tsconfig (Join-Path $site 'tsconfig.json') $script @args
    }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally { Pop-Location }
