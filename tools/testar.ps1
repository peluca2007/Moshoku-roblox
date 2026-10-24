# Verificação automática fora do Studio: compila todo src e roda os specs de
# módulos puros e a simulação do painel. Não substitui o playtest no Studio
# (serviços do Roblox, rede, render); ver docs/TESTES.md.
# Uso: powershell -File tools/testar.ps1 [-LuauDirectory <pasta com luau.exe>]
param([string]$LuauDirectory)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent

function Test-LuauDirectory([string]$Directory) {
    if ([string]::IsNullOrWhiteSpace($Directory)) { return $false }
    try {
        return (Test-Path -LiteralPath (Join-Path $Directory 'luau.exe') -PathType Leaf) -and
            (Test-Path -LiteralPath (Join-Path $Directory 'luau-compile.exe') -PathType Leaf)
    } catch {
        return $false
    }
}

# Valores explicitamente informados têm precedência e erro claro; nunca ocultar
# um caminho inválido usando um fallback automático.
$explicitLuauDirectory = $null
$hasExplicitLuauDirectory = $false
if ($PSBoundParameters.ContainsKey('LuauDirectory')) {
    $explicitLuauDirectory = $LuauDirectory
    $hasExplicitLuauDirectory = $true
} elseif (-not [string]::IsNullOrWhiteSpace($env:LUAU_DIR)) {
    $explicitLuauDirectory = $env:LUAU_DIR
    $hasExplicitLuauDirectory = $true
}
if ($hasExplicitLuauDirectory) {
    if (-not (Test-LuauDirectory $explicitLuauDirectory)) {
        throw "Luau foi configurado explicitamente, mas luau.exe e luau-compile.exe não foram encontrados em '$explicitLuauDirectory'. Corrija -LuauDirectory ou LUAU_DIR."
    }
    $LuauDirectory = $explicitLuauDirectory
} else {
    $luauCandidates = @()
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $luauCandidates += Join-Path $env:LOCALAPPDATA 'moshoku-luau-0.741'
    }
    $userProfile = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    if (-not [string]::IsNullOrWhiteSpace($userProfile)) {
        $luauCandidates += Join-Path $userProfile 'AppData\Local\Temp\moshoku-luau-0.741'
    }
    $LuauDirectory = $luauCandidates | Where-Object { Test-LuauDirectory $_ } | Select-Object -First 1
    if (-not $LuauDirectory) {
        throw ("Luau não encontrado. Procurados: {0}. Baixe luau-windows.zip da release oficial 0.741 " -f ($luauCandidates -join ', ') +
        "(https://github.com/luau-lang/luau/releases/tag/0.741; sha256 be90c3223f3dc26777ef234244c2b1eae16b3c574f1ab7d1446972f72c28cab1) " +
        "e extraia nessa pasta, ou use -LuauDirectory.")
}
}
$LuauDirectory = [IO.Path]::GetFullPath($LuauDirectory)
$luau = Join-Path $LuauDirectory 'luau.exe'
$compiler = Join-Path $LuauDirectory 'luau-compile.exe'
$python = (Get-Command python -ErrorAction SilentlyContinue)
if (-not $python) { throw 'Python não encontrado no PATH (usado para montar os specs).' }

