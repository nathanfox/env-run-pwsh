# env-run-pwsh

A lightweight PowerShell environment management utility for running commands with environment-specific configurations. This is a cross-platform PowerShell port of the original [env-run](https://github.com/user/env-run) bash utility.

## Overview

`env-run-pwsh` allows you to manage multiple environment configurations (dev, uat, prod) and execute commands with the appropriate environment variables loaded. It supports layered configuration with base settings and environment-specific overrides, plus cross-platform secret management.

## Features

- **Multi-environment support**: Separate configurations for dev, uat, and prod
- **Layered configuration**: Base settings with environment-specific overrides
- **Cross-platform secret management**: Integration with platform-specific secret stores
- **Two usage modes**: Environment loading and command execution
- **Cross-platform compatibility**: Works on Windows, Linux, and macOS
- **PowerShell 7+ support**: Designed for modern PowerShell Core

## Installation

1. Ensure you have PowerShell 7+ installed (`pwsh` command available)
2. Copy `env-run.ps1` to your desired location
3. Run the setup script to create initial environment files: `./setup-envs.ps1`

## Usage

### Environment Loading
Load environment variables for the current session:
```powershell
./env-run.ps1 dev
./env-run.ps1 prod
./env-run.ps1 uat
```

### Command Execution
Run commands with environment-specific variables:
```powershell
./env-run.ps1 dev npm start
./env-run.ps1 prod ./deploy.sh
./env-run.ps1 uat python manage.py migrate
```

## Configuration

Environment files are stored in platform-specific locations:
- **Windows**: `%APPDATA%\env\`
- **Linux/macOS**: `$XDG_CONFIG_HOME/env/` or `~/.config/env/`

Files include:
- `base.env` - Variables shared across all environments
- `dev.env` - Development-specific variables
- `uat.env` - UAT/staging-specific variables
- `prod.env` - Production-specific variables

### Example Configuration

**base.env:**
```bash
API_BASE_URL=https://api.example.com
LOG_LEVEL=info
APP_NAME=MyApplication
```

**dev.env:**
```bash
ASPNETCORE_ENVIRONMENT=Development
NODE_ENV=development
API_BASE_URL=https://dev-api.example.com
LOG_LEVEL=debug
```

## Secret Management

The utility supports multiple cross-platform secret storage options:

### PowerShell SecretManagement Module (Recommended)
```powershell
# Install the module
Install-Module Microsoft.PowerShell.SecretManagement

# Store a secret
Set-Secret -Name "MyApp-Dev-ApiKey" -Secret "your-secret-value"

# Use in environment files
API_KEY=$(Get-Secret -Name "MyApp-Dev-ApiKey" -AsPlainText -ErrorAction SilentlyContinue)
```

### Linux (secret-tool)
```bash
# Install libsecret-tools
sudo apt install libsecret-tools

# Store a secret
secret-tool store --label='API Key Dev' service env-vars key API_KEY_DEV

# Use in environment files
API_KEY=$(secret-tool lookup service env-vars key API_KEY_DEV 2>/dev/null || echo "fallback-value")
```

### macOS (Keychain)
```bash
# Store a secret
security add-generic-password -s "MyApp-Dev" -a "ApiKey" -w "your-secret-value"

# Use in environment files
API_KEY=$(security find-generic-password -w -s "MyApp-Dev" -a "ApiKey" 2>/dev/null || echo "fallback-value")
```

### Windows (Credential Manager)
```powershell
# Store a secret
cmdkey /add:"MyApp-Dev-ApiKey" /user:"ApiKey" /pass:"your-secret-value"

# Use in environment files (via PowerShell)
$API_KEY = (Get-StoredCredential -Target "MyApp-Dev-ApiKey").GetNetworkCredential().Password
```

## Testing

Run the comprehensive test suites to verify functionality:

**Test the main env-run utility:**
```powershell
./Test-EnvRun.ps1
```

**Test the setup script:**
```powershell
./Test-SetupEnvs.ps1
```

The test scripts verify:
- **env-run tests**: Error handling, environment loading, variable overrides, command execution, environment loading without commands
- **setup-envs tests**: Directory creation, file generation, content validation, cross-platform compatibility, secret tool detection

## Requirements

- **PowerShell 7+** (pwsh command)
- **Optional secret management tools**:
  - PowerShell: `Microsoft.PowerShell.SecretManagement` module
  - Linux: `libsecret-tools` package
  - macOS: `security` command (built-in)
  - Windows: `cmdkey` command (built-in)

## Cross-Platform Compatibility

The utility automatically detects the platform and adjusts behavior accordingly:

- **Configuration paths**: Uses platform-appropriate directories
- **Secret management**: Detects and uses available secret storage tools
- **Command execution**: Handles platform-specific command syntax
- **Path handling**: Correctly processes Windows and Unix-style paths

## Differences from Original env-run

While maintaining the same core functionality, this PowerShell version includes:

- **Cross-platform secret management**: Supports multiple secret storage backends
- **Enhanced error handling**: More detailed error messages and validation
- **PowerShell integration**: Native PowerShell variable export syntax
- **Modern PowerShell features**: Uses PowerShell 7+ cmdlets and syntax
- **Comprehensive testing**: Extensive test coverage for all platforms

## Examples

### Basic Usage
```powershell
# Load development environment
./env-run.ps1 dev

# Run a development server
./env-run.ps1 dev npm run dev

# Deploy to production
./env-run.ps1 prod ./deploy.ps1

# Run database migrations in UAT
./env-run.ps1 uat dotnet ef database update
```

### Advanced Usage
```powershell
# Run PowerShell script with environment
./env-run.ps1 prod pwsh -File ./my-script.ps1

# Load environment then run multiple commands
./env-run.ps1 dev
npm install
npm run build
npm test
```

## License

This project is provided as-is for personal and commercial use.

## Contributing

Feel free to submit issues and enhancement requests. This project aims to maintain compatibility with the original env-run while adding PowerShell-specific improvements.