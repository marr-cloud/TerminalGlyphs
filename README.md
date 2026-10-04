# TerminalGlyphs

Nerd Font icons and colors for files and folders in `Get-ChildItem`, for PowerShell 7.4+.

TerminalGlyphs is a reimplementation of [Terminal-Icons](https://github.com/devblackops/Terminal-Icons), which has not
been maintained since 2023. It keeps the Terminal-Icons mappings and colors (with the colors that were hard to read on
white or dark backgrounds darkened or lightened to 3:1 contrast, keeping their hue) and adds:

- **Reliable imports.** Terminal-Icons rewrites its theme files on every import. When several sessions start at once
  (split panes, restored tabs), they corrupt those files, and hosts that load the profile inside `try { }` (such as
  Warp) then fail with `Import-Clixml: ... dictionary entry ...`. TerminalGlyphs never writes to disk.
- **Fast imports.** Data loads on the first listing, not on import.
- **Icons for current tooling**: Go, Rust, Cloudflare/wrangler, Terraform, CloudFormation/SAM/CDK, mise, uv, pnpm,
  Bun, Astro, Vite/VitePress/Vitest, Docker, Claude, Kiro and other AI tools, Biome, Deno and just, plus hundreds of
  file names and extensions imported from [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons).
- **A JSONC config** with a JSON Schema, instead of cmdlets that store themes in `%APPDATA%`.

## Requirements

- PowerShell 7.4 or later.
- A Nerd Font **3.5.1 or later** in your terminal. Several icons (Cloudflare, Astro, Bun, pnpm, Vite, Terraform,
  Claude) do not exist in older versions, and some older code points draw different logos. `Install-TerminalGlyphSetup`
  installs or updates it for you.

## Install

```powershell
Install-PSResource TerminalGlyphs
Import-Module TerminalGlyphs; Install-TerminalGlyphSetup
```

`Install-TerminalGlyphSetup`:

- Updates the Nerd Fonts 3.x families in your user font folder that are older than 3.5.1, and installs JetBrainsMono
  if you have no Nerd Font (or the packages you pass with `-Family`). If you still have Nerd Fonts 2.x files, it
  asks you to remove them first. Packages are downloaded from the Nerd Fonts GitHub release and checked against the
  SHA-256 checksums shipped with the module. No admin rights needed. Works on Windows, Linux and macOS.
- Replaces `Import-Module Terminal-Icons` in your profile with `Import-Module TerminalGlyphs` (or adds it), keeping a
  backup next to the profile.
- Prints one result per step. Preview with `-WhatIf`; use `-SkipFont` or `-SkipProfile` to skip a step.
- Installs other fonts with `-Family`, which takes the release package (`FiraCode`, `CascadiaCode`), the font name
  (`CaskaydiaCove`, `MesloLGS`) or, for most fonts, the name in your terminal settings
  (`'JetBrainsMono Nerd Font Mono'`). Press Tab after `-Family` to list the packages.

Then choose the Nerd Font in your terminal settings (the command tells you its name) and open a new terminal.
On Windows, fonts that were in use are replaced after you **Restart Windows**; until then, apps keep the old version.

## Configuration

Optional. TerminalGlyphs reads the first of these that is set:

1. `$env:TERMINALGLYPHS_CONFIG`
2. `$env:XDG_CONFIG_HOME/terminalglyphs/config.jsonc`
3. `~/.config/terminalglyphs/config.jsonc`

```jsonc
{
  "$schema": "https://raw.githubusercontent.com/marr-cloud/TerminalGlyphs/main/schema/config.schema.json",
  "colorTheme": "default", // default | light | dracula
  "icons": {
    "files": { "names": { "justfile": "nf-md-format_list_checks" } },
    "directories": { "names": { "infra": "nf-dev-terraform" } }
  },
  "colors": {
    "files": { "extensions": { ".go": "00ADD8" } }
  }
}
```

Your entries are merged on top of the theme. Rules, in order: symbolic link or junction, exact name, longest
extension (`app.d.ts` matches `.d.ts` before `.ts`), default. Names are not case-sensitive. Invalid entries are skipped
with a single warning; the rest still applies. Run `Update-TerminalGlyphConfig` after editing.

## Commands

| Command | Purpose |
|---|---|
| `Install-TerminalGlyphSetup` | Install or update Nerd Fonts and add TerminalGlyphs to your profile. |
| `Get-TerminalGlyph <path>` | Which icon and color a file gets, and which rule matched. |
| `Show-TerminalGlyphTheme` | Preview every mapping of the active themes. |
| `Find-NerdGlyph <name>` | Search Nerd Fonts glyph names for your config. |
| `Update-TerminalGlyphConfig` | Reload your config in the current session. |
| `Format-TerminalGlyph` | Used by the `Get-ChildItem` view. |

## Development

Install from source:

```powershell
git clone https://github.com/marr-cloud/TerminalGlyphs.git
cd TerminalGlyphs
./build.ps1
$target = Join-Path ($env:PSModulePath -split [IO.Path]::PathSeparator)[0] 'TerminalGlyphs'
New-Item -ItemType Directory -Force -Path $target | Out-Null
Copy-Item -Recurse -Force -Path ./out/TerminalGlyphs/* -Destination $target
```

Run the tests:

```powershell
Install-PSResource -Name Pester -Version '[5.9.0, 6.0.0)' -Scope CurrentUser -TrustRepository
Install-PSResource -Name PSScriptAnalyzer -Version '1.25.0' -Scope CurrentUser -TrustRepository
./build.ps1 -Task Test
./build.ps1 -Task Test -Tag Performance -ExcludeTag @()
```

Themes live in `themes/` as JSONC and are validated against Nerd Fonts 3.5.1 at build time.

## Credits

Built on Terminal-Icons by Brandon Olin, DirColors by Dustin L. Howett and Nerd Fonts by Ryan L McIntyre.
See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Licensed under the [MIT License](LICENSE).
