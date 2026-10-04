# TerminalGlyphs 0.3.0 Devicons Mappings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Importar desde nvim-web-devicons los iconos y colores de archivos que faltan en el tema, auditar los mapeos actuales y publicar TerminalGlyphs 0.3.0.

**Architecture:** La lógica vive en `tools/DeviconsMapping.psm1` (funciones puras y testeables: lectura, traducción de glifos, colores, comparación, informe y aplicación). `tools/Import-DeviconsMapping.ps1` es un envoltorio fino con dos modos (`-Report` y `-Apply`). Los datos de la referencia se vendorizan con un `manifest.json`. Los temas se escriben con `tools/Set-ThemeEntry.ps1`. El módulo TerminalGlyphs no cambia: solo crecen los temas que compila el build.

**Tech Stack:** PowerShell 7.4+, Pester 5.9.x, PSScriptAnalyzer 1.25.0, JSONC, nvim-web-devicons (MIT, commit `58447c1fca354bbf184425e4a8d01deecbd6f3c4`).

**Spec:** `docs/superpowers/specs/2026-10-04-devicons-mappings-design.md`

## Global Constraints

- Referencia fija: nvim-web-devicons commit `58447c1fca354bbf184425e4a8d01deecbd6f3c4`, archivos `lua/nvim-web-devicons/default/icons_by_filename.lua` y `icons_by_file_extension.lua`, licencia MIT.
- Los mapeos existentes no cambian salvo que su clave esté en `adopt` de `tools/devicons-decisions.jsonc`.
- Traducción de glifos: primero un nombre que el tema ya use para ese código; si no, orden de familias `dev`, `seti`, `custom`, `md`, `fa`, `oct`, `cod` y el resto en orden alfabético; dentro de una familia, el nombre más corto y luego el orden alfabético.
- Colores: `light` = mismo color salvo contraste con `#FFFFFF` < 3:1, entonces se baja la luminosidad HSL (tono y saturación fijos) en pasos de 0,01 hasta >= 3:1; `dracula` = paleta `FF5555`, `FFB86C`, `F1FA8C`, `50FA7B`, `8BE9FD`, `BD93F9`, `FF79C6` por tono más cercano; saturación < 0,15 -> `F8F8F2` si luminosidad >= 0,5, si no `6272A4`.
- Colores en mayúsculas `RRGGBB` sin `#` (como el resto de temas).
- Fuera de alcance: carpetas (solo auditoría), iconos de sistema operativo o escritorio, cambios en la resolución.
- Versión `0.3.0` solo en la tarea 8.
- `src/`, `tools/` y `build.ps1`: solo ASCII, PSScriptAnalyzer sin hallazgos. Los tests construyen caracteres de Nerd Fonts con `[char]::ConvertFromUtf32(...)`, nunca literales.
- Commits en inglés, imperativo y *sentence case*, terminando exactamente con:
  `git commit -m "<Subject>" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"`
- Nunca `git push` ni publicar sin confirmación del usuario. Rama `feat/0.3.0-mappings`.
- Ciclo: `./build.ps1; Invoke-Pester -Path <archivo> -Output Detailed` para rojo/verde; antes de cada commit `./build.ps1 -Task Test` y **solo se commitea si termina con 0 fallos** (no encadenar el commit sin comprobar el código de salida).

## Review Focus

1. **Clave de la referencia que solo difiere en mayúsculas de una existente** (`Dockerfile` frente a `dockerfile`): se trata como existente (diferencia o igual), nunca se duplica → tests en las tareas 4 y 5.
2. **Extensiones compuestas** (`d.ts`, `blade.php`): conservan todo el sufijo con un punto delante (`.d.ts`) → test en la tarea 2.
3. **Colores de referencia casi blancos o casi negros**: `light` llega a 3:1 y `dracula` los manda a los grises de la paleta → tests en la tarea 3.
4. **Volver a ejecutar `-Apply`**: no cambia ningún byte de los temas → test en la tarea 5.
5. **Cabecera de los temas** (comentarios de crédito de Terminal-Icons): se conserva y la línea de crédito nueva se añade una sola vez → test en la tarea 5.

---

## Mapa de archivos

| Archivo | Responsabilidad | Tarea |
|---|---|---|
| `vendor/nvim-web-devicons/{icons_by_filename.lua,icons_by_file_extension.lua,LICENSE,manifest.json,README.md}` | Datos de referencia fijados | 1 |
| `THIRD_PARTY_NOTICES.md`, `tests/Meta.Tests.ps1` | Crédito y su test | 1 |
| `tools/DeviconsMapping.psm1` | Funciones de la importación | 2–5 |
| `tests/Devicons.Tests.ps1` | Tests de la herramienta con datos falsos | 2–6 |
| `tools/Import-DeviconsMapping.ps1` | Envoltorio `-Report` / `-Apply` | 6 |
| `docs/mappings/devicons-0.3.0.md`, `tools/devicons-decisions.jsonc`, `themes/**` | Informe, decisiones y temas resultantes | 7 |
| `tests/Themes.Tests.ps1` | Invariante: todo icono tiene color en los tres temas | 7 |
| `src/TerminalGlyphs.psd1`, `tests/Quality.Tests.ps1`, `README.md`, `CHANGELOG.md` | Release 0.3.0 | 8 |

---

### Task 1: Vendorizar la referencia

**Files:**
- Create: `vendor/nvim-web-devicons/icons_by_filename.lua`, `vendor/nvim-web-devicons/icons_by_file_extension.lua`, `vendor/nvim-web-devicons/LICENSE`, `vendor/nvim-web-devicons/manifest.json`, `vendor/nvim-web-devicons/README.md`
- Modify: `THIRD_PARTY_NOTICES.md`, `tests/Meta.Tests.ps1`

**Interfaces:**
- Produces: `vendor/nvim-web-devicons/manifest.json` = `{ "commit": "58447c1fca354bbf184425e4a8d01deecbd6f3c4", "files": { "icons_by_filename.lua": "<SHA256>", "icons_by_file_extension.lua": "<SHA256>" } }` (hash en mayúsculas, como `Get-FileHash`).

- [ ] **Step 1: Test que falla (crédito)**

En `tests/Meta.Tests.ps1`, dentro de `It 'THIRD_PARTY_NOTICES.md credits <Project>' -ForEach @(...)`, añade a la lista:

```powershell
        @{ Project = 'nvim-web-devicons'; Copyright = 'Copyright (c) 2023 nvim-tree' }
```

(`Copyright (c) 2023 nvim-tree` es la línea del LICENSE de ese commit, verificada al escribir el plan.)

- [ ] **Step 2: Ejecutar y ver que falla**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Meta.Tests.ps1 -Output Detailed`
Expected: FAIL en `credits nvim-web-devicons`.

- [ ] **Step 3: Descargar los datos fijados**

```powershell
$commit = '58447c1fca354bbf184425e4a8d01deecbd6f3c4'
$vendor = './vendor/nvim-web-devicons'
New-Item -ItemType Directory -Force -Path $vendor | Out-Null
foreach ($file in 'icons_by_filename.lua', 'icons_by_file_extension.lua') {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/nvim-tree/nvim-web-devicons/$commit/lua/nvim-web-devicons/default/$file" -OutFile (Join-Path $vendor $file)
}
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/nvim-tree/nvim-web-devicons/$commit/LICENSE" -OutFile (Join-Path $vendor 'LICENSE')
$files = [ordered]@{}
foreach ($file in 'icons_by_filename.lua', 'icons_by_file_extension.lua') { $files[$file] = (Get-FileHash -LiteralPath (Join-Path $vendor $file) -Algorithm SHA256).Hash }
[System.IO.File]::WriteAllText((Resolve-Path $vendor).Path + '/manifest.json', ([ordered]@{ commit = $commit; files = $files } | ConvertTo-Json) + "`n", [System.Text.UTF8Encoding]::new($false))
```

Comprueba: `icons_by_filename.lua` tiene 221 entradas y `icons_by_file_extension.lua` 494 (`([regex]::Matches((Get-Content <archivo> -Raw), '\["[^"]+"\]\s*=')).Count`). Si no, para y avisa.

`vendor/nvim-web-devicons/README.md`:

```markdown
# nvim-web-devicons data

- Source: https://github.com/nvim-tree/nvim-web-devicons (commit 58447c1fca354bbf184425e4a8d01deecbd6f3c4,
  `lua/nvim-web-devicons/default/icons_by_filename.lua` and `icons_by_file_extension.lua`)
- License: MIT (see LICENSE in this folder)
- `manifest.json` records the commit and the SHA-256 of each data file; `tools/Import-DeviconsMapping.ps1` refuses data
  that does not match it.

