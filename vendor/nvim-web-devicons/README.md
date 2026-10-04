# nvim-web-devicons data

- Source: https://github.com/nvim-tree/nvim-web-devicons (commit 58447c1fca354bbf184425e4a8d01deecbd6f3c4,
  `lua/nvim-web-devicons/default/icons_by_filename.lua` and `icons_by_file_extension.lua`)
- License: MIT (see LICENSE in this folder)
- `manifest.json` records the commit and the SHA-256 of each data file; `tools/Import-DeviconsMapping.ps1` refuses data
  that does not match it.

Used only by `tools/Import-DeviconsMapping.ps1` to propose file icons and colors for the themes. The module build does
not read these files.
