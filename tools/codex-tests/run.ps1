param([Parameter(Mandatory=$true)][string]$LuauDirectory)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$runtime = Join-Path $LuauDirectory 'luau.exe'
$compiler = Join-Path $LuauDirectory 'luau-compile.exe'
foreach ($executable in @($runtime, $compiler)) {
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw "Executavel nao encontrado: $executable" }
}
$suites = @('Dice', 'MesaProtocol', 'MesaSave', 'FichaImport')
$testDir = Join-Path $env:TEMP ('moshoku-codex-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testDir | Out-Null
Push-Location -LiteralPath $projectRoot
try {
    $sources = @('src/client/MesaPanel.luau')
    foreach ($suite in $suites) { $sources += "src/shared/$suite.luau", "src/server/tests/$suite.spec.luau" }
    foreach ($relative in $sources) {
        & $compiler $relative | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Falha de sintaxe: $relative" }
        Write-Output "Sintaxe OK: $relative"
    }
} finally { Pop-Location }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'roblox-types.luau') -Destination $testDir
# Adapta apenas imports e injeta os dois tipos simulados na copia temporaria.
# Nenhuma copia volta para src; os specs e algoritmos sao os originais.
$typePrelude = "local RobloxTypes = require(`"./roblox-types`")`nlocal Vector3, Color3 = RobloxTypes.Vector3, RobloxTypes.Color3`n"
foreach ($suite in $suites) {
    foreach ($source in @("src/shared/$suite.luau", "src/server/tests/$suite.spec.luau")) {
        $adapted = [IO.File]::ReadAllText((Join-Path $projectRoot $source))
        $adapted = $adapted.Replace('local Shared = game:GetService("ReplicatedStorage").Shared', '')
        foreach ($dependency in $suites) {
            $adapted = $adapted.Replace(('require(game:GetService("ReplicatedStorage").Shared.' + $dependency + ')'), ('require("./' + $dependency + '")'))
            $adapted = $adapted.Replace(('require(Shared.' + $dependency + ')'), ('require("./' + $dependency + '")'))
        }
        if ($adapted.Contains('game:GetService')) { throw "Import Roblox nao adaptado: $source" }
        $filename = if ($source.Contains('/tests/')) { "$($suite)Spec.luau" } else { "$suite.luau" }
        [IO.File]::WriteAllText((Join-Path $testDir $filename), $typePrelude + $adapted)
    }
}
$runner = @'
local suites = {
 {"Dice", require("./DiceSpec")},
 {"MesaProtocol", require("./MesaProtocolSpec")},
 {"MesaSave", require("./MesaSaveSpec")},
 {"FichaImport", require("./FichaImportSpec")},
}
local t = {
 eq=function(a,b,msg) assert(a==b, (msg or "").." esperado "..tostring(b)..", obtido "..tostring(a)) end,
 ok=function(a,msg) assert(a,msg or "condição falsa") end,
 fails=function(fn,msg) assert(not pcall(fn),msg or "era esperado erro") end,
}
local passed,failed=0,0
for _,suite in suites do
 local suitePassed,suiteFailed=0,0
 for name,fn in suite[2] do
  local ok,err=pcall(fn,t)
  if ok then suitePassed+=1 else suiteFailed+=1; print("FALHA",suite[1],name,err) end
 end
 passed+=suitePassed; failed+=suiteFailed
 print(suite[1]..":",suitePassed,"ok,",suiteFailed,"falhas")
end
print("Total:",passed,"ok,",failed,"falhas")
assert(failed==0,"Specs falharam")
'@
[IO.File]::WriteAllText((Join-Path $testDir 'specs-run.luau'), $runner)
& $runtime (Join-Path $testDir 'specs-run.luau')
if ($LASTEXITCODE -ne 0) { throw 'Falha nos specs' }
$panel = [IO.File]::ReadAllText((Join-Path $projectRoot 'src/client/MesaPanel.luau'))
$fixture = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'panel-fixture.luau'))
[IO.File]::WriteAllText((Join-Path $testDir 'panel-run.luau'), $fixture.Replace('-- PANEL_SOURCE', $panel))
& $runtime (Join-Path $testDir 'panel-run.luau')
if ($LASTEXITCODE -ne 0) { throw 'Falha no teste de callbacks do painel' }
Write-Output 'Verificacoes concluidas; layout e integracao Roblox dependem de playtest.'
