# Third-party notices

TerminalGlyphs includes material from the following projects.

## Terminal-Icons

- Source: https://github.com/devblackops/Terminal-Icons (v0.11.0)
- Used for: the file, extension and folder mappings and the colors in `themes/` (migrated by
  `tools/Convert-UpstreamTheme.ps1`), and the `Get-ChildItem` view in `src/TerminalGlyphs.format.ps1xml`.
- License: MIT

    Copyright (c) 2019 Brandon Olin

## DirColors

- Source: https://github.com/DHowett/DirColors
- Used for: the original layout of the `Get-ChildItem` view, through Terminal-Icons.
- License: MIT

    Copyright 2017 Dustin L. Howett

## Nerd Fonts

- Source: https://github.com/ryanoasis/nerd-fonts (v3.5.1, `glyphnames.json`)
- Used for: glyph names and code points in `vendor/nerd-fonts/glyphnames.json`, `TerminalGlyphs.data.json` and
  `glyphs.json`. Nerd Fonts applies the MIT License to source files outside folders with an explicit OFL license;
  see `vendor/nerd-fonts/LICENSE`.
- License: MIT

    Copyright (c) 2014 Ryan L McIntyre

The full MIT License text is in `LICENSE`. Each copyright notice above applies to the material listed for it.
