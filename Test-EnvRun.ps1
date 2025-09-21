#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Test script for env-run PowerShell utility

.DESCRIPTION
    Comprehensive test suite for the env-run.ps1 script that validates:
    - Error handling for invalid environments
    - Environment variable loading and overrides
    - Export functionality
    - Command execution with environment variables
    - Environment loading without commands
    - Cross-platform compatibility
#>

# Test counters
$script:TestsRun = 0
$script:TestsPassed = 0
$script:TestsFailed = 0

# Test configuration - cross-platform temporary directory
$TempBase = if ($IsWindows) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { "/tmp" }
$script:TestDir = Join-Path $TempBase "env-run-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$script:TestEnvDir = Join-Path $script:TestDir "env"

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
    
    # Create test directories
    New-Item -ItemType Directory -Path $script:TestEnvDir -Force | Out-Null
    
    # Create test environment files
    $baseContent = @"
BASE_VAR=base_value
SHARED_VAR=from_base
"@
    Set-Content -Path (Join-Path $script:TestEnvDir "base.env") -Value $baseContent
    
    $devContent = @"
ASPNETCORE_ENVIRONMENT=Development
DEV_VAR=dev_value
SHARED_VAR=from_dev
"@
    Set-Content -Path (Join-Path $script:TestEnvDir "dev.env") -Value $devContent
    
    $uatContent = @"
ASPNETCORE_ENVIRONMENT=Staging
UAT_VAR=uat_value
SHARED_VAR=from_uat
"@
    Set-Content -Path (Join-Path $script:TestEnvDir "uat.env") -Value $uatContent
    
    $prodContent = @"
ASPNETCORE_ENVIRONMENT=Production
PROD_VAR=prod_value
SHARED_VAR=from_prod
"@
    Set-Content -Path (Join-Path $script:TestEnvDir "prod.env") -Value $prodContent
    
    # Create test script that outputs relevant environment variables
    $testScriptContent = @"
#!/usr/bin/env pwsh
`$vars = @('BASE_VAR', 'SHARED_VAR', 'ASPNETCORE_ENVIRONMENT', 'DEV_VAR', 'UAT_VAR', 'PROD_VAR')
foreach (`$var in `$vars) {
    `$value = [Environment]::GetEnvironmentVariable(`$var)
    if (`$value) {
        Write-Output "`$var=`$value"
    }
}
"@
    
    $testScriptPath = Join-Path $script:TestDir "test-env-output.ps1"
    Set-Content -Path $testScriptPath -Value $testScriptContent
    
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
        # Set test environment variables
        $env:APPDATA = $script:TestDir
        $env:XDG_CONFIG_HOME = $script:TestDir
        
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
    } finally {
        # Clean up environment variables
        Remove-Item env:APPDATA -ErrorAction SilentlyContinue
        Remove-Item env:XDG_CONFIG_HOME -ErrorAction SilentlyContinue
    }
}

# Test functions
function Test-InvalidEnvironment {
    $script:TestsRun++
    Write-Host "$($script:Colors.Yellow)Running test: Invalid environment$($script:Colors.Reset)"
    
    try {
        & "./env-run.ps1" "invalid" "echo" "test" 2>&1 | Out-Null
        Write-Host "$($script:Colors.Red)✗ FAIL: Invalid environment - Expected exception but command succeeded$($script:Colors.Reset)"
        $script:TestsFailed++
    } catch {
        if ($_.Exception.Message -like "*Cannot validate argument on parameter 'Environment'*") {
            Write-Host "$($script:Colors.Green)✓ PASS: Invalid environment$($script:Colors.Reset)"
            $script:TestsPassed++
        } else {
            Write-Host "$($script:Colors.Red)✗ FAIL: Invalid environment - Wrong exception: $($_.Exception.Message)$($script:Colors.Reset)"
            $script:TestsFailed++
        }
    }
}

function Test-MissingCommand {
    Invoke-Test -TestName "No command (environment loading only)" -ExpectedOutput "Environment variables loaded for 'dev'" -TestScript {
        & "./env-run.ps1" "dev"
    }
}

function Test-DevEnvironment {
    Invoke-Test -TestName "Dev environment variables" -ExpectedOutput "ASPNETCORE_ENVIRONMENT=Development" -TestScript {
        & "./env-run.ps1" "dev" "pwsh" "-File" (Join-Path $script:TestDir "test-env-output.ps1")
    }
}

function Test-UatEnvironment {
    Invoke-Test -TestName "UAT environment variables" -ExpectedOutput "ASPNETCORE_ENVIRONMENT=Staging" -TestScript {
        & "./env-run.ps1" "uat" "pwsh" "-File" (Join-Path $script:TestDir "test-env-output.ps1")
    }
}

function Test-ProdEnvironment {
    Invoke-Test -TestName "Prod environment variables" -ExpectedOutput "ASPNETCORE_ENVIRONMENT=Production" -TestScript {
        & "./env-run.ps1" "prod" "pwsh" "-File" (Join-Path $script:TestDir "test-env-output.ps1")
    }
}

function Test-VariableOverride {
    Invoke-Test -TestName "Variable override (dev overrides base)" -ExpectedOutput "SHARED_VAR=from_dev" -TestScript {
        & "./env-run.ps1" "dev" "pwsh" "-File" (Join-Path $script:TestDir "test-env-output.ps1")
    }
}

function Test-ExportDev {
    Invoke-Test -TestName "Export dev environment" -ExpectedOutput "`$env:BASE_VAR = 'base_value'" -TestScript {
        & "./env-run.ps1" "dev" -Export
    }
}

function Test-ExportProd {
    Invoke-Test -TestName "Export prod environment" -ExpectedOutput "`$env:SHARED_VAR = 'from_prod'" -TestScript {
        & "./env-run.ps1" "prod" -Export
    }
}

function Test-SimpleCommand {
    Invoke-Test -TestName "Simple command execution" -ExpectedOutput "Hello from PowerShell" -TestScript {
        & "./env-run.ps1" "dev" "Write-Output" "Hello from PowerShell"
    }
}

function Test-CommandWithArguments {
    Invoke-Test -TestName "Command with multiple arguments" -ExpectedOutput "arg1`narg2`narg3" -TestScript {
        & "./env-run.ps1" "dev" "Write-Output" "arg1" "arg2" "arg3"
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
    Write-Host "$($script:Colors.Cyan)Starting env-run PowerShell tests...$($script:Colors.Reset)"
    
    # Check if env-run.ps1 exists
    if (-not (Test-Path "./env-run.ps1")) {
        Write-Host "$($script:Colors.Red)Error: env-run.ps1 script not found in current directory$($script:Colors.Reset)"
        exit 1
    }
    
    Setup-TestEnvironment
    
    try {
        # Run all tests
        Test-InvalidEnvironment
        Test-MissingCommand
        Test-DevEnvironment
        Test-UatEnvironment
        Test-ProdEnvironment
        Test-VariableOverride
        Test-ExportDev
        Test-ExportProd
        Test-SimpleCommand
        Test-CommandWithArguments
        
    } finally {
        Cleanup-TestEnvironment
    }
    
    Write-TestSummary
}

# Run main function
Main