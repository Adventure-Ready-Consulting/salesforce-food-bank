param(
    [string]$OutputPath,
    [switch]$SkipStaticBuild
)

$ErrorActionPreference = 'Stop'

# This script is intended to be run from the repository root, but it also
# anchors paths to the script location so it works regardless of the shell's
# current working directory.
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$BuildScript = Join-Path $RepoRoot 'resource-bundles\Angular.resource\buildstatic.py'

if (-not $SkipStaticBuild) {
    if (-not (Test-Path $BuildScript)) {
        throw "Angular static-resource build script not found: $BuildScript"
    }

    Write-Host 'Rebuilding Angular static resource...'
    & python $BuildScript
    if ($LASTEXITCODE -ne 0) {
        throw "Angular static-resource build failed with exit code $LASTEXITCODE"
    }
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutputPath = Join-Path $RepoRoot "food-bank-src-$Stamp.zip"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $RepoRoot $OutputPath
}

$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)

if (Test-Path $OutputPath) {
    Remove-Item $OutputPath -Force
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$FileStream = [System.IO.File]::Open($OutputPath, [System.IO.FileMode]::CreateNew)
$Zip = New-Object System.IO.Compression.ZipArchive(
    $FileStream,
    [System.IO.Compression.ZipArchiveMode]::Create,
    $false
)

try {
    $ExcludedDirectories = @(
        '.git', '.vs', '.sf', '.sfdx', 'node_modules', '__pycache__', 'bin', 'obj'
    )

    $Files = Get-ChildItem -Path $RepoRoot -Recurse -File | Where-Object {
        $FullName = $_.FullName
        $RelativePath = $FullName.Substring($RepoRoot.Length).TrimStart('\', '/')
        $Segments = $RelativePath -split '[\\/]'

        $InExcludedDirectory = $false
        foreach ($Directory in $ExcludedDirectories) {
            if ($Segments -contains $Directory) {
                $InExcludedDirectory = $true
                break
            }
        }

        -not $InExcludedDirectory -and
        $FullName -ne $OutputPath -and
        $_.Extension -ne '.zip' -and
        $_.Name -ne '.DS_Store'
    }

    foreach ($File in $Files) {
        $RelativePath = $File.FullName.Substring($RepoRoot.Length).TrimStart('\', '/')
        $EntryName = $RelativePath.Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $Zip,
            $File.FullName,
            $EntryName,
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
}
finally {
    $Zip.Dispose()
    $FileStream.Dispose()
}

Write-Host ''
Write-Host 'Food Bank upload ZIP created:'
Write-Host $OutputPath
