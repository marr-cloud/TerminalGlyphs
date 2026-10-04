# TerminalGlyphs 0.2.0 Setup Command Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Añadir `Install-TerminalGlyphSetup` (instala/actualiza Nerd Fonts 3.5.1 y ajusta el perfil) sin repetir el fallo de caché de fuentes de Windows, y dejar TerminalGlyphs 0.2.0 listo para la PowerShell Gallery.

**Architecture:** Un comando público orquesta funciones privadas pequeñas, cada una con una responsabilidad y probada por separado: leer la tabla `name` de una fuente, detectar familias instaladas, descargar y verificar un paquete del release, copiar/registrar/renombrar archivos, limpiar renombrados tras un reinicio y editar el perfil. La red, `AddFontResource` y `fc-cache` quedan detrás de envoltorios mínimos para sustituirlos en los tests. `build.ps1` compila `nerdfonts.json` (prefijo de archivo → paquete del release) desde el `fonts.json` oficial vendorizado.

**Tech Stack:** PowerShell 7.4+, Pester 5.9.x, PSScriptAnalyzer 1.25.0, PSResourceGet, `tar` del sistema (bsdtar/GNU tar con xz), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-04-setup-command-design.md` (y la base `docs/superpowers/specs/2026-10-03-terminalglyphs-design.md`).

## Global Constraints

- Módulo `TerminalGlyphs`; la versión pasa a `0.2.0` **solo en la Tarea 9**. GUID `191db48e-7499-4eff-8584-fb8c62a2ddee`, `PowerShellVersion = '7.4'`, `CompatiblePSEditions = @('Core')`.
- Nerd Fonts **3.5.1**: release `https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/<Paquete>.tar.xz` + `SHA-256.txt` (formato por línea: `<sha256 en minúsculas>  <archivo>`).
- API pública final exacta (6): `Format-TerminalGlyph`, `Get-TerminalGlyph`, `Show-TerminalGlyphTheme`, `Find-NerdGlyph`, `Update-TerminalGlyphConfig`, `Install-TerminalGlyphSetup`.
- **El import sigue sin leer datos ni escribir nada.** `Install-TerminalGlyphSetup` nunca se ejecuta al importar.
- **Los tests nunca tocan la máquina real**: ni la carpeta de fuentes del usuario, ni `HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts`, ni `$PROFILE`, ni la red. Registro de pruebas: `HKCU:\Software\TerminalGlyphs.Tests\Fonts` (se borra al terminar).
- Estados del resumen en inglés, como el resto de mensajes del módulo: `OK`, `Unchanged` (spec: "Sin cambios"), `Skipped` ("Omitido"), `Error`.
- Fuentes renombradas en uso (Windows): `<archivo>.<yyyyMMddHHmmss>.old-nerdfont` con la hora **UTC**; se borran solo si `LastBootUpTime` (UTC) es posterior.
- Código, comentarios, nombres, mensajes y commits **en inglés**; commits en imperativo y *sentence case* (`Add …`, `Fix …`).
- Cada commit termina con estas dos líneas (un solo `-m` para que queden juntas como trailers):
  `git commit -m "<Subject>" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"`
- Nunca `git push` ni publicar en la Gallery. Se trabaja en un worktree de la rama `feat/setup-command`, nunca en `main`.
- `src/`, `build.ps1` y `tools/`: **solo ASCII**; parámetros con nombre en cmdlets; E/S con `[System.IO.File]`/`[System.IO.Path]::Combine`.
- Nunca `"$var: ..."` en strings con comillas dobles: usa `"${var}: ..."` o `"$($var): ..."`.
- Las variables de PowerShell no distinguen mayúsculas: en `Install-TerminalGlyphSetup` **no uses `$family`** como variable de bucle (pisaría el parámetro `-Family`).
- `-ErrorAction Ignore` (no `SilentlyContinue`) cuando un fallo esperado no debe quedar en `$Error`.
- Ciclo rojo/verde de cada tarea: `./build.ps1` y luego `Invoke-Pester -Path <archivo de test> -Output Detailed`. **Antes de cada commit, la suite completa:** `./build.ps1 -Task Test` (0 fallos; PSScriptAnalyzer 0 hallazgos).

## Review Focus

1. **Perfil con la importación indentada, entre comillas o con más parámetros** (`    Import-Module -Name 'Terminal-Icons' -ErrorAction SilentlyContinue`): solo cambia el nombre del módulo y se conserva el resto de la línea → test en la Tarea 7.
2. **Perfil en UTF-16 LE con BOM** (lo crea Windows PowerShell 5.1 o el Bloc de notas): sigue en UTF-16 LE tras editarlo → test en la Tarea 7.
3. **Carpeta del perfil inexistente** (máquina nueva, Documentos redirigido a OneDrive): se crea la carpeta y el perfil → test en la Tarea 7.
4. **Dos ejecuciones antes de reiniciar Windows** (dos copias renombradas del mismo archivo): ninguna se borra hasta después del reinicio y se vuelve a pedir el reinicio → tests en las Tareas 6 y 8.
5. **Nombres de archivo con otra capitalización o variantes de prefijo** (`jetbrainsmononerdfont-italic.TTF`, `MesloLGSDZNerdFont-…`, `IosevkaTermSlabNerdFont-…`, `JetBrainsMonoNLNerdFont-…`): se asignan al paquete correcto por el prefijo más largo → test en la Tarea 3.

---

## Mapa de archivos

| Archivo | Responsabilidad | Tarea |
|---|---|---|
| `vendor/nerd-fonts/fonts.json`, `vendor/nerd-fonts/README.md` | Índice oficial de familias v3.5.1 (`patchedName` → `folderName`) | 1 |
| `build.ps1` | Compila `nerdfonts.json` (`version` + `packages`: prefijo → paquete) | 1 |
| `src/TerminalGlyphs.psm1` | `$script:FontsPath` | 1 |
| `tests/TestHelpers.ps1` | `New-TestFont`, `Get-SystemTar`, `New-FakeNerdFontRelease` | 2, 4 |
| `src/Private/Read-FontInfo.ps1` | Nombre completo, familia y versión Nerd Fonts de la tabla `name` | 2 |
| `src/Private/Get-FontLocation.ps1` | Plataforma y carpeta de fuentes del usuario | 3 |
| `src/Private/Get-NerdFontInstallation.ps1` | Familias instaladas, archivos, versión mínima, desactualizada | 3 |
| `src/Private/Invoke-NerdFontDownload.ps1` | Envoltorio de red (`Invoke-WebRequest`) | 4 |
| `src/Private/Save-NerdFontRelease.ps1` | Descarga, verifica SHA-256 y extrae un paquete | 4 |
| `src/Private/Register-FontResource.ps1` | Envoltorio de `AddFontResourceW` + `WM_FONTCHANGE` | 5 |
| `src/Private/Invoke-FontCacheRefresh.ps1` | Envoltorio de `fc-cache -f` | 5 |
| `src/Private/Install-NerdFontFile.ps1` | Copia / registra / renombra según plataforma | 5 |
| `src/Private/Remove-StaleFontFile.ps1` | Borra renombrados tras un reinicio; restaura originales perdidos | 6 |
| `src/Private/Update-ProfileImport.ps1` | Edita el perfil (respaldo, codificación, escritura atómica) | 7 |
| `src/Public/Install-TerminalGlyphSetup.ps1` | Orquesta los pasos y el resumen | 8 |
| `tests/Fonts.Tests.ps1` | Tests de las funciones privadas de fuentes | 2–6 |
| `tests/Profile.Tests.ps1` | Tests de `Update-ProfileImport` | 7 |
| `tests/Setup.Tests.ps1` | Tests del comando (con mocks y de extremo a extremo) | 8 |
| `tools/Install-NerdFont.ps1` | Se elimina | 9 |
| `README.md`, `CHANGELOG.md`, `src/TerminalGlyphs.psd1`, specs | Versión 0.2.0 y documentación | 9 |
| `tools/Test-Publish.ps1`, `.github/workflows/{ci,publish}.yml` | Ensayo de publicación y CI en macOS | 10 |

---

### Task 1: Índice de familias de Nerd Fonts en el build

**Files:**
- Create: `vendor/nerd-fonts/fonts.json` (descargado)
- Modify: `vendor/nerd-fonts/README.md`, `THIRD_PARTY_NOTICES.md`, `build.ps1:101-103`, `src/TerminalGlyphs.psm1:4`
- Test: `tests/Helpers.Tests.ps1`, `tests/Build.Tests.ps1`

**Interfaces:**
- Produces: archivo compilado `out/TerminalGlyphs/<versión>/nerdfonts.json` con forma `{ "version": "3.5.1", "packages": { "<prefijo de archivo>": "<paquete del release>" } }` (72 entradas; prefijo = `patchedName` sin espacios). Variable de módulo `$script:FontsPath` = ruta a ese archivo.

- [ ] **Step 1: Escribir los tests que fallan**

En `tests/Helpers.Tests.ps1`, dentro de `Describe 'vendored Nerd Fonts data'`, añade:

```powershell
    It 'includes the font index of the same release' {
        $path = Join-Path $root 'vendor' 'nerd-fonts' 'fonts.json'
        (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash | Should -Be '893E03F5FB079036AE19A05B30985C40603909F5C663919DA0760DF86FEEEFD6'
        (Read-JsoncFile -Path $path)['fonts'].Count | Should -Be 72
    }
```

En `tests/Build.Tests.ps1`, añade `@{ File = 'nerdfonts.json' }` a la lista de `It 'contains <File>'` y, dentro de `Describe 'build output'`:

```powershell
    It 'maps Nerd Fonts file prefixes to release packages' {
        $fonts = Get-Content -LiteralPath (Join-Path $moduleDir 'nerdfonts.json') -Raw | ConvertFrom-Json -AsHashtable
        $fonts['version'] | Should -Be '3.5.1'
        $fonts['packages'].Count | Should -Be 72
        $fonts['packages']['JetBrainsMono'] | Should -BeExactly 'JetBrainsMono'
        $fonts['packages']['CaskaydiaCove'] | Should -BeExactly 'CascadiaCode'
        $fonts['packages']['MesloLG'] | Should -BeExactly 'Meslo'
        $fonts['packages']['InconsolataLGC'] | Should -BeExactly 'InconsolataLGC'
    }

    It 'keeps the font index path in the module body without reading it on import' {
        $psm1 = Get-Content -LiteralPath (Join-Path $moduleDir 'TerminalGlyphs.psm1') -Raw
        $psm1 | Should -Match ([regex]::Escape("`$script:FontsPath = [System.IO.Path]::Combine(`$PSScriptRoot, 'nerdfonts.json')"))
    }
```

- [ ] **Step 2: Ejecutar y ver que fallan**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Helpers.Tests.ps1, ./tests/Build.Tests.ps1 -Output Detailed`
Expected: FAIL en los tres tests nuevos (archivo inexistente / `nerdfonts.json` no existe / patrón no encontrado).

- [ ] **Step 3: Vendorizar `fonts.json`**

```powershell
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/ryanoasis/nerd-fonts/v3.5.1/bin/scripts/lib/fonts.json' -OutFile ./vendor/nerd-fonts/fonts.json
(Get-FileHash ./vendor/nerd-fonts/fonts.json -Algorithm SHA256).Hash   # debe ser 893E03F5FB079036AE19A05B30985C40603909F5C663919DA0760DF86FEEEFD6
```

Si el hash no coincide, para y avisa (no lo cambies en el test).

Reemplaza `vendor/nerd-fonts/README.md` por:

```markdown
# Nerd Fonts data

- License: MIT for source files outside folders with an explicit OFL license (see LICENSE in this folder).

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
```

En `THIRD_PARTY_NOTICES.md`, sección `## Nerd Fonts`, cambia las dos primeras viñetas por:

```markdown
- Source: https://github.com/ryanoasis/nerd-fonts (v3.5.1, `glyphnames.json` and `bin/scripts/lib/fonts.json`)
- Used for: glyph names and code points in `vendor/nerd-fonts/glyphnames.json`, `TerminalGlyphs.data.json` and
  `glyphs.json`, and the font family index in `vendor/nerd-fonts/fonts.json` and `nerdfonts.json`. Nerd Fonts applies
  the MIT License to source files outside folders with an explicit OFL license; see `vendor/nerd-fonts/LICENSE`.
```

- [ ] **Step 4: Compilar `nerdfonts.json`**

En `build.ps1`, justo después de la línea que escribe `glyphs.json` (línea 103), añade:

```powershell
    $fontIndex = Read-JsoncFile -Path ([System.IO.Path]::Combine($root, 'vendor', 'nerd-fonts', 'fonts.json'))
    $packages = [System.Collections.Generic.SortedDictionary[string, string]]::new([System.StringComparer]::Ordinal)
    foreach ($font in $fontIndex['fonts']) { $packages[$font['patchedName'].Replace(' ', '')] = $font['folderName'] }
    $nerdFonts = [ordered]@{ version = $nerd.Version; packages = $packages }
    [System.IO.File]::WriteAllText([System.IO.Path]::Combine($moduleDir, 'nerdfonts.json'), ($nerdFonts | ConvertTo-Json -Compress), $utf8)
```

En `src/TerminalGlyphs.psm1`, después de la línea de `$script:GlyphsPath`, añade:

```powershell
$script:FontsPath = [System.IO.Path]::Combine($PSScriptRoot, 'nerdfonts.json')
```

- [ ] **Step 5: Ejecutar y ver que pasan**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Helpers.Tests.ps1, ./tests/Build.Tests.ps1 -Output Detailed`
Expected: PASS.

- [ ] **Step 6: Suite completa y commit**

Run: `./build.ps1 -Task Test` → 0 fallos.

```powershell
git add vendor/nerd-fonts build.ps1 src/TerminalGlyphs.psm1 THIRD_PARTY_NOTICES.md tests/Helpers.Tests.ps1 tests/Build.Tests.ps1
git commit -m "Add Nerd Fonts family index to the build" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 2: Leer nombre y versión de una fuente

**Files:**
- Create: `src/Private/Read-FontInfo.ps1`, `tests/Fonts.Tests.ps1`
- Modify: `tests/TestHelpers.ps1` (añadir `New-TestFont`)

**Interfaces:**
- Produces: `Read-FontInfo -Path <string>` → `[pscustomobject]@{ FullName = [string]; Family = [string]; Version = [version] o $null }`, o `$null` si el archivo no se puede leer o no tiene tabla `name`/ID 4. `Family` = ID 16 (familia tipográfica) o, si falta, ID 1. Prefiere registros de plataforma 3 con idioma 0x409.
- Produces (tests): `New-TestFont -Path <string> [-FullName] [-Family] [-TypographicFamily] [-Version]` → ruta; `-TypographicFamily ''` omite el ID 16.

Datos reales verificados (JetBrainsMonoNerdFontMono-Regular.ttf 3.5.1): ID 4 = `JetBrainsMono NFM Regular`; ID 5 = `Version 2.304; ttfautohint (v1.8.4.7-5d5b);Nerd Fonts 3.5.1`; ID 16 (0x409) = `JetBrainsMono Nerd Font Mono` pero ID 16 (0x809) = `JetBrainsMono NFM`; FiraCode no tiene ID 16 e ID 1 = `FiraCode Nerd Font Mono`.

- [ ] **Step 1: Añadir el generador de fuentes de prueba**

Al final de `tests/TestHelpers.ps1`:

```powershell
function New-TestFont {
    # A minimal sfnt with only a 'name' table: enough for Read-FontInfo, not a usable font.
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$FullName = 'Test NFM Regular',
        [string]$Family = 'Test NFM',
        [string]$TypographicFamily = 'Test Nerd Font Mono',
        [string]$Version = 'Version 1.000;Nerd Fonts 3.5.1'
    )
    $records = [System.Collections.Generic.List[object]]::new()
    $records.Add(@(1, 0x409, $Family))
    $records.Add(@(4, 0x409, $FullName))
    $records.Add(@(5, 0x409, $Version))
    if ($TypographicFamily) {
        # A British English record first: Read-FontInfo must prefer US English, as real Nerd Fonts need.
        $records.Add(@(16, 0x809, 'Wrong Family'))
        $records.Add(@(16, 0x409, $TypographicFamily))
    }
    $put = {
        param($List, [long]$Value, [int]$Size)
        for ($shift = 8 * ($Size - 1); $shift -ge 0; $shift -= 8) { $List.Add([byte](($Value -shr $shift) -band 0xFF)) }
    }
    $strings = [System.Collections.Generic.List[byte]]::new()
    $table = [System.Collections.Generic.List[byte]]::new()
    & $put $table 0 2
    & $put $table $records.Count 2
    & $put $table (6 + 12 * $records.Count) 2
    foreach ($record in $records) {
        $text = [System.Text.Encoding]::BigEndianUnicode.GetBytes([string]$record[2])
        & $put $table 3 2
        & $put $table 1 2
        & $put $table $record[1] 2
        & $put $table $record[0] 2
        & $put $table $text.Length 2
        & $put $table $strings.Count 2
        $strings.AddRange($text)
    }
    $table.AddRange($strings)
    $font = [System.Collections.Generic.List[byte]]::new()
    & $put $font 0x00010000 4
    & $put $font 1 2
    & $put $font 16 2
    & $put $font 0 2
    & $put $font 0 2
    $font.AddRange([byte[]][char[]]'name')
    & $put $font 0 4
    & $put $font 28 4
    & $put $font $table.Count 4
    $font.AddRange($table)
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($Path)) | Out-Null
    [System.IO.File]::WriteAllBytes($Path, $font.ToArray())
    $Path
}
```

- [ ] **Step 2: Escribir los tests que fallan**

Crea `tests/Fonts.Tests.ps1`:

```powershell
BeforeDiscovery {
    $userFonts = if ($IsWindows) { Join-Path $env:LOCALAPPDATA 'Microsoft' 'Windows' 'Fonts' } else { $null }
    $realFont = if ($userFonts -and (Test-Path -LiteralPath $userFonts)) {
        Get-ChildItem -LiteralPath $userFonts -Filter '*NerdFontMono-Regular.ttf' -ErrorAction Ignore | Select-Object -First 1
    }
}

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot 'src' 'Private') -Filter '*.ps1')) { . $file.FullName }
}

Describe 'Read-FontInfo' {
    It 'reads the full name, the US English typographic family and the Nerd Fonts version' {
        $path = New-TestFont -Path (Join-Path $TestDrive 'a.ttf') -FullName 'JetBrainsMono NFM Regular' -Family 'JetBrainsMono NFM' -TypographicFamily 'JetBrainsMono Nerd Font Mono' -Version 'Version 2.304; ttfautohint (v1.8.4.7-5d5b);Nerd Fonts 3.5.1'
        $info = Read-FontInfo -Path $path
        $info.FullName | Should -BeExactly 'JetBrainsMono NFM Regular'
        $info.Family | Should -BeExactly 'JetBrainsMono Nerd Font Mono'
        $info.Version | Should -Be ([version]'3.5.1')
    }

    It 'falls back to the legacy family name' {
        $path = New-TestFont -Path (Join-Path $TestDrive 'b.ttf') -Family 'FiraCode Nerd Font Mono' -TypographicFamily ''
        (Read-FontInfo -Path $path).Family | Should -BeExactly 'FiraCode Nerd Font Mono'
    }

    It 'returns a null version for fonts that are not from Nerd Fonts' {
        $info = Read-FontInfo -Path (New-TestFont -Path (Join-Path $TestDrive 'c.ttf') -Version 'Version 1.0')
        $info.FullName | Should -Not -BeNullOrEmpty
        $info.Version | Should -BeNullOrEmpty
    }

    It 'returns $null for <Case>' -ForEach @(@{ Case = 'a truncated file'; Length = 20 }, @{ Case = 'an empty file'; Length = 0 }) {
        $bytes = [System.IO.File]::ReadAllBytes((New-TestFont -Path (Join-Path $TestDrive "full-$Length.ttf")))
        $path = Join-Path $TestDrive "cut-$Length.ttf"
        # 20 bytes keep the 12-byte header but cut the table directory.
        [System.IO.File]::WriteAllBytes($path, [byte[]]@($bytes | Select-Object -First $Length))
        Read-FontInfo -Path $path | Should -BeNullOrEmpty
    }

    It 'returns $null for a missing file' {
        Read-FontInfo -Path (Join-Path $TestDrive 'missing.ttf') | Should -BeNullOrEmpty
    }

    It 'reads an installed Nerd Font' -Skip:(-not $realFont) -ForEach @(@{ RealFont = $realFont }) {
        $info = Read-FontInfo -Path $RealFont.FullName
        $info.FullName | Should -Not -BeNullOrEmpty
        $info.Version | Should -Not -BeNullOrEmpty
    }
}
```

- [ ] **Step 3: Ejecutar y ver que fallan**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Fonts.Tests.ps1 -Output Detailed`
Expected: FAIL con "The term 'Read-FontInfo' is not recognized".

- [ ] **Step 4: Implementar**

Crea `src/Private/Read-FontInfo.ps1`:

```powershell
function Read-FontInfo {
    <#
    .SYNOPSIS
        Reads the full name, family and Nerd Fonts version from the OpenType 'name' table of a font file.
    .DESCRIPTION
        Returns $null when the file cannot be read or has no full name. Version is $null when the version string
        has no "Nerd Fonts X.Y.Z" part. US English Windows records are preferred over other languages.
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $stream = $null
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        $read = {
            param([long]$Offset, [long]$Count)
            if ($Count -gt 1MB) { throw 'The name table is too large.' }
            $buffer = [byte[]]::new($Count)
            [void]$stream.Seek($Offset, [System.IO.SeekOrigin]::Begin)
            $stream.ReadExactly($buffer, 0, $buffer.Length)
            , $buffer
        }
        $u16 = { param([byte[]]$Bytes, [int]$At) ([int]$Bytes[$At] -shl 8) -bor $Bytes[$At + 1] }
        $u32 = { param([byte[]]$Bytes, [int]$At) ([long]$Bytes[$At] -shl 24) -bor ([long]$Bytes[$At + 1] -shl 16) -bor ([long]$Bytes[$At + 2] -shl 8) -bor $Bytes[$At + 3] }

        $header = & $read 0 12
        $tableCount = & $u16 $header 4
        $directory = & $read 12 (16 * $tableCount)
        $table = $null
        for ($i = 0; $i -lt $tableCount; $i++) {
            if ([System.Text.Encoding]::ASCII.GetString($directory, 16 * $i, 4) -ceq 'name') {
                $table = & $read (& $u32 $directory (16 * $i + 8)) (& $u32 $directory (16 * $i + 12))
                break
            }
        }
        if ($null -eq $table) { return $null }

        $count = & $u16 $table 2
        $storage = & $u16 $table 4
        $names = @{}
        $ranks = @{}
        for ($i = 0; $i -lt $count; $i++) {
            $record = 6 + 12 * $i
            $platform = & $u16 $table $record
            $language = & $u16 $table ($record + 4)
            $nameId = & $u16 $table ($record + 6)
            if ($platform -notin 0, 3 -or $nameId -notin 1, 4, 5, 16) { continue }
            $rank = if ($platform -eq 3 -and $language -eq 0x409) { 0 } else { 1 }
            if ($ranks.ContainsKey($nameId) -and $ranks[$nameId] -le $rank) { continue }
            $ranks[$nameId] = $rank
            $names[$nameId] = [System.Text.Encoding]::BigEndianUnicode.GetString($table, $storage + (& $u16 $table ($record + 10)), (& $u16 $table ($record + 8)))
        }
        if (-not $names.ContainsKey(4)) { return $null }

        $version = $null
        if ($names[5] -match 'Nerd Fonts (\d+\.\d+(?:\.\d+)?)') { $version = [version]$Matches[1] }
        $family = if ($names.ContainsKey(16)) { $names[16] } else { $names[1] }
        [pscustomobject]@{ FullName = $names[4]; Family = $family; Version = $version }
    } catch {
        Write-Verbose -Message "Could not read font names from ${Path}: $($_.Exception.Message)"
        $null
    } finally {
        if ($stream) { $stream.Dispose() }
    }
}
```

- [ ] **Step 5: Ejecutar y ver que pasan**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Fonts.Tests.ps1 -Output Detailed`
Expected: PASS (el test de fuente instalada pasa en tu Windows y se omite en CI).

- [ ] **Step 6: Suite completa y commit**

Run: `./build.ps1 -Task Test` → 0 fallos.

```powershell
git add src/Private/Read-FontInfo.ps1 tests/Fonts.Tests.ps1 tests/TestHelpers.ps1
git commit -m "Read font names and Nerd Fonts version from the name table" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 3: Detectar las Nerd Fonts instaladas

**Files:**
- Create: `src/Private/Get-FontLocation.ps1`, `src/Private/Get-NerdFontInstallation.ps1`
- Test: `tests/Fonts.Tests.ps1`

**Interfaces:**
- Consumes: `Read-FontInfo -Path` (Tarea 2).
- Produces: `Get-FontLocation` → `[pscustomobject]@{ Platform = 'Windows'|'Linux'|'MacOS'; Directory = [string] }`.
  Windows: `%LOCALAPPDATA%\Microsoft\Windows\Fonts`; macOS: `~/Library/Fonts`; Linux: `$XDG_DATA_HOME/fonts` o `~/.local/share/fonts`.
- Produces: `Get-NerdFontInstallation -FontDirectory <string> -PackageMap <IDictionary prefijo→paquete> -MinimumVersion <version>` → un objeto por familia, tipo `TerminalGlyphs.NerdFontFamily`: `Name` (paquete, o el prefijo si es desconocida), `Package` (`$null` si desconocida), `Files` (`List[string]`, rutas completas), `Version` (la menor leída, o `$null`), `IsOutdated` (`$true` si algún archivo es < mínima o no tiene versión legible). Busca recursivamente `*.ttf|*.otf` cuyo nombre contenga `NerdFont` (sin distinguir mayúsculas). Carpeta inexistente → nada.

- [ ] **Step 1: Escribir los tests que fallan**

Añade a `tests/Fonts.Tests.ps1`:

```powershell
Describe 'Get-FontLocation' {
    It 'returns the per-user font folder of this platform' {
        $location = Get-FontLocation
        if ($IsWindows) {
            $location.Platform | Should -Be 'Windows'
            $location.Directory | Should -Be (Join-Path $env:LOCALAPPDATA 'Microsoft' 'Windows' 'Fonts')
        } elseif ($IsMacOS) {
            $location.Platform | Should -Be 'MacOS'
            $location.Directory | Should -Be (Join-Path $HOME 'Library' 'Fonts')
        } else {
            $location.Platform | Should -Be 'Linux'
        }
    }

    It 'honors XDG_DATA_HOME on Linux' -Skip:(-not $IsLinux) {
        $saved = $env:XDG_DATA_HOME
        try {
            $env:XDG_DATA_HOME = Join-Path $TestDrive 'xdg'
            (Get-FontLocation).Directory | Should -Be (Join-Path $TestDrive 'xdg' 'fonts')
        } finally {
            $env:XDG_DATA_HOME = $saved
        }
    }
}

Describe 'Get-NerdFontInstallation' {
    BeforeAll {
        $map = @{
            JetBrainsMono = 'JetBrainsMono'; FiraCode = 'FiraCode'; MesloLG = 'Meslo'; Hack = 'Hack'
            Iosevka = 'Iosevka'; IosevkaTerm = 'IosevkaTerm'; IosevkaTermSlab = 'IosevkaTermSlab'
        }
        $dir = Join-Path $TestDrive 'detect'
        New-TestFont -Path (Join-Path $dir 'JetBrainsMonoNerdFontMono-Regular.ttf') | Out-Null
        New-TestFont -Path (Join-Path $dir 'JetBrainsMonoNLNerdFont-Bold.ttf') -Version 'Version 2.304;Nerd Fonts 3.0.2' | Out-Null
        New-TestFont -Path (Join-Path $dir 'jetbrainsmononerdfont-italic.TTF') | Out-Null
        New-TestFont -Path (Join-Path $dir 'FiraCodeNerdFont-Regular.ttf') | Out-Null
        New-TestFont -Path (Join-Path $dir 'MesloLGSDZNerdFont-Regular.ttf') | Out-Null
        New-TestFont -Path (Join-Path $dir 'IosevkaTermSlabNerdFont-Regular.ttf') | Out-Null
        New-TestFont -Path (Join-Path $dir 'NerdFonts' 'Hack' 'HackNerdFont-Regular.ttf') | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $dir 'HackNerdFontMono-Regular.ttf'), 'not a font')
        New-TestFont -Path (Join-Path $dir 'FooBarNerdFont-Regular.ttf') | Out-Null
        New-TestFont -Path (Join-Path $dir 'Arial.ttf') | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $dir 'FiraCodeNerdFont-Bold.ttf.20260101000000.old-nerdfont'), 'old')
        $families = @(Get-NerdFontInstallation -FontDirectory $dir -PackageMap $map -MinimumVersion '3.5.1')
        function Get-Family([string]$Name) { $families | Where-Object Name -EQ $Name }
    }

    It 'groups variants and other casings under one package and reports the oldest version' {
        $jetbrains = Get-Family 'JetBrainsMono'
        $jetbrains.Package | Should -Be 'JetBrainsMono'
        $jetbrains.Files.Count | Should -Be 3
        $jetbrains.Version | Should -Be ([version]'3.0.2')
        $jetbrains.IsOutdated | Should -BeTrue
    }

    It 'reports current families as not outdated' {
        (Get-Family 'FiraCode').IsOutdated | Should -BeFalse
        (Get-Family 'FiraCode').Files.Count | Should -Be 1
    }

    It 'uses the longest known prefix (<Name>)' -ForEach @(@{ Name = 'Meslo' }, @{ Name = 'IosevkaTermSlab' }) {
        (Get-Family $Name).Package | Should -Be $Name
    }

    It 'searches subfolders and treats unreadable files as outdated' {
        $hack = Get-Family 'Hack'
        $hack.Files.Count | Should -Be 2
        $hack.IsOutdated | Should -BeTrue
    }

    It 'reports unknown families without a package' {
        $unknown = Get-Family 'FooBar'
        $unknown.Package | Should -BeNullOrEmpty
        $unknown.Files.Count | Should -Be 1
    }

    It 'ignores fonts that are not Nerd Fonts and renamed leftovers' {
        $families.Files | Should -Not -Contain (Join-Path $dir 'Arial.ttf')
        @($families.Files | Where-Object { $_ -like '*.old-nerdfont' }).Count | Should -Be 0
        $families.Count | Should -Be 6
    }

    It 'returns nothing for a missing folder' {
        Get-NerdFontInstallation -FontDirectory (Join-Path $TestDrive 'nope') -PackageMap $map -MinimumVersion '3.5.1' | Should -BeNullOrEmpty
    }
}
```

- [ ] **Step 2: Ejecutar y ver que fallan**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Fonts.Tests.ps1 -Output Detailed`
Expected: FAIL con "Get-FontLocation / Get-NerdFontInstallation is not recognized".