$tempRoot = [IO.Path]::GetFullPath($env:TEMP).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
$work = [IO.Path]::GetFullPath((Join-Path $tempRoot ('moshoku-testes-' + [guid]::NewGuid().ToString('N'))))
if ([IO.Path]::GetDirectoryName($work).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) -ne $tempRoot -or
    [IO.Path]::GetFileName($work) -notmatch '^moshoku-testes-[0-9a-f]{32}$') {
    throw "Pasta temporária insegura; limpeza cancelada: '$work' (raiz: '$tempRoot')."
}
New-Item -ItemType Directory -Path $work | Out-Null
$failures = 0
$ErrorActionPreference = 'Continue'
try {
    # 1. Sintaxe de todos os scripts.
    # Caminho relativo: o compilador não abre caminhos absolutos com acento ("Área de Trabalho").
    $sources = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'src') -Recurse -Filter '*.luau'
    $broken = 0
    Push-Location -LiteralPath $projectRoot
    try {
        foreach ($file in $sources) {
            $relative = $file.FullName.Substring($projectRoot.Length + 1)
            & $compiler $relative | Out-Null
            if ($LASTEXITCODE -ne 0) { $broken++; Write-Output "ERRO de sintaxe: $relative" }
        }
    } finally { Pop-Location }
    Write-Output ("Compilação: {0} arquivo(s), {1} com erro" -f $sources.Count, $broken)
    $failures += $broken

    # 2. Specs (só módulos puros rodam fora do Studio).
    $shared = Join-Path $projectRoot 'src\shared'
    $harness = Join-Path $PSScriptRoot 'testes\harness.py'
    foreach ($spec in Get-ChildItem -LiteralPath (Join-Path $projectRoot 'src\server\tests') -Filter '*.spec.luau') {
        # Specs marcados "SOMENTE STUDIO" dependem da hierarquia do Roblox; rodam pelo TestRunner no Studio.
        if ((Get-Content -LiteralPath $spec.FullName -TotalCount 1 -Encoding UTF8) -match 'SOMENTE STUDIO') { Write-Output "$($spec.Name): só no Studio"; continue }
        $runFile = Join-Path $work ($spec.BaseName + '.run.luau')
        & python $harness $runFile $spec.FullName $shared
        if ($LASTEXITCODE -ne 0) { $failures++; Write-Output "ERRO ao montar $($spec.Name)"; continue }
        $output = & $luau $runFile 2>&1
        $result = $output | Where-Object { "$_" -like 'RESULTADO*' } | Select-Object -Last 1
        $output | Where-Object { "$_" -like 'FALHA*' } | ForEach-Object { Write-Output "  $_" }
        if ($LASTEXITCODE -ne 0 -or -not $result) {
            $failures++
            Write-Output "$($spec.Name): não executou"
            $output | Select-Object -Last 5 | ForEach-Object { Write-Output "  $_" }
            continue
        }
        $parts = "$result" -split '\s+'
        Write-Output ("{0}: {1} ok, {2} falha(s)" -f $spec.Name, $parts[1], $parts[2])
        $failures += [int]$parts[2]
    }

    # P1: um prompt por NPC e coordenação de respostas tardias sem Studio.
    & python (Join-Path $PSScriptRoot 'testes\p1_npcs.py')
    if ($LASTEXITCODE -ne 0) { $failures++ }
    & python (Join-Path $PSScriptRoot 'testes\ui_p1_telas.py')
    if ($LASTEXITCODE -ne 0) { $failures++ }
    $p1NpcSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'codex-tests\p1-npcs-fixture.luau'), [Text.Encoding]::UTF8)
    $p1Estado = [IO.File]::ReadAllText((Join-Path $projectRoot 'src\client\DialogoNpcEstado.luau'), [Text.Encoding]::UTF8)
    $p1NpcRun = Join-Path $work 'p1-npcs.run.luau'
    [IO.File]::WriteAllText($p1NpcRun, $p1NpcSource.Replace('-- DIALOGO_ESTADO_SOURCE', $p1Estado), [Text.UTF8Encoding]::new($false))
    $output = & $luau $p1NpcRun 2>&1
    if ($LASTEXITCODE -ne 0) { $failures++; Write-Output 'P1 NPC: FALHA'; $output | Select-Object -Last 8 | ForEach-Object { Write-Output "$_" } }
    else { $output | ForEach-Object { Write-Output "$_" } }

    # U2: contrato de estilo das telas do mundo (inclui leitura UTF-8 das fontes).
    & python (Join-Path $PSScriptRoot 'testes\ui_u2.py')
    if ($LASTEXITCODE -ne 0) { $failures++ }

    # U4: contratos estáticos da entrada (sem Studio).
    & python (Join-Path $PSScriptRoot 'testes\ui_u4.py')
    if ($LASTEXITCODE -ne 0) { $failures++ }

    # U3: estilo UTF-8 e layout real da barra de ações com APIs falsas.
    & python (Join-Path $PSScriptRoot 'testes\ui_u3.py')
    if ($LASTEXITCODE -ne 0) { $failures++ }
    $u3Fixture = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'codex-tests\u3-fixture.luau'), [Text.Encoding]::UTF8)
    $u3Extra = [IO.File]::ReadAllText((Join-Path $projectRoot 'src\client\UI\ExtraCombate.luau'), [Text.Encoding]::UTF8)
    $u3Extra = $u3Extra.Replace('local T = require(script.Parent.Tema)', 'local T = tema').Replace('local C = require(script.Parent.Componentes)', 'local C = componentes')
    $u3Run = Join-Path $work 'u3.run.luau'
    [IO.File]::WriteAllText($u3Run, $u3Fixture.Replace('-- U3_EXTRA_SOURCE', $u3Extra), [Text.UTF8Encoding]::new($false))
    $output = & $luau $u3Run 2>&1
    if ($LASTEXITCODE -ne 0) { $failures++; Write-Output 'Interface U3: FALHA'; $output | Select-Object -Last 6 | ForEach-Object { Write-Output "  $_" } }
    else { $output | ForEach-Object { Write-Output "$_" } }

    # 2b. Catálogo do livro confere com o site (se o site estiver ao lado).
    $siteDir = if ($env:MOSHOKU_SITE) { $env:MOSHOKU_SITE } else { Join-Path (Split-Path $projectRoot -Parent) 'Moshoku tensei rpg' }
    if (Test-Path -LiteralPath (Join-Path $siteDir 'node_modules\tsx')) {
        $saida = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'gerar-catalogo.ps1') --verificar 2>&1
        if ($LASTEXITCODE -ne 0) {
            $failures++
            Write-Output 'Catálogo: FALHA'
            $saida | Select-Object -Last 3 | ForEach-Object { Write-Output "  $_" }
        } else {
            Write-Output 'Catálogo: confere com o site'
        }
    } else {
        Write-Output 'Catálogo: site não encontrado; verificação pulada'
    }

    # 3. Simulação do painel (APIs falsas; valida pedidos enviados, não o visual).
    $fixture = Join-Path $PSScriptRoot 'codex-tests\panel-fixture.luau'
    if (Test-Path -LiteralPath $fixture) {
        $panel = [IO.File]::ReadAllText((Join-Path $projectRoot 'src\client\MesaPanel.luau'))
        $runFile = Join-Path $work 'panel.run.luau'
        [IO.File]::WriteAllText($runFile, [IO.File]::ReadAllText($fixture).Replace('-- PANEL_SOURCE', $panel))
        $output = & $luau $runFile 2>&1
        if ($LASTEXITCODE -ne 0) {
            $failures++
            Write-Output 'Painel: FALHA'
            $output | Select-Object -Last 5 | ForEach-Object { Write-Output "  $_" }
        } else {
            Write-Output 'Painel: simulação ok'
        }
    }
    # U2. Interações da run/treinador/avisos com APIs falsas, sem Studio.
    $u2Fixture = Join-Path $PSScriptRoot 'codex-tests\u2-fixture.luau'
    $u2Source = [IO.File]::ReadAllText($u2Fixture, [Text.Encoding]::UTF8)
    foreach ($view in @(@('RUN', 'RunView'), @('TREINADOR', 'TreinadorView'), @('PROVACOES', 'ProvacoesView'), @('AVISOS', 'AvisosJogo'))) {
        $source = [IO.File]::ReadAllText((Join-Path $projectRoot ('src\client\' + $view[1] + '.luau')), [Text.Encoding]::UTF8)
        $u2Source = $u2Source.Replace(('-- U2_' + $view[0] + '_SOURCE'), $source)
    }
    $u2RunFile = Join-Path $work 'u2.run.luau'
    [IO.File]::WriteAllText($u2RunFile, $u2Source, [Text.UTF8Encoding]::new($false))
    $output = & $luau $u2RunFile 2>&1
    if ($LASTEXITCODE -ne 0) {
        $failures++
        Write-Output 'Interface U2: FALHA'
        $output | Select-Object -Last 8 | ForEach-Object { Write-Output "  $_" }
    } else { Write-Output 'Interface U2: simulação Run/Treinador/Avisos ok (APIs falsas)' }

    # 4. Cache da ficha e projeções do cliente (transporte simulado).
    $stateFixture = Join-Path $PSScriptRoot 'codex-tests\state-fixture.luau'
    if (Test-Path -LiteralPath $stateFixture) {
        $stateSource = [IO.File]::ReadAllText((Join-Path $projectRoot 'src\client\MesaState.luau'))
        $runFile = Join-Path $work 'state.run.luau'
        [IO.File]::WriteAllText($runFile, [IO.File]::ReadAllText($stateFixture).Replace('-- STATE_SOURCE', $stateSource))
        $output = & $luau $runFile 2>&1
        if ($LASTEXITCODE -ne 0) {
            $failures++
            Write-Output 'Estado do cliente: FALHA'
            $output | Select-Object -Last 5 | ForEach-Object { Write-Output "  $_" }
        } else { Write-Output 'Estado do cliente: simulação ok' }
    }
} finally {
    $workParent = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($work)).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    if ($workParent -eq $tempRoot -and [IO.Path]::GetFileName($work) -match '^moshoku-testes-[0-9a-f]{32}$') {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Write-Warning "Limpeza temporária cancelada por caminho fora da raiz esperada: '$work'."
    }
}
if ($failures -gt 0) {
    Write-Output "RESULTADO: $failures problema(s)"
    exit 1
}
Write-Output 'RESULTADO: tudo ok (fora do Studio)'
