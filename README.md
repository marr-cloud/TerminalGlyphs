# TerminalGlyphs

Nerd Font icons and colors for files and folders in `Get-ChildItem`, for PowerShell 7.4+.

TerminalGlyphs is a reimplementation of [Terminal-Icons](https://github.com/devblackops/Terminal-Icons), which has not
been maintained since 2023. It keeps the Terminal-Icons mappings and colors and adds:

- **Reliable imports.** Terminal-Icons rewrites its theme files on every import. When several sessions start at once
  (split panes, restored tabs), they corrupt those files, and hosts that load the profile inside `try { }` (such as
  Warp) then fail with `Import-Clixml: ... dictionary entry ...`. TerminalGlyphs never writes to disk.
- **Fast imports.** Data loads on the first listing, not on import.
- **Icons for current tooling**: Go, Rust, Cloudflare/wrangler, Terraform, CloudFormation/SAM/CDK, mise, uv, pnpm,
  Bun, Astro, Vite/VitePress/Vitest, Docker, Claude, Kiro and other AI tools, Biome, Deno and just.
- **A JSONC config** with a JSON Schema, instead of cmdlets that store themes in `%APPDATA%`.

## Requirements

- PowerShell 7.4 or later.
- A Nerd Font **3.5.1 or later** in your terminal. Several icons (Cloudflare, Astro, Bun, pnpm, Vite, Terraform,
  Claude) do not exist in older versions, and some older code points draw different logos. On Windows you can update
  the fonts you already have with `./tools/Install-NerdFont.ps1 -Family JetBrainsMono, FiraCode`.

## Install from source

```powershell
git clone https://github.com/marr-cloud/TerminalGlyphs.git
cd TerminalGlyphs
./build.ps1
$modules = ($env:PSModulePath -split [IO.Path]::PathSeparator)[0]
Copy-Item -Recurse -Force ./out/TerminalGlyphs (Join-Path $modules 'TerminalGlyphs')
```

Then, in your profile, replace `Import-Module Terminal-Icons` with:

```powershell
Import-Module TerminalGlyphs
```

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
| `Get-TerminalGlyph <path>` | Which icon and color a file gets, and which rule matched. |
| `Show-TerminalGlyphTheme` | Preview every mapping of the active themes. |
| `Find-NerdGlyph <name>` | Search Nerd Fonts glyph names for your config. |
| `Update-TerminalGlyphConfig` | Reload your config in the current session. |
| `Format-TerminalGlyph` | Used by the `Get-ChildItem` view. |

## Development

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