- [ ] **Step 3: Implementar**

Crea `src/Private/Get-FontLocation.ps1`:

```powershell
function Get-FontLocation {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param()

    $userProfile = [Environment]::GetFolderPath('UserProfile')
    if ($IsWindows) {
        $platform = 'Windows'
        $directory = [System.IO.Path]::Combine([Environment]::GetFolderPath('LocalApplicationData'), 'Microsoft', 'Windows', 'Fonts')
    } elseif ($IsMacOS) {
        $platform = 'MacOS'
        $directory = [System.IO.Path]::Combine($userProfile, 'Library', 'Fonts')
    } else {
        $platform = 'Linux'
        $dataHome = if ($env:XDG_DATA_HOME) { $env:XDG_DATA_HOME } else { [System.IO.Path]::Combine($userProfile, '.local', 'share') }
        $directory = [System.IO.Path]::Combine($dataHome, 'fonts')
    }
    [pscustomobject]@{ Platform = $platform; Directory = $directory }
}
```

Crea `src/Private/Get-NerdFontInstallation.ps1`:

```powershell
function Get-NerdFontInstallation {
    <#
    .SYNOPSIS
        Groups the Nerd Font files in a folder by release package and reports which ones are outdated.
    .DESCRIPTION
        The package of a file is found from the part of its name before "NerdFont", using the longest matching
        prefix in -PackageMap (JetBrainsMonoNL and JetBrainsMono both belong to JetBrainsMono). Files without a
        readable Nerd Fonts version count as outdated.
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FontDirectory,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$PackageMap,

        [Parameter(Mandatory)]
        [version]$MinimumVersion
    )

    if (-not [System.IO.Directory]::Exists($FontDirectory)) { return }
    $ignoreCase = [System.StringComparison]::OrdinalIgnoreCase
    $prefixes = @($PackageMap.Keys | Sort-Object -Property Length -Descending)
    $families = [ordered]@{}
    $files = Get-ChildItem -LiteralPath $FontDirectory -Recurse -File -ErrorAction Ignore |
        Where-Object { $_.Extension -in '.ttf', '.otf' -and $_.Name.Contains('NerdFont', $ignoreCase) } |
        Sort-Object -Property FullName
    foreach ($file in $files) {
        $stem = $file.Name.Substring(0, $file.Name.IndexOf('NerdFont', $ignoreCase))
        $prefix = $prefixes | Where-Object { $stem.StartsWith($_, $ignoreCase) } | Select-Object -First 1
        $package = if ($prefix) { $PackageMap[$prefix] } else { $null }
        $key = if ($package) { $package } else { "?$stem" }
        if (-not $families.Contains($key)) {
            $families[$key] = [pscustomobject]@{
                PSTypeName = 'TerminalGlyphs.NerdFontFamily'
                Name       = if ($package) { $package } else { $stem }
                Package    = $package
                Files      = [System.Collections.Generic.List[string]]::new()
                Version    = $null
                IsOutdated = $false
            }
        }
        $entry = $families[$key]
        $entry.Files.Add($file.FullName)
        $info = Read-FontInfo -Path $file.FullName
        if ($null -eq $info -or $null -eq $info.Version) {
            $entry.IsOutdated = $true
            continue
        }
        if ($null -eq $entry.Version -or $info.Version -lt $entry.Version) { $entry.Version = $info.Version }
        if ($info.Version -lt $MinimumVersion) { $entry.IsOutdated = $true }
    }
    $families.Values
}
```

- [ ] **Step 4: Ejecutar y ver que pasan**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Fonts.Tests.ps1 -Output Detailed`
Expected: PASS.

- [ ] **Step 5: Suite completa y commit**

Run: `./build.ps1 -Task Test` → 0 fallos.

```powershell
git add src/Private/Get-FontLocation.ps1 src/Private/Get-NerdFontInstallation.ps1 tests/Fonts.Tests.ps1
git commit -m "Detect installed Nerd Fonts families and versions" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 4: Descargar, verificar y extraer un paquete

**Files:**
- Create: `src/Private/Invoke-NerdFontDownload.ps1`, `src/Private/Save-NerdFontRelease.ps1`
- Modify: `tests/TestHelpers.ps1` (añadir `Get-SystemTar`, `New-FakeNerdFontRelease`)
- Test: `tests/Fonts.Tests.ps1`

**Interfaces:**
- Produces: `Invoke-NerdFontDownload -Uri <string> -OutFile <string>` (único punto de red; los tests lo sustituyen).
- Produces: `Save-NerdFontRelease -Package <string> -Version <string> -Destination <string> [-BaseUri <string>]` → rutas completas (`string[]`) de los `.ttf`/`.otf` extraídos en `<Destination>/<Package>/`, ordenadas por nombre. Descarga `SHA-256.txt` una sola vez por `-Destination`. Lanza error si el paquete no está en `SHA-256.txt`, si el hash no coincide (sin extraer nada) o si `tar` falla. `-BaseUri` por defecto: `https://github.com/ryanoasis/nerd-fonts/releases/download`.
- Produces (tests): `Get-SystemTar` → ruta de `tar`; `New-FakeNerdFontRelease -Root <string> -Package <string> -FontName <string[]> [-Version <string>]` crea `<Root>/<Package>.tar.xz` y añade su línea a `<Root>/SHA-256.txt`. El `FullName` de cada fuente falsa es `<nombre sin extensión> New`.

- [ ] **Step 1: Añadir los helpers de release falso**

Al final de `tests/TestHelpers.ps1`:

```powershell
function Get-SystemTar {
    # Git for Windows puts GNU tar first in PATH, which cannot read Windows paths; use the bsdtar shipped with Windows.
    if ($IsWindows) { [System.IO.Path]::Combine($env:SystemRoot, 'System32', 'tar.exe') } else { 'tar' }
}

function New-FakeNerdFontRelease {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Package,
        [Parameter(Mandatory)][string[]]$FontName,
        [string]$Version = 'Version 1.000;Nerd Fonts 3.5.1'
    )
    $source = Join-Path $Root "$Package-src"
    foreach ($name in $FontName) {
        New-TestFont -Path (Join-Path $source $name) -FullName "$([System.IO.Path]::GetFileNameWithoutExtension($name)) New" -Version $Version | Out-Null
    }
    $archive = Join-Path $Root "$Package.tar.xz"
    & (Get-SystemTar) -cJf $archive -C $source .
    if ($LASTEXITCODE -ne 0) { throw "tar could not create $archive" }
    $hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    Add-Content -LiteralPath (Join-Path $Root 'SHA-256.txt') -Value "$hash  $Package.tar.xz"
    $Root
}
```

- [ ] **Step 2: Escribir los tests que fallan**

Añade a `tests/Fonts.Tests.ps1`:

```powershell
Describe 'Save-NerdFontRelease' {
    BeforeAll {
        $script:Release = New-FakeNerdFontRelease -Root (Join-Path $TestDrive 'release') -Package 'JetBrainsMono' -FontName 'JetBrainsMonoNerdFontMono-Regular.ttf', 'JetBrainsMonoNerdFont-Bold.ttf'
        New-FakeNerdFontRelease -Root $script:Release -Package 'Hack' -FontName 'HackNerdFont-Regular.ttf' | Out-Null
    }

    BeforeEach {
        Mock Invoke-NerdFontDownload { Copy-Item -LiteralPath (Join-Path $script:Release ($Uri -split '/')[-1]) -Destination $OutFile }
        $work = Join-Path $TestDrive "work-$([guid]::NewGuid())"
        [System.IO.Directory]::CreateDirectory($work) | Out-Null
    }

    It 'returns the extracted fonts after checking the SHA-256' {
        $files = @(Save-NerdFontRelease -Package 'JetBrainsMono' -Version '3.5.1' -Destination $work)
        $files.Count | Should -Be 2
        [System.IO.Path]::GetFileName($files[0]) | Should -Be 'JetBrainsMonoNerdFont-Bold.ttf'
        $files | ForEach-Object { $_ | Should -Exist }
        (Read-FontInfo -Path $files[1]).FullName | Should -Be 'JetBrainsMonoNerdFontMono-Regular New'
        Should -Invoke Invoke-NerdFontDownload -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/JetBrainsMono.tar.xz' }
        Should -Invoke Invoke-NerdFontDownload -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/SHA-256.txt' }
    }

    It 'downloads SHA-256.txt once per destination' {
        Save-NerdFontRelease -Package 'JetBrainsMono' -Version '3.5.1' -Destination $work | Out-Null
        Save-NerdFontRelease -Package 'Hack' -Version '3.5.1' -Destination $work | Out-Null
        Should -Invoke Invoke-NerdFontDownload -Times 1 -Exactly -ParameterFilter { $Uri -like '*/SHA-256.txt' }
    }

    It 'refuses an archive whose checksum does not match' {
        Mock Invoke-NerdFontDownload {
            if ($Uri -like '*/SHA-256.txt') { Set-Content -LiteralPath $OutFile -Value "$('0' * 64)  JetBrainsMono.tar.xz" }
            else { Copy-Item -LiteralPath (Join-Path $script:Release 'JetBrainsMono.tar.xz') -Destination $OutFile }
        }
        { Save-NerdFontRelease -Package 'JetBrainsMono' -Version '3.5.1' -Destination $work } | Should -Throw '*Checksum mismatch*'
        Join-Path $work 'JetBrainsMono' | Should -Not -Exist
    }

    It 'fails when the package is not in SHA-256.txt' {
        { Save-NerdFontRelease -Package 'Nope' -Version '3.5.1' -Destination $work } | Should -Throw '*no entry for Nope.tar.xz*'
    }

    It 'lets download errors through' {
        Mock Invoke-NerdFontDownload { throw 'network down' }
        { Save-NerdFontRelease -Package 'Hack' -Version '3.5.1' -Destination $work } | Should -Throw '*network down*'
    }
}
```

- [ ] **Step 3: Ejecutar y ver que fallan**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Fonts.Tests.ps1 -Output Detailed`
Expected: FAIL (Mock no encuentra `Invoke-NerdFontDownload`; `Save-NerdFontRelease` no reconocido).

- [ ] **Step 4: Implementar**

Crea `src/Private/Invoke-NerdFontDownload.ps1`:

```powershell
function Invoke-NerdFontDownload {
    # The only network access of the module; tests replace it.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter(Mandatory)]
        [string]$OutFile
    )

    Invoke-WebRequest -Uri $Uri -OutFile $OutFile -ErrorAction Stop
}
```

Crea `src/Private/Save-NerdFontRelease.ps1`:

```powershell
function Save-NerdFontRelease {
    <#
    .SYNOPSIS
        Downloads a Nerd Fonts release package, checks its SHA-256 and extracts its font files.
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Package,

        [Parameter(Mandatory)]
        [string]$Version,

        [Parameter(Mandatory)]
        [string]$Destination,

        [string]$BaseUri = 'https://github.com/ryanoasis/nerd-fonts/releases/download'
    )

    $release = "$BaseUri/v$Version"
    $archiveName = "$Package.tar.xz"
    $sums = [System.IO.Path]::Combine($Destination, 'SHA-256.txt')
    if (-not [System.IO.File]::Exists($sums)) { Invoke-NerdFontDownload -Uri "$release/SHA-256.txt" -OutFile $sums }
    $expected = $null
    foreach ($line in [System.IO.File]::ReadAllLines($sums)) {
        if ($line -match '^([0-9a-fA-F]{64})\s+\*?(.+?)\s*$' -and $Matches[2] -ceq $archiveName) {
            $expected = $Matches[1]
            break
        }
    }
    if (-not $expected) { throw "SHA-256.txt of Nerd Fonts $Version has no entry for $archiveName." }

    $archive = [System.IO.Path]::Combine($Destination, $archiveName)
    Invoke-NerdFontDownload -Uri "$release/$archiveName" -OutFile $archive
    $actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
    if ($actual -ne $expected) { throw "Checksum mismatch for ${archiveName}: expected $expected, got $actual." }

    $extract = [System.IO.Path]::Combine($Destination, $Package)
    [System.IO.Directory]::CreateDirectory($extract) | Out-Null
    $tar = if ($IsWindows) { [System.IO.Path]::Combine($env:SystemRoot, 'System32', 'tar.exe') } else { 'tar' }
    & $tar -xf $archive -C $extract
    if ($LASTEXITCODE -ne 0) { throw "tar could not extract $archiveName (exit code $LASTEXITCODE)." }
    Get-ChildItem -LiteralPath $extract -Recurse -File |
        Where-Object { $_.Extension -in '.ttf', '.otf' } |
        Sort-Object -Property Name |
        ForEach-Object { $_.FullName }
}
```

- [ ] **Step 5: Ejecutar y ver que pasan**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Fonts.Tests.ps1 -Output Detailed`
Expected: PASS.

- [ ] **Step 6: Suite completa y commit**

Run: `./build.ps1 -Task Test` → 0 fallos.

