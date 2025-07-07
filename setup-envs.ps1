#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Setup script for env-run PowerShell utility - creates environment configuration files.

.DESCRIPTION
    This script creates the directory structure and template environment files for the env-run utility.
    It detects and reports on available secret management tools for cross-platform secret storage.

.NOTES
    Creates environment files in:
    - Windows: $env:APPDATA\env\
    - Linux/macOS: $env:XDG_CONFIG_HOME/env/ or ~/.config/env/
#>

# Determine configuration directory based on platform
function Get-ConfigDirectory {
    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        return Join-Path $env:APPDATA "env"
    } else {
        $xdgConfigHome = $env:XDG_CONFIG_HOME
        if ([string]::IsNullOrEmpty($xdgConfigHome)) {
            $xdgConfigHome = Join-Path $HOME ".config"
        }
        return Join-Path $xdgConfigHome "env"
    }
}

# Check for secret management tools
function Test-SecretTools {
    Write-Host "Checking for secret management tools..." -ForegroundColor Yellow
    
    $tools = @()
    
    # Check for PowerShell SecretManagement module
    if (Get-Module -ListAvailable -Name Microsoft.PowerShell.SecretManagement -ErrorAction SilentlyContinue) {
        $tools += "Microsoft.PowerShell.SecretManagement (PowerShell module)"
    }
    
    # Check for secret-tool (Linux)
    if (Get-Command secret-tool -ErrorAction SilentlyContinue) {
        $tools += "secret-tool (Linux libsecret)"
    }
    
    # Check for security command (macOS)
    if (Get-Command security -ErrorAction SilentlyContinue) {
        $tools += "security (macOS Keychain)"
    }
    
    # Check for Windows Credential Manager (Windows)
    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        if (Get-Command cmdkey -ErrorAction SilentlyContinue) {
            $tools += "cmdkey (Windows Credential Manager)"
        }
    }
    
    if ($tools.Count -eq 0) {
        Write-Host "No secret management tools found." -ForegroundColor Red
        Write-Host "Consider installing:" -ForegroundColor Yellow
        Write-Host "  - PowerShell: Install-Module Microsoft.PowerShell.SecretManagement" -ForegroundColor Gray
        Write-Host "  - Linux: sudo apt install libsecret-tools" -ForegroundColor Gray
        Write-Host "  - macOS: security command (built-in)" -ForegroundColor Gray
        Write-Host "  - Windows: cmdkey command (built-in)" -ForegroundColor Gray
    } else {
        Write-Host "Found secret management tools:" -ForegroundColor Green
        foreach ($tool in $tools) {
            Write-Host "  ✓ $tool" -ForegroundColor Green
        }
    }
    
    return $tools
}

# Create environment file with content
function New-EnvFile {
    param(
        [string]$FilePath,
        [string]$Content
    )
    
    if (Test-Path $FilePath) {
        Write-Host "File already exists: $FilePath" -ForegroundColor Yellow
        return
    }
    
    try {
        Set-Content -Path $FilePath -Value $Content -Encoding UTF8
        Write-Host "Created: $FilePath" -ForegroundColor Green
    } catch {
        Write-Error "Failed to create $FilePath`: $($_.Exception.Message)"
    }
}

# Main execution
try {
    Write-Host "Setting up env-run PowerShell utility..." -ForegroundColor Cyan
    
    $configDir = Get-ConfigDirectory
    Write-Host "Configuration directory: $configDir" -ForegroundColor Gray
    
    # Create directory if it doesn't exist
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        Write-Host "Created directory: $configDir" -ForegroundColor Green
    } else {
        Write-Host "Directory exists: $configDir" -ForegroundColor Yellow
    }
    
    # Check for secret management tools
    $secretTools = Test-SecretTools
    
    # Create base.env
    $baseContent = @"
# Base environment variables shared across all environments
# These can be overridden by environment-specific files

# API Configuration
API_BASE_URL=https://api.example.com
API_TIMEOUT=30

# Logging
LOG_LEVEL=info
LOG_FORMAT=json

