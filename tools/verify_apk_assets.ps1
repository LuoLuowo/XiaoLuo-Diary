param([Parameter(Mandatory=$true)][string]$ApkPath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $ApkPath))
try {
    $required = @(
        'assets/flutter_assets/FontManifest.json',
        'assets/flutter_assets/AssetManifest.bin',
        'assets/flutter_assets/fonts/MaterialIcons-Regular.otf',
        'assets/flutter_assets/packages/cupertino_icons/assets/CupertinoIcons.ttf',
        'assets/flutter_assets/assets/fonts/SimHei.ttf'
    )
    foreach ($name in $required) {
        $entry = $archive.GetEntry($name)
        if ($null -eq $entry -or $entry.Length -eq 0) {
            throw "APK is missing a required Flutter asset: $name. Do not distribute it."
        }
        Write-Output "$name : $($entry.Length) bytes"
    }
    $stream = $archive.GetEntry('assets/flutter_assets/FontManifest.json').Open()
    $reader = [System.IO.StreamReader]::new($stream)
    try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
    if ('MaterialIcons' -notin $manifest.family) { throw 'MaterialIcons is not registered in FontManifest.' }
    Write-Output 'APK font and asset validation passed.'
} finally { $archive.Dispose() }
