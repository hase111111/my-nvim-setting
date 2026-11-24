[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("install", "install-tools", "uninstall", "status", "setup", "check", "update", "help")]
    [string]$Command = "help",

    [switch]$Force
)

$ErrorActionPreference = "Stop"
$packageId = "Neovim.Neovim"
$ripgrepPackageId = "BurntSushi.ripgrep.MSVC"
$archivePackageId = "7zip.7zip"
$treeSitterVersion = "0.27.2"
$configSource = Join-Path $PSScriptRoot "nvim"
$configDestination = Join-Path $env:LOCALAPPDATA "nvim"
$backupRoot = Join-Path $env:LOCALAPPDATA "nvim-backups"

function Assert-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget was not found. Install or update App Installer first."
    }
}

function Install-WingetPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    Write-Host "Checking package: $Id"
    & winget list --id $Id --exact --accept-source-agreements | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Already installed: $Id"
        return
    }

    Write-Host "Installing: $Id"
    & winget install --id $Id --exact --source winget --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        throw "winget install failed for $Id (exit code: $LASTEXITCODE)"
    }
}

function Install-Tools {
    Assert-Winget
    Install-WingetPackage -Id $ripgrepPackageId
    Install-WingetPackage -Id $archivePackageId
    Install-TreeSitterCli
    Write-Host "ripgrep, 7-Zip, and tree-sitter CLI are ready."
}

function Install-TreeSitterCli {
    $existing = Get-Command tree-sitter -ErrorAction SilentlyContinue
    if ($existing) {
        try {
            $versionOutput = & $existing.Source --version
            if ($versionOutput -match '(\d+\.\d+\.\d+)') {
                $installedVersion = [version]$Matches[1]
                if ($installedVersion -ge [version]"0.26.1") {
                    Write-Host "Already installed: tree-sitter $installedVersion"
                    return
                }
            }
        }
        catch {
            Write-Host "Ignoring an unusable tree-sitter command: $($existing.Source)"
        }
    }

    $architecture = $env:PROCESSOR_ARCHITECTURE
    switch ($architecture) {
        "AMD64" {
            $assetName = "tree-sitter-cli-windows-x64.zip"
            $expectedHash = "9A6DC00C08ED26E98C05481F08C6F83C5FF05C6756442AEC2AFF1800732AD3DA"
        }
        "ARM64" {
            $assetName = "tree-sitter-cli-windows-arm64.zip"
            $expectedHash = "303AC25E8ED3D423131B7B47F87CD049C1C3D82BDF7A11C5E0348366ABEF072C"
        }
        "x86" {
            $assetName = "tree-sitter-cli-windows-x86.zip"
            $expectedHash = "95787A11D6EA998F475C6570EBC0E41055BEF7579FCF8B58A44D7041166A9755"
        }
        default {
            throw "Unsupported architecture for tree-sitter CLI: $architecture"
        }
    }

    $downloadUrl = "https://github.com/tree-sitter/tree-sitter/releases/download/v$treeSitterVersion/$assetName"
    $installDirectory = Join-Path $env:LOCALAPPDATA "Programs\tree-sitter-cli"
    $temporaryDirectory = Join-Path $env:TEMP ("tree-sitter-cli-" + [guid]::NewGuid().ToString("N"))
    $archivePath = Join-Path $temporaryDirectory $assetName

    New-Item -ItemType Directory -Path $temporaryDirectory | Out-Null
    try {
        Write-Host "Downloading tree-sitter CLI $treeSitterVersion from the official release..."
        Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath -UseBasicParsing
        $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
        if ($actualHash -ne $expectedHash) {
            throw "tree-sitter CLI checksum mismatch"
        }

        Expand-Archive -LiteralPath $archivePath -DestinationPath $temporaryDirectory -Force
        $executable = Get-ChildItem -LiteralPath $temporaryDirectory -Recurse -Filter "tree-sitter.exe" -File | Select-Object -First 1
        if (-not $executable) {
            throw "tree-sitter.exe was not found in the official archive"
        }

        New-Item -ItemType Directory -Path $installDirectory -Force | Out-Null
        Copy-Item -LiteralPath $executable.FullName -Destination (Join-Path $installDirectory "tree-sitter.exe") -Force
    }
    finally {
        $resolvedTemporary = [System.IO.Path]::GetFullPath($temporaryDirectory)
        $resolvedTempRoot = [System.IO.Path]::GetFullPath($env:TEMP)
        if ($resolvedTemporary.StartsWith($resolvedTempRoot) -and (Split-Path $resolvedTemporary -Leaf).StartsWith("tree-sitter-cli-")) {
            Remove-Item -LiteralPath $resolvedTemporary -Recurse -Force
        }
    }

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $pathEntries = @($userPath -split ';' | Where-Object { $_ })
    if ($pathEntries -notcontains $installDirectory) {
        $newUserPath = (@($pathEntries) + $installDirectory) -join ';'
        [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
    }
    if (($env:Path -split ';') -notcontains $installDirectory) {
        $env:Path = "$installDirectory;$env:Path"
    }

    & (Join-Path $installDirectory "tree-sitter.exe") --version
}

function Show-Status {
    Write-Host "Neovim status"
    Write-Host "--------------"

    $nvim = Get-Command nvim -ErrorAction SilentlyContinue
    if ($nvim) {
        Write-Host "Installed : Yes"
        Write-Host "Command   : $($nvim.Source)"
        & $nvim.Source --version | Select-Object -First 1
    }
    else {
        Write-Host "Installed : No (nvim is not on PATH)"
    }

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        try {
            $wingetVersion = & $winget.Source --version
            Write-Host "winget    : $wingetVersion"
            Write-Host ""
            Write-Host "winget package information:"
            & $winget.Source list --id $packageId --exact --source winget
            & $winget.Source list --id $ripgrepPackageId --exact --source winget
            & $winget.Source list --id $archivePackageId --exact --source winget
        }
        catch {
            Write-Host "winget    : Found but could not be executed"
            Write-Host "Details   : $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "winget    : Not found"
    }
}

function Install-Config {
    if (-not $env:LOCALAPPDATA) {
        throw "LOCALAPPDATA is not defined."
    }
    if (-not (Test-Path -LiteralPath (Join-Path $configSource "init.lua") -PathType Leaf)) {
        throw "The repository config was not found: $configSource"
    }

    if (Test-Path -LiteralPath $configDestination) {
        if ($Force) {
            Write-Host "Removing existing config without backup: $configDestination"
        }
        else {
            New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $backupDestination = Join-Path $backupRoot "nvim-$timestamp"
            Copy-Item -LiteralPath $configDestination -Destination $backupDestination -Recurse
            Write-Host "Backup created: $backupDestination"
        }
        Remove-Item -LiteralPath $configDestination -Recurse -Force
    }

    Copy-Item -LiteralPath $configSource -Destination $configDestination -Recurse
    Write-Host "Config installed: $configDestination"
}

function Test-Config {
    $nvim = Get-Command nvim -ErrorAction SilentlyContinue
    if (-not $nvim) {
        throw "nvim was not found on PATH."
    }

    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
        throw "git was not found on PATH. It is required to install plugins."
    }

    Write-Host "Command : $($nvim.Source)"
    Write-Host "Config  : $configDestination"
    Write-Host "Git     : $(& $git.Source --version)"
    $ripgrep = Get-Command rg -ErrorAction SilentlyContinue
    if ($ripgrep) {
        Write-Host "Ripgrep : $(& $ripgrep.Source --version | Select-Object -First 1)"
    }
    else {
        Write-Host "Ripgrep : Not found (required for Telescope live grep)"
    }
    $gxx = Get-Command "g++" -ErrorAction SilentlyContinue
    if ($gxx) {
        Write-Host "G++     : $($gxx.Source)"
        & $gxx.Source --version | Select-Object -First 1
    }
    else {
        Write-Host "G++     : Not found on PATH"
    }
    $masonClangdCandidates = @(
        (Join-Path $env:LOCALAPPDATA "nvim-data\mason\bin\clangd.exe"),
        (Join-Path $env:LOCALAPPDATA "nvim-data\mason\bin\clangd.cmd")
    )
    $masonClangd = $masonClangdCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if ($masonClangd) {
        Write-Host "Clangd  : $masonClangd"
    }
    else {
        Write-Host "Clangd  : Not installed by Mason yet"
    }
    $treeSitter = Get-Command tree-sitter -ErrorAction SilentlyContinue
    if ($treeSitter) {
        Write-Host "TS CLI  : $($treeSitter.Source)"
    }
    else {
        Write-Host "TS CLI  : Not found (run install-tools or update)"
    }
    Write-Host ""
    & $nvim.Source --headless "+lua print('Config loaded successfully: ' .. vim.fn.stdpath('config'))" "+qa"
    if ($LASTEXITCODE -ne 0) {
        throw "Neovim could not load the config (exit code: $LASTEXITCODE)"
    }
}

