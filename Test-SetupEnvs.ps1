#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Test script for setup-envs.ps1 utility

.DESCRIPTION
    Test suite for the setup-envs.ps1 script that validates:
    - Directory creation in correct locations
    - Environment file generation with proper content
    - Cross-platform path handling
    - Secret tool detection
    - Error handling and edge cases
#>

# Test counters
$script:TestsRun = 0
$script:TestsPassed = 0
$script:TestsFailed = 0

# Test configuration
$script:TestDir = Join-Path $env:TEMP "setup-envs-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# ANSI color codes for cross-platform compatibility
$script:Colors = @{
    Red = "`e[0;31m"
    Green = "`e[0;32m"
    Yellow = "`e[1;33m"
    Cyan = "`e[0;36m"
    Gray = "`e[0;37m"
    Reset = "`e[0m"
}

# Setup test environment
function Setup-TestEnvironment {
    Write-Host "$($script:Colors.Yellow)Setting up test environment...$($script:Colors.Reset)"
    
    # Create test directory
    New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
    
    Write-Host "$($script:Colors.Green)Test environment setup complete$($script:Colors.Reset)"
}

# Cleanup test environment
function Cleanup-TestEnvironment {
    Write-Host "$($script:Colors.Yellow)Cleaning up test environment...$($script:Colors.Reset)"
    
    if (Test-Path $script:TestDir) {
        Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host "$($script:Colors.Green)Cleanup complete$($script:Colors.Reset)"
}

# Run a single test
function Invoke-Test {
    param(
        [string]$TestName,
        [scriptblock]$TestScript,
        [string]$ExpectedOutput = $null,
        [bool]$ExpectFailure = $false
    )
    
    $script:TestsRun++
    Write-Host "$($script:Colors.Yellow)Running test: $TestName$($script:Colors.Reset)"
    
    try {
        # Capture output and exit code
        $output = ""
        $exitCode = 0
        
        # Run test script
        $result = & $TestScript 2>&1
        if ($LASTEXITCODE) {
            $exitCode = $LASTEXITCODE
        }
        
        $output = $result | Out-String
        
        # Evaluate test result
        $testPassed = $false
        
        if ($ExpectFailure) {
            # For failure tests, we expect non-zero exit code and specific output
            if ($exitCode -ne 0 -and ($null -eq $ExpectedOutput -or $output -like "*$ExpectedOutput*")) {
                $testPassed = $true
            }
        } else {
            # For success tests, we expect zero exit code and specific output
            if ($exitCode -eq 0 -and ($null -eq $ExpectedOutput -or $output -like "*$ExpectedOutput*")) {
                $testPassed = $true
            }
        }
        
        if ($testPassed) {
            Write-Host "$($script:Colors.Green)✓ PASS: $TestName$($script:Colors.Reset)"
            $script:TestsPassed++
        } else {
            Write-Host "$($script:Colors.Red)✗ FAIL: $TestName$($script:Colors.Reset)"
            Write-Host "Expected: $ExpectedOutput"
            Write-Host "Actual: $output"
            Write-Host "Exit code: $exitCode"
            $script:TestsFailed++
        }
        
    } catch {
        Write-Host "$($script:Colors.Red)✗ ERROR: $TestName - $($_.Exception.Message)$($script:Colors.Reset)"
        $script:TestsFailed++
    }
}

# Test functions
function Test-DirectoryCreation {
    Invoke-Test -TestName "Directory creation" -ExpectedOutput "Setup complete!" -TestScript {
        # Set test environment
        $env:APPDATA = $script:TestDir
        $env:XDG_CONFIG_HOME = $script:TestDir
        
        try {
            & "./setup-envs.ps1"
            
            # Verify directory was created
            $expectedDir = if ($IsWindows -or $env:OS -eq 'Windows_NT') {
                Join-Path $script:TestDir "env"
            } else {
                Join-Path $script:TestDir "env"
            }
            
            if (Test-Path $expectedDir) {
                Write-Output "Directory created successfully"
                Write-Output "Setup complete!"
            } else {
                Write-Error "Directory was not created"
            }
        } finally {
            Remove-Item env:APPDATA -ErrorAction SilentlyContinue
            Remove-Item env:XDG_CONFIG_HOME -ErrorAction SilentlyContinue
        }
    }
}

function Test-FileGeneration {
    Invoke-Test -TestName "Environment file generation" -TestScript {
        # Set test environment
        $env:APPDATA = $script:TestDir
        $env:XDG_CONFIG_HOME = $script:TestDir
        
        try {
            & "./setup-envs.ps1" | Out-Null
            
            # Check for all expected files
            $expectedDir = Join-Path $script:TestDir "env"
            $expectedFiles = @("base.env", "dev.env", "uat.env", "prod.env")
            $allFilesExist = $true
            
            foreach ($file in $expectedFiles) {
                $filePath = Join-Path $expectedDir $file
                if (-not (Test-Path $filePath)) {
                    $allFilesExist = $false
                    Write-Error "Missing file: $file"
                }
            }
            
            if ($allFilesExist) {
                Write-Output "All environment files created successfully"
            }
        } finally {
            Remove-Item env:APPDATA -ErrorAction SilentlyContinue
            Remove-Item env:XDG_CONFIG_HOME -ErrorAction SilentlyContinue
        }
    }
}

function Test-FileContent {
    Invoke-Test -TestName "Environment file content validation" -TestScript {
        # Set test environment
        $env:APPDATA = $script:TestDir
        $env:XDG_CONFIG_HOME = $script:TestDir
        
        try {
            & "./setup-envs.ps1" | Out-Null
            
            # Check content of dev.env
            $devEnvPath = Join-Path $script:TestDir "env" "dev.env"
            if (Test-Path $devEnvPath) {
                $content = Get-Content $devEnvPath -Raw
                if ($content -like "*ASPNETCORE_ENVIRONMENT=Development*" -and $content -like "*NODE_ENV=development*") {
                    Write-Output "Dev environment file content is correct"
                } else {
                    Write-Error "Dev environment file content is incorrect"
                }
            } else {
                Write-Error "Dev environment file not found"
            }
            
            # Check content of base.env
            $baseEnvPath = Join-Path $script:TestDir "env" "base.env"
            if (Test-Path $baseEnvPath) {
                $content = Get-Content $baseEnvPath -Raw
                if ($content -like "*API_BASE_URL=https://api.example.com*") {
                    Write-Output "Base environment file content is correct"
                } else {
                    Write-Error "Base environment file content is incorrect"
                }
            } else {
                Write-Error "Base environment file not found"
            }
        } finally {
            Remove-Item env:APPDATA -ErrorAction SilentlyContinue
            Remove-Item env:XDG_CONFIG_HOME -ErrorAction SilentlyContinue
        }
    }
}

function Test-ExistingFilesHandling {
    Invoke-Test -TestName "Existing files handling" -ExpectedOutput "File already exists" -TestScript {
        # Set test environment
        $env:APPDATA = $script:TestDir
        $env:XDG_CONFIG_HOME = $script:TestDir
        
        try {
            # Create environment directory and a file
            $envDir = Join-Path $script:TestDir "env"
            New-Item -ItemType Directory -Path $envDir -Force | Out-Null
            Set-Content -Path (Join-Path $envDir "base.env") -Value "EXISTING_VAR=test"
            
            # Run setup script
            & "./setup-envs.ps1"
            
        } finally {
            Remove-Item env:APPDATA -ErrorAction SilentlyContinue
            Remove-Item env:XDG_CONFIG_HOME -ErrorAction SilentlyContinue
        }
    }
}

function Test-SecretToolDetection {
    Invoke-Test -TestName "Secret tool detection" -ExpectedOutput "Checking for secret management tools" -TestScript {
        # Set test environment
        $env:APPDATA = $script:TestDir
        $env:XDG_CONFIG_HOME = $script:TestDir
        
        try {
            & "./setup-envs.ps1"
        } finally {
            Remove-Item env:APPDATA -ErrorAction SilentlyContinue
            Remove-Item env:XDG_CONFIG_HOME -ErrorAction SilentlyContinue
        }
    }
}

function Test-CrossPlatformPaths {
    Invoke-Test -TestName "Cross-platform path handling" -TestScript {
        # Test Windows path
        $env:APPDATA = $script:TestDir
        $env:OS = 'Windows_NT'
        
        try {
            & "./setup-envs.ps1" | Out-Null
            
            # Verify Windows path structure
            $windowsEnvDir = Join-Path $script:TestDir "env"
            if (Test-Path $windowsEnvDir) {
                Write-Output "Windows path handling successful"
            } else {
                Write-Error "Windows path handling failed"
            }
            
        } finally {
            Remove-Item env:APPDATA -ErrorAction SilentlyContinue
            Remove-Item env:OS -ErrorAction SilentlyContinue
        }
        
        # Test Unix path
        $env:XDG_CONFIG_HOME = $script:TestDir
        Remove-Item env:OS -ErrorAction SilentlyContinue
        
        try {
            & "./setup-envs.ps1" | Out-Null
            
            # Verify Unix path structure
            $unixEnvDir = Join-Path $script:TestDir "env"
            if (Test-Path $unixEnvDir) {
                Write-Output "Unix path handling successful"
            } else {
                Write-Error "Unix path handling failed"
            }
            
        } finally {
            Remove-Item env:XDG_CONFIG_HOME -ErrorAction SilentlyContinue
        }
    }
}

# Print test summary
function Write-TestSummary {
    Write-Host ""
    Write-Host "$($script:Colors.Cyan)=========================================$($script:Colors.Reset)"
    Write-Host "$($script:Colors.Cyan)Test Summary:$($script:Colors.Reset)"
    Write-Host "Tests run: $script:TestsRun"
    Write-Host "$($script:Colors.Green)Tests passed: $script:TestsPassed$($script:Colors.Reset)"
    Write-Host "$($script:Colors.Red)Tests failed: $script:TestsFailed$($script:Colors.Reset)"
    Write-Host "$($script:Colors.Cyan)=========================================$($script:Colors.Reset)"
    
    if ($script:TestsFailed -eq 0) {
        Write-Host "$($script:Colors.Green)All tests passed!$($script:Colors.Reset)"
        exit 0
    } else {
        Write-Host "$($script:Colors.Red)Some tests failed!$($script:Colors.Reset)"
        exit 1
    }
}

# Main execution
function Main {
    Write-Host "$($script:Colors.Cyan)Starting setup-envs PowerShell tests...$($script:Colors.Reset)"
    
    # Check if setup-envs.ps1 exists
    if (-not (Test-Path "./setup-envs.ps1")) {
        Write-Host "$($script:Colors.Red)Error: setup-envs.ps1 script not found in current directory$($script:Colors.Reset)"
        exit 1
    }
    
    Setup-TestEnvironment
    
    try {
        # Run all tests
        Test-DirectoryCreation
        Test-FileGeneration
        Test-FileContent
        Test-ExistingFilesHandling
        Test-SecretToolDetection
        Test-CrossPlatformPaths
        
    } finally {
        Cleanup-TestEnvironment
    }
    
    Write-TestSummary
}

# Run main function
Main