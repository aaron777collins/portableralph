# Changelog

All notable changes to PortableRalph will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.8.0] - 2026-02-21

### Added
- Comprehensive security audit with TDD approach and security checklist
- Code quality improvements and enhanced testing infrastructure  
- Windows CI support and comprehensive Windows compatibility documentation
- Enhanced error handling across all PortableRalph components
- Comprehensive PowerShell syntax validation tests
- Production readiness documentation including troubleshooting and performance guides
- Docker sandbox implementation (PR #2 from dmelo)
- Comprehensive Windows installation and CI documentation

### Changed
- Improved launcher.bat reliability with better test result handling
- Enhanced parameter-based help handling with error protection
- Improved PowerShell invocation and quoting in batch scripts

### Fixed
- Critical error handling validation failures in p4-3
- PowerShell syntax errors for Windows compatibility  
- Unmatched quote issues in ralph.ps1
- Error handling for invalid modes, options, and help requests
- Launcher.bat reliability improvements and batch syntax errors
- Email notifications fix (PR #3 from avwohl)
- Unicode character issues causing PowerShell syntax errors
- YAML parsing errors in Windows workflow
- SSRF protection - properly reject localhost URLs

### Security
- Comprehensive security audit report and security theater removal
- SSRF protection improvements for URL validation
- Enhanced error protection in parameter handling

## [1.7.0] - 2025-01-15

### Added
- Windows support and concurrency fixes
- Claude Code skill integration for ralph
- New terminal-style icon with white variant for better visibility

### Changed
- Updated icons to new R> terminal style
- Improved icon scaling and centering

## [1.6.0] - 2025-01-15

### Added
- **Self-update system**: `ralph update` command for managing versions
  - `ralph update` - Update to latest version
  - `ralph update --check` - Check for updates without installing
  - `ralph update --list` - List all available versions
  - `ralph update <version>` - Install specific version (e.g., `ralph update 1.5.0`)
  - `ralph rollback` - Revert to previous version
- Version history tracking in `~/.ralph_version_history`
- Automatic backup before updates in `~/.ralph_backup/`
- GitHub releases for version management

### Changed
- Updated help text to include update commands

## [1.5.0] - 2025-01-15

### Added
- **Auto-commit toggle**: Control whether Ralph commits after each iteration
  - `ralph config commit on/off` - Enable/disable globally
  - `DO_NOT_COMMIT` directive in plan files for per-plan control
- Config file syntax validation before sourcing

### Fixed
- Color variable ordering bug in `validate_config()` function

## [1.4.0] - 2025-01-14

### Added
- Notification subcommands: `ralph notify setup` and `ralph notify test`
- Namespaced CLI structure for better organization

### Changed
- Improved help text with alias information
- Updated installer for better interactive piped install support

### Fixed
- ANSI escape sequence rendering (`echo -e` flag)
- Interactive input when piping installer via curl (`< /dev/tty`)

## [1.3.0] - 2025-01-13

### Added
- Multi-platform notification support (Slack, Discord, Telegram, custom scripts)
- Notification frequency configuration (`RALPH_NOTIFY_FREQUENCY`)
- Setup wizard for notifications

## [1.2.0] - 2025-01-12

### Added
- Plan mode for task breakdown before implementation
- Automatic exit after planning completes
- Progress file format improvements

## [1.1.0] - 2025-01-11

### Added
- Max iterations limit for build mode
- Improved progress tracking

## [1.0.0] - 2025-01-10

### Added
- Initial release
- Autonomous AI development loop using Claude CLI
- Build mode for task implementation
- Progress file tracking
- Git integration for automatic commits

[Unreleased]: https://github.com/aaron777collins/portableralph/compare/v1.8.0...HEAD
[1.8.0]: https://github.com/aaron777collins/portableralph/compare/v1.7.0...v1.8.0
[1.7.0]: https://github.com/aaron777collins/portableralph/compare/v1.6.0...v1.7.0
[1.6.0]: https://github.com/aaron777collins/portableralph/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/aaron777collins/portableralph/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/aaron777collins/portableralph/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/aaron777collins/portableralph/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/aaron777collins/portableralph/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/aaron777collins/portableralph/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/aaron777collins/portableralph/releases/tag/v1.0.0
