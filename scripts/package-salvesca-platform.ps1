[CmdletBinding()]
param(
  [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\build\salvesca-platform-release')
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$platformRoot = Join-Path $repositoryRoot 'salvesca-platform'
$modules = @('asistent', 'usluge', 'posao', 'prevod', 'finansije', 'prevoz')
$releaseRoot = Join-Path $OutputDirectory ((Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss'))

if (-not (Test-Path -LiteralPath (Join-Path $platformRoot 'index.html'))) {
  throw "Salvesca platform root was not found at $platformRoot."
}

New-Item -ItemType Directory -Force -Path $releaseRoot | Out-Null
$archiveRoot = Join-Path $releaseRoot 'archives'
New-Item -ItemType Directory -Force -Path $archiveRoot | Out-Null

function New-DeployArchive {
  param(
    [Parameter(Mandatory)] [string]$Name,
    [Parameter(Mandatory)] [string]$SourceDirectory,
    [switch]$Recurse
  )

  $archivePath = Join-Path $archiveRoot "$Name.zip"
  $files = Get-ChildItem -LiteralPath $SourceDirectory -File -Recurse:$Recurse
  if ($files.Count -eq 0) { throw "No deployable files in $SourceDirectory." }
  Compress-Archive -LiteralPath $files.FullName -DestinationPath $archivePath -CompressionLevel Optimal
  return [pscustomobject]@{
    site = $Name
    archive = [IO.Path]::GetFileName($archivePath)
    sha256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    files = $files.Count
  }
}

$manifest = [ordered]@{
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
  commit = (git -C $repositoryRoot rev-parse HEAD).Trim()
  deployment = @()
}

# Root domain salvesca.com: extract into the root document directory.
$manifest.deployment += New-DeployArchive -Name 'salvesca-com' -SourceDirectory $platformRoot

# Each archive is intentionally flat: extract it directly into that subdomain's
# document root in CPanel, never into a shared parent folder.
foreach ($module in $modules) {
  $moduleRoot = Join-Path $platformRoot $module
  if (-not (Test-Path -LiteralPath (Join-Path $moduleRoot 'index.html'))) {
    throw "Missing module entry point: $moduleRoot\\index.html"
  }
  $manifest.deployment += New-DeployArchive -Name "$module-salvesca-com" -SourceDirectory $moduleRoot -Recurse
}

$manifestPath = Join-Path $releaseRoot 'manifest.json'
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding utf8

Write-Output "Prepared Salvesca deployment archives in: $releaseRoot"
Get-Content -LiteralPath $manifestPath