function Update-Plugins {
    $nvim = Get-Command nvim -ErrorAction SilentlyContinue
    if (-not $nvim) {
        throw "nvim was not found on PATH."
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "git was not found on PATH."
    }
    if (-not (Test-Path -LiteralPath (Join-Path $configDestination "init.lua") -PathType Leaf)) {
        throw "No installed config was found. Run setup first."
    }

    Install-TreeSitterCli

    & $nvim.Source --headless "+Lazy! sync" "+qa"
    if ($LASTEXITCODE -ne 0) {
        throw "Plugin update failed (exit code: $LASTEXITCODE)"
    }
    & $nvim.Source --headless "+MasonInstall clangd" "+qa"
    if ($LASTEXITCODE -ne 0) {
        throw "Mason tool installation failed (exit code: $LASTEXITCODE)"
    }
    $installedLockfile = Join-Path $configDestination "lazy-lock.json"
    if (Test-Path -LiteralPath $installedLockfile -PathType Leaf) {
        Copy-Item -LiteralPath $installedLockfile -Destination (Join-Path $configSource "lazy-lock.json") -Force
        Write-Host "Lockfile saved to the repository config."
    }
    Write-Host "Plugins are synchronized."
}

function Show-Help {
    Write-Host @"
Neovim manager for Windows

Usage:
  .\manage-nvim.bat install
  .\manage-nvim.bat install-tools
  .\manage-nvim.bat uninstall
  .\manage-nvim.bat status
  .\manage-nvim.bat setup
  .\manage-nvim.bat setup --force
  .\manage-nvim.bat check
  .\manage-nvim.bat update

setup backs up an existing config before replacing it.
setup --force replaces it without creating a backup.
uninstall does not remove your configuration.
uninstall also keeps shared command-line tools such as ripgrep.
"@
}

try {
    switch ($Command) {
        "install" {
            Assert-Winget
            Install-WingetPackage -Id $packageId
            Install-WingetPackage -Id $ripgrepPackageId
            Install-WingetPackage -Id $archivePackageId
            Write-Host ""
            Write-Host "Neovim, ripgrep, and 7-Zip are ready. Open a new terminal, then run:"
            Write-Host "  manage-nvim.bat status"
        }
        "install-tools" {
            Install-Tools
        }
        "uninstall" {
            Assert-Winget
            & winget uninstall --id $packageId --exact --source winget
            if ($LASTEXITCODE -ne 0) {
                throw "winget uninstall failed (exit code: $LASTEXITCODE)"
            }
            Write-Host "Neovim was uninstalled. Configuration files were kept."
        }
        "status" {
            Show-Status
        }
        "setup" {
            Install-Config
        }
        "check" {
            Test-Config
        }
        "update" {
            Update-Plugins
        }
        "help" {
            Show-Help
        }
    }
}
catch {
    Write-Error $_
    exit 1
}

