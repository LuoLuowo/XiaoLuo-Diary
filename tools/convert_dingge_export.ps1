param(
  [Parameter(Mandatory = $true)][string]$SourceZip,
  [Parameter(Mandatory = $true)][string]$DestinationZip
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-Sha1Short([string]$Value) {
  $sha = [System.Security.Cryptography.SHA1]::Create()
  try {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    $hash = $sha.ComputeHash($bytes)
    return ([BitConverter]::ToString($hash).Replace('-', '').ToLowerInvariant()).Substring(0, 12)
  } finally { $sha.Dispose() }
}

function Get-EntryText($Entry) {
  $reader = [IO.StreamReader]::new($Entry.Open(), [Text.Encoding]::UTF8, $true)
  try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

function Get-EpochMilliseconds([datetime]$Date) {
  return [DateTimeOffset]::new($Date, [TimeSpan]::FromHours(8)).ToUnixTimeMilliseconds()
}

# ConvertTo-Json writes a single pipeline object as an object rather than an
# array. The app's importer expects these JSON fields to always be arrays.
function ConvertTo-CompactJsonArray($Items, [int]$Depth = 12) {
  $parts = @($Items | ForEach-Object { ConvertTo-Json -InputObject $_ -Compress -Depth $Depth })
  return '[' + ($parts -join ',') + ']'
}

if (-not (Test-Path -LiteralPath $SourceZip -PathType Leaf)) { throw "找不到源文件：$SourceZip" }
if (Test-Path -LiteralPath $DestinationZip) { throw "目标文件已存在，为保护已有文件不会覆盖：$DestinationZip" }

$destinationFolder = Split-Path -Parent $DestinationZip
if (-not (Test-Path -LiteralPath $destinationFolder)) { New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null }

$source = [System.IO.Compression.ZipFile]::OpenRead($SourceZip)
try {
  $entriesByPath = @{}
  $textRows = [System.Collections.Generic.List[object]]::new()
  $mediaByKey = @{}
  $unparsedText = [System.Collections.Generic.List[string]]::new()

  foreach ($entry in $source.Entries) {
    if ($entry.FullName.EndsWith('/')) { continue }
    $entriesByPath[$entry.FullName] = $entry
    $name = [IO.Path]::GetFileName($entry.FullName)
    $parent = [IO.Path]::GetFileName([IO.Path]::GetDirectoryName($entry.FullName))
    $extension = [IO.Path]::GetExtension($name).ToLowerInvariant()

    if ($extension -eq '.txt' -and $name -match '^(\d{4}-\d{2}-\d{2})_(\d{2}-\d{2})(?:-(\d+))?\.txt$') {
      # A trailing -1/-2 in this export is a duplicate-file sequence, not a
      # different filename format. Give it a distinct second for stable import
      # identity while retaining the source minute for media association.
      $seconds = if ($Matches[3]) { ([int]$Matches[3]).ToString('00') } else { '00' }
      $timestamp = "$($Matches[1]) $($Matches[2].Replace('-', ':')):$seconds"
      $date = [datetime]::ParseExact($timestamp, 'yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)
      $prefix = $date.ToString('MM-dd_HH-mm')
      $textRows.Add([pscustomobject]@{ Entry = $entry; Date = $date; Key = "$parent|$prefix" })
      continue
    }

    if ($extension -in @('.jpg', '.jpeg', '.png', '.mp4', '.m4a') -and $name -match '^(\d{2}-\d{2}_\d{2}-\d{2})_(?:Pic|Video|Audio)_\d+\.(?:jpg|jpeg|png|mp4|m4a)$') {
      $key = "$parent|$($Matches[1])"
      if (-not $mediaByKey.ContainsKey($key)) { $mediaByKey[$key] = [System.Collections.Generic.List[object]]::new() }
      $mediaByKey[$key].Add($entry)
    } elseif ($extension -eq '.txt') {
      $unparsedText.Add($entry.FullName)
    }
  }

  $diaries = [System.Collections.Generic.List[object]]::new()
  $copyItems = [System.Collections.Generic.List[object]]::new()
  $usedMediaKeys = [System.Collections.Generic.HashSet[string]]::new()
  $nextId = 1

  foreach ($row in ($textRows | Sort-Object Date, { $_.Entry.FullName })) {
    $raw = Get-EntryText $row.Entry
    $lines = @($raw -split "`r?`n")
    $separator = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -match '^-{5,}$') { $separator = $i; break } }
    $bodyLines = if ($separator -ge 0) { @($lines[($separator + 1)..($lines.Count - 1)]) } else { @($lines | Select-Object -Skip 1) }
    while ($bodyLines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($bodyLines[0])) { $bodyLines = @($bodyLines | Select-Object -Skip 1) }
    while ($bodyLines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($bodyLines[$bodyLines.Count - 1])) { $bodyLines = @($bodyLines | Select-Object -First ($bodyLines.Count - 1)) }
    $title = if ($bodyLines.Count -gt 0) { $bodyLines[0].Trim() } else { '无标题日记' }
    $content = if ($bodyLines.Count -gt 1) { (@($bodyLines | Select-Object -Skip 1) -join "`n").Trim() } else { '' }

    $images = [System.Collections.Generic.List[string]]::new()
    $videos = [System.Collections.Generic.List[string]]::new()
    $attachments = [System.Collections.Generic.List[string]]::new()
    $richOps = [System.Collections.Generic.List[object]]::new()
    if (-not [string]::IsNullOrWhiteSpace($content)) { $richOps.Add([ordered]@{ insert = "$content`n" }) }

    if ($mediaByKey.ContainsKey($row.Key) -and -not $usedMediaKeys.Contains($row.Key)) {
      $usedMediaKeys.Add($row.Key) | Out-Null
      foreach ($mediaEntry in ($mediaByKey[$row.Key] | Sort-Object FullName)) {
        $mediaName = [IO.Path]::GetFileName($mediaEntry.FullName)
        $ext = [IO.Path]::GetExtension($mediaName).ToLowerInvariant()
        $bucket = if ($ext -in @('.jpg', '.jpeg', '.png')) { 'images' } elseif ($ext -eq '.mp4') { 'videos' } else { 'attachments' }
        $target = "media/$bucket/$((Get-Sha1Short $mediaEntry.FullName))-$mediaName"
        $copyItems.Add([pscustomobject]@{ Source = $mediaEntry; Target = $target })
        if ($bucket -eq 'images') { $images.Add($target); $richOps.Add([ordered]@{ insert = [ordered]@{ image = $target } }); $richOps.Add([ordered]@{ insert = "`n" }) }
        elseif ($bucket -eq 'videos') { $videos.Add($target); $richOps.Add([ordered]@{ insert = [ordered]@{ video = $target } }); $richOps.Add([ordered]@{ insert = "`n" }) }
        else { $attachments.Add($target) }
      }
    }
    if ($richOps.Count -eq 0) { $richOps.Add([ordered]@{ insert = "`n" }) }
    $epoch = Get-EpochMilliseconds $row.Date
    $diaries.Add([ordered]@{
      id = $nextId; title = $title; content = $content; rich_content = (ConvertTo-CompactJsonArray $richOps)
      diary_date = $epoch; created_at = $epoch; updated_at = $epoch; category = '其他'; tags = '[]'
      images = (ConvertTo-CompactJsonArray $images); videos = (ConvertTo-CompactJsonArray $videos); attachments = (ConvertTo-CompactJsonArray $attachments)
    })
    $nextId++
  }

  # Preserve any recognized media not paired with a TXT entry as a dated media-only diary.
  foreach ($key in ($mediaByKey.Keys | Sort-Object)) {
    if ($usedMediaKeys.Contains($key)) { continue }
    $parts = $key -split '\|'
    if ($parts.Count -ne 2 -or $parts[0] -notmatch '^\d{8}$' -or $parts[1] -notmatch '^(\d{2})-(\d{2})_(\d{2})-(\d{2})$') { continue }
    $date = [datetime]::ParseExact("$($parts[0]) $($Matches[3]):$($Matches[4]):00", 'yyyyMMdd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)
    $images = [System.Collections.Generic.List[string]]::new(); $videos = [System.Collections.Generic.List[string]]::new(); $attachments = [System.Collections.Generic.List[string]]::new(); $richOps = [System.Collections.Generic.List[object]]::new()
    foreach ($mediaEntry in ($mediaByKey[$key] | Sort-Object FullName)) {
      $mediaName = [IO.Path]::GetFileName($mediaEntry.FullName); $ext = [IO.Path]::GetExtension($mediaName).ToLowerInvariant()
      $bucket = if ($ext -in @('.jpg', '.jpeg', '.png')) { 'images' } elseif ($ext -eq '.mp4') { 'videos' } else { 'attachments' }
      $target = "media/$bucket/$((Get-Sha1Short $mediaEntry.FullName))-$mediaName"; $copyItems.Add([pscustomobject]@{ Source = $mediaEntry; Target = $target })
      if ($bucket -eq 'images') { $images.Add($target); $richOps.Add([ordered]@{ insert = [ordered]@{ image = $target } }); $richOps.Add([ordered]@{ insert = "`n" }) }
      elseif ($bucket -eq 'videos') { $videos.Add($target); $richOps.Add([ordered]@{ insert = [ordered]@{ video = $target } }); $richOps.Add([ordered]@{ insert = "`n" }) }
      else { $attachments.Add($target) }
    }
    $epoch = Get-EpochMilliseconds $date
    $diaries.Add([ordered]@{ id = $nextId; title = '导入的媒体记录'; content = ''; rich_content = (ConvertTo-CompactJsonArray $richOps); diary_date = $epoch; created_at = $epoch; updated_at = $epoch; category = '其他'; tags = '[]'; images = (ConvertTo-CompactJsonArray $images); videos = (ConvertTo-CompactJsonArray $videos); attachments = (ConvertTo-CompactJsonArray $attachments) })
    $nextId++
  }

  $data = [ordered]@{ diaries = @($diaries); tags = @(); categories = @(); books = @(); summaries = @{}; profile = [ordered]@{ nickname = '小罗'; signature = ''; birthday = ''; homeText = ''; avatarPath = '' }; settings = @{} }
  $dataJson = $data | ConvertTo-Json -Compress -Depth 20
  $dataBytes = [Text.Encoding]::UTF8.GetBytes($dataJson)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { $dataHash = ([BitConverter]::ToString($sha.ComputeHash($dataBytes)).Replace('-', '').ToLowerInvariant()) } finally { $sha.Dispose() }
  $manifest = [ordered]@{ format = 'xiaoluo_diary_backup'; version = 1; createdAt = [DateTime]::UtcNow.ToString('o'); dataSha256 = $dataHash; diaryCount = $diaries.Count; bookCount = 0; mediaCount = $copyItems.Count; source = '定格日记导出转换' }
  $report = [ordered]@{ source = [IO.Path]::GetFileName($SourceZip); convertedAt = [DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'); diaryCount = $diaries.Count; sourceTextCount = $textRows.Count; imageCount = @($copyItems | Where-Object { $_.Target -like 'media/images/*' }).Count; videoCount = @($copyItems | Where-Object { $_.Target -like 'media/videos/*' }).Count; attachmentCount = @($copyItems | Where-Object { $_.Target -like 'media/attachments/*' }).Count; unparsedTextFiles = @($unparsedText) }

  $out = [System.IO.Compression.ZipFile]::Open($DestinationZip, [System.IO.Compression.ZipArchiveMode]::Create)
  try {
    foreach ($item in @(@{ Path = 'manifest.json'; Bytes = [Text.Encoding]::UTF8.GetBytes(($manifest | ConvertTo-Json -Compress -Depth 10)) }, @{ Path = 'data.json'; Bytes = $dataBytes }, @{ Path = 'conversion_report.json'; Bytes = [Text.Encoding]::UTF8.GetBytes(($report | ConvertTo-Json -Compress -Depth 10)) })) {
      $entry = $out.CreateEntry($item.Path, [System.IO.Compression.CompressionLevel]::Optimal)
      $stream = $entry.Open(); try { $stream.Write($item.Bytes, 0, $item.Bytes.Length) } finally { $stream.Dispose() }
    }
    $total = $copyItems.Count; $index = 0
    foreach ($item in $copyItems) {
      $index++
      $entry = $out.CreateEntry($item.Target, [System.IO.Compression.CompressionLevel]::NoCompression)
      $input = $item.Source.Open(); $output = $entry.Open()
      try { $input.CopyTo($output, 1048576) } finally { $output.Dispose(); $input.Dispose() }
      if (($index % 25) -eq 0 -or $index -eq $total) { Write-Host "已写入媒体 $index / $total" }
    }
  } finally { $out.Dispose() }

  Write-Host "转换完成：$DestinationZip"
  Write-Host "日记 $($diaries.Count) 篇；媒体 $($copyItems.Count) 个。"
} finally { $source.Dispose() }