Used only by `tools/Import-DeviconsMapping.ps1` to propose file icons and colors for the themes. The module build does
not read these files.
```

- [ ] **Step 4: Crédito**

En `THIRD_PARTY_NOTICES.md`, antes de la línea final (`The full MIT License text is in ...`), añade:

```markdown
## nvim-web-devicons

- Source: https://github.com/nvim-tree/nvim-web-devicons (commit 58447c1)
- Used for: file name and extension icons and colors imported into `themes/` with `tools/Import-DeviconsMapping.ps1`,
  and the vendored data in `vendor/nvim-web-devicons/`.
- License: MIT

    Copyright (c) 2023 nvim-tree
```

- [ ] **Step 5: Verde, suite y commit**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Meta.Tests.ps1 -Output Detailed` → PASS. Luego `./build.ps1 -Task Test` (0 fallos).

```powershell
git add vendor/nvim-web-devicons THIRD_PARTY_NOTICES.md tests/Meta.Tests.ps1
git commit -m "Vendor nvim-web-devicons file icon data" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 2: Leer la referencia y traducir glifos

**Files:**
- Create: `tools/DeviconsMapping.psm1`, `tests/Devicons.Tests.ps1`

**Interfaces:**
- Produces (exportadas por el módulo):
  - `Confirm-DeviconsData -VendorPath <string>` → `[string]` commit; lanza si falta `manifest.json`, si no lista un archivo, si falta o si su SHA-256 no coincide.
  - `Read-DeviconsFile -Path <string> [-Extension]` → objetos `{ Key; Icon; Color; Group }` (`Color` en `RRGGBB` mayúsculas; con `-Extension`, `Key` lleva `.` delante).
  - `Get-NerdGlyphIndex -GlyphNamesPath <string>` → `[hashtable]` código (int) → `List[string]` de nombres `nf-...`.
  - `Select-GlyphName -CodePoint <int> -GlyphIndex <hashtable> [-UsedName <HashSet[string]>]` → `[string]` o nada.

- [ ] **Step 1: Tests que fallan**

Crea `tests/Devicons.Tests.ps1`:

```powershell
BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    . (Join-Path $script:RepoRoot 'src' 'Private' 'Read-JsoncFile.ps1')
    Import-Module (Join-Path $script:RepoRoot 'tools' 'DeviconsMapping.psm1') -Force
    function Get-Char([int]$Code) { [char]::ConvertFromUtf32($Code) }

    # A small fake world: reference data, glyph names and themes, all in TestDrive.
    function New-FakeWorld([string]$Name) {
        $root = Join-Path $TestDrive $Name
        $vendor = Join-Path $root 'vendor'
        $themes = Join-Path $root 'themes'
        foreach ($dir in $vendor, (Join-Path $themes 'icons'), (Join-Path $themes 'colors')) { [System.IO.Directory]::CreateDirectory($dir) | Out-Null }
        $entry = { param($Key, $Code, $Color, $Group) '  ["{0}"] = {{ icon = "{1}", color = "#{2}", cterm_color = "33", name = "{3}" }},' -f $Key, (Get-Char $Code), $Color, $Group }
        $names = @(
            'return {'
            & $entry '.prettierrc' 0xE600 '4285F4' 'PrettierConfig'
            & $entry '.prettierrc.json' 0xE600 '4285F4' 'PrettierConfig'
            & $entry 'go.mod' 0xE603 '00ADD8' 'GoMod'
            & $entry 'Dockerfile' 0xE601 '458EE6' 'Dockerfile'
            & $entry 'weird' 0xE6FF 'FFFFFF' 'Weird'
            '}'
        ) -join "`n"
        $extensions = @(
            'return {'
            & $entry 'env' 0xE602 'FAF743' 'Env'
            & $entry 'go' 0xE603 '00ADD8' 'Go'
            & $entry 'zig' 0xE604 'F69A1B' 'Zig'
            & $entry 'd.ts' 0xE605 'D59855' 'TypeScriptDeclaration'
            '}'
        ) -join "`n"
        [System.IO.File]::WriteAllText((Join-Path $vendor 'icons_by_filename.lua'), $names)
        [System.IO.File]::WriteAllText((Join-Path $vendor 'icons_by_file_extension.lua'), $extensions)
        $files = [ordered]@{}
        foreach ($file in 'icons_by_filename.lua', 'icons_by_file_extension.lua') { $files[$file] = (Get-FileHash -LiteralPath (Join-Path $vendor $file) -Algorithm SHA256).Hash }
        [System.IO.File]::WriteAllText((Join-Path $vendor 'manifest.json'), ([ordered]@{ commit = 'abc123'; files = $files } | ConvertTo-Json))

        $glyphs = [ordered]@{
            METADATA     = @{ version = '3.5.1' }
            'seti-zzz'   = @{ char = (Get-Char 0xE600); code = 'e600' }
            'dev-aaa'    = @{ char = (Get-Char 0xE600); code = 'e600' }
            'md-bbb'     = @{ char = (Get-Char 0xE601); code = 'e601' }
            'fa-ccc'     = @{ char = (Get-Char 0xE601); code = 'e601' }
            'fa-x'       = @{ char = (Get-Char 0xE602); code = 'e602' }
            'fa-xyz'     = @{ char = (Get-Char 0xE602); code = 'e602' }
            'dev-used'   = @{ char = (Get-Char 0xE603); code = 'e603' }
            'dev-a'      = @{ char = (Get-Char 0xE603); code = 'e603' }
            'weather-w'  = @{ char = (Get-Char 0xE604); code = 'e604' }
            'linux-l'    = @{ char = (Get-Char 0xE604); code = 'e604' }
            'seti-ts'    = @{ char = (Get-Char 0xE605); code = 'e605' }
        }
        $glyphNames = Join-Path $root 'glyphnames.json'
        [System.IO.File]::WriteAllText($glyphNames, ($glyphs | ConvertTo-Json))

        $header = "// Migrated from Terminal-Icons v0.11.0 (https://github.com/devblackops/Terminal-Icons).`n"
        [System.IO.File]::WriteAllText((Join-Path $themes 'icons' 'default.jsonc'), $header + '{ "name": "default", "files": { "names": { "go.mod": "nf-dev-used", "dockerfile": "nf-dev-aaa", "nocolor": "nf-dev-a" }, "extensions": { ".go": "nf-dev-used" } }, "directories": { "names": { ".git": "nf-dev-a" } } }' + "`n")
        foreach ($theme in 'default', 'light', 'dracula') {
            $dockerfile = if ($theme -eq 'light') { '' } else { '"dockerfile": "458EE6", ' }
            [System.IO.File]::WriteAllText((Join-Path $themes 'colors' "$theme.jsonc"), $header + "{ `"name`": `"$theme`", `"files`": { `"names`": { $dockerfile`"go.mod`": `"00ADD8`" }, `"extensions`": { `".go`": `"00ADD8`" } } }`n")
        }
        [pscustomobject]@{ Root = $root; Vendor = $vendor; Themes = $themes; GlyphNames = $glyphNames }
    }
}

AfterAll {
    Remove-Module DeviconsMapping -ErrorAction SilentlyContinue
}

Describe 'Confirm-DeviconsData' {
    It 'accepts the vendored reference and returns its commit' {
        Confirm-DeviconsData -VendorPath (Join-Path $script:RepoRoot 'vendor' 'nvim-web-devicons') | Should -Be '58447c1fca354bbf184425e4a8d01deecbd6f3c4'
    }

    It 'refuses data that does not match manifest.json' {
        $world = New-FakeWorld 'tampered'
        Add-Content -LiteralPath (Join-Path $world.Vendor 'icons_by_filename.lua') -Value '-- changed'
        { Confirm-DeviconsData -VendorPath $world.Vendor } | Should -Throw '*does not match manifest.json*'
    }
}

Describe 'Read-DeviconsFile' {
    BeforeAll { $world = New-FakeWorld 'read' }

    It 'reads names with their icon, upper-case color and group' {
        $entries = @(Read-DeviconsFile -Path (Join-Path $world.Vendor 'icons_by_filename.lua'))
        $entries.Count | Should -Be 5
        $prettier = $entries | Where-Object Key -EQ '.prettierrc'
        $prettier.Icon | Should -Be (Get-Char 0xE600)
        $prettier.Color | Should -BeExactly '4285F4'
        $prettier.Group | Should -Be 'PrettierConfig'
    }

    It 'adds the dot to extensions, including compound ones' {
        $keys = @(Read-DeviconsFile -Path (Join-Path $world.Vendor 'icons_by_file_extension.lua') -Extension).Key
        $keys | Should -Contain '.env'
        $keys | Should -Contain '.d.ts'
    }
}

