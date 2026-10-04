# Nerd Fonts data

- License: MIT for source files outside folders with an explicit OFL license (see LICENSE in this folder).
- `manifest.json` records the Nerd Fonts version and the SHA-256 of each data file below. `build.ps1` fails if a file
  does not match it or if the version differs from `glyphnames.json`, so update the files and `manifest.json` together.

## glyphnames.json

- Source: https://github.com/ryanoasis/nerd-fonts/blob/v3.5.1/glyphnames.json
- Version: 3.5.1
- SHA256: D2FA6615A38EB527462CB71FF17AA44B1D6453D437ED263AB8D5B458393669E8

Used at build time to validate theme glyph names and to generate the glyph maps.

## fonts.json

- Source: https://github.com/ryanoasis/nerd-fonts/blob/v3.5.1/bin/scripts/lib/fonts.json
- Version: 3.5.1
- SHA256: 893E03F5FB079036AE19A05B30985C40603909F5C663919DA0760DF86FEEEFD6

Used at build time to map installed font file names (`patchedName`) to release packages (`folderName`) in
`nerdfonts.json`, for `Install-TerminalGlyphSetup`.

## SHA-256.txt

- Source: https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/SHA-256.txt
- Version: 3.5.1
- SHA256: E03D7AD54547D83F1620719CBC89B5684BC0C6FB028160640AA322B5035A63FB (matches the asset digest GitHub reports for
  the release; its 72 `.tar.xz` checksums also match the GitHub digests of those assets)

Used at build time to store the checksum of every `.tar.xz` package in `nerdfonts.json`. `Install-TerminalGlyphSetup`
checks each download against it instead of downloading a checksum file from the same release.
