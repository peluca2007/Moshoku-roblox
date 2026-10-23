# Lança o Codex CLI com um brief de build/codex/<Nome>.md, em segundo plano ou não.
# Uso: powershell -File tools/codex.ps1 -Brief V1 [-Modelo gpt-6.1-sol] [-SoLeitura]
# Saída: build/codex/<Nome>.out (resposta final) e build/codex/<Nome>.log (tudo).
# O binário do app muda de pasta a cada atualização; aqui ele é procurado pelo mais novo.
param(
    [Parameter(Mandatory = $true)][string]$Brief,
    [string]$Modelo = 'gpt-6.1-sol',
    [switch]$SoLeitura
)
$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
$arquivo = Join-Path $raiz "build/codex/$Brief.md"
if (-not (Test-Path $arquivo)) { throw "Brief não encontrado: $arquivo" }
$exe = Get-ChildItem "$env:LOCALAPPDATA/OpenAI/Codex/bin" -Recurse -Filter codex.exe |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $exe) { throw 'codex.exe do app não encontrado em AppData/Local/OpenAI/Codex/bin' }
$sandbox = if ($SoLeitura) { 'read-only' } else { 'workspace-write' }
$saida = Join-Path $raiz "build/codex/$Brief.out"
$log = Join-Path $raiz "build/codex/$Brief.log"
# No PowerShell 5.1, `Get-Content | codex.exe -` não fecha a entrada e o Codex nunca começa;
# por isso o brief vai por redirecionamento de arquivo.
$erros = Join-Path $raiz "build/codex/$Brief.err.log"
$argumentos = @('exec', '-m', $Modelo, '--skip-git-repo-check', '-c', 'windows.sandbox=unelevated',
    '--sandbox', $sandbox, '-o', "`"$saida`"", '-')
$processo = Start-Process -FilePath $exe.FullName -ArgumentList $argumentos -WorkingDirectory $raiz `
    -RedirectStandardInput $arquivo -RedirectStandardOutput $log -RedirectStandardError $erros `
    -NoNewWindow -Wait -PassThru
Write-Output "codex terminou ($Brief), código $($processo.ExitCode): $saida"
