$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$document = New-Object System.Xml.XmlDocument
$root = $document.CreateElement('roblox')
$root.SetAttribute('version', '4')
$document.AppendChild($root) | Out-Null
function Add-Instance($parent, $class, $name, $sourcePath) {
    $item = $document.CreateElement('Item')
    $item.SetAttribute('class', $class)
    $item.SetAttribute('referent', [guid]::NewGuid().ToString())
    $properties = $document.CreateElement('Properties')
    $property = $document.CreateElement('string')
    $property.SetAttribute('name', 'Name')
    $property.InnerText = $name
    $properties.AppendChild($property) | Out-Null
    if ($sourcePath) {
        $source = $document.CreateElement('ProtectedString')
        $source.SetAttribute('name', 'Source')
        $source.InnerText = [IO.File]::ReadAllText((Join-Path $projectRoot $sourcePath))
        $properties.AppendChild($source) | Out-Null
    }
    $item.AppendChild($properties) | Out-Null
    $parent.AppendChild($item) | Out-Null
    return $item
}
# Propriedade tipada simples no XML do .rbxlx (token, bool, float, Color3). `Color3` recebe
# o valor como 'R,G,B' em 0-255 e grava os canais em 0-1, como o Studio.
function Add-Property($item, $type, $name, $value) {
    $culture = [Globalization.CultureInfo]::InvariantCulture
    $properties = $item.SelectSingleNode('Properties')
    $property = $document.CreateElement($type)
    $property.SetAttribute('name', $name)
    if ($type -eq 'Color3') {
        $channels = $value -split ','
        foreach ($i in 0..2) {
            $channel = $document.CreateElement(('R', 'G', 'B')[$i])
            $channel.InnerText = ([double]$channels[$i] / 255).ToString('0.######', $culture)
            $property.AppendChild($channel) | Out-Null
        }
    } elseif ($type -eq 'bool') {
        $property.InnerText = if ($value) { 'true' } else { 'false' }
    } elseif ($value -is [double] -or $value -is [single]) {
        $property.InnerText = ([double]$value).ToString('0.######', $culture)
    } else {
        $property.InnerText = [string]$value
    }
    $properties.AppendChild($property) | Out-Null
}
function Add-Modules($parent, $directory) {
    $path = Join-Path $projectRoot $directory
    Get-ChildItem -LiteralPath $path -Filter '*.luau' -File | ForEach-Object {
        $script:moduleCount++
        Add-Instance $parent 'ModuleScript' $_.BaseName (Join-Path $directory $_.Name) | Out-Null
    }
    Get-ChildItem -LiteralPath $path -Directory | ForEach-Object {
        $folder = Add-Instance $parent 'Folder' $_.Name $null
        Add-Modules $folder (Join-Path $directory $_.Name)
    }
}
$script:moduleCount = 0
$workspace = Add-Instance $root 'Workspace' 'Workspace' $null
# Terreno do mundo V2: o relevo é gerado em runtime pelo servidor (server/Mundo); aqui só ficam
# as propriedades que o Studio guarda no arquivo. Decoration liga a grama 3D animada; a água
# é azul-esverdeada clara, de fantasia estilizada (valores a olho; ajustar aqui).
$terrain = Add-Instance $workspace 'Terrain' 'Terrain' $null
Add-Property $terrain 'bool' 'Decoration' $true
Add-Property $terrain 'Color3' 'WaterColor' '58,176,184'
Add-Property $terrain 'float' 'WaterReflectance' ([double]0.55)
Add-Property $terrain 'float' 'WaterTransparency' ([double]0.55)
Add-Property $terrain 'float' 'WaterWaveSize' ([double]0.12)
Add-Property $terrain 'float' 'WaterWaveSpeed' ([double]8)
# Lighting.Technology é Enum.Technology (create.roblox.com/docs/reference/engine/enums/Technology):
# Legacy=0, Voxel=1, Compatibility=2, ShadowMap=3, Future=4, Unified=5. O arquivo guarda o
# número em <token>. Future dá sombras e luz por pixel; o Studio só relê ao reabrir o place.
# Brilho e cores por zona continuam no cliente (client/AmbienteMundo + shared/Mundo/AmbientePerfis).
$lighting = Add-Instance $root 'Lighting' 'Lighting' $null
Add-Property $lighting 'token' 'Technology' 4
Add-Property $lighting 'bool' 'GlobalShadows' $true
Add-Property $lighting 'float' 'ShadowSoftness' ([double]0.25)
Add-Property $lighting 'float' 'EnvironmentDiffuseScale' ([double]1)
Add-Property $lighting 'float' 'EnvironmentSpecularScale' ([double]1)
$server = Add-Instance $root 'ServerScriptService' 'ServerScriptService' $null
Add-Instance $server 'Script' 'RPGServer' 'src/server.server.luau' | Out-Null
$folder = Add-Instance $server 'Folder' 'Server' $null
Add-Modules $folder 'src/server'
$replicated = Add-Instance $root 'ReplicatedStorage' 'ReplicatedStorage' $null
$shared = Add-Instance $replicated 'Folder' 'Shared' $null
Add-Modules $shared 'src/shared'
$starter = Add-Instance $root 'StarterPlayer' 'StarterPlayer' $null
$scripts = Add-Instance $starter 'StarterPlayerScripts' 'StarterPlayerScripts' $null
Add-Instance $scripts 'LocalScript' 'RPGClient' 'src/client.client.luau' | Out-Null
$client = Add-Instance $scripts 'Folder' 'Client' $null
Add-Modules $client 'src/client'
$output = Join-Path $projectRoot 'Moshoku-Prototipo.rbxlx'
$document.Save($output)
[xml]$check = Get-Content -LiteralPath $output -Raw
$expected = $script:moduleCount + 2
if ($check.SelectNodes('//ProtectedString[@name="Source"]').Count -ne $expected) {
    throw 'Quantidade inesperada de scripts no arquivo gerado.'
}
if ($check.SelectSingleNode('//Item[@class="Lighting"]/Properties/token[@name="Technology"]').InnerText -ne '4' -or
    $check.SelectSingleNode('//Item[@class="Terrain"]/Properties/bool[@name="Decoration"]').InnerText -ne 'true') {
    throw 'Lighting.Technology ou Terrain.Decoration ausente no arquivo gerado.'
}
Write-Output "Arquivo gerado e XML verificado: $output"
