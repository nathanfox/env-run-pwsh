# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a PowerShell port of the original env-run bash utility, designed to provide cross-platform environment management for PowerShell 7+ users. The project consists of three main components:

- `env-run.ps1`: Main PowerShell script that loads environment variables and executes commands
- `setup-envs.ps1`: Setup script that creates environment configuration files and detects secret management tools
- Test scripts: `Test-EnvRun.ps1` and `Test-SetupEnvs.ps1` for comprehensive testing

## Core Architecture

The utility uses a layered environment variable approach similar to the original:

1. **Base variables** (`base.env`) - shared across all environments
2. **Environment-specific variables** (`{dev,uat,prod}.env`) - override base settings
3. **Cross-platform secret management** - integrates with multiple secret storage backends

## Key Differences from Original env-run

### Cross-Platform Secret Management
Unlike the original which only supported Linux `secret-tool`, this version supports:
- **PowerShell SecretManagement** module (recommended)
- **Linux**: `secret-tool` (libsecret)
- **macOS**: `security` command (Keychain)
- **Windows**: `cmdkey` command (Credential Manager)

### Configuration Paths
Platform-specific configuration directories:
- **Windows**: `$env:APPDATA\env\`
- **Linux/macOS**: `$env:XDG_CONFIG_HOME/env/` or `~/.config/env/`

### PowerShell Integration
- Native PowerShell parameter handling with `[Parameter]` attributes
- PowerShell-style variable export: `$env:VARIABLE = 'value'`
- Cross-platform compatibility using `$IsWindows` and environment detection
- Error handling with PowerShell's `try-catch` blocks

## Usage Patterns

**Command execution:**
```powershell
./env-run.ps1 dev npm start
./env-run.ps1 prod ./deploy.ps1
```

**Environment variable export:**
```powershell
./env-run.ps1 dev --export | Invoke-Expression
./env-run.ps1 prod --export
```

## Testing Strategy

The test suite uses PowerShell's native testing capabilities:
- **Isolated test environments**: Each test runs in a temporary directory
- **Cross-platform color support**: ANSI escape codes for colored output
- **Comprehensive coverage**: Tests error handling, environment loading, secret detection, and cross-platform compatibility

## Development Notes

### PowerShell Best Practices
- Uses `#!/usr/bin/env pwsh` shebang for cross-platform compatibility
- Implements proper parameter validation with `[ValidateSet]`
- Uses `[Environment]::SetEnvironmentVariable()` for reliable variable setting
- Handles both Windows and Unix path separators correctly

### Error Handling
- Comprehensive input validation for environment names and file paths
- Graceful fallback when configuration files don't exist
- Detailed error messages with usage examples
- Proper exit codes for success/failure scenarios

### Secret Management Integration
- Automatic detection of available secret management tools
- Platform-specific examples in generated environment files
- Fallback mechanisms when secret tools aren't available
- Clear documentation for each supported secret backend

## File Structure

```
env-run-pwsh/
├── env-run.ps1           # Main environment management script
├── setup-envs.ps1        # Environment setup and configuration
├── Test-EnvRun.ps1       # Test suite for main script
├── Test-SetupEnvs.ps1    # Test suite for setup script
├── README.md             # User documentation
└── CLAUDE.md             # This file
```

## Maintenance Guidelines

When modifying the scripts:
- Maintain compatibility with PowerShell 7+ across all platforms
- Test on Windows, Linux, and macOS if possible
- Keep the same command-line interface as the original env-run
- Update tests when adding new functionality
- Document any new secret management integrations
- Follow PowerShell naming conventions (Verb-Noun for functions)

## Performance Considerations

- Environment file parsing is optimized for typical configuration file sizes
- Secret tool detection is cached during setup to avoid repeated checks
- Cross-platform compatibility checks are minimal and efficient
- Test execution uses parallel-safe temporary directories