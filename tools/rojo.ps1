param([ValidateRange(1024, 65535)][int]$Porta = 34872)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$projectFile = Join-Path $projectRoot 'default.project.json'
$rojoCommand = Get-Command rojo -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$rojoPath = if ($rojoCommand) { $rojoCommand.Source } else { $null }

# Aftman pode estar instalado sem aparecer no PATH do editor/terminal atual.
if (-not $rojoPath) {
    foreach ($relative in @('.aftman\bin\rojo.exe', '.rokit\bin\rojo.exe')) {
        $candidate = Join-Path $env:USERPROFILE $relative
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $rojoPath = $candidate
            break
        }
    }
}
if (-not $rojoPath) {
    throw 'Rojo nao encontrado. Instale a CLI ou use Rojo: Open menu na extensao do VS Code.'
}
if (-not (Test-Path -LiteralPath $projectFile -PathType Leaf)) {
    throw "Projeto nao encontrado: $projectFile"
}

# Evita iniciar outro servidor quando a tarefa já está rodando em outro terminal.
$serverInfo = $null
try {
    $serverInfo = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$Porta/api/rojo" -TimeoutSec 2
} catch {
    # Sem servidor nesta porta: o comando serve abaixo fará a inicialização.
}
if ($serverInfo) {
    $projectName = (Get-Content -LiteralPath $projectFile -Raw | ConvertFrom-Json).name
    $serverText = if ($serverInfo.Content -is [byte[]]) {
        [System.Text.Encoding]::UTF8.GetString($serverInfo.Content)
    } else { [string]$serverInfo.Content }
    if (-not $serverText.Contains($projectName)) {
        throw "A porta $Porta ja atende outro projeto. Use -Porta com uma porta livre."
    }
    Write-Host "Servidor deste projeto ja ativo. No plugin Rojo, conecte a localhost:$Porta."
    return
}

Push-Location -LiteralPath $projectRoot
try {
    Write-Host "Sincronizacao: no plugin Rojo do Studio, conecte a localhost:$Porta."
    & $rojoPath serve $projectFile --address 127.0.0.1 --port $Porta
    if ($LASTEXITCODE -ne 0) { throw "Rojo terminou com codigo $LASTEXITCODE. Confira o erro acima." }
} finally {
    Pop-Location
}
