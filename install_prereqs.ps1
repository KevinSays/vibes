# VIBES Network Visualizer Prerequisites Installer for Windows
# ==================================================
# This script installs all required dependencies for the VIBES project on Windows
# - Go 1.21+
# - Npcap (for packet capture)
# - Development tools
#
# The frontend ships prebuilt inside the Go binary, so Node.js/npm are only
# needed to change the frontend. To install them too, run:
#   $env:VIBES_DEV=1; .\install_prereqs.ps1

$VibesDev = $env:VIBES_DEV -eq "1"

$FE_NAME="vibes-network-visualizer"
$FE_PRIVATE=$true
$FE_VERSION="0.1.0"

# Load the requirements.conf file
Get-Content requirements.conf | Where-Object { $_ -notmatch '^\s*#' } | ForEach-Object {
    $key, $value = $_.Split('=', 2).Trim()
}

# Function to display styled output
function Write-Header {
    param([string]$text)
    Write-Host "`n==>" -ForegroundColor Cyan -NoNewline
    Write-Host " $text" -ForegroundColor White
}

function Write-Step {
    param([string]$text)
    Write-Host "  ->" -ForegroundColor Green -NoNewline
    Write-Host " $text" -ForegroundColor White
}

function Write-Warning {
    param([string]$text)
    Write-Host "  !" -ForegroundColor Yellow -NoNewline
    Write-Host " $text" -ForegroundColor White
}

function Write-Error {
    param([string]$text)
    Write-Host "  X" -ForegroundColor Red -NoNewline
    Write-Host " $text" -ForegroundColor White
}

# Check if script is run as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script requires administrator privileges to install some components."
    Write-Step "Please right-click on the script and select 'Run as administrator'"
    Read-Host "Press Enter to exit"
    exit
}

# Verify we have internet connection
Write-Header "Checking internet connection"
if (-not (Test-Connection -ComputerName www.google.com -Count 1 -Quiet)) {
    Write-Error "No internet connection detected. Please connect to the internet and try again."
    Read-Host "Press Enter to exit"
    exit
}

# Check for chocolatey package manager
Write-Header "Checking for Chocolatey package manager"
$chocoInstalled = $false
if (Get-Command choco -ErrorAction SilentlyContinue) {
    $chocoInstalled = $true
    Write-Step "Chocolatey is already installed"
} else {
    Write-Step "Installing Chocolatey..."
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        Write-Step "Chocolatey installed successfully"
        $chocoInstalled = $true
    } catch {
        Write-Error "Failed to install Chocolatey: $_"
        Read-Host "Press Enter to exit"
        exit
    }
}

# Install Go
Write-Header "Installing Go $GO_VER"
if (Get-Command go -ErrorAction SilentlyContinue) {
    $goVersion = (go version) -replace '.*go([0-9]+\.[0-9]+).*', '$1'
    Write-Step "Go $goVersion is already installed"
    
    # Compare versions (basic check)
    if ([version]$goVersion -lt [version]"$GO_RUN") {
        Write-Warning "Your Go version might be too old. Version $GO_RUN+ is recommended."
        Write-Step "Proceeding with existing installation..."
    }
} else {
    Write-Step "Installing Go $GO_VER..."
    choco install golang -y --version=$GO_VER
    refreshenv
    Write-Step "Go installation complete"
}

# Install Node.js (frontend development only)
if (-not $VibesDev) {
    Write-Header "Skipping Node.js (frontend is prebuilt; set VIBES_DEV=1 to install)"
} elseif (Get-Command node -ErrorAction SilentlyContinue) {
    Write-Header "Installing Node.js"
    $nodeVersion = (node -v) -replace 'v', ''
    Write-Step "Node.js $nodeVersion is already installed"
    
    # Compare versions
    if ([version]$nodeVersion -lt [version]"$NODE_VER.$NODE_MIN_VER") {
        Write-Warning "Your Node.js version is too old. Version $NODE_VER.$NODE_MIN_VER+ is required."
        Write-Step "Upgrading Node.js..."
        choco install nodejs -y --version=$NODE_VER.$NODE_MIN_VER
        refreshenv
    }
} else {
    Write-Header "Installing Node.js"
    Write-Step "Installing Node.js $NODE_VER.$NODE_MIN_VER..."
    choco install nodejs -y --version=$NODE_VER.$NODE_MIN_VER
    refreshenv
    Write-Step "Node.js installation complete"
}

# Install Npcap for packet capture
Write-Header "Installing Npcap for packet capture"
if (Test-Path "C:\Windows\System32\Npcap") {
    Write-Step "Npcap is already installed"
} else {
    Write-Step "Installing Npcap..."
    choco install npcap -y
    Write-Step "Npcap installation complete"
}

# Install Git if not present
Write-Header "Installing Git"
if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Step "Git is already installed"
} else {
    Write-Step "Installing Git..."
    choco install git -y
    refreshenv
    Write-Step "Git installation complete"
}

# Setup project directories
Write-Header "Setting up project directories"
$projectRoot = Get-Location

# Setup backend environment
Write-Step "Creating backend directories"
if (-not (Test-Path "backend")) {
    New-Item -ItemType Directory -Path "backend" | Out-Null
    New-Item -ItemType Directory -Path "backend\cmd" | Out-Null
    New-Item -ItemType Directory -Path "backend\internal" | Out-Null
    New-Item -ItemType Directory -Path "backend\pkg" | Out-Null
}

# Create go.mod if it doesn't exist
if (-not (Test-Path "backend\go.mod")) {
    Write-Step "Creating go.mod"
    Set-Content -Path "backend\go.mod" -Value @"
module github.com/vibes-network-visualizer

go $GO_RUN

require (
	github.com/gorilla/websocket v$WEBSOCKET_VER
	github.com/google/gopacket v$GOPACKET_VER
)
"@
}

# Install Go dependencies
Write-Header "Installing Go dependencies"
Push-Location "backend"
try {
    Write-Step "Installing github.com/gorilla/websocket..."
    go get -u github.com/gorilla/websocket@v$WEBSOCKET_VER
    Write-Step "Installing github.com/google/gopacket..."
    go get -u github.com/google/gopacket@v$GOPACKET_VER
} catch {
    Write-Error "Failed to install Go dependencies: $_"
} finally {
    Pop-Location
}

# Install frontend dependencies (frontend development only)
if ($VibesDev) {
    Write-Header "Installing frontend dependencies"
    Push-Location "frontend"
    try {
        Write-Step "Installing Node.js dependencies..."
        npm install
    } catch {
        Write-Error "Failed to install Node.js dependencies: $_"
    } finally {
        Pop-Location
    }
}

# Create data and logs directories
Write-Header "Creating data and logs directories"
if (-not (Test-Path "data")) {
    New-Item -ItemType Directory -Path "data" | Out-Null
    Write-Step "Created data directory"
}
if (-not (Test-Path "logs")) {
    New-Item -ItemType Directory -Path "logs" | Out-Null
    Write-Step "Created logs directory"
}

# Final message
Write-Header "VIBES Network Visualizer prerequisites installation completed!"
Write-Step "To start VIBES: cd backend/cmd && go run . then open http://localhost:8080"
if ($VibesDev) {
    Write-Step "Frontend dev server (hot reload): cd frontend && npm run dev"
}

Write-Warning "Note: You may need to run the command prompt as administrator for packet capture capabilities"
Write-Header "Ready to build the sickest network visualizer ever! 🚀"
Read-Host "Press Enter to exit"

