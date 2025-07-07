#!/usr/bin/env pwsh

<#
.SYNOPSIS
    A PowerShell environment management utility for running commands with environment-specific configurations.

.DESCRIPTION
    env-run allows you to manage multiple environment configurations (dev, uat, prod) and execute commands
    with the appropriate environment variables loaded. It supports layered configuration with base settings
    and environment-specific overrides, plus cross-platform secret management.

.PARAMETER Environment
    The environment to use (dev, uat, prod)

.PARAMETER Command
    The command to execute (optional, use --export to output environment variables)

.PARAMETER Arguments
    Arguments to pass to the command

.PARAMETER Export
    Output export statements for environment variables instead of executing a command

.EXAMPLE
    ./env-run.ps1 dev npm start
    ./env-run.ps1 prod ./deploy.sh
    ./env-run.ps1 dev --export | Invoke-Expression

.NOTES
    Environment files are stored in:
    - Windows: $env:APPDATA\env\
    - Linux/macOS: $env:XDG_CONFIG_HOME/env/ or ~/.config/env/
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('dev', 'uat', 'prod')]
    [string]$Environment,

    [Parameter(Position = 1)]
    [string]$Command,

    [Parameter(Position = 2, ValueFromRemainingArguments = $true)]
    [string[]]$Arguments,

    [switch]$Export
)

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

# Load environment file and return variables as hashtable
function Import-EnvFile {
    param([string]$FilePath)
    
    $envVars = @{}
    
    if (Test-Path $FilePath) {
        $content = Get-Content $FilePath -ErrorAction SilentlyContinue
        foreach ($line in $content) {
            # Skip comments and empty lines
            if ($line -match '^\s*#' -or $line -match '^\s*$') {
                continue
            }
            
            # Match KEY=VALUE pattern
            if ($line -match '^([^=]+)=(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                
                # Remove quotes if present
                if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
                    $value = $matches[1]
                }
                
                $envVars[$key] = $value
            }
        }
    }
    
    return $envVars
}

# Set environment variables
function Set-EnvironmentVariables {
    param([hashtable]$Variables)
    
    foreach ($key in $Variables.Keys) {
        [Environment]::SetEnvironmentVariable($key, $Variables[$key], 'Process')
    }
}

# Main execution
try {
    $configDir = Get-ConfigDirectory
    $baseFile = Join-Path $configDir "base.env"
    $envFile = Join-Path $configDir "$Environment.env"
    
    # Check if environment file exists
    if (-not (Test-Path $envFile)) {
        Write-Error "Environment file not found: $envFile"
        Write-Host "Usage: ./env-run.ps1 <dev|uat|prod> <command> [args...]" -ForegroundColor Red
        Write-Host "       ./env-run.ps1 <dev|uat|prod> --export" -ForegroundColor Red
        exit 1
    }
    
    # Load base environment variables
    $baseVars = Import-EnvFile $baseFile
    
    # Load environment-specific variables (these override base)
    $envVars = Import-EnvFile $envFile
    
    # Merge variables (env-specific overrides base)
    $allVars = $baseVars.Clone()
    foreach ($key in $envVars.Keys) {
        $allVars[$key] = $envVars[$key]
    }
    
    # Handle --export flag
    if ($Export) {
        foreach ($key in $allVars.Keys) {
            Write-Output "`$env:$key = '$($allVars[$key])'"
        }
        exit 0
    }
    
    # Check if command is provided
    if ([string]::IsNullOrEmpty($Command)) {
        Write-Error "No command specified"
        Write-Host "Usage: ./env-run.ps1 <dev|uat|prod> <command> [args...]" -ForegroundColor Red
        Write-Host "       ./env-run.ps1 <dev|uat|prod> --export" -ForegroundColor Red
        exit 1
    }
    
    # Set environment variables
    Set-EnvironmentVariables $allVars
    
    # Execute the command
    if ($Arguments) {
        & $Command @Arguments
    } else {
        & $Command
    }
    
    exit $LASTEXITCODE
    
} catch {
    Write-Error "Error: $($_.Exception.Message)"
    exit 1
}