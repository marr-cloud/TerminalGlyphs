# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.1] - 2026-10-04

### Added

- `-Family` accepts font names (`CaskaydiaCove`, `MesloLGS`, `JetBrainsMonoNL`) and the names shown in terminal
  settings (`'JetBrainsMono Nerd Font Mono'`), suggests similar packages for unknown names, and completes the
  release packages with Tab.

### Changed

- Downloads are checked against the Nerd Fonts 3.5.1 checksums shipped with the module, instead of a `SHA-256.txt`
  downloaded from the same release.
- On Linux, Nerd Fonts in `~/.fonts` are updated in place instead of being reported as installed for all users.

### Fixed

- Replaced font files in subfolders of the font folder are cleaned up after a restart too.
- When `tar` cannot extract a package on Linux or macOS and `xz` is missing, the error says to install it.

## [0.2.0] - 2026-10-04

### Added

- `Install-TerminalGlyphSetup` installs or updates Nerd Fonts 3.5.1 for the current user on Windows, Linux and macOS
  (checking the release SHA-256) and replaces `Import-Module Terminal-Icons` in your profile, with a backup.
- Install from the PowerShell Gallery with `Install-PSResource TerminalGlyphs`.

### Fixed

- Updating fonts that are in use on Windows no longer makes apps fall back to other fonts: replaced files are only
  deleted after Windows restarts.

### Removed

- `tools/Install-NerdFont.ps1`, replaced by `Install-TerminalGlyphSetup`.

## [0.1.0] - 2026-10-04

### Added

- First release of TerminalGlyphs, a reimplementation of Terminal-Icons 0.11.0 for PowerShell 7.4+.
- Icons and colors for Go, Rust, Cloudflare/wrangler, Terraform, CloudFormation/SAM/CDK, mise, uv, pnpm, Bun,
  Astro, Vite/VitePress/Vitest, Docker, Claude, Kiro and other AI tools, Biome, Deno, TOML and just.
- JSONC user config with a JSON Schema.
- `Get-TerminalGlyph`, `Show-TerminalGlyphTheme`, `Find-NerdGlyph` and `Update-TerminalGlyphConfig`.

### Fixed

- Imports no longer fail with `Import-Clixml` errors when several sessions start at once: the module never writes
  to disk and loads its data lazily.
- Glyphs removed from Nerd Fonts 3.x (`nf-dev-code_badge`, `nf-dev-html5_multimedia`, `nf-dev-onedrive`) were replaced.
- The `rakefile` mapping, declared as an extension in Terminal-Icons, now matches by name.