Describe 'Select-GlyphName' {
    BeforeAll {
        $world = New-FakeWorld 'select'
        $index = Get-NerdGlyphIndex -GlyphNamesPath $world.GlyphNames
    }

    It 'picks <Expected> for U+<Code>' -ForEach @(
        @{ Code = 0xE600; Expected = 'nf-dev-aaa' }
        @{ Code = 0xE601; Expected = 'nf-md-bbb' }
        @{ Code = 0xE602; Expected = 'nf-fa-x' }
        @{ Code = 0xE604; Expected = 'nf-linux-l' }
    ) {
        Select-GlyphName -CodePoint $Code -GlyphIndex $index | Should -BeExactly $Expected
    }

    It 'prefers a name the theme already uses' {
        $used = [System.Collections.Generic.HashSet[string]]::new([string[]]@('nf-dev-used'))
        Select-GlyphName -CodePoint 0xE603 -GlyphIndex $index -UsedName $used | Should -BeExactly 'nf-dev-used'
    }

    It 'returns nothing for a code point without a name' {
        Select-GlyphName -CodePoint 0xE6FF -GlyphIndex $index | Should -BeNullOrEmpty
    }
}
```

- [ ] **Step 2: Ejecutar y ver que fallan**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Devicons.Tests.ps1 -Output Detailed`
Expected: FAIL (no existe `tools/DeviconsMapping.psm1`).

- [ ] **Step 3: Implementar**

Crea `tools/DeviconsMapping.psm1`:

```powershell
# Functions for tools/Import-DeviconsMapping.ps1: import file icons and colors from the vendored nvim-web-devicons data.
. ([System.IO.Path]::Combine($PSScriptRoot, '..', 'src', 'Private', 'Read-JsoncFile.ps1'))

$script:FamilyOrder = @('dev', 'seti', 'custom', 'md', 'fa', 'oct', 'cod')

function Confirm-DeviconsData {
    # Returns the reference commit after checking every data file against manifest.json.
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$VendorPath
    )

    $manifestPath = [System.IO.Path]::Combine($VendorPath, 'manifest.json')
    if (-not [System.IO.File]::Exists($manifestPath)) { throw "$manifestPath is missing." }
    $manifest = [System.IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json -AsHashtable
    foreach ($name in 'icons_by_filename.lua', 'icons_by_file_extension.lua') {
        if ($null -eq $manifest['files'] -or -not $manifest['files'].Contains($name)) { throw "manifest.json does not list $name." }
        $path = [System.IO.Path]::Combine($VendorPath, $name)
        if (-not [System.IO.File]::Exists($path)) { throw "$name is listed in manifest.json but missing: $path" }
        $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        if ($actual -ne $manifest['files'][$name]) {
            throw "$path does not match manifest.json (expected SHA-256 $($manifest['files'][$name]), got $actual)."
        }
    }
    [string]$manifest['commit']
}

function Read-DeviconsFile {
    # One object per entry of an nvim-web-devicons table: Key, Icon, Color (RRGGBB) and Group (the entry's name).
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$Extension
    )

    $text = [System.IO.File]::ReadAllText($Path)
    $pattern = '\["(?<key>[^"]+)"\]\s*=\s*\{\s*icon\s*=\s*"(?<icon>[^"]*)",\s*color\s*=\s*"#(?<color>[0-9A-Fa-f]{6})",\s*cterm_color\s*=\s*"\d+",\s*name\s*=\s*"(?<name>[^"]+)"\s*,?\s*\}'
    foreach ($match in [regex]::Matches($text, $pattern)) {
        $key = $match.Groups['key'].Value
        if ($Extension) { $key = ".$key" }
        [pscustomobject]@{
            Key   = $key
            Icon  = $match.Groups['icon'].Value
            Color = $match.Groups['color'].Value.ToUpperInvariant()
            Group = $match.Groups['name'].Value
        }
    }
}

function Get-NerdGlyphIndex {
    # Code point -> Nerd Fonts names (nf-...) from glyphnames.json.
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$GlyphNamesPath
    )

    $raw = Read-JsoncFile -Path $GlyphNamesPath
    $index = @{}
    foreach ($name in $raw.Keys) {
        if ($name -ceq 'METADATA') { continue }
        $code = [Convert]::ToInt32($raw[$name]['code'], 16)
        if (-not $index.ContainsKey($code)) { $index[$code] = [System.Collections.Generic.List[string]]::new() }
        $index[$code].Add("nf-$name")
    }
    $index
}

function Select-GlyphName {
    # One name for a code point: a name the theme already uses, else by family order, then length, then name.
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$CodePoint,

        [Parameter(Mandatory)]
        [hashtable]$GlyphIndex,

        [System.Collections.Generic.HashSet[string]]$UsedName
    )

    if (-not $GlyphIndex.ContainsKey($CodePoint)) { return }
    $names = $GlyphIndex[$CodePoint]
    if ($UsedName) {
        $used = $names | Where-Object { $UsedName.Contains($_) } | Sort-Object | Select-Object -First 1
        if ($used) { return $used }
    }
    $rank = {
        $family = ($_ -split '-')[1]
        $position = [array]::IndexOf($script:FamilyOrder, $family)
        if ($position -lt 0) { 100 } else { $position }
    }
    $names | Sort-Object -Property @(
        @{ Expression = $rank }
        @{ Expression = { ($_ -split '-')[1] } }
        @{ Expression = { $_.Length } }
        @{ Expression = { $_ } }
    ) | Select-Object -First 1
}

Export-ModuleMember -Function Confirm-DeviconsData, Read-DeviconsFile, Get-NerdGlyphIndex, Select-GlyphName
```

- [ ] **Step 4: Verde, suite y commit**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Devicons.Tests.ps1 -Output Detailed` → PASS. Luego `./build.ps1 -Task Test` (0 fallos, PSScriptAnalyzer y ASCII incluidos).

```powershell
git add tools/DeviconsMapping.psm1 tests/Devicons.Tests.ps1
git commit -m "Read nvim-web-devicons data and translate its glyphs" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 3: Derivar colores light y dracula

**Files:**
- Modify: `tools/DeviconsMapping.psm1`, `tests/Devicons.Tests.ps1`

**Interfaces:**
- Produces (exportadas): `Get-ContrastWithWhite -Hex <string>` → `[double]`; `ConvertTo-Hsl -Hex <string>` → `[double[]]` (tono 0–360, saturación 0–1, luminosidad 0–1); `ConvertTo-LightColor -Hex <string>` → `RRGGBB`; `ConvertTo-DraculaColor -Hex <string>` → `RRGGBB`. Aceptan `#` opcional y mayúsculas o minúsculas.

- [ ] **Step 1: Tests que fallan**

Añade a `tests/Devicons.Tests.ps1`:

```powershell
Describe 'ConvertTo-LightColor' {
    It 'keeps <Hex>, which already has 3:1 contrast on white' -ForEach @(@{ Hex = '1354BF' }, @{ Hex = '123456' }) {
        ConvertTo-LightColor -Hex $Hex | Should -BeExactly $Hex
    }

    It 'darkens <Hex> to at least 3:1 on white, keeping its hue' -ForEach @(@{ Hex = 'FBF0DF' }, @{ Hex = 'F7DF1E' }, @{ Hex = '00ADD8' }, @{ Hex = 'FFFFFF' }) {
        $light = ConvertTo-LightColor -Hex $Hex
        Get-ContrastWithWhite -Hex $light | Should -BeGreaterOrEqual 3
        $light | Should -Match '^[0-9A-F]{6}$'
        if ((ConvertTo-Hsl -Hex $Hex)[1] -gt 0) {
            [Math]::Abs((ConvertTo-Hsl -Hex $light)[0] - (ConvertTo-Hsl -Hex $Hex)[0]) | Should -BeLessOrEqual 3
        }
    }

    It 'accepts a leading # and lower case' {
        ConvertTo-LightColor -Hex '#1354bf' | Should -BeExactly '1354BF'
    }
}

Describe 'ConvertTo-DraculaColor' {
    It 'maps <Hex> to <Expected>' -ForEach @(
        @{ Hex = 'E44D26'; Expected = 'FF5555' }
        @{ Hex = '3178C6'; Expected = '8BE9FD' }
        @{ Hex = '41B883'; Expected = '50FA7B' }
        @{ Hex = '#bd93f9'; Expected = 'BD93F9' }
        @{ Hex = '6D8086'; Expected = '6272A4' }
        @{ Hex = 'FFFFFF'; Expected = 'F8F8F2' }
        @{ Hex = '000000'; Expected = '6272A4' }
    ) {
        ConvertTo-DraculaColor -Hex $Hex | Should -BeExactly $Expected
    }
}
```

