# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