```powershell
git add src/Private/Invoke-NerdFontDownload.ps1 src/Private/Save-NerdFontRelease.ps1 tests/Fonts.Tests.ps1 tests/TestHelpers.ps1
git commit -m "Download and verify Nerd Fonts release packages" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 5: Instalar archivos de fuente por plataforma

**Files:**
- Create: `src/Private/Register-FontResource.ps1`, `src/Private/Invoke-FontCacheRefresh.ps1`, `src/Private/Install-NerdFontFile.ps1`
- Test: `tests/Fonts.Tests.ps1`

**Interfaces:**
- Consumes: `Read-FontInfo` (Tarea 2).
- Produces: `Register-FontResource -Path <string[]>` (Windows: `AddFontResourceW` por archivo y un solo `WM_FONTCHANGE`; lanza error si Windows rechaza un archivo).
- Produces: `Invoke-FontCacheRefresh -Directory <string>` → `[bool]` (`$false` si no hay `fc-cache`).
- Produces: `Install-NerdFontFile -SourceFile <string[]> -TargetDirectory <string> -Platform <Windows|Linux|MacOS> [-InstalledFile <string[]>] [-UpdateOnly] [-RegistryPath <string>]` → `[pscustomobject]@{ Added = List[string] (rutas nuevas); Replaced = [int]; Renamed = [int]; Failed = List[string] (nombres) }`.
  - Un origen cuyo nombre (sin distinguir mayúsculas) está en `-InstalledFile` reemplaza **ese** archivo, esté donde esté.
  - Si no está instalado: con `-UpdateOnly` se omite; si no, se copia a `-TargetDirectory` y, en Windows, se registra en `-RegistryPath` (`"<FullName> (TrueType|OpenType)" = <ruta>`) y se carga con `Register-FontResource` (una llamada al final con todos los añadidos).
  - Windows, archivo en uso: renombrar a `<archivo>.<yyyyMMddHHmmss UTC>.old-nerdfont`, copiar el nuevo, `Renamed++`; si esa copia falla, devolver el original a su sitio y `Failed`. En Linux/macOS un fallo de copia va directo a `Failed`.
  - `fc-cache` **no** se llama aquí (lo hace el comando una vez al final).

- [ ] **Step 1: Escribir los tests que fallan**

Añade a `tests/Fonts.Tests.ps1`:

```powershell
Describe 'Invoke-FontCacheRefresh' {
    It 'returns whether fc-cache ran' {
        $expected = [bool](Get-Command -Name 'fc-cache' -CommandType Application -ErrorAction Ignore)
        Invoke-FontCacheRefresh -Directory $TestDrive | Should -Be $expected
    }
}

Describe 'Register-FontResource' -Skip:(-not $IsWindows) {
    It 'fails for a file Windows cannot load' {
        $path = Join-Path $TestDrive 'not-a-font.ttf'
        [System.IO.File]::WriteAllText($path, 'nope')
        { Register-FontResource -Path $path } | Should -Throw '*could not load*'
    }
}

Describe 'Install-NerdFontFile' {
    BeforeAll {
        $registryPath = 'HKCU:\Software\TerminalGlyphs.Tests\Fonts'
        function New-Case {
            $case = Join-Path $TestDrive "case-$([guid]::NewGuid())"
            $new = Join-Path $case 'new'
            [pscustomobject]@{
                Root   = $case
                Fonts  = Join-Path $case 'fonts'
                Source = @(
                    New-TestFont -Path (Join-Path $new 'TestNerdFontMono-Regular.ttf') -FullName 'Test NFM Regular'
                    New-TestFont -Path (Join-Path $new 'TestNerdFontMono-Bold.otf') -FullName 'Test NFM Bold'
                )
            }
        }
    }

    BeforeEach {
        Mock Register-FontResource { }
    }

    AfterAll {
        if ($IsWindows) { Remove-Item -LiteralPath 'HKCU:\Software\TerminalGlyphs.Tests' -Recurse -Force -ErrorAction Ignore }
    }

    It 'adds missing files on <Platform> without touching the registry' -ForEach @(@{ Platform = 'Linux' }, @{ Platform = 'MacOS' }) {
        $case = New-Case
        $result = Install-NerdFontFile -SourceFile $case.Source -TargetDirectory $case.Fonts -Platform $Platform
        $result.Added.Count | Should -Be 2
        Join-Path $case.Fonts 'TestNerdFontMono-Regular.ttf' | Should -Exist
        Should -Invoke Register-FontResource -Times 0
    }

    It 'registers added files for the current Windows user and loads them once' -Skip:(-not $IsWindows) {
        $case = New-Case
        $result = Install-NerdFontFile -SourceFile $case.Source -TargetDirectory $case.Fonts -Platform Windows -RegistryPath $registryPath
        $result.Added.Count | Should -Be 2
        $key = Get-Item -LiteralPath $registryPath
        $key.GetValue('Test NFM Regular (TrueType)') | Should -Be (Join-Path $case.Fonts 'TestNerdFontMono-Regular.ttf')
        $key.GetValue('Test NFM Bold (OpenType)') | Should -Be (Join-Path $case.Fonts 'TestNerdFontMono-Bold.otf')
        Should -Invoke Register-FontResource -Times 1 -Exactly -ParameterFilter { $Path.Count -eq 2 }
    }

    It 'with -UpdateOnly, skips files that are not installed' {
        $case = New-Case
        $result = Install-NerdFontFile -SourceFile $case.Source -TargetDirectory $case.Fonts -Platform Windows -UpdateOnly -RegistryPath $registryPath
        $result.Added.Count + $result.Replaced | Should -Be 0
        $case.Fonts | Should -Not -Exist
    }

    It 'replaces installed files where they are, matching names without case' {
        $case = New-Case
        $installed = New-TestFont -Path (Join-Path $case.Root 'elsewhere' 'testnerdfontmono-regular.ttf') -FullName 'Old'
        $result = Install-NerdFontFile -SourceFile $case.Source -TargetDirectory $case.Fonts -Platform Linux -InstalledFile $installed -UpdateOnly
        $result.Replaced | Should -Be 1
        (Read-FontInfo -Path $installed).FullName | Should -Be 'Test NFM Regular'
        $case.Fonts | Should -Not -Exist
    }

    It 'on Windows, renames a file in use and copies the new one' {
        $case = New-Case
        $installed = New-TestFont -Path (Join-Path $case.Fonts 'TestNerdFontMono-Regular.ttf') -FullName 'Old'
        $script:CopyCalls = 0
        Mock Copy-Item {
            $script:CopyCalls++
            if ($script:CopyCalls -eq 1) { throw [System.IO.IOException]::new('The file is in use.') }
            [System.IO.File]::Copy($LiteralPath, $Destination, $true)
        }
        $result = Install-NerdFontFile -SourceFile $case.Source[0] -TargetDirectory $case.Fonts -Platform Windows -InstalledFile $installed -UpdateOnly
        $result.Renamed | Should -Be 1
        (Read-FontInfo -Path $installed).FullName | Should -Be 'Test NFM Regular'
        $stale = @(Get-ChildItem -LiteralPath $case.Fonts -Filter '*.old-nerdfont')
        $stale.Count | Should -Be 1
        $stale[0].Name | Should -Match '^TestNerdFontMono-Regular\.ttf\.\d{14}\.old-nerdfont$'
        (Read-FontInfo -Path $stale[0].FullName).FullName | Should -Be 'Old'
    }

    It 'on Windows, puts the original back when the new copy fails' {
        $case = New-Case
        $installed = New-TestFont -Path (Join-Path $case.Fonts 'TestNerdFontMono-Regular.ttf') -FullName 'Old'
        Mock Copy-Item { throw [System.IO.IOException]::new('The file is in use.') }
        $result = Install-NerdFontFile -SourceFile $case.Source[0] -TargetDirectory $case.Fonts -Platform Windows -InstalledFile $installed -UpdateOnly
        $result.Failed | Should -Be @('TestNerdFontMono-Regular.ttf')
        (Read-FontInfo -Path $installed).FullName | Should -Be 'Old'
        @(Get-ChildItem -LiteralPath $case.Fonts -Filter '*.old-nerdfont').Count | Should -Be 0
    }

    It 'on <Platform>, reports a failed copy without renaming' -ForEach @(@{ Platform = 'Linux' }, @{ Platform = 'MacOS' }) {
        $case = New-Case
        $installed = New-TestFont -Path (Join-Path $case.Fonts 'TestNerdFontMono-Regular.ttf') -FullName 'Old'
        Mock Copy-Item { throw [System.IO.IOException]::new('Permission denied.') }
        $result = Install-NerdFontFile -SourceFile $case.Source[0] -TargetDirectory $case.Fonts -Platform $Platform -InstalledFile $installed -UpdateOnly
        $result.Failed.Count | Should -Be 1
        @(Get-ChildItem -LiteralPath $case.Fonts -Filter '*.old-nerdfont').Count | Should -Be 0
    }
}
```

- [ ] **Step 2: Ejecutar y ver que fallan**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Fonts.Tests.ps1 -Output Detailed`
Expected: FAIL (funciones no reconocidas).

- [ ] **Step 3: Implementar**

Crea `src/Private/Register-FontResource.ps1`:

```powershell
function Register-FontResource {
    # Loads newly copied fonts into the current Windows session, so they can be used without signing out.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Path
    )

    $api = 'TerminalGlyphs.FontApi' -as [type]
    if (-not $api) {
        Add-Type -Namespace 'TerminalGlyphs' -Name 'FontApi' -MemberDefinition @'
[DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
public static extern int AddFontResourceW(string lpFileName);
[DllImport("user32.dll", CharSet = CharSet.Unicode)]
public static extern IntPtr SendMessageTimeoutW(IntPtr hWnd, uint Msg, UIntPtr wParam, IntPtr lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
        $api = 'TerminalGlyphs.FontApi' -as [type]
    }
    foreach ($file in $Path) {
        if ($api::AddFontResourceW($file) -eq 0) { throw "Windows could not load the font $file." }
    }
    $result = [UIntPtr]::Zero
    # HWND_BROADCAST, WM_FONTCHANGE, SMTO_ABORTIFHUNG, 1 second.
    [void]$api::SendMessageTimeoutW([IntPtr]0xFFFF, 0x001D, [UIntPtr]::Zero, [IntPtr]::Zero, 0x0002, 1000, [ref]$result)
}
```

Crea `src/Private/Invoke-FontCacheRefresh.ps1`:

```powershell
function Invoke-FontCacheRefresh {
    # Rebuilds the fontconfig cache on Linux. Returns $false when fc-cache is not installed or fails.
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Directory
    )

    $fcCache = Get-Command -Name 'fc-cache' -CommandType Application -ErrorAction Ignore | Select-Object -First 1
    if (-not $fcCache) { return $false }
    & $fcCache.Source -f $Directory | Out-Null
    $LASTEXITCODE -eq 0
}
```

Crea `src/Private/Install-NerdFontFile.ps1`:

```powershell
function Install-NerdFontFile {
    <#
    .SYNOPSIS
        Copies Nerd Font files into the user's font folder, replacing the installed copies.
    .DESCRIPTION
        Each source file replaces the installed file with the same name (-InstalledFile), wherever it is. Files that
        are not installed are skipped with -UpdateOnly; otherwise they are copied to -TargetDirectory and, on Windows,
        registered for the current user and loaded. On Windows, an installed file that is in use is renamed to
        <name>.<yyyyMMddHHmmss>.old-nerdfont (UTC) before copying; Remove-StaleFontFile deletes it after a restart.
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$SourceFile,

        [Parameter(Mandatory)]
        [string]$TargetDirectory,

        [Parameter(Mandatory)]
        [ValidateSet('Windows', 'Linux', 'MacOS')]
        [string]$Platform,

        [string[]]$InstalledFile = @(),

        [switch]$UpdateOnly,

        [string]$RegistryPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    )

    $installed = @{}
    foreach ($path in $InstalledFile) { $installed[[System.IO.Path]::GetFileName($path)] = $path }
    $result = [pscustomobject]@{
        Added    = [System.Collections.Generic.List[string]]::new()
        Replaced = 0
        Renamed  = 0
        Failed   = [System.Collections.Generic.List[string]]::new()
    }

    foreach ($source in $SourceFile) {
        $name = [System.IO.Path]::GetFileName($source)
        if ($installed.ContainsKey($name)) {
            $target = $installed[$name]
            try {
                Copy-Item -LiteralPath $source -Destination $target -Force -ErrorAction Stop
                $result.Replaced++
                continue
            } catch {
                if ($Platform -ne 'Windows') {
                    $result.Failed.Add($name)
                    continue
                }
            }
            # Windows keeps fonts in use open: it allows renaming them but not overwriting them.
            $stale = '{0}.{1}.old-nerdfont' -f $target, [DateTime]::UtcNow.ToString('yyyyMMddHHmmss', [cultureinfo]::InvariantCulture)
            try {
                Move-Item -LiteralPath $target -Destination $stale -ErrorAction Stop
            } catch {
                $result.Failed.Add($name)
                continue
            }
            try {
                Copy-Item -LiteralPath $source -Destination $target -ErrorAction Stop
                $result.Renamed++
            } catch {
                $result.Failed.Add($name)
                try {
                    Move-Item -LiteralPath $stale -Destination $target -Force -ErrorAction Stop
                } catch {
                    Write-Warning -Message "TerminalGlyphs: $name could not be restored now; it will be restored the next time you run Install-TerminalGlyphSetup."
                }
            }
            continue
        }
        if ($UpdateOnly) { continue }

        [System.IO.Directory]::CreateDirectory($TargetDirectory) | Out-Null
        $target = [System.IO.Path]::Combine($TargetDirectory, $name)
        try {
            Copy-Item -LiteralPath $source -Destination $target -Force -ErrorAction Stop
        } catch {
            $result.Failed.Add($name)
            continue
        }
        if ($Platform -eq 'Windows') {
            $info = Read-FontInfo -Path $target
            $label = if ($info) { $info.FullName } else { [System.IO.Path]::GetFileNameWithoutExtension($target) }
            $kind = if ([System.IO.Path]::GetExtension($target) -eq '.otf') { 'OpenType' } else { 'TrueType' }
            if (-not (Test-Path -LiteralPath $RegistryPath)) { New-Item -Path $RegistryPath -Force | Out-Null }
            New-ItemProperty -LiteralPath $RegistryPath -Name "$label ($kind)" -Value $target -PropertyType String -Force | Out-Null
        }
        $result.Added.Add($target)
    }

    if ($Platform -eq 'Windows' -and $result.Added.Count -gt 0) { Register-FontResource -Path $result.Added.ToArray() }
    $result
}
```

- [ ] **Step 4: Ejecutar y ver que pasan**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Fonts.Tests.ps1 -Output Detailed`
Expected: PASS (los tests de registro y `Register-FontResource` solo corren en Windows).

- [ ] **Step 5: Suite completa y commit**

Run: `./build.ps1 -Task Test` → 0 fallos.

```powershell
git add src/Private/Register-FontResource.ps1 src/Private/Invoke-FontCacheRefresh.ps1 src/Private/Install-NerdFontFile.ps1 tests/Fonts.Tests.ps1
git commit -m "Install Nerd Font files for the current user" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 6: Limpiar fuentes renombradas solo tras un reinicio

**Files:**
- Create: `src/Private/Remove-StaleFontFile.ps1`
- Test: `tests/Fonts.Tests.ps1`