- [ ] **Step 2: Ejecutar y ver que fallan**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Devicons.Tests.ps1 -Output Detailed`
Expected: FAIL ("ConvertTo-LightColor is not recognized").

- [ ] **Step 3: Implementar**

En `tools/DeviconsMapping.psm1`, antes de `Export-ModuleMember`, añade:

```powershell
$script:DraculaPalette = @('FF5555', 'FFB86C', 'F1FA8C', '50FA7B', '8BE9FD', 'BD93F9', 'FF79C6')

function Get-ContrastWithWhite {
    # WCAG contrast ratio of a color against #FFFFFF.
    [OutputType([double])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Hex
    )

    $value = $Hex.TrimStart('#')
    $channels = foreach ($offset in 0, 2, 4) {
        $channel = [Convert]::ToInt32($value.Substring($offset, 2), 16) / 255.0
        if ($channel -le 0.04045) { $channel / 12.92 } else { [Math]::Pow(($channel + 0.055) / 1.055, 2.4) }
    }
    $luminance = 0.2126 * $channels[0] + 0.7152 * $channels[1] + 0.0722 * $channels[2]
    1.05 / ($luminance + 0.05)
}

function ConvertTo-Hsl {
    # Hue (0-360), saturation (0-1) and lightness (0-1) of a color.
    [OutputType([double[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Hex
    )

    $value = $Hex.TrimStart('#')
    $red = [Convert]::ToInt32($value.Substring(0, 2), 16) / 255.0
    $green = [Convert]::ToInt32($value.Substring(2, 2), 16) / 255.0
    $blue = [Convert]::ToInt32($value.Substring(4, 2), 16) / 255.0
    $max = [Math]::Max($red, [Math]::Max($green, $blue))
    $min = [Math]::Min($red, [Math]::Min($green, $blue))
    $lightness = ($max + $min) / 2
    if ($max -eq $min) { return [double[]]@(0.0, 0.0, $lightness) }
    $delta = $max - $min
    $saturation = if ($lightness -gt 0.5) { $delta / (2 - $max - $min) } else { $delta / ($max + $min) }
    $hue = if ($max -eq $red) { (($green - $blue) / $delta) % 6 } elseif ($max -eq $green) { ($blue - $red) / $delta + 2 } else { ($red - $green) / $delta + 4 }
    $hue *= 60
    if ($hue -lt 0) { $hue += 360 }
    [double[]]@($hue, $saturation, $lightness)
}

function ConvertFrom-Hsl {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [double]$Hue,

        [Parameter(Mandatory)]
        [double]$Saturation,

        [Parameter(Mandatory)]
        [double]$Lightness
    )

    $chroma = (1 - [Math]::Abs(2 * $Lightness - 1)) * $Saturation
    $second = $chroma * (1 - [Math]::Abs((($Hue / 60) % 2) - 1))
    $match = $Lightness - $chroma / 2
    $rgb = switch ([Math]::Floor($Hue / 60) % 6) {
        0 { $chroma, $second, 0 }
        1 { $second, $chroma, 0 }
        2 { 0, $chroma, $second }
        3 { 0, $second, $chroma }
        4 { $second, 0, $chroma }
        default { $chroma, 0, $second }
    }
    ($rgb | ForEach-Object { '{0:X2}' -f [int][Math]::Round(($_ + $match) * 255) }) -join ''
}

function ConvertTo-LightColor {
    # The same color for the light theme, darkened (same hue and saturation) until it has 3:1 contrast on white.
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Hex
    )

    $value = $Hex.TrimStart('#').ToUpperInvariant()
    if ((Get-ContrastWithWhite -Hex $value) -ge 3) { return $value }
    $hue, $saturation, $lightness = ConvertTo-Hsl -Hex $value
    while ($lightness -gt 0) {
        $lightness = [Math]::Max(0, $lightness - 0.01)
        $candidate = ConvertFrom-Hsl -Hue $hue -Saturation $saturation -Lightness $lightness
        if ((Get-ContrastWithWhite -Hex $candidate) -ge 3) { return $candidate }
    }
    '000000'
}

function ConvertTo-DraculaColor {
    # The closest Dracula palette color by hue; greys go to the Dracula foreground or comment color.
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Hex
    )

    $hue, $saturation, $lightness = ConvertTo-Hsl -Hex $Hex
    if ($saturation -lt 0.15) { if ($lightness -ge 0.5) { return 'F8F8F2' } else { return '6272A4' } }
    $best = $null
    $bestDistance = 361.0
    foreach ($candidate in $script:DraculaPalette) {
        $distance = [Math]::Abs((ConvertTo-Hsl -Hex $candidate)[0] - $hue)
        $distance = [Math]::Min($distance, 360 - $distance)
        if ($distance -lt $bestDistance) { $best = $candidate; $bestDistance = $distance }
    }
    $best
}
```

Y cambia la línea de exportación a:

```powershell
Export-ModuleMember -Function Confirm-DeviconsData, Read-DeviconsFile, Get-NerdGlyphIndex, Select-GlyphName, Get-ContrastWithWhite, ConvertTo-Hsl, ConvertTo-LightColor, ConvertTo-DraculaColor
```

- [ ] **Step 4: Verde, suite y commit**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Devicons.Tests.ps1 -Output Detailed` → PASS. Si un caso de `dracula` no coincide, imprime el tono con `ConvertTo-Hsl` y revisa la cuenta antes de cambiar el caso: los esperados están calculados con las reglas de Global Constraints. Luego `./build.ps1 -Task Test` (0 fallos).

```powershell
git add tools/DeviconsMapping.psm1 tests/Devicons.Tests.ps1
git commit -m "Derive light and Dracula colors for imported icons" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 4: Comparar con el tema y escribir el informe

**Files:**
- Modify: `tools/DeviconsMapping.psm1`, `tests/Devicons.Tests.ps1`

**Interfaces:**
- Consumes: funciones de las tareas 2 y 3.
- Produces (exportadas):
  - `Get-DeviconsComparison -VendorPath <string> -GlyphNamesPath <string> -ThemesPath <string>` → `[pscustomobject]@{ Commit; New; Different; Unmapped; MissingColor }` (listas). Elementos:
    - `New` y `Different`: `{ Section ('names'|'extensions'); Key; Group; Glyph; Color; CurrentKey; CurrentGlyph; CurrentColor }` (`CurrentKey` es la clave tal como está en el tema; en `New` es `$null`).
    - `Unmapped`: `{ Section; Key; Group; CodePoint }`.
    - `MissingColor`: `{ Section; Key; MissingIn (string[] de 'default'|'light'|'dracula'); ReferenceColor (RRGGBB o $null) }`.
    - `Different` = clave existente (sin distinguir mayúsculas) cuyo glifo actual tiene otro **punto de código** que el de la referencia (dos nombres del mismo código no son una diferencia).
  - `Write-DeviconsReport -Comparison <pscustomobject> -Path <string>` escribe Markdown (UTF-8 sin BOM, LF).

- [ ] **Step 1: Tests que fallan**

Añade a `tests/Devicons.Tests.ps1`:

```powershell
Describe 'Get-DeviconsComparison' {
    BeforeAll {
        $world = New-FakeWorld 'compare'
        $comparison = Get-DeviconsComparison -VendorPath $world.Vendor -GlyphNamesPath $world.GlyphNames -ThemesPath $world.Themes
    }

    It 'returns the reference commit' {
        $comparison.Commit | Should -Be 'abc123'
    }

    It 'lists the entries the theme does not have' {
        @($comparison.New.Key | Sort-Object) | Should -Be @('.d.ts', '.env', '.prettierrc', '.prettierrc.json', '.zig')
        ($comparison.New | Where-Object Key -EQ '.zig').Glyph | Should -BeExactly 'nf-linux-l'
    }

    It 'treats a key that differs only in case as existing and reports the other glyph' {
        $docker = @($comparison.Different)
        $docker.Count | Should -Be 1
        $docker[0].Key | Should -BeExactly 'Dockerfile'
        $docker[0].CurrentKey | Should -BeExactly 'dockerfile'
        $docker[0].CurrentGlyph | Should -BeExactly 'nf-dev-aaa'
        $docker[0].Glyph | Should -BeExactly 'nf-md-bbb'
        $comparison.New.Key | Should -Not -Contain 'Dockerfile'
    }

    It 'leaves out entries whose glyph is the same code point, even under another name' {
        $comparison.New.Key + $comparison.Different.Key | Should -Not -Contain 'go.mod'
        $comparison.New.Key + $comparison.Different.Key | Should -Not -Contain '.go'
    }

    It 'lists glyphs that Nerd Fonts does not name' {
        @($comparison.Unmapped).Key | Should -Be @('weird')
    }

    It 'lists icons without a color and the reference color when there is one' {
        $nocolor = $comparison.MissingColor | Where-Object Key -EQ 'nocolor'
        @($nocolor.MissingIn) | Should -Be @('default', 'light', 'dracula')
        $nocolor.ReferenceColor | Should -BeNullOrEmpty
        $docker = $comparison.MissingColor | Where-Object Key -EQ 'dockerfile'
        @($docker.MissingIn) | Should -Be @('light')
        $docker.ReferenceColor | Should -BeExactly '458EE6'
    }
}

