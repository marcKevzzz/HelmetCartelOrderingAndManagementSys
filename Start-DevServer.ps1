# Start-DevServer.ps1 - Automated IIS Express runner for Helmet Cartel
param (
    [int]$SiteId = 2,
    [switch]$NoBrowser
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = (Resolve-Path (Join-Path $scriptDir "HelmetCartelOrderingAndManagementSys")).Path
$configPath = Join-Path $scriptDir ".vs\HelmetCartelOrderingAndManagementSys.slnx\config\applicationhost.config"

if (-not (Test-Path $configPath)) {
    Write-Warning "applicationhost.config was not found at $configPath. If opening via Visual Studio, Visual Studio will generate it automatically."
} else {
    # Dynamically update physicalPath in applicationhost.config to match this device's repository path
    [xml]$configXml = Get-Content $configPath
    $site = $configXml.configuration.'system.applicationHost'.sites.site | Where-Object { $_.id -eq "$SiteId" }
    if ($site -and $site.application.virtualDirectory.physicalPath -ne $projectDir) {
        Write-Host "Syncing physicalPath in applicationhost.config to local directory: $projectDir" -ForegroundColor Cyan
        $site.application.virtualDirectory.physicalPath = $projectDir
        $configXml.Save($configPath)
    }
}

# Locate IIS Express executable
$iisExpressPath = "C:\Program Files\IIS Express\iisexpress.exe"
if (-not (Test-Path $iisExpressPath)) {
    $iisExpressPath = "C:\Program Files (x86)\IIS Express\iisexpress.exe"
}

if (-not (Test-Path $iisExpressPath)) {
    Write-Error "IIS Express executable was not found. Please install IIS Express or Visual Studio."
    exit 1
}

Write-Host "Starting IIS Express on ports 61909 (HTTP) and 44359 (HTTPS)..." -ForegroundColor Green
Write-Host "Project directory: $projectDir" -ForegroundColor Gray
Write-Host "Press Ctrl+C to stop IIS Express." -ForegroundColor Yellow

if (-not $NoBrowser) {
    Start-Process "https://localhost:44359/"
}

& $iisExpressPath /config:"$configPath" /siteid:$SiteId
