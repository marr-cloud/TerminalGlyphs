# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Readable Dracula colors: 14 colors below 3:1 contrast on the Dracula background (`#282A36`) are lightened, keeping
  their hue: Python and uv (`pyproject.toml`, `uv.lock`, `.venv`), Terraform, Julia, `.DS_Store` and `vue.config.*`. The
  contrast test now covers the Dracula theme too.

## [0.3.2] - 2026-10-04

### Changed

- Readable colors: 281 colors of the light theme now have at least 3:1 contrast on white (for example `.js`, `.ts`,
  `.sql` and `CHANGELOG` were bright yellow or green) and 10 colors of the default theme have at least 3:1 on a dark
  background (`#1E1E1E`), keeping their hue. A test keeps every color of both themes readable.
- The performance test reports the median of three first listings.

## [0.3.1] - 2026-10-04

### Changed

- The first listing of a session is faster (about 290 ms instead of 450 ms in 0.3.0, and below 0.2.2): the built-in
  themes are loaded without a function call per entry, and the build stores the ANSI sequence of every theme color.

## [0.3.0] - 2026-10-04

### Added

- 165 file names and 346 extensions with icons and colors from nvim-web-devicons (for example `.prettierrc`,
  `.editorconfig`, `.env`, `eslint.config.js`, `.graphql`, `.nix`, `.zig`, `.d.ts`, `.test.ts`), plus
  `config.ru`. Colors are made readable on dark backgrounds (default), on white (light) and mapped to the Dracula
  palette.
- Colors for the `.codex`, `.cursor`, `.gemini` and `.kiro` folders.
- `tools/Import-DeviconsMapping.ps1` to report and apply mappings from the vendored nvim-web-devicons data.

### Changed

- 19 file icons now use the nvim-web-devicons glyph and color: PowerShell (`.ps1`, `.psd1`, `.psm1`), YAML, npm
  (`package.json`, `package-lock.json`), `tsconfig.json`, Jupyter, Photoshop, `.vsix`, `.csproj`, clang-format and
  clang-tidy, subtitles (`.ass`, `.srt`, `.lrc`) and `code_of_conduct.md`.

### Fixed

- Every file icon has a color in the default, light and Dracula themes.

## [0.2.2] - 2026-10-04

### Changed

- `-Family` accepts variant suffixes only for the families that ship them: `JetBrainsMonoNL`, `MesloLGS`/`LGM`/`LGL`
  (with or without `DZ`), `OverpassM` and `OpenDyslexicM`. Unknown names now get suggestions from package and font
  names (`MonaspiceNe` -> `Monaspace`, `'Terminus TTF'` -> `Terminus`, `'iA Writer Mono'` -> `iA-Writer`).
- `build.ps1` checks the vendored Nerd Fonts data against `vendor/nerd-fonts/manifest.json` (version and SHA-256 of
  each file), so a partial update fails the build instead of the download.
- `tools/Test-Publish.ps1` runs the rehearsal in a child pwsh: no more retries to remove its temporary folder, and
  temporary paths with quotes work.

### Fixed

- A font that cannot be replaced in several folders is counted once.
- The fontconfig test no longer writes to the real `~/.cache/fontconfig`.

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