Describe 'Write-DeviconsReport' {
    It 'writes the groups, differences, unmapped glyphs and missing colors' {
        $world = New-FakeWorld 'report'
        $comparison = Get-DeviconsComparison -VendorPath $world.Vendor -GlyphNamesPath $world.GlyphNames -ThemesPath $world.Themes
        $path = Join-Path $world.Root 'report.md'
        Write-DeviconsReport -Comparison $comparison -Path $path
        $text = [System.IO.File]::ReadAllText($path)
        $text | Should -Match '(?m)^### PrettierConfig$'
        $text | Should -Match ([regex]::Escape('| names | .prettierrc.json | nf-dev-aaa | 4285F4 |'))
        $text | Should -Match ([regex]::Escape('| names | Dockerfile | nf-dev-aaa | nf-md-bbb |'))
        $text | Should -Match 'weird'
        $text | Should -Match ([regex]::Escape('| names | nocolor | default, light, dracula |'))
        $text | Should -Match 'abc123'
    }
}
```

- [ ] **Step 2: Ejecutar y ver que fallan**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Devicons.Tests.ps1 -Output Detailed`
Expected: FAIL ("Get-DeviconsComparison is not recognized").

- [ ] **Step 3: Implementar**

En `tools/DeviconsMapping.psm1`, antes de `Export-ModuleMember`:

```powershell
function Find-ThemeKey {
    # The key as written in a theme section that equals -Key without case, or nothing.
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary]$Map,

        [Parameter(Mandatory)]
        [string]$Key
    )

    if ($null -eq $Map) { return }
    $Map.Keys | Where-Object { $_ -eq $Key } | Select-Object -First 1
}

function Get-DeviconsComparison {
    # Compares the reference with the themes: new entries, other glyphs, unnamed glyphs and icons without a color.
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$VendorPath,

        [Parameter(Mandatory)]
        [string]$GlyphNamesPath,

        [Parameter(Mandatory)]
        [string]$ThemesPath
    )

    $commit = Confirm-DeviconsData -VendorPath $VendorPath
    $index = Get-NerdGlyphIndex -GlyphNamesPath $GlyphNamesPath
    $codeOf = @{}
    foreach ($code in $index.Keys) { foreach ($name in $index[$code]) { $codeOf[$name] = $code } }
    $icons = Read-JsoncFile -Path ([System.IO.Path]::Combine($ThemesPath, 'icons', 'default.jsonc'))
    $colors = [ordered]@{}
    foreach ($theme in 'default', 'light', 'dracula') { $colors[$theme] = Read-JsoncFile -Path ([System.IO.Path]::Combine($ThemesPath, 'colors', "$theme.jsonc")) }

    $used = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($kind in 'files', 'directories') {
        if ($null -eq $icons[$kind]) { continue }
        foreach ($value in $icons[$kind].Values) {
            if ($value -is [System.Collections.IDictionary]) { foreach ($name in $value.Values) { [void]$used.Add([string]$name) } }
            elseif ($value -is [string]) { [void]$used.Add($value) }
        }
    }

    $result = [pscustomobject]@{
        Commit       = $commit
        New          = [System.Collections.Generic.List[object]]::new()
        Different    = [System.Collections.Generic.List[object]]::new()
        Unmapped     = [System.Collections.Generic.List[object]]::new()
        MissingColor = [System.Collections.Generic.List[object]]::new()
    }
    $reference = @{}
    foreach ($source in @(@{ File = 'icons_by_filename.lua'; Section = 'names'; Extension = $false }, @{ File = 'icons_by_file_extension.lua'; Section = 'extensions'; Extension = $true })) {
        $reference[$source.Section] = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $map = $icons['files'][$source.Section]
        $colorMap = $colors['default']['files'][$source.Section]
        foreach ($entry in (Read-DeviconsFile -Path ([System.IO.Path]::Combine($VendorPath, $source.File)) -Extension:$source.Extension)) {
            $reference[$source.Section][$entry.Key] = $entry
            $codePoint = [char]::ConvertToUtf32($entry.Icon, 0)
            $glyph = Select-GlyphName -CodePoint $codePoint -GlyphIndex $index -UsedName $used
            if (-not $glyph) {
                $result.Unmapped.Add([pscustomobject]@{ Section = $source.Section; Key = $entry.Key; Group = $entry.Group; CodePoint = ('U+{0:X4}' -f $codePoint) })
                continue
            }
            $currentKey = Find-ThemeKey -Map $map -Key $entry.Key
            $item = [pscustomobject]@{
                Section      = $source.Section
                Key          = $entry.Key
                Group        = $entry.Group
                Glyph        = $glyph
                Color        = $entry.Color
                CurrentKey   = $currentKey
                CurrentGlyph = if ($currentKey) { $map[$currentKey] } else { $null }
                CurrentColor = $null
            }
            if ($currentKey) {
                $colorKey = Find-ThemeKey -Map $colorMap -Key $currentKey
                if ($colorKey) { $item.CurrentColor = $colorMap[$colorKey] }
            }
            if (-not $currentKey) { $result.New.Add($item) }
            elseif ($codeOf[[string]$item.CurrentGlyph] -ne $codePoint) { $result.Different.Add($item) }
        }
    }

    foreach ($section in 'names', 'extensions') {
        $map = $icons['files'][$section]
        if ($null -eq $map) { continue }
        foreach ($key in $map.Keys) {
            $missing = @(foreach ($theme in $colors.Keys) { if (-not (Find-ThemeKey -Map $colors[$theme]['files'][$section] -Key $key)) { $theme } })
            if ($missing.Count -eq 0) { continue }
            $referenceColor = if ($reference[$section].ContainsKey($key)) { $reference[$section][$key].Color } else { $null }
            $result.MissingColor.Add([pscustomobject]@{ Section = $section; Key = $key; MissingIn = [string[]]$missing; ReferenceColor = $referenceColor })
        }
    }
    $result
}

function Write-DeviconsReport {
    # Writes the comparison as Markdown, grouping new entries by the reference's name for each entry.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Comparison,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $cell = { param($Value) ([string]$Value).Replace('|', '\|') }
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# nvim-web-devicons mappings report')
    $lines.Add('')
    $lines.Add("Reference: https://github.com/nvim-tree/nvim-web-devicons commit $($Comparison.Commit)")
    $lines.Add('')
    $lines.Add('| | Count |')
    $lines.Add('|---|---|')
    $lines.Add("| New file names | $(@($Comparison.New | Where-Object Section -EQ 'names').Count) |")
    $lines.Add("| New extensions | $(@($Comparison.New | Where-Object Section -EQ 'extensions').Count) |")
    $lines.Add("| Existing entries with another glyph | $($Comparison.Different.Count) |")
    $lines.Add("| Glyphs without a Nerd Fonts 3.5.1 name | $($Comparison.Unmapped.Count) |")
    $lines.Add("| Icons without a color in some theme | $($Comparison.MissingColor.Count) |")
    $lines.Add('')
    $lines.Add('## New entries')
    foreach ($group in ($Comparison.New | Group-Object -Property Group | Sort-Object -Property Name)) {
        $lines.Add('')
        $lines.Add("### $($group.Name)")
        $lines.Add('')
        $lines.Add('| Section | Key | Glyph | Color |')
        $lines.Add('|---|---|---|---|')
        foreach ($item in ($group.Group | Sort-Object -Property Section, Key)) {
            $lines.Add(('| {0} | {1} | {2} | {3} |' -f $item.Section, (& $cell $item.Key), $item.Glyph, $item.Color))
        }
    }
    $lines.Add('')
    $lines.Add('## Existing entries with another glyph')
    $lines.Add('')
    $lines.Add('| Section | Key | Current glyph | Reference glyph | Current color | Reference color |')
    $lines.Add('|---|---|---|---|---|---|')
    foreach ($item in ($Comparison.Different | Sort-Object -Property Section, Key)) {
        $lines.Add(('| {0} | {1} | {2} | {3} | {4} | {5} |' -f $item.Section, (& $cell $item.Key), $item.CurrentGlyph, $item.Glyph, $item.CurrentColor, $item.Color))
    }
    $lines.Add('')
    $lines.Add('## Glyphs without a Nerd Fonts 3.5.1 name')
    $lines.Add('')
    $lines.Add('| Section | Key | Group | Code point |')
    $lines.Add('|---|---|---|---|')
    foreach ($item in $Comparison.Unmapped) { $lines.Add(('| {0} | {1} | {2} | {3} |' -f $item.Section, (& $cell $item.Key), $item.Group, $item.CodePoint)) }
    $lines.Add('')
    $lines.Add('## Icons without a color')
    $lines.Add('')
    $lines.Add('| Section | Key | Missing in | Reference color |')
    $lines.Add('|---|---|---|---|')
    foreach ($item in ($Comparison.MissingColor | Sort-Object -Property Section, Key)) {
        $lines.Add(('| {0} | {1} | {2} | {3} |' -f $item.Section, (& $cell $item.Key), ($item.MissingIn -join ', '), $item.ReferenceColor))
    }
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($Path))) | Out-Null
    [System.IO.File]::WriteAllText($Path, ($lines -join "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
}
```

