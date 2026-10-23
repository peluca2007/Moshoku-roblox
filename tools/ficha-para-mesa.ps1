# Gera o código de mesa de uma ficha do site e copia para a área de transferência.
# Uso: powershell -File tools/ficha-para-mesa.ps1 <arquivo .mtficha/.json | link>
# O site original é só lido; ver tools/ficha-para-mesa.mts e docs/MESA.md.
param([Parameter(Mandatory = $true)][string]$Ficha)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$site = if ($env:MOSHOKU_SITE) { $env:MOSHOKU_SITE } else { Join-Path (Split-Path $projectRoot -Parent) 'Moshoku tensei rpg' }
# Absoluto antes de trocar de pasta: um caminho relativo mudaria de sentido depois.
if (-not (Test-Path -LiteralPath $site)) { throw "Pasta do site não encontrada: $site" }
$site = (Resolve-Path -LiteralPath $site).Path
$tsx = Join-Path $site 'node_modules\tsx\dist\cli.mjs'
if (-not (Test-Path -LiteralPath $tsx)) {
    throw "tsx não encontrado em $tsx. Rode 'npm install' na pasta do site ou defina MOSHOKU_SITE."
}
$env:MOSHOKU_SITE = $site
if (Test-Path -LiteralPath $Ficha) { $Ficha = (Resolve-Path -LiteralPath $Ficha).Path }
$script = Join-Path $PSScriptRoot 'ficha-para-mesa.mts'

# O Node escreve UTF-8; o console do Windows costuma estar em ibm850 e
# corromperia nomes acentuados na captura (verificado: "Irmão" virava "Irm├úo").
$encodingAnterior = [Console]::OutputEncoding
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
Push-Location -LiteralPath $site
try {
    # Diagnósticos do Node vão para stderr; sucesso é decidido pelo código de saída.
    $ErrorActionPreference = 'Continue'
    $codigo = & node $tsx --tsconfig (Join-Path $site 'tsconfig.json') $script $Ficha
    $saida = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
} finally {
    Pop-Location
    [Console]::OutputEncoding = $encodingAnterior
}
if ($saida -ne 0) { exit $saida }
$linha = ($codigo | Select-Object -Last 1)
Set-Clipboard -Value $linha
Write-Output ''
Write-Output $linha
Write-Output ''
Write-Output 'Código copiado. No Roblox: painel do mestre > Colar código de ficha.'