**Interfaces:**
- Produces: `Remove-StaleFontFile -FontDirectory <string> [-BootTime <datetime>] [-WhatIf] [-Confirm]` → `[pscustomobject]@{ Removed = [int]; Restored = [int]; Pending = [int] }`. `-BootTime` por defecto: `(Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime`. Solo considera `*.<14 dígitos>.old-nerdfont` (los demás se ignoran). Si falta el original → lo restaura (el más reciente primero). Si el arranque (UTC) es posterior a la marca → lo borra; si no → `Pending`. Un borrado que falla cuenta como `Pending`. `ShouldProcess` por archivo.

- [ ] **Step 1: Escribir los tests que fallan**

Añade a `tests/Fonts.Tests.ps1`:

```powershell
Describe 'Remove-StaleFontFile' {
    BeforeAll {
        function New-StaleCase([datetime[]]$RenamedAt, [switch]$NoOriginal) {
            $dir = Join-Path $TestDrive "stale-$([guid]::NewGuid())"
            [System.IO.Directory]::CreateDirectory($dir) | Out-Null
            if (-not $NoOriginal) { [System.IO.File]::WriteAllText((Join-Path $dir 'A.ttf'), 'new') }
            foreach ($time in $RenamedAt) {
                $stamp = $time.ToUniversalTime().ToString('yyyyMMddHHmmss', [cultureinfo]::InvariantCulture)
                [System.IO.File]::WriteAllText((Join-Path $dir "A.ttf.$stamp.old-nerdfont"), "old $stamp")
            }
            $dir
        }
        $now = [DateTime]::UtcNow
    }

    It 'deletes a renamed file once Windows restarted after the rename' {
        $dir = New-StaleCase -RenamedAt $now.AddHours(-2)
        $result = Remove-StaleFontFile -FontDirectory $dir -BootTime $now.AddHours(-1)
        $result.Removed | Should -Be 1
        $result.Pending | Should -Be 0
        @(Get-ChildItem -LiteralPath $dir -Filter '*.old-nerdfont').Count | Should -Be 0
    }

    It 'keeps every renamed copy until Windows restarts' {
        $dir = New-StaleCase -RenamedAt $now.AddHours(-2), $now.AddMinutes(-5)
        $result = Remove-StaleFontFile -FontDirectory $dir -BootTime $now.AddHours(-3)
        $result.Pending | Should -Be 2
        $result.Removed | Should -Be 0
        @(Get-ChildItem -LiteralPath $dir -Filter '*.old-nerdfont').Count | Should -Be 2
    }

    It 'restores the newest renamed copy when the original is missing' {
        $dir = New-StaleCase -RenamedAt $now.AddHours(-2), $now.AddMinutes(-5) -NoOriginal
        $result = Remove-StaleFontFile -FontDirectory $dir -BootTime $now.AddHours(-3)
        $result.Restored | Should -Be 1
        $result.Pending | Should -Be 1
        $newest = $now.AddMinutes(-5).ToString('yyyyMMddHHmmss', [cultureinfo]::InvariantCulture)
        [System.IO.File]::ReadAllText((Join-Path $dir 'A.ttf')) | Should -Be "old $newest"
    }

    It 'ignores files without a timestamp' {
        $dir = New-StaleCase -RenamedAt @()
        [System.IO.File]::WriteAllText((Join-Path $dir 'A.ttf.old-nerdfont'), 'legacy')
        $result = Remove-StaleFontFile -FontDirectory $dir -BootTime $now
        $result.Removed + $result.Restored + $result.Pending | Should -Be 0
        Join-Path $dir 'A.ttf.old-nerdfont' | Should -Exist
    }

    It 'changes nothing with -WhatIf' {
        $dir = New-StaleCase -RenamedAt $now.AddHours(-2)
        Remove-StaleFontFile -FontDirectory $dir -BootTime $now -WhatIf | Out-Null
        @(Get-ChildItem -LiteralPath $dir -Filter '*.old-nerdfont').Count | Should -Be 1
    }

    It 'returns zeros for a missing folder' {
        $result = Remove-StaleFontFile -FontDirectory (Join-Path $TestDrive 'none') -BootTime $now
        $result.Removed + $result.Restored + $result.Pending | Should -Be 0
    }

    It 'reads the boot time from Windows by default' -Skip:(-not $IsWindows) {
        $dir = New-StaleCase -RenamedAt $now.AddYears(-30)
        (Remove-StaleFontFile -FontDirectory $dir).Removed | Should -Be 1
    }
}
```

- [ ] **Step 2: Ejecutar y ver que fallan**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Fonts.Tests.ps1 -Output Detailed`
Expected: FAIL ("Remove-StaleFontFile is not recognized").

- [ ] **Step 3: Implementar**

Crea `src/Private/Remove-StaleFontFile.ps1`:

```powershell
function Remove-StaleFontFile {
    <#
    .SYNOPSIS
        Deletes font files renamed by Install-NerdFontFile once Windows has restarted.
    .DESCRIPTION
        The Windows font cache keeps using a renamed font file until the next restart; deleting it earlier makes
        apps fall back to other fonts. A renamed file whose original is missing is restored instead.
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$FontDirectory,

        [datetime]$BootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    )

    $result = [pscustomobject]@{ Removed = 0; Restored = 0; Pending = 0 }
    if (-not [System.IO.Directory]::Exists($FontDirectory)) { return $result }
    $boot = $BootTime.ToUniversalTime()
    $styles = [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal
    $files = Get-ChildItem -LiteralPath $FontDirectory -Filter '*.old-nerdfont' -File -ErrorAction Ignore | Sort-Object -Property Name -Descending
    foreach ($file in $files) {
        if ($file.Name -notmatch '^(?<original>.+)\.(?<stamp>\d{14})\.old-nerdfont$') { continue }
        $originalName = $Matches['original']
        $renamedAt = [datetime]::MinValue
        if (-not [datetime]::TryParseExact($Matches['stamp'], 'yyyyMMddHHmmss', [cultureinfo]::InvariantCulture, $styles, [ref]$renamedAt)) { continue }
        $original = [System.IO.Path]::Combine($file.DirectoryName, $originalName)

        if (-not [System.IO.File]::Exists($original)) {
            if ($PSCmdlet.ShouldProcess($file.FullName, "Restore missing font $originalName")) {
                try {
                    Move-Item -LiteralPath $file.FullName -Destination $original -ErrorAction Stop
                    $result.Restored++
                } catch {
                    $result.Pending++
                }
            }
            continue
        }
        if ($boot -le $renamedAt) {
            $result.Pending++
            continue
        }
        if ($PSCmdlet.ShouldProcess($file.FullName, 'Delete replaced font file')) {
            try {
                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                $result.Removed++
            } catch {
                $result.Pending++
            }
        }
    }
    $result
}
```

- [ ] **Step 4: Ejecutar y ver que pasan**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Fonts.Tests.ps1 -Output Detailed`
Expected: PASS.

- [ ] **Step 5: Suite completa y commit**

Run: `./build.ps1 -Task Test` → 0 fallos.

```powershell
git add src/Private/Remove-StaleFontFile.ps1 tests/Fonts.Tests.ps1
git commit -m "Delete replaced font files only after a restart" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 7: Editar el perfil

**Files:**
- Create: `src/Private/Update-ProfileImport.ps1`, `tests/Profile.Tests.ps1`

**Interfaces:**
- Produces: `Update-ProfileImport [-Path <string[]>] [-WhatIf] [-Confirm]` → `[pscustomobject]@{ Path = [string]; Status = 'OK'|'Unchanged'|'Skipped'; Detail = [string] }`.
  - `-Path` por defecto: `$PROFILE.CurrentUserCurrentHost`, `CurrentUserAllHosts`, `AllUsersCurrentHost`, `AllUsersAllHosts` (se descartan nulos; si no queda ninguno, error).
  - Destino: el primero que exista y contenga una importación (no comentada) de `Terminal-Icons` o `TerminalGlyphs`; si ninguno, el primero de la lista.
  - Ya importa TerminalGlyphs → `Unchanged` (si además importa Terminal-Icons, el detalle pide quitar esa línea).
  - Importa Terminal-Icons → se cambia **solo el nombre del módulo** en cada línea `Import-Module [-Name] ['"]Terminal-Icons['"]`, conservando indentación, comillas y el resto de la línea.
  - Si no → añade al final `# Added by TerminalGlyphs` + `Import-Module -Name TerminalGlyphs` con el salto de línea del archivo.
  - Antes de escribir un archivo existente: respaldo `<perfil>.terminalglyphs-<yyyyMMddHHmmss>.bak` (vía `[System.IO.File]::Replace`). Conserva codificación con o sin BOM (UTF-8, UTF-16) y CRLF/LF. Perfil nuevo: crea la carpeta, UTF-8 sin BOM, sin respaldo.
  - `ShouldProcess` una vez; con `-WhatIf` → `Skipped`, sin escribir nada.

- [ ] **Step 1: Escribir los tests que fallan**

Crea `tests/Profile.Tests.ps1`:

```powershell
BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    . (Join-Path $script:RepoRoot 'src' 'Private' 'Update-ProfileImport.ps1')
    function New-Profile([string]$Content, [System.Text.Encoding]$Encoding = [System.Text.UTF8Encoding]::new($false)) {
        $path = Join-Path $TestDrive ([guid]::NewGuid()) 'profile.ps1'
        [System.IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null
        [System.IO.File]::WriteAllText($path, $Content, $Encoding)
        $path
    }
    function Get-Backup([string]$Path) { @(Get-ChildItem -LiteralPath (Split-Path -Parent $Path) -Filter '*.terminalglyphs-*.bak') }
}

Describe 'Update-ProfileImport' {
    It 'replaces the Terminal-Icons import and keeps a backup' {
        $original = "Invoke-Expression (&starship init powershell)`nImport-Module -Name Terminal-Icons`nfunction x { exit }`n"
        $path = New-Profile $original
        $result = Update-ProfileImport -Path $path
        $result.Status | Should -Be 'OK'
        $result.Path | Should -Be $path
        [System.IO.File]::ReadAllText($path) | Should -BeExactly "Invoke-Expression (&starship init powershell)`nImport-Module -Name TerminalGlyphs`nfunction x { exit }`n"
        $backup = Get-Backup $path
        $backup.Count | Should -Be 1
        $backup[0].Name | Should -Match '^profile\.ps1\.terminalglyphs-\d{14}\.bak$'
        [System.IO.File]::ReadAllText($backup[0].FullName) | Should -BeExactly $original
    }

    It 'changes only the module name in <Case>' -ForEach @(
        @{ Case = 'an indented line with quotes and parameters'; Line = "    Import-Module -Name 'Terminal-Icons' -ErrorAction SilentlyContinue"; Expected = "    Import-Module -Name 'TerminalGlyphs' -ErrorAction SilentlyContinue" }
        @{ Case = 'a positional name in double quotes'; Line = 'Import-Module "Terminal-Icons"'; Expected = 'Import-Module "TerminalGlyphs"' }
        @{ Case = 'another casing'; Line = 'import-module terminal-icons'; Expected = 'import-module TerminalGlyphs' }
    ) {
        $path = New-Profile "if (`$true) {`n$Line`n}`n"
        Update-ProfileImport -Path $path | Out-Null
        [System.IO.File]::ReadAllText($path) | Should -BeExactly "if (`$true) {`n$Expected`n}`n"
    }

    It 'appends the import when there is none, ignoring comments and similar names' {
        $path = New-Profile "# Import-Module Terminal-Icons`nImport-Module Terminal-IconsExtra`n"
        Update-ProfileImport -Path $path | Out-Null
        [System.IO.File]::ReadAllText($path) | Should -BeExactly "# Import-Module Terminal-Icons`nImport-Module Terminal-IconsExtra`n# Added by TerminalGlyphs`nImport-Module -Name TerminalGlyphs`n"
    }

    It 'adds a line break before appending to a file without a final newline' {
        $path = New-Profile 'Set-Alias ll ls'
        Update-ProfileImport -Path $path | Out-Null
        [System.IO.File]::ReadAllText($path) | Should -BeExactly "Set-Alias ll ls$([Environment]::NewLine)# Added by TerminalGlyphs$([Environment]::NewLine)Import-Module -Name TerminalGlyphs$([Environment]::NewLine)"
    }

    It 'is idempotent' {
        $path = New-Profile "Import-Module Terminal-Icons`n"
        Update-ProfileImport -Path $path | Out-Null
        $second = Update-ProfileImport -Path $path
        $second.Status | Should -Be 'Unchanged'
        (Get-Backup $path).Count | Should -Be 1
    }

    It 'asks to remove Terminal-Icons when both modules are imported' {
        $path = New-Profile "Import-Module TerminalGlyphs`nImport-Module Terminal-Icons`n"
        $result = Update-ProfileImport -Path $path
        $result.Status | Should -Be 'Unchanged'
        $result.Detail | Should -Match 'remove.*Terminal-Icons'
    }

    It 'creates the profile and its folder when they do not exist' {
        $path = Join-Path $TestDrive 'OneDrive' 'Documents' 'PowerShell' 'profile.ps1'
        $result = Update-ProfileImport -Path $path, (Join-Path $TestDrive 'other.ps1')
        $result.Status | Should -Be 'OK'
        [System.IO.File]::ReadAllText($path) | Should -BeExactly "# Added by TerminalGlyphs$([Environment]::NewLine)Import-Module -Name TerminalGlyphs$([Environment]::NewLine)"
        [System.IO.File]::ReadAllBytes($path)[0] | Should -Not -Be 0xEF
        (Get-Backup $path).Count | Should -Be 0
    }

    It 'edits the first profile that already imports a module' {
        $first = New-Profile "Set-Alias ll ls`n"
        $second = New-Profile "Import-Module Terminal-Icons`n"
        $result = Update-ProfileImport -Path $first, $second
        $result.Path | Should -Be $second
        [System.IO.File]::ReadAllText($first) | Should -BeExactly "Set-Alias ll ls`n"
    }

    It 'keeps <Case>' -ForEach @(
        @{ Case = 'UTF-8 with BOM and CRLF'; Encoding = [System.Text.UTF8Encoding]::new($true); Newline = "`r`n"; Preamble = @(0xEF, 0xBB, 0xBF) }
        @{ Case = 'UTF-8 without BOM and LF'; Encoding = [System.Text.UTF8Encoding]::new($false); Newline = "`n"; Preamble = @() }
        @{ Case = 'UTF-16 LE with BOM'; Encoding = [System.Text.Encoding]::Unicode; Newline = "`r`n"; Preamble = @(0xFF, 0xFE) }
    ) {
        $path = New-Profile "Set-Alias ll ls$($Newline)Import-Module Terminal-Icons$Newline" $Encoding
        Update-ProfileImport -Path $path | Out-Null
        $bytes = [System.IO.File]::ReadAllBytes($path)
        if ($Preamble.Count -gt 0) { $bytes[0..($Preamble.Count - 1)] | Should -Be $Preamble }
        else { $bytes[0] | Should -Be ([byte][char]'S') }
        [System.IO.File]::ReadAllText($path) | Should -BeExactly "Set-Alias ll ls$($Newline)Import-Module TerminalGlyphs$Newline"
    }

    It 'appends with the newline style of the file' {
        $path = New-Profile "Set-Alias ll ls`r`n"
        Update-ProfileImport -Path $path | Out-Null
        [System.IO.File]::ReadAllText($path) | Should -BeExactly "Set-Alias ll ls`r`n# Added by TerminalGlyphs`r`nImport-Module -Name TerminalGlyphs`r`n"
    }

    It 'changes nothing with -WhatIf' {
        $path = New-Profile "Import-Module Terminal-Icons`n"
        $result = Update-ProfileImport -Path $path -WhatIf
        $result.Status | Should -Be 'Skipped'
        [System.IO.File]::ReadAllText($path) | Should -BeExactly "Import-Module Terminal-Icons`n"
        (Get-Backup $path).Count | Should -Be 0
        @(Get-ChildItem -LiteralPath (Split-Path -Parent $path) -Filter '*.tmp').Count | Should -Be 0
    }
}
```

- [ ] **Step 2: Ejecutar y ver que fallan**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Profile.Tests.ps1 -Output Detailed`
Expected: FAIL (no existe `src/Private/Update-ProfileImport.ps1`).

- [ ] **Step 3: Implementar**

Crea `src/Private/Update-ProfileImport.ps1`:

```powershell
function Update-ProfileImport {
    <#
    .SYNOPSIS
        Makes a PowerShell profile import TerminalGlyphs instead of Terminal-Icons.
    .DESCRIPTION
        Edits the first profile in -Path that already imports Terminal-Icons or TerminalGlyphs, or else the first
        profile in -Path. Keeps a backup, the file encoding and the line endings, and writes atomically.
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string[]]$Path = @($PROFILE.CurrentUserCurrentHost, $PROFILE.CurrentUserAllHosts, $PROFILE.AllUsersCurrentHost, $PROFILE.AllUsersAllHosts)
    )

    $oldImport = '(?im)^(?<lead>[ \t]*Import-Module[ \t]+(?:-Name[ \t]+)?)(?<quote>[''"]?)Terminal-Icons\k<quote>(?=[ \t;]|\r?$)'
    $newImport = '(?im)^[ \t]*Import-Module[ \t]+(?:-Name[ \t]+)?[''"]?TerminalGlyphs(?=[''" \t;]|\r?$)'
    $candidates = @($Path | Where-Object { $_ })
    if ($candidates.Count -eq 0) { throw 'This PowerShell host has no profile path.' }

    $target = $candidates[0]
    foreach ($candidate in $candidates) {
        if (-not [System.IO.File]::Exists($candidate)) { continue }
        $content = [System.IO.File]::ReadAllText($candidate)
        if ($content -match $newImport -or $content -match $oldImport) {
            $target = $candidate
            break
        }
    }

    $encoding = [System.Text.UTF8Encoding]::new($false)
    $text = ''
    $exists = [System.IO.File]::Exists($target)
    if ($exists) {
        $reader = [System.IO.StreamReader]::new($target, $encoding, $true)
        try {
            $text = $reader.ReadToEnd()
            $encoding = $reader.CurrentEncoding
        } finally {
            $reader.Dispose()
        }
    }

    if ($text -match $newImport) {
        $detail = 'already imports TerminalGlyphs'
        if ($text -match $oldImport) { $detail += '; remove the Import-Module Terminal-Icons line' }
        return [pscustomobject]@{ Path = $target; Status = 'Unchanged'; Detail = $detail }
    }

    $newline = if ($text.Contains("`r`n")) { "`r`n" } elseif ($text.Contains("`n")) { "`n" } else { [Environment]::NewLine }
    if ($text -match $oldImport) {
        $updated = [regex]::Replace($text, $oldImport, '${lead}${quote}TerminalGlyphs${quote}')
        $action = 'Replace Import-Module Terminal-Icons with TerminalGlyphs'
    } else {
        $separator = if ($text.Length -gt 0 -and -not $text.EndsWith("`n")) { $newline } else { '' }
        $updated = $text + $separator + '# Added by TerminalGlyphs' + $newline + 'Import-Module -Name TerminalGlyphs' + $newline
        $action = 'Add Import-Module TerminalGlyphs'
    }
    if (-not $PSCmdlet.ShouldProcess($target, $action)) {
        return [pscustomobject]@{ Path = $target; Status = 'Skipped'; Detail = $action }
    }

    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($target)) | Out-Null
    $temp = "$target.terminalglyphs.tmp"
    try {
        [System.IO.File]::WriteAllText($temp, $updated, $encoding)
        if ($exists) {
            $backup = '{0}.terminalglyphs-{1}.bak' -f $target, [DateTime]::Now.ToString('yyyyMMddHHmmss', [cultureinfo]::InvariantCulture)
            [System.IO.File]::Replace($temp, $target, $backup)
            $action += "; backup in $backup"
        } else {
            [System.IO.File]::Move($temp, $target)
        }
    } catch {
        [System.IO.File]::Delete($temp)
        throw
    }
    [pscustomobject]@{ Path = $target; Status = 'OK'; Detail = $action }
}
```

- [ ] **Step 4: Ejecutar y ver que pasan**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Profile.Tests.ps1 -Output Detailed`
Expected: PASS.

- [ ] **Step 5: Suite completa y commit**

Run: `./build.ps1 -Task Test` → 0 fallos.

```powershell
git add src/Private/Update-ProfileImport.ps1 tests/Profile.Tests.ps1
git commit -m "Update the profile import with a backup" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 8: Comando `Install-TerminalGlyphSetup`

**Files:**
- Create: `src/Public/Install-TerminalGlyphSetup.ps1`, `tests/Setup.Tests.ps1`
- Modify: `src/TerminalGlyphs.psd1:11` (`FunctionsToExport`), `tests/Quality.Tests.ps1:2,26`

**Interfaces:**
- Consumes: `$script:FontsPath` (T1), `Read-FontInfo` (T2), `Get-FontLocation`, `Get-NerdFontInstallation` (T3), `Save-NerdFontRelease` (T4), `Install-NerdFontFile`, `Invoke-FontCacheRefresh` (T5), `Remove-StaleFontFile` (T6), `Update-ProfileImport` (T7).
- Produces: `Install-TerminalGlyphSetup [-Family <string[]>] [-SkipFont] [-SkipProfile] [-WhatIf] [-Confirm]` → objetos `TerminalGlyphs.SetupStep` (`Step`, `Status`, `Detail`), emitidos en este orden: `Font cleanup` (solo Windows), `Font <nombre>` por familia desconocida (`Skipped`) y por paquete, o `Fonts` si se omite o falla todo el bloque; y `Profile`. Al final, por `Write-Host`: `Set your terminal font to '<familia>'.` (solo si instaló una familia nueva), `Restart Windows to finish replacing fonts that were in use; until then, apps keep the old version.` (si hay renombrados de esta ejecución o pendientes), `Open a new terminal to load TerminalGlyphs.` (si el perfil cambió).
  - `-Family` desconocida (comparada con los paquetes de `nerdfonts.json`, sin distinguir mayúsculas) → error **antes** de cambiar nada.
  - Paquetes a procesar: los instalados conocidos + los de `-Family`; si no se pasa `-Family` y no hay ninguna Nerd Font (ni siquiera desconocida) → `JetBrainsMono`. Instalado y al día → `Unchanged`. Instalado y desactualizado → actualizar con `-UpdateOnly` y `-InstalledFile`. No instalado → instalar todo el paquete.
  - `ShouldProcess("<Paquete> Nerd Font", <acción>)` por paquete **antes** de descargar; denegado/`-WhatIf` → `Skipped`. `Remove-StaleFontFile` y `Update-ProfileImport` heredan `-WhatIf`/`-Confirm` (no se envuelven en otro `ShouldProcess`, para no preguntar dos veces).
  - Destino: Linux `<Directory>/NerdFonts/<Paquete>`; Windows/macOS `<Directory>`. Linux: `Invoke-FontCacheRefresh` una vez si cambió algo; si devuelve `$false`, aviso.
  - Carpeta temporal `terminalglyphs-<guid>` en `[System.IO.Path]::GetTempPath()`, creada solo si se aprueba un paquete y borrada siempre en `finally` (`-WhatIf:$false -Confirm:$false -ErrorAction Ignore`).
  - Un fallo en un paso → `Error` con el mensaje; los demás pasos siguen.

- [ ] **Step 1: Escribir los tests que fallan**

Crea `tests/Setup.Tests.ps1`:

```powershell
BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    Import-Module (Get-BuiltManifestPath) -Force
    $fontDir = Join-Path $TestDrive 'fonts'

    function Invoke-Setup([hashtable]$Parameters = @{}) {
        $output = Install-TerminalGlyphSetup @Parameters 6>&1
        [pscustomobject]@{
            Steps = @($output | Where-Object { $_.PSObject.TypeNames -contains 'TerminalGlyphs.SetupStep' })
            Notes = @($output | Where-Object { $_ -is [System.Management.Automation.InformationRecord] } | ForEach-Object { "$_" })
        }
    }
    function Get-Step($Result, [string]$Name) { $Result.Steps | Where-Object Step -EQ $Name }
    function New-Family([string]$Package, [string]$Version, [bool]$Outdated) {
        [pscustomobject]@{
            Name       = $Package
            Package    = $Package
            Files      = [System.Collections.Generic.List[string]]@(Join-Path $fontDir "$($Package)NerdFont-Regular.ttf")
            Version    = [version]$Version
            IsOutdated = $Outdated
        }
    }
}

AfterAll {
    Remove-Module TerminalGlyphs -ErrorAction SilentlyContinue
}

Describe 'Install-TerminalGlyphSetup' {
    BeforeEach {
        # Never touch the real font folder, registry, network or profile.
        Mock -ModuleName TerminalGlyphs Get-FontLocation { [pscustomobject]@{ Platform = 'Windows'; Directory = $fontDir } }
        Mock -ModuleName TerminalGlyphs Remove-StaleFontFile { [pscustomobject]@{ Removed = 0; Restored = 0; Pending = 0 } }
        Mock -ModuleName TerminalGlyphs Get-NerdFontInstallation { }
        Mock -ModuleName TerminalGlyphs Save-NerdFontRelease { @(Join-Path $Destination $Package "$($Package)NerdFontMono-Regular.ttf") }
        Mock -ModuleName TerminalGlyphs Install-NerdFontFile {
            $names = @($SourceFile | ForEach-Object { Join-Path $TargetDirectory (Split-Path -Leaf $_) })
            [pscustomobject]@{
                Added    = [System.Collections.Generic.List[string]]@(if (-not $UpdateOnly) { $names })
                Replaced = if ($UpdateOnly) { $names.Count } else { 0 }
                Renamed  = 0
                Failed   = [System.Collections.Generic.List[string]]::new()
            }
        }
        Mock -ModuleName TerminalGlyphs Read-FontInfo { [pscustomobject]@{ FullName = 'JetBrainsMono NFM Regular'; Family = 'JetBrainsMono Nerd Font Mono'; Version = [version]'3.5.1' } }
        Mock -ModuleName TerminalGlyphs Invoke-FontCacheRefresh { $true }
        Mock -ModuleName TerminalGlyphs Update-ProfileImport { [pscustomobject]@{ Path = 'profile.ps1'; Status = 'OK'; Detail = 'Replace Import-Module Terminal-Icons with TerminalGlyphs' } }
    }

    It 'installs JetBrainsMono when there is no Nerd Font and says which font to choose' {
        $result = Invoke-Setup
        (Get-Step $result 'Font JetBrainsMono').Status | Should -Be 'OK'
        Should -Invoke -ModuleName TerminalGlyphs Save-NerdFontRelease -Times 1 -Exactly -ParameterFilter { $Package -eq 'JetBrainsMono' -and $Version -eq '3.5.1' }
        Should -Invoke -ModuleName TerminalGlyphs Install-NerdFontFile -Times 1 -Exactly -ParameterFilter { -not $UpdateOnly -and $TargetDirectory -eq $fontDir -and $Platform -eq 'Windows' }
        $result.Notes | Should -Contain "Set your terminal font to 'JetBrainsMono Nerd Font Mono'."
        (Get-Step $result 'Profile').Status | Should -Be 'OK'
        $result.Notes | Should -Contain 'Open a new terminal to load TerminalGlyphs.'
    }

    It 'updates only the outdated families it finds' {
        Mock -ModuleName TerminalGlyphs Get-NerdFontInstallation { New-Family 'FiraCode' '3.0.2' $true; New-Family 'Hack' '3.5.1' $false }
        $result = Invoke-Setup
        (Get-Step $result 'Font FiraCode').Status | Should -Be 'OK'
        (Get-Step $result 'Font FiraCode').Detail | Should -Match 'Update from 3\.0\.2 to Nerd Fonts 3\.5\.1'
        (Get-Step $result 'Font Hack').Status | Should -Be 'Unchanged'
        Get-Step $result 'Font JetBrainsMono' | Should -BeNullOrEmpty
        Should -Invoke -ModuleName TerminalGlyphs Install-NerdFontFile -Times 1 -Exactly -ParameterFilter { $UpdateOnly -and $InstalledFile -contains (Join-Path $fontDir 'FiraCodeNerdFont-Regular.ttf') }
        $result.Notes | Should -Not -Contain "Set your terminal font to 'JetBrainsMono Nerd Font Mono'."
    }

    It 'installs the families in -Family next to the ones that are current' {
        Mock -ModuleName TerminalGlyphs Get-NerdFontInstallation { New-Family 'JetBrainsMono' '3.5.1' $false }
        $result = Invoke-Setup @{ Family = 'firacode' }
        (Get-Step $result 'Font JetBrainsMono').Status | Should -Be 'Unchanged'
        (Get-Step $result 'Font FiraCode').Status | Should -Be 'OK'
        Should -Invoke -ModuleName TerminalGlyphs Save-NerdFontRelease -Times 1 -Exactly -ParameterFilter { $Package -ceq 'FiraCode' }
    }

    It 'does not install the default font when an unknown Nerd Font is installed' {
        Mock -ModuleName TerminalGlyphs Get-NerdFontInstallation { [pscustomobject]@{ Name = 'FooBar'; Package = $null; Files = [System.Collections.Generic.List[string]]@('x'); Version = $null; IsOutdated = $true } }
        $result = Invoke-Setup @{ WarningAction = 'SilentlyContinue' }
        (Get-Step $result 'Font FooBar').Status | Should -Be 'Skipped'
        Get-Step $result 'Font JetBrainsMono' | Should -BeNullOrEmpty
        Should -Invoke -ModuleName TerminalGlyphs Save-NerdFontRelease -Times 0
    }

    It 'rejects an unknown -Family before changing anything' {
        { Install-TerminalGlyphSetup -Family 'NoSuchFont' } | Should -Throw '*Unknown Nerd Fonts package*NoSuchFont*'
        Should -Invoke -ModuleName TerminalGlyphs Get-FontLocation -Times 0
        Should -Invoke -ModuleName TerminalGlyphs Update-ProfileImport -Times 0
    }

    It 'keeps going and removes its temporary folder when a download fails' {
        $script:Work = $null
        Mock -ModuleName TerminalGlyphs Save-NerdFontRelease { $script:Work = $Destination; throw 'network down' }
        $result = Invoke-Setup
        (Get-Step $result 'Font JetBrainsMono').Status | Should -Be 'Error'
        (Get-Step $result 'Font JetBrainsMono').Detail | Should -Match 'network down'
        $script:Work | Should -Not -BeNullOrEmpty
        $script:Work | Should -Not -Exist
        (Get-Step $result 'Profile').Status | Should -Be 'OK'
    }

    It 'reports files that could not be replaced as an error' {
        Mock -ModuleName TerminalGlyphs Get-NerdFontInstallation { New-Family 'FiraCode' '3.0.2' $true }
        Mock -ModuleName TerminalGlyphs Install-NerdFontFile { [pscustomobject]@{ Added = [System.Collections.Generic.List[string]]::new(); Replaced = 0; Renamed = 0; Failed = [System.Collections.Generic.List[string]]@('FiraCodeNerdFont-Regular.ttf') } }
        (Get-Step (Invoke-Setup) 'Font FiraCode').Status | Should -Be 'Error'
    }

    It 'asks for a restart when a font in use was renamed or is still waiting' -ForEach @(
        @{ Case = 'renamed now'; Renamed = 1; Pending = 0 }
        @{ Case = 'pending from a previous run'; Renamed = 0; Pending = 2 }
    ) {
        Mock -ModuleName TerminalGlyphs Get-NerdFontInstallation { New-Family 'FiraCode' '3.0.2' $true }
        Mock -ModuleName TerminalGlyphs Install-NerdFontFile { [pscustomobject]@{ Added = [System.Collections.Generic.List[string]]::new(); Replaced = 0; Renamed = $Renamed; Failed = [System.Collections.Generic.List[string]]::new() } }
        Mock -ModuleName TerminalGlyphs Remove-StaleFontFile { [pscustomobject]@{ Removed = 0; Restored = 0; Pending = $Pending } }
        $result = Invoke-Setup
        $result.Notes | Should -Contain 'Restart Windows to finish replacing fonts that were in use; until then, apps keep the old version.'
    }

    It 'reports a cleanup error and still installs fonts' {
        Mock -ModuleName TerminalGlyphs Remove-StaleFontFile { throw 'access denied' }
        $result = Invoke-Setup
        (Get-Step $result 'Font cleanup').Status | Should -Be 'Error'
        (Get-Step $result 'Font JetBrainsMono').Status | Should -Be 'OK'
    }

    It 'on Linux, installs into NerdFonts/<Package> and refreshes the font cache once' {
        Mock -ModuleName TerminalGlyphs Get-FontLocation { [pscustomobject]@{ Platform = 'Linux'; Directory = $fontDir } }
        Invoke-Setup @{ Family = 'JetBrainsMono', 'Hack' } | Out-Null
        Should -Invoke -ModuleName TerminalGlyphs Remove-StaleFontFile -Times 0
        Should -Invoke -ModuleName TerminalGlyphs Install-NerdFontFile -Times 1 -Exactly -ParameterFilter { $TargetDirectory -eq (Join-Path $fontDir 'NerdFonts' 'Hack') }
        Should -Invoke -ModuleName TerminalGlyphs Invoke-FontCacheRefresh -Times 1 -Exactly
    }

    It 'skips both steps with -SkipFont and -SkipProfile' {
        $result = Invoke-Setup @{ SkipFont = $true; SkipProfile = $true }
        (Get-Step $result 'Fonts').Status | Should -Be 'Skipped'
        (Get-Step $result 'Profile').Status | Should -Be 'Skipped'
        Should -Invoke -ModuleName TerminalGlyphs Get-FontLocation -Times 0
        Should -Invoke -ModuleName TerminalGlyphs Update-ProfileImport -Times 0
    }

    It 'downloads nothing with -WhatIf' {
        $result = Invoke-Setup @{ WhatIf = $true }
        (Get-Step $result 'Font JetBrainsMono').Status | Should -Be 'Skipped'
        Should -Invoke -ModuleName TerminalGlyphs Save-NerdFontRelease -Times 0
        Should -Invoke -ModuleName TerminalGlyphs Install-NerdFontFile -Times 0
    }
}