# Application Settings
APP_NAME=MyApplication
APP_VERSION=1.0.0
"@
    
    New-EnvFile (Join-Path $configDir "base.env") $baseContent
    
    # Create dev.env
    $devContent = @"
# Development environment variables
# These override base.env settings

ASPNETCORE_ENVIRONMENT=Development
NODE_ENV=development

# Development API
API_BASE_URL=https://dev-api.example.com
LOG_LEVEL=debug

# Development Database
DATABASE_URL=postgres://user:pass@localhost:5432/myapp_dev

# Example secret retrieval (uncomment and modify based on your secret tool):
# Windows PowerShell SecretManagement:
# API_KEY=`$(Get-Secret -Name "MyApp-Dev-ApiKey" -AsPlainText -ErrorAction SilentlyContinue)
# Linux secret-tool:
# API_KEY=`$(secret-tool lookup service env-vars key API_KEY_DEV 2>/dev/null || echo "dev-fallback-key")
# macOS Keychain:
# API_KEY=`$(security find-generic-password -w -s "MyApp-Dev" -a "ApiKey" 2>/dev/null || echo "dev-fallback-key")
"@
    
    New-EnvFile (Join-Path $configDir "dev.env") $devContent
    
    # Create uat.env
    $uatContent = @"
# UAT/Staging environment variables
# These override base.env settings

ASPNETCORE_ENVIRONMENT=Staging
NODE_ENV=staging

# UAT API
API_BASE_URL=https://uat-api.example.com
LOG_LEVEL=warn

# UAT Database
DATABASE_URL=postgres://user:pass@uat-db:5432/myapp_uat

# Example secret retrieval (uncomment and modify based on your secret tool):
# API_KEY=`$(Get-Secret -Name "MyApp-UAT-ApiKey" -AsPlainText -ErrorAction SilentlyContinue)
"@
    
    New-EnvFile (Join-Path $configDir "uat.env") $uatContent
    
    # Create prod.env
    $prodContent = @"
# Production environment variables
# These override base.env settings

ASPNETCORE_ENVIRONMENT=Production
NODE_ENV=production

# Production API
API_BASE_URL=https://api.example.com
LOG_LEVEL=error

# Production Database
DATABASE_URL=postgres://user:pass@prod-db:5432/myapp_prod

# Example secret retrieval (uncomment and modify based on your secret tool):
# API_KEY=`$(Get-Secret -Name "MyApp-Prod-ApiKey" -AsPlainText -ErrorAction SilentlyContinue)
"@
    
    New-EnvFile (Join-Path $configDir "prod.env") $prodContent
    
    Write-Host ""
    Write-Host "Setup complete! 🎉" -ForegroundColor Green
    Write-Host ""
    Write-Host "Usage examples:" -ForegroundColor Cyan
    Write-Host "  ./env-run.ps1 dev npm start" -ForegroundColor Gray
    Write-Host "  ./env-run.ps1 prod ./deploy.sh" -ForegroundColor Gray
    Write-Host "  ./env-run.ps1 dev --export | Invoke-Expression" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Configuration files created in: $configDir" -ForegroundColor Gray
    Write-Host "Edit these files to match your application's requirements." -ForegroundColor Gray
    
    if ($secretTools.Count -gt 0) {
        Write-Host ""
        Write-Host "Secret management examples:" -ForegroundColor Cyan
        
        if ($secretTools -like "*Microsoft.PowerShell.SecretManagement*") {
            Write-Host "  Set-Secret -Name 'MyApp-Dev-ApiKey' -Secret 'your-secret-value'" -ForegroundColor Gray
        }
        
        if ($secretTools -like "*secret-tool*") {
            Write-Host "  secret-tool store --label='API Key Dev' service env-vars key API_KEY_DEV" -ForegroundColor Gray
        }
        
        if ($secretTools -like "*security*") {
            Write-Host "  security add-generic-password -s 'MyApp-Dev' -a 'ApiKey' -w 'your-secret-value'" -ForegroundColor Gray
        }
    }
    
} catch {
    Write-Error "Setup failed: $($_.Exception.Message)"
    exit 1
}