Y añade `Get-DeviconsComparison, Write-DeviconsReport` a `Export-ModuleMember`.

- [ ] **Step 4: Verde, suite y commit**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Devicons.Tests.ps1 -Output Detailed` → PASS. Luego `./build.ps1 -Task Test` (0 fallos).

```powershell
git add tools/DeviconsMapping.psm1 tests/Devicons.Tests.ps1
git commit -m "Compare devicons with the themes and write a report" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 5: Aplicar las decisiones a los temas

**Files:**
- Modify: `tools/DeviconsMapping.psm1`, `tests/Devicons.Tests.ps1`

**Interfaces:**
- Consumes: `Get-DeviconsComparison` (tarea 4), `ConvertTo-LightColor`, `ConvertTo-DraculaColor` (tarea 3), `tools/Set-ThemeEntry.ps1` (existente: `-Path <jsonc> -Section 'files.names'|'files.extensions' -Entries <hashtable>`).
- Produces (exportada): `Invoke-DeviconsApply -Comparison <pscustomobject> -ThemesPath <string> -DecisionsPath <string> [-SetThemeEntryPath <string>]` → `[pscustomobject]@{ Icons = [int]; Colors = [int] }` (entradas escritas). Archivo de decisiones JSONC: `{ "exclude": [ "<clave>" | "group:<Grupo>" ], "adopt": [ "<clave existente>" ], "colors": { "<clave>": "#RRGGBB" } }`. Añade a los temas modificados la línea de cabecera `// Some entries from nvim-web-devicons (https://github.com/nvim-tree/nvim-web-devicons). MIT License. See THIRD_PARTY_NOTICES.md.` una sola vez, después de los comentarios existentes.

- [ ] **Step 1: Tests que fallan**

Añade a `tests/Devicons.Tests.ps1`:

```powershell
Describe 'Invoke-DeviconsApply' {
    BeforeAll {
        function Invoke-Apply($World, [string]$Decisions) {
            $path = Join-Path $World.Root "decisions-$([guid]::NewGuid()).jsonc"
            [System.IO.File]::WriteAllText($path, $Decisions)
            $comparison = Get-DeviconsComparison -VendorPath $World.Vendor -GlyphNamesPath $World.GlyphNames -ThemesPath $World.Themes
            Invoke-DeviconsApply -Comparison $comparison -ThemesPath $World.Themes -DecisionsPath $path
        }
        function Read-Theme($World, [string]$Relative) { Read-JsoncFile -Path (Join-Path $World.Themes $Relative) }
        $decisions = '{ "exclude": [ "group:Env", ".d.ts" ], "adopt": [ "dockerfile" ], "colors": { "nocolor": "#123456" } }'
    }

    It 'adds the new entries that are not excluded, with derived colors' {
        $world = New-FakeWorld 'apply-new'
        Invoke-Apply $world $decisions | Out-Null
        $icons = Read-Theme $world 'icons/default.jsonc'
        $icons['files']['names']['.prettierrc'] | Should -BeExactly 'nf-dev-aaa'
        $icons['files']['names']['.prettierrc.json'] | Should -BeExactly 'nf-dev-aaa'
        $icons['files']['extensions']['.zig'] | Should -BeExactly 'nf-linux-l'
        $icons['files']['extensions'].Keys | Should -Not -Contain '.env'
        $icons['files']['extensions'].Keys | Should -Not -Contain '.d.ts'
        (Read-Theme $world 'colors/default.jsonc')['files']['extensions']['.zig'] | Should -BeExactly 'F69A1B'
        (Read-Theme $world 'colors/light.jsonc')['files']['extensions']['.zig'] | Should -BeExactly (ConvertTo-LightColor -Hex 'F69A1B')
        (Read-Theme $world 'colors/dracula.jsonc')['files']['extensions']['.zig'] | Should -BeExactly (ConvertTo-DraculaColor -Hex 'F69A1B')
    }

    It 'changes an existing entry only when it is in adopt' {
        $world = New-FakeWorld 'apply-adopt'
        Invoke-Apply $world $decisions | Out-Null
        (Read-Theme $world 'icons/default.jsonc')['files']['names']['dockerfile'] | Should -BeExactly 'nf-md-bbb'
        (Read-Theme $world 'icons/default.jsonc')['files']['names']['go.mod'] | Should -BeExactly 'nf-dev-used'

        $other = New-FakeWorld 'apply-keep'
        Invoke-Apply $other '{ "exclude": [], "adopt": [], "colors": {} }' | Out-Null
        (Read-Theme $other 'icons/default.jsonc')['files']['names']['dockerfile'] | Should -BeExactly 'nf-dev-aaa'
        @((Read-Theme $other 'icons/default.jsonc')['files']['names'].Keys | Where-Object { $_ -eq 'dockerfile' }).Count | Should -Be 1
    }

    It 'fills missing colors from the reference or from the decisions file' {
        $world = New-FakeWorld 'apply-colors'
        Invoke-Apply $world $decisions | Out-Null
        (Read-Theme $world 'colors/default.jsonc')['files']['names']['nocolor'] | Should -BeExactly '123456'
        (Read-Theme $world 'colors/light.jsonc')['files']['names']['nocolor'] | Should -BeExactly '123456'
        (Read-Theme $world 'colors/dracula.jsonc')['files']['names']['nocolor'] | Should -BeExactly (ConvertTo-DraculaColor -Hex '123456')
        (Read-Theme $world 'colors/light.jsonc')['files']['names']['dockerfile'] | Should -BeExactly (ConvertTo-LightColor -Hex '458EE6')
    }

    It 'keeps the existing header and adds the credit line once' {
        $world = New-FakeWorld 'apply-header'
        Invoke-Apply $world $decisions | Out-Null
        $lines = [System.IO.File]::ReadAllLines((Join-Path $world.Themes 'icons' 'default.jsonc'))
        $lines[0] | Should -Match 'Migrated from Terminal-Icons'
        $lines[1] | Should -Match 'nvim-web-devicons'
        @($lines | Where-Object { $_ -match 'nvim-web-devicons' }).Count | Should -Be 1
    }

    It 'changes nothing when run again' {
        $world = New-FakeWorld 'apply-twice'
        Invoke-Apply $world $decisions | Out-Null
        $before = Get-TreeSnapshot -Path $world.Themes
        $second = Invoke-Apply $world $decisions
        $second.Icons + $second.Colors | Should -Be 0
        Get-TreeSnapshot -Path $world.Themes | Should -Be $before
    }
}
```

- [ ] **Step 2: Ejecutar y ver que fallan**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Devicons.Tests.ps1 -Output Detailed`
Expected: FAIL ("Invoke-DeviconsApply is not recognized").

- [ ] **Step 3: Implementar**

En `tools/DeviconsMapping.psm1`, antes de `Export-ModuleMember`:

```powershell
$script:CreditLine = '// Some entries from nvim-web-devicons (https://github.com/nvim-tree/nvim-web-devicons). MIT License. See THIRD_PARTY_NOTICES.md.'

function Add-ThemeCreditLine {
    # Adds the nvim-web-devicons credit after the leading comment lines of a theme file, once.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $lines = [System.IO.File]::ReadAllLines($Path)
    if ($lines -contains $script:CreditLine) { return }
    $headerCount = 0
    while ($headerCount -lt $lines.Count -and $lines[$headerCount] -match '^\s*//') { $headerCount++ }
    $updated = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $headerCount; $i++) { $updated.Add($lines[$i]) }
    $updated.Add($script:CreditLine)
    for ($i = $headerCount; $i -lt $lines.Count; $i++) { $updated.Add($lines[$i]) }
    [System.IO.File]::WriteAllText($Path, ($updated -join "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
}

function Invoke-DeviconsApply {
    # Writes the approved entries into the icon theme and the three color themes.
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Comparison,

        [Parameter(Mandatory)]
        [string]$ThemesPath,

        [Parameter(Mandatory)]
        [string]$DecisionsPath,

        [string]$SetThemeEntryPath = ([System.IO.Path]::Combine($PSScriptRoot, 'Set-ThemeEntry.ps1'))
    )

    $decisions = Read-JsoncFile -Path $DecisionsPath
    $exclude = [System.Collections.Generic.HashSet[string]]::new([string[]]@($decisions['exclude']), [System.StringComparer]::OrdinalIgnoreCase)
    $adopt = [System.Collections.Generic.HashSet[string]]::new([string[]]@($decisions['adopt']), [System.StringComparer]::OrdinalIgnoreCase)
    $manualColors = @{}
    if ($decisions['colors']) { foreach ($key in $decisions['colors'].Keys) { $manualColors[$key] = $decisions['colors'][$key].TrimStart('#').ToUpperInvariant() } }

    $iconEntries = @{ names = @{}; extensions = @{} }
    $colorEntries = @{}
    foreach ($theme in 'default', 'light', 'dracula') { $colorEntries[$theme] = @{ names = @{}; extensions = @{} } }
    $setColor = {
        param([string]$Section, [string]$Key, [string]$Hex, [string[]]$Themes)
        foreach ($theme in $Themes) {
            $colorEntries[$theme][$Section][$Key] = switch ($theme) {
                'light' { ConvertTo-LightColor -Hex $Hex }
                'dracula' { ConvertTo-DraculaColor -Hex $Hex }
                default { $Hex }
            }
        }
    }

    foreach ($item in $Comparison.New) {
        if ($exclude.Contains($item.Key) -or $exclude.Contains("group:$($item.Group)")) { continue }
        $iconEntries[$item.Section][$item.Key] = $item.Glyph
        & $setColor $item.Section $item.Key $item.Color @('default', 'light', 'dracula')
    }
    foreach ($item in $Comparison.Different) {
        if (-not $adopt.Contains($item.CurrentKey)) { continue }
        $iconEntries[$item.Section][$item.CurrentKey] = $item.Glyph
        & $setColor $item.Section $item.CurrentKey $item.Color @('default', 'light', 'dracula')
    }
    foreach ($item in $Comparison.MissingColor) {
        $hex = if ($item.ReferenceColor) { $item.ReferenceColor } elseif ($manualColors.ContainsKey($item.Key)) { $manualColors[$item.Key] } else { $null }
        if (-not $hex) { continue }
        foreach ($theme in $item.MissingIn) {
            if (-not $colorEntries[$theme][$item.Section].ContainsKey($item.Key)) { & $setColor $item.Section $item.Key $hex @($theme) }
        }
    }

    $written = [pscustomobject]@{ Icons = 0; Colors = 0 }
    $targets = @(@{ Path = [System.IO.Path]::Combine($ThemesPath, 'icons', 'default.jsonc'); Entries = $iconEntries; Kind = 'Icons' })
    foreach ($theme in 'default', 'light', 'dracula') { $targets += @{ Path = [System.IO.Path]::Combine($ThemesPath, 'colors', "$theme.jsonc"); Entries = $colorEntries[$theme]; Kind = 'Colors' } }
    foreach ($target in $targets) {
        $changed = $false
        foreach ($section in 'names', 'extensions') {
            $entries = $target.Entries[$section]
            if ($entries.Count -eq 0) { continue }
            & $SetThemeEntryPath -Path $target.Path -Section "files.$section" -Entries $entries
            $written.($target.Kind) += $entries.Count
            $changed = $true
        }
        if ($changed) { Add-ThemeCreditLine -Path $target.Path }
    }
    $written
}
```

Y añade `Invoke-DeviconsApply` a `Export-ModuleMember`.

- [ ] **Step 4: Verde, suite y commit**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Devicons.Tests.ps1 -Output Detailed` → PASS. Luego `./build.ps1 -Task Test` (0 fallos).

```powershell
git add tools/DeviconsMapping.psm1 tests/Devicons.Tests.ps1
git commit -m "Apply devicons decisions to the themes" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 6: Envoltorio `tools/Import-DeviconsMapping.ps1`

**Files:**
- Create: `tools/Import-DeviconsMapping.ps1`
- Modify: `tests/Devicons.Tests.ps1`

**Interfaces:**
- Consumes: `Get-DeviconsComparison`, `Write-DeviconsReport`, `Invoke-DeviconsApply`.
- Produces: `./tools/Import-DeviconsMapping.ps1 -Report <ruta> [-ThemesPath] [-VendorPath] [-GlyphNamesPath]` y `./tools/Import-DeviconsMapping.ps1 -Apply [-Decisions <ruta>] [-ThemesPath] [-VendorPath] [-GlyphNamesPath]`. Valores por defecto: `themes/`, `vendor/nvim-web-devicons/`, `vendor/nerd-fonts/glyphnames.json`, `tools/devicons-decisions.jsonc`.

- [ ] **Step 1: Tests que fallan**

Añade a `tests/Devicons.Tests.ps1`:

```powershell
Describe 'Import-DeviconsMapping.ps1' {
    BeforeAll { $script:Tool = Join-Path $script:RepoRoot 'tools' 'Import-DeviconsMapping.ps1' }

    It 'writes the report' {
        $world = New-FakeWorld 'tool-report'
        $report = Join-Path $world.Root 'out' 'report.md'
        & $script:Tool -Report $report -ThemesPath $world.Themes -VendorPath $world.Vendor -GlyphNamesPath $world.GlyphNames 6> $null
        $report | Should -Exist
        [System.IO.File]::ReadAllText($report) | Should -Match '### PrettierConfig'
    }

    It 'applies a decisions file' {
        $world = New-FakeWorld 'tool-apply'
        $decisions = Join-Path $world.Root 'decisions.jsonc'
        [System.IO.File]::WriteAllText($decisions, '{ "exclude": [], "adopt": [], "colors": {} }')
        & $script:Tool -Apply -Decisions $decisions -ThemesPath $world.Themes -VendorPath $world.Vendor -GlyphNamesPath $world.GlyphNames 6> $null
        (Read-JsoncFile -Path (Join-Path $world.Themes 'icons' 'default.jsonc'))['files']['extensions']['.zig'] | Should -BeExactly 'nf-linux-l'
    }
}
```

- [ ] **Step 2: Ejecutar y ver que fallan**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Devicons.Tests.ps1 -Output Detailed`
Expected: FAIL (el script no existe).

- [ ] **Step 3: Implementar**

Crea `tools/Import-DeviconsMapping.ps1`:

```powershell
<#
.SYNOPSIS
    Proposes and applies file icons and colors from the vendored nvim-web-devicons data.
.DESCRIPTION
    -Report writes a Markdown report: new entries grouped by the reference's name, existing entries with another
    glyph, glyphs without a Nerd Fonts name and icons without a color. -Apply writes the entries allowed by the
    decisions file into themes/icons/default.jsonc and the three color themes; existing entries change only when they
    are listed in "adopt".
.EXAMPLE
    ./tools/Import-DeviconsMapping.ps1 -Report docs/mappings/devicons-0.3.0.md
.EXAMPLE
    ./tools/Import-DeviconsMapping.ps1 -Apply
#>
#Requires -Version 7.4
[CmdletBinding(DefaultParameterSetName = 'Report')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Report')]
    [string]$Report,

    [Parameter(Mandatory, ParameterSetName = 'Apply')]
    [switch]$Apply,

    [Parameter(ParameterSetName = 'Apply')]
    [string]$Decisions = ([System.IO.Path]::Combine($PSScriptRoot, 'devicons-decisions.jsonc')),

    [string]$ThemesPath = ([System.IO.Path]::Combine($PSScriptRoot, '..', 'themes')),

    [string]$VendorPath = ([System.IO.Path]::Combine($PSScriptRoot, '..', 'vendor', 'nvim-web-devicons')),

    [string]$GlyphNamesPath = ([System.IO.Path]::Combine($PSScriptRoot, '..', 'vendor', 'nerd-fonts', 'glyphnames.json'))
)

$ErrorActionPreference = 'Stop'
# .NET resolves relative paths against the process folder, not the PowerShell location.
$resolve = { param([string]$Path) $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Path) }
$ThemesPath = & $resolve $ThemesPath
$VendorPath = & $resolve $VendorPath
$GlyphNamesPath = & $resolve $GlyphNamesPath
$Decisions = & $resolve $Decisions
if ($Report) { $Report = & $resolve $Report }
Import-Module ([System.IO.Path]::Combine($PSScriptRoot, 'DeviconsMapping.psm1')) -Force
$comparison = Get-DeviconsComparison -VendorPath $VendorPath -GlyphNamesPath $GlyphNamesPath -ThemesPath $ThemesPath
if ($Apply) {
    $written = Invoke-DeviconsApply -Comparison $comparison -ThemesPath $ThemesPath -DecisionsPath $Decisions
    Write-Host "Applied $($written.Icons) icon entries and $($written.Colors) color entries."
} else {
    Write-DeviconsReport -Comparison $comparison -Path $Report
    Write-Host "Report written to $Report ($($comparison.New.Count) new, $($comparison.Different.Count) different)."
}
```

- [ ] **Step 4: Verde, suite y commit**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Devicons.Tests.ps1 -Output Detailed` → PASS. Luego `./build.ps1 -Task Test` (0 fallos).

```powershell
git add tools/Import-DeviconsMapping.ps1 tests/Devicons.Tests.ps1
git commit -m "Add the devicons import tool" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 7: Informe, decisiones del usuario y aplicación

**Files:**
- Create: `docs/mappings/devicons-0.3.0.md`, `tools/devicons-decisions.jsonc`
- Modify: `themes/icons/default.jsonc`, `themes/colors/default.jsonc`, `themes/colors/light.jsonc`, `themes/colors/dracula.jsonc`, `tests/Themes.Tests.ps1`

**Interfaces:**
- Consumes: `tools/Import-DeviconsMapping.ps1` (tarea 6).

- [ ] **Step 1: Generar el informe real**

Run: `./tools/Import-DeviconsMapping.ps1 -Report docs/mappings/devicons-0.3.0.md`
Expected: `Report written to ... (524 new, 113 different).` Si los números difieren, investiga antes de seguir (la medición del brainstorming dio 174 nombres + 350 extensiones nuevos y 113 diferencias).

- [ ] **Step 2: PUERTA HUMANA — decisiones del usuario**

Para y presenta al usuario un resumen del informe: recuento por grupo, lista de diferencias con una recomendación por fila (mantener / adoptar) y entradas sin color que la referencia no cubre. El usuario decide qué grupos o claves excluir, qué diferencias adoptar y qué colores manuales usar. **No continúes sin su respuesta.**

- [ ] **Step 3: Archivo de decisiones**

Crea `tools/devicons-decisions.jsonc` con lo decidido:

```jsonc
// Decisions for tools/Import-DeviconsMapping.ps1 -Apply (see docs/mappings/devicons-0.3.0.md).
{
  // Keys (".foo", "Foofile") or groups ("group:<Name>") that are not imported.
  "exclude": [],
  // Existing keys whose glyph and color are replaced by the reference's.
  "adopt": [],
  // Colors for icons without a color that the reference does not cover.
  "colors": {}
}
```

- [ ] **Step 4: Test de la invariante (falla antes de aplicar)**

En `tests/Themes.Tests.ps1` añade:

```powershell
Describe 'theme consistency' {
    It 'gives every file icon a color in <Theme>' -ForEach @(@{ Theme = 'default' }, @{ Theme = 'light' }, @{ Theme = 'dracula' }) {
        . (Join-Path $script:RepoRoot 'src' 'Private' 'Read-JsoncFile.ps1')
        $icons = Read-JsoncFile -Path (Join-Path $script:RepoRoot 'themes' 'icons' 'default.jsonc')
        $colors = Read-JsoncFile -Path (Join-Path $script:RepoRoot 'themes' 'colors' "$Theme.jsonc")
        $missing = foreach ($section in 'names', 'extensions') {
            $colorKeys = @($colors['files'][$section].Keys)
            foreach ($key in $icons['files'][$section].Keys) { if ($colorKeys -notcontains $key) { "files.$section[$key]" } }
        }
        $missing | Should -BeNullOrEmpty
    }
}
```

(`-notcontains` no distingue mayúsculas, igual que la resolución del módulo. `tests/Themes.Tests.ps1` no carga `TestHelpers.ps1`: añade al bloque un `BeforeAll { . (Join-Path $PSScriptRoot 'TestHelpers.ps1') }` para tener `$script:RepoRoot`.)

Run: `./build.ps1; Invoke-Pester -Path ./tests/Themes.Tests.ps1 -Output Detailed`
Expected: FAIL con las 14 + 3 entradas sin color actuales.

- [ ] **Step 5: Aplicar**

Run: `./tools/Import-DeviconsMapping.ps1 -Apply`
Expected: `Applied <n> icon entries and <m> color entries.`
Revisa `git diff --stat themes` (solo crecen los cuatro temas; las claves existentes solo cambian si están en `adopt`). Si la invariante sigue fallando por claves sin color que la referencia no cubre y no están en `colors`, vuelve al paso 2 con esa lista concreta.

- [ ] **Step 6: Verde y comprobación real**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Themes.Tests.ps1 -Output Detailed` → PASS. Luego, en un pwsh aparte:

```powershell
Import-Module ./out/TerminalGlyphs/<versión>/TerminalGlyphs.psd1
$dir = Join-Path $env:TEMP "tg-check-$([guid]::NewGuid())"; New-Item -ItemType Directory $dir | Out-Null
'.prettierrc', '.editorconfig', '.env', 'Makefile', 'app.d.ts', 'schema.graphql' | ForEach-Object { New-Item -ItemType File (Join-Path $dir $_) | Out-Null }
Get-ChildItem $dir | Get-TerminalGlyph | Format-Table Name, IconName, Color, Rule
Remove-Item $dir -Recurse -Force
```

Comprueba que cada archivo tiene icono y color y que `app.d.ts` sigue resolviendo por su regla de siempre (salvo que su diferencia se haya adoptado). Luego `./build.ps1 -Task Test` (0 fallos).

- [ ] **Step 7: Commit**

```powershell
git add docs/mappings/devicons-0.3.0.md tools/devicons-decisions.jsonc themes tests/Themes.Tests.ps1
git commit -m "Import file icons and colors from nvim-web-devicons" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 8: Rendimiento y release 0.3.0

**Files:**
- Modify: `src/TerminalGlyphs.psd1`, `tests/Quality.Tests.ps1`, `README.md`, `CHANGELOG.md`

- [ ] **Step 1: Rendimiento**

Run: `./build.ps1 -Task Test -Tag Performance -ExcludeTag @()` y anota la mediana de `Import-Module` y el tiempo del primer listado. Compara con `main` (`git stash` no: usa `git worktree add` temporal de `main` en `$env:TEMP`, ejecuta lo mismo allí y bórralo después). El import debe seguir < 100 ms; si el primer listado empeora más de un 25 %, avisa al usuario antes de seguir.

- [ ] **Step 2: Test de versión que falla**

En `tests/Quality.Tests.ps1`: `$manifest.Version | Should -Be ([version]'0.3.0')`.
Run: `./build.ps1; Invoke-Pester -Path ./tests/Quality.Tests.ps1 -FullNameFilter '*targets pwsh*' -Output Detailed` → FAIL (0.2.2).

- [ ] **Step 3: Versión, README y CHANGELOG**

`src/TerminalGlyphs.psd1`: `ModuleVersion = '0.3.0'`.

README, en la lista inicial de ventajas, cambia la viñeta de iconos para que mencione la cobertura y el crédito:

```markdown
- **Icons for current tooling**: Go, Rust, Cloudflare/wrangler, Terraform, CloudFormation/SAM/CDK, mise, uv, pnpm,
  Bun, Astro, Vite/VitePress/Vitest, Docker, Claude, Kiro and other AI tools, Biome, Deno and just, plus hundreds of
  file names and extensions imported from [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons).
```

CHANGELOG, bajo `## [Unreleased]`:

```markdown
### Added

- <N> file names and <M> extensions with icons and colors from nvim-web-devicons (for example `.prettierrc`,
  `.editorconfig`, `.env`, `Makefile`, `.graphql`, `.proto`, `.nix`, `.zig`), with light and Dracula colors derived
  from them.
- `tools/Import-DeviconsMapping.ps1` to report and apply mappings from the vendored nvim-web-devicons data.

### Fixed

- Every file icon has a color in the default, light and Dracula themes.
```

(Sustituye `<N>` y `<M>` por los recuentos aplicados en la tarea 7; añade una línea `### Changed` si se adoptaron diferencias, con cuántas.)

- [ ] **Step 4: Verde, suite y commit**

Run: `./build.ps1 -Task Test` (0 fallos) y `./tools/Test-Publish.ps1` (OK, 0.3.0, 6 funciones).

```powershell
git add src/TerminalGlyphs.psd1 tests/Quality.Tests.ps1 README.md CHANGELOG.md
git commit -m "Prepare 0.3.0" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

## Verificación final

1. `./build.ps1 -Task Test`: 0 fallos.
2. Rendimiento dentro de los límites de la tarea 8.
3. `./tools/Test-Publish.ps1`: OK.
4. `./tools/Import-DeviconsMapping.ps1 -Apply` una segunda vez: `Applied 0 icon entries and 0 color entries.` y `git status` limpio.
5. Revisión independiente de la rama; PR y publicación solo con confirmación del usuario.