Describe 'Install-TerminalGlyphSetup end to end' {
    BeforeAll {
        $script:Release = New-FakeNerdFontRelease -Root (Join-Path $TestDrive 'e2e-release') -Package 'JetBrainsMono' -FontName 'JetBrainsMonoNerdFontMono-Regular.ttf', 'JetBrainsMonoNerdFont-Regular.ttf'
    }

    BeforeEach {
        $script:Case = Join-Path $TestDrive "e2e-$([guid]::NewGuid())"
        $script:Fonts = Join-Path $script:Case 'fonts'
        $script:Installed = New-TestFont -Path (Join-Path $script:Fonts 'NerdFonts' 'JetBrainsMono' 'JetBrainsMonoNerdFontMono-Regular.ttf') -FullName 'Old' -Version 'Version 2.304;Nerd Fonts 3.0.2'
        $script:ProfilePath = Join-Path $script:Case 'profile.ps1'
        [System.IO.File]::WriteAllText($script:ProfilePath, "Import-Module Terminal-Icons`n")
        $script:SavedProfile = $global:PROFILE
        $global:PROFILE = [pscustomobject]@{ CurrentUserCurrentHost = $script:ProfilePath; CurrentUserAllHosts = $null; AllUsersCurrentHost = $null; AllUsersAllHosts = $null }
        # Linux keeps the real code path free of the registry and the Windows font API on every OS.
        Mock -ModuleName TerminalGlyphs Get-FontLocation { [pscustomobject]@{ Platform = 'Linux'; Directory = $script:Fonts } }
        Mock -ModuleName TerminalGlyphs Invoke-FontCacheRefresh { $true }
        Mock -ModuleName TerminalGlyphs Invoke-NerdFontDownload { Copy-Item -LiteralPath (Join-Path $script:Release ($Uri -split '/')[-1]) -Destination $OutFile }
    }

    AfterEach {
        $global:PROFILE = $script:SavedProfile
    }

    It 'updates the installed font and the profile' {
        $result = Invoke-Setup
        (Get-Step $result 'Font JetBrainsMono').Status | Should -Be 'OK'
        (Get-Step $result 'Profile').Status | Should -Be 'OK'
        $info = InModuleScope TerminalGlyphs -Parameters @{ Path = $script:Installed } { param($Path) Read-FontInfo -Path $Path }
        $info.Version | Should -Be ([version]'3.5.1')
        $info.FullName | Should -Be 'JetBrainsMonoNerdFontMono-Regular New'
        Join-Path $script:Fonts 'NerdFonts' 'JetBrainsMono' 'JetBrainsMonoNerdFont-Regular.ttf' | Should -Not -Exist
        [System.IO.File]::ReadAllText($script:ProfilePath) | Should -BeExactly "Import-Module TerminalGlyphs`n"
        Should -Invoke -ModuleName TerminalGlyphs Invoke-FontCacheRefresh -Times 1 -Exactly
    }

    It 'changes nothing with -WhatIf' {
        $before = Get-TreeSnapshot -Path $script:Case
        $result = Invoke-Setup @{ WhatIf = $true }
        (Get-Step $result 'Font JetBrainsMono').Status | Should -Be 'Skipped'
        (Get-Step $result 'Profile').Status | Should -Be 'Skipped'
        Get-TreeSnapshot -Path $script:Case | Should -Be $before
        Should -Invoke -ModuleName TerminalGlyphs Invoke-NerdFontDownload -Times 0
    }

    It 'is idempotent' {
        Invoke-Setup | Out-Null
        $second = Invoke-Setup
        (Get-Step $second 'Font JetBrainsMono').Status | Should -Be 'Unchanged'
        (Get-Step $second 'Profile').Status | Should -Be 'Unchanged'
    }
}
```

En `tests/Quality.Tests.ps1`, añade `'Install-TerminalGlyphSetup'` a la lista de `BeforeDiscovery` y cambia el test de exportaciones a:

```powershell
        @($module.ExportedFunctions.Keys | Sort-Object) | Should -Be @('Find-NerdGlyph', 'Format-TerminalGlyph', 'Get-TerminalGlyph', 'Install-TerminalGlyphSetup', 'Show-TerminalGlyphTheme', 'Update-TerminalGlyphConfig')
```

- [ ] **Step 2: Ejecutar y ver que fallan**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Setup.Tests.ps1, ./tests/Quality.Tests.ps1 -Output Detailed`
Expected: FAIL ("Install-TerminalGlyphSetup is not recognized"; exportaciones distintas).

- [ ] **Step 3: Implementar**

Crea `src/Public/Install-TerminalGlyphSetup.ps1`:

```powershell
function Install-TerminalGlyphSetup {
    <#
    .SYNOPSIS
        Installs or updates Nerd Fonts and makes your PowerShell profile import TerminalGlyphs.
    .DESCRIPTION
        Updates the Nerd Fonts in your user font folder that are older than the version TerminalGlyphs is built for
        (3.5.1), installs the packages in -Family (or JetBrainsMono if you have no Nerd Font), and replaces
        "Import-Module Terminal-Icons" in your profile, keeping a backup. Fonts are installed for the current user
        only, without admin rights. Your terminal settings are not changed: choose the font there afterwards.

        Each step runs even if another one fails, and the command returns one result per step. On Windows, fonts
        that were in use are replaced after you restart Windows.
    .PARAMETER Family
        Nerd Fonts release packages to install or update, such as JetBrainsMono, FiraCode, CascadiaCode or Meslo.
    .PARAMETER SkipFont
        Does not install, update or clean up fonts.
    .PARAMETER SkipProfile
        Does not change your profile.
    .EXAMPLE
        Install-TerminalGlyphSetup
    .EXAMPLE
        Install-TerminalGlyphSetup -Family FiraCode -WhatIf
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string[]]$Family,

        [switch]$SkipFont,

        [switch]$SkipProfile
    )

    $ErrorActionPreference = 'Stop'
    $nerdFonts = [System.IO.File]::ReadAllText($script:FontsPath) | ConvertFrom-Json -AsHashtable
    $version = [version]$nerdFonts['version']
    $packageMap = $nerdFonts['packages']
    $knownPackages = @($packageMap.Values | Sort-Object -Unique)
    $requested = foreach ($name in $Family) {
        $match = $knownPackages | Where-Object { $_ -eq $name } | Select-Object -First 1
        if (-not $match) { throw "Unknown Nerd Fonts package '$name'. Use a release package name such as JetBrainsMono, FiraCode, CascadiaCode, Hack or Meslo." }
        $match
    }

    $newStep = {
        param([string]$Name, [string]$Status, [string]$Detail)
        [pscustomobject]@{ PSTypeName = 'TerminalGlyphs.SetupStep'; Step = $Name; Status = $Status; Detail = $Detail }
    }
    $restartNeeded = $false
    $profileChanged = $false
    $fontToChoose = $null

    if ($SkipFont) {
        & $newStep 'Fonts' 'Skipped' 'Skipped with -SkipFont'
    } else {
        $work = $null
        try {
            $location = Get-FontLocation
            if ($location.Platform -eq 'Windows') {
                try {
                    $stale = Remove-StaleFontFile -FontDirectory $location.Directory
                    if ($stale.Pending -gt 0) { $restartNeeded = $true }
                    if ($stale.Removed + $stale.Restored -gt 0) {
                        & $newStep 'Font cleanup' 'OK' ('Removed {0} replaced file(s), restored {1}' -f $stale.Removed, $stale.Restored)
                    } elseif ($stale.Pending -gt 0) {
                        & $newStep 'Font cleanup' 'Unchanged' ('{0} replaced file(s) waiting for a restart' -f $stale.Pending)
                    } else {
                        & $newStep 'Font cleanup' 'Unchanged' 'Nothing to clean up'
                    }
                } catch {
                    & $newStep 'Font cleanup' 'Error' $_.Exception.Message
                }
            }

            $installed = @(Get-NerdFontInstallation -FontDirectory $location.Directory -PackageMap $packageMap -MinimumVersion $version)
            foreach ($unknown in ($installed | Where-Object { -not $_.Package })) {
                Write-Warning -Message "TerminalGlyphs: $($unknown.Name) is not a Nerd Fonts $version family; it was not changed."
                & $newStep "Font $($unknown.Name)" 'Skipped' 'Unknown Nerd Fonts family'
            }
            $plan = [ordered]@{}
            foreach ($entry in ($installed | Where-Object { $_.Package })) { $plan[$entry.Package] = $entry }
            foreach ($name in $requested) { if (-not $plan.Contains($name)) { $plan[$name] = $null } }
            if (-not $Family -and $installed.Count -eq 0) { $plan['JetBrainsMono'] = $null }

            $changed = 0
            foreach ($package in $plan.Keys) {
                $current = $plan[$package]
                $stepName = "Font $package"
                if ($current -and -not $current.IsOutdated) {
                    & $newStep $stepName 'Unchanged' "Nerd Fonts $($current.Version)"
                    continue
                }
                $action = if ($current) {
                    $from = if ($current.Version) { $current.Version } else { 'an unknown version' }
                    "Update from $from to Nerd Fonts $version"
                } else {
                    "Install Nerd Fonts $version"
                }
                if (-not $PSCmdlet.ShouldProcess("$package Nerd Font", $action)) {
                    & $newStep $stepName 'Skipped' $action
                    continue
                }
                try {
                    if (-not $work) {
                        $work = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "terminalglyphs-$([guid]::NewGuid())")
                        [System.IO.Directory]::CreateDirectory($work) | Out-Null
                    }
                    $files = @(Save-NerdFontRelease -Package $package -Version $version.ToString() -Destination $work)
                    $target = if ($location.Platform -eq 'Linux') { [System.IO.Path]::Combine($location.Directory, 'NerdFonts', $package) } else { $location.Directory }
                    $installedFiles = @()
                    if ($current) { $installedFiles = [string[]]$current.Files }
                    $result = Install-NerdFontFile -SourceFile $files -TargetDirectory $target -Platform $location.Platform -InstalledFile $installedFiles -UpdateOnly:([bool]$current)
                    $changed += $result.Added.Count + $result.Replaced + $result.Renamed
                    if ($result.Renamed -gt 0) { $restartNeeded = $true }
                    if (-not $current -and -not $fontToChoose) {
                        $mono = $result.Added | Where-Object { [System.IO.Path]::GetFileName($_) -like '*NerdFontMono-Regular.*' } | Select-Object -First 1
                        $info = if ($mono) { Read-FontInfo -Path $mono }
                        $fontToChoose = if ($info -and $info.Family) { $info.Family } else { "$package Nerd Font Mono" }
                    }
                    $detail = '{0}: {1} added, {2} replaced' -f $action, $result.Added.Count, ($result.Replaced + $result.Renamed)
                    if ($result.Failed.Count -gt 0) {
                        & $newStep $stepName 'Error' ('{0}; {1} file(s) in use could not be replaced, close the apps that use them and run again' -f $detail, $result.Failed.Count)
                    } else {
                        & $newStep $stepName 'OK' $detail
                    }
                } catch {
                    & $newStep $stepName 'Error' $_.Exception.Message
                }
            }
            if ($changed -gt 0 -and $location.Platform -eq 'Linux' -and -not (Invoke-FontCacheRefresh -Directory $location.Directory)) {
                Write-Warning -Message 'TerminalGlyphs: fc-cache was not found; sign out and back in to see the new fonts.'
            }
        } catch {
            & $newStep 'Fonts' 'Error' $_.Exception.Message
        } finally {
            if ($work) { Remove-Item -LiteralPath $work -Recurse -Force -WhatIf:$false -Confirm:$false -ErrorAction Ignore }
        }
    }

    if ($SkipProfile) {
        & $newStep 'Profile' 'Skipped' 'Skipped with -SkipProfile'
    } else {
        try {
            $profileResult = Update-ProfileImport
            & $newStep 'Profile' $profileResult.Status ('{0}: {1}' -f $profileResult.Path, $profileResult.Detail)
            $profileChanged = $profileResult.Status -eq 'OK'
        } catch {
            & $newStep 'Profile' 'Error' $_.Exception.Message
        }
    }

    if ($fontToChoose) { Write-Host "Set your terminal font to '$fontToChoose'." }
    if ($restartNeeded) { Write-Host 'Restart Windows to finish replacing fonts that were in use; until then, apps keep the old version.' }
    if ($profileChanged) { Write-Host 'Open a new terminal to load TerminalGlyphs.' }
}
```

En `src/TerminalGlyphs.psd1`, línea 11:

```powershell
    FunctionsToExport    = @('Format-TerminalGlyph', 'Get-TerminalGlyph', 'Show-TerminalGlyphTheme', 'Find-NerdGlyph', 'Update-TerminalGlyphConfig', 'Install-TerminalGlyphSetup')
```

- [ ] **Step 4: Ejecutar y ver que pasan**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Setup.Tests.ps1, ./tests/Quality.Tests.ps1 -Output Detailed`
Expected: PASS.

- [ ] **Step 5: Suite completa y commit**

Run: `./build.ps1 -Task Test` → 0 fallos (incluye: el import sigue sin escribir, PSScriptAnalyzer 0 hallazgos, ASCII).

```powershell
git add src/Public/Install-TerminalGlyphSetup.ps1 src/TerminalGlyphs.psd1 tests/Setup.Tests.ps1 tests/Quality.Tests.ps1
git commit -m "Add Install-TerminalGlyphSetup" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 9: Versión 0.2.0, documentación y retirada del script de fuentes

**Files:**
- Delete: `tools/Install-NerdFont.ps1`
- Modify: `src/TerminalGlyphs.psd1:3`, `README.md`, `CHANGELOG.md`, `docs/superpowers/specs/2026-10-03-terminalglyphs-design.md:67`, `tests/Quality.Tests.ps1:21`, `tests/Build.Tests.ps1:99`, `tests/Meta.Tests.ps1`

**Interfaces:**
- Produces: `ModuleVersion = '0.2.0'`; los tests leen la versión de `src/TerminalGlyphs.psd1` en vez de fijar `0.1.0` en rutas.

- [ ] **Step 1: Escribir los tests que fallan**

En `tests/Quality.Tests.ps1`, línea 21: `$manifest.Version | Should -Be ([version]'0.2.0')`.

En `tests/Build.Tests.ps1`, en `BeforeAll` añade `$moduleVersion = (Import-PowerShellDataFile -Path (Join-Path $script:RepoRoot 'src' 'TerminalGlyphs.psd1')).ModuleVersion` y en la línea 99 cambia `'0.1.0'` por `$moduleVersion`.

En `tests/Meta.Tests.ps1`, línea 58: `$manifests[0].FullName | Should -Be (Join-Path $target (Import-PowerShellDataFile -Path (Join-Path $script:RepoRoot 'src' 'TerminalGlyphs.psd1')).ModuleVersion 'TerminalGlyphs.psd1')`. Y dentro de `Describe 'documentation'` añade:

```powershell
    It 'README documents the two-line install from the Gallery' {
        $readme = Get-RepoText 'README.md'
        $readme | Should -Match ([regex]::Escape('Install-PSResource TerminalGlyphs'))
        $readme | Should -Match ([regex]::Escape('Import-Module TerminalGlyphs; Install-TerminalGlyphSetup'))
        $readme | Should -Match 'Restart Windows'
        $readme | Should -Not -Match 'Install-NerdFont\.ps1'
    }

    It 'no longer ships the old font script' {
        Join-Path $script:RepoRoot 'tools' 'Install-NerdFont.ps1' | Should -Not -Exist
    }
```

- [ ] **Step 2: Ejecutar y ver que fallan**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Quality.Tests.ps1, ./tests/Meta.Tests.ps1 -Output Detailed`
Expected: FAIL (versión 0.1.0; README sin instalación de la Gallery; script aún presente).

- [ ] **Step 3: Implementar**

`git rm tools/Install-NerdFont.ps1`. En `src/TerminalGlyphs.psd1`: `ModuleVersion = '0.2.0'`.

En `README.md`, reemplaza la sección `## Requirements` y `## Install from source` (líneas 16–38) por:

````markdown
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

- Updates the Nerd Fonts in your user font folder to 3.5.1, or installs JetBrainsMono if you have none. Packages
  are downloaded from the Nerd Fonts GitHub release and checked against its SHA-256 list. No admin rights needed.
- Replaces `Import-Module Terminal-Icons` in your profile with `Import-Module TerminalGlyphs` (or adds it), keeping a
  backup next to the profile.
- Prints one result per step. Preview with `-WhatIf`; use `-Family FiraCode` for other fonts, `-SkipFont` or
  `-SkipProfile` to skip a step.

Then choose the Nerd Font in your terminal settings (the command tells you its name) and open a new terminal.
On Windows, fonts that were in use are replaced after you **Restart Windows**; until then, apps keep the old version.
````

En `## Commands`, añade la fila `| \`Install-TerminalGlyphSetup\` | Install or update Nerd Fonts and add TerminalGlyphs to your profile. |` como primera fila. En `## Development`, al principio, añade el bloque de instalación desde el código (lo que antes era `## Install from source`):

````markdown
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
````

En `CHANGELOG.md`, deja `## [Unreleased]` encima con lo nuevo y pasa lo existente a `## [0.1.0] - 2026-10-04`:

```markdown
## [Unreleased]

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
```

(Las secciones `### Added`/`### Fixed` de 0.1.0 quedan debajo sin cambios.)

En `docs/superpowers/specs/2026-10-03-terminalglyphs-design.md`, debajo de la fila de la línea 67 añade:

```markdown
| API pública v0.2 | Añade `Install-TerminalGlyphSetup` (ver `2026-10-04-setup-command-design.md`). |
```

- [ ] **Step 4: Ejecutar y ver que pasan**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Quality.Tests.ps1, ./tests/Meta.Tests.ps1, ./tests/Build.Tests.ps1 -Output Detailed`
Expected: PASS (el build ahora sale en `out/TerminalGlyphs/0.2.0/`).

- [ ] **Step 5: Suite completa y commit**

Run: `./build.ps1 -Task Test` → 0 fallos.

```powershell
git add -A src/TerminalGlyphs.psd1 README.md CHANGELOG.md docs/superpowers/specs/2026-10-03-terminalglyphs-design.md tests tools
git commit -m "Release 0.2.0 with the setup command" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 10: Ensayo de publicación y CI en macOS

**Files:**
- Create: `tools/Test-Publish.ps1`
- Modify: `.github/workflows/ci.yml`, `.github/workflows/publish.yml`, `tests/Meta.Tests.ps1`

**Interfaces:**
- Produces: `./tools/Test-Publish.ps1` publica `out/TerminalGlyphs/<versión>` en un repositorio PSResourceGet temporal (carpeta en `%TEMP%`, nombre único), lo recupera con `Save-PSResource` a otra carpeta temporal, lo importa en un `pwsh -NoProfile` hijo y comprueba que exporta los 6 comandos. Siempre desregistra el repositorio y borra sus carpetas. **No instala nada en el perfil del usuario** (usa `Save-PSResource`, no `Install-PSResource`).

- [ ] **Step 1: Escribir los tests que fallan**

En `tests/Meta.Tests.ps1`, cambia `It 'CI runs on Windows and Linux'` por:

```powershell
    It 'CI runs on Windows, Linux and macOS and rehearses publishing' {
        $ci = Get-RepoText '.github/workflows/ci.yml'
        $ci | Should -Match 'windows-latest'
        $ci | Should -Match 'ubuntu-latest'
        $ci | Should -Match 'macos-latest'
        $ci | Should -Match ([regex]::Escape('./build.ps1 -Task Test'))
        $ci | Should -Match ([regex]::Escape('./tools/Test-Publish.ps1'))
    }

    It 'rehearses publishing before publishing' {
        $publish = Get-RepoText '.github/workflows/publish.yml'
        $publish.IndexOf('./tools/Test-Publish.ps1') | Should -BeGreaterThan 0
        $publish.IndexOf('./tools/Test-Publish.ps1') | Should -BeLessThan $publish.IndexOf('Publish-PSResource -Path')
    }
```

- [ ] **Step 2: Ejecutar y ver que fallan**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Meta.Tests.ps1 -Output Detailed`
Expected: FAIL.

- [ ] **Step 3: Implementar**

Crea `tools/Test-Publish.ps1`:

```powershell
<#
.SYNOPSIS
    Rehearses publishing: publishes the built module to a temporary local repository and imports it back.
.DESCRIPTION
    Nothing is installed: the module is saved to a temporary folder and imported in a child pwsh. The temporary
    repository is always unregistered and its folders removed. Run ./build.ps1 first.
.EXAMPLE
    ./build.ps1; ./tools/Test-Publish.ps1
#>
#Requires -Version 7.4
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$manifest = Import-PowerShellDataFile -LiteralPath ([System.IO.Path]::Combine($root, 'src', 'TerminalGlyphs.psd1'))
$version = $manifest.ModuleVersion
$built = [System.IO.Path]::Combine($root, 'out', 'TerminalGlyphs', $version)
if (-not [System.IO.Directory]::Exists($built)) { throw "Module not built: $built. Run ./build.ps1 first." }

$work = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "terminalglyphs-publish-$([guid]::NewGuid())")
$feed = [System.IO.Path]::Combine($work, 'feed')
$saved = [System.IO.Path]::Combine($work, 'saved')
$repository = "TerminalGlyphsRehearsal$([guid]::NewGuid().ToString('N'))"
[System.IO.Directory]::CreateDirectory($feed) | Out-Null
[System.IO.Directory]::CreateDirectory($saved) | Out-Null
try {
    Register-PSResourceRepository -Name $repository -Uri $feed -Trusted
    Publish-PSResource -Path $built -Repository $repository
    Save-PSResource -Name 'TerminalGlyphs' -Version $version -Repository $repository -Path $saved -TrustRepository
    $savedManifest = [System.IO.Path]::Combine($saved, 'TerminalGlyphs', $version, 'TerminalGlyphs.psd1')
    $count = & ([Environment]::ProcessPath) -NoProfile -NonInteractive -Command "(Import-Module '$savedManifest' -PassThru).ExportedFunctions.Count"
    if ($LASTEXITCODE -ne 0 -or [int]$count -ne $manifest.FunctionsToExport.Count) {
        throw "The published module exported $count functions; expected $($manifest.FunctionsToExport.Count)."
    }
    Write-Host "Publish rehearsal OK: TerminalGlyphs $version exports $count functions."
} finally {
    Unregister-PSResourceRepository -Name $repository -ErrorAction Ignore
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction Ignore
}
```

En `.github/workflows/ci.yml`: matriz `os: [windows-latest, ubuntu-latest, macos-latest]` y, tras `Build and test`:

```yaml
      - name: Rehearse publishing
        shell: pwsh
        run: ./tools/Test-Publish.ps1
```

En `.github/workflows/publish.yml`, en el paso `Build and test`, añade como última línea `./tools/Test-Publish.ps1`.

- [ ] **Step 4: Ejecutar y ver que pasan**

Run: `./build.ps1; Invoke-Pester -Path ./tests/Meta.Tests.ps1 -Output Detailed; ./tools/Test-Publish.ps1`
Expected: PASS y `Publish rehearsal OK: TerminalGlyphs 0.2.0 exports 6 functions.` Después, `Get-PSResourceRepository` no debe listar ningún `TerminalGlyphsRehearsal*`.

Si `Publish-PSResource` o `Save-PSResource` fallan por la estructura de carpetas, no adivines: lee el error, consulta `Get-Help Publish-PSResource -Full` / `Save-PSResource -Full` y ajusta la ruta `$savedManifest` según lo que realmente cree.

- [ ] **Step 5: Suite completa y commit**

Run: `./build.ps1 -Task Test` → 0 fallos.

```powershell
git add tools/Test-Publish.ps1 .github/workflows/ci.yml .github/workflows/publish.yml tests/Meta.Tests.ps1
git commit -m "Rehearse publishing and run CI on macOS" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

## Verificación final (`superpowers:verification-before-completion`)

1. `./build.ps1 -Task Test` en el worktree: 0 fallos; anotar totales (pasados/omitidos).
2. `./build.ps1 -Task Test -Tag Performance -ExcludeTag @()`: import < 100 ms (mediana), sin regresión frente a 0.1.0.
3. `./tools/Test-Publish.ps1`: OK y sin repositorios `TerminalGlyphsRehearsal*` registrados después.
4. **En la máquina real, solo con `-WhatIf`** y desde el build (sin instalarlo), en un `pwsh -NoProfile` aparte:
   `Import-Module ./out/TerminalGlyphs/0.2.0/TerminalGlyphs.psd1; Install-TerminalGlyphSetup -WhatIf | Format-Table -AutoSize`
   Esperado: `Font cleanup` `Unchanged`, `Font FiraCode`/`Font JetBrainsMono` `Unchanged` (ya están en 3.5.1), `Profile` `Unchanged` (ya importa TerminalGlyphs), ningún archivo ni el perfil modificados. Ejecutarlo de verdad en la máquina del usuario requiere su confirmación.
5. CI en Windows, Ubuntu y **macOS** verde: solo tras el push, que requiere confirmación del usuario (`finishing-a-development-branch`).
