# TerminalGlyphs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir `TerminalGlyphs`, una reimplementación de Terminal-Icons para pwsh 7.4+ que nunca escribe a disco al importar, carga sus datos de forma diferida y añade iconos Nerd Fonts 3.5.1 para el stack del autor.

**Architecture:** Módulo script. `build.ps1` valida los temas JSONC contra `glyphnames.json` (Nerd Fonts 3.5.1), compila `TerminalGlyphs.data.json` y `glyphs.json`, y concatena las funciones en un único `.psm1`. El import solo registra la vista de `Get-ChildItem` (`Update-FormatData -PrependPath`); el primer `Format-TerminalGlyph` carga los datos y la config de usuario y construye tablas de resolución `OrdinalIgnoreCase`.

**Tech Stack:** PowerShell 7.4+, Pester 5.9.x, PSScriptAnalyzer 1.25.0, JSONC (`ConvertFrom-Json -AsHashtable`), JSON Schema 2020-12, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-03-terminalglyphs-design.md`

## Global Constraints

- Módulo `TerminalGlyphs`, `ModuleVersion = '0.1.0'`, `GUID = '191db48e-7499-4eff-8584-fb8c62a2ddee'`, `Author = 'marr-cloud'`.
- Solo pwsh 7.4+: `PowerShellVersion = '7.4'`, `CompatiblePSEditions = @('Core')`.
- Nerd Fonts **3.5.1**: `vendor/nerd-fonts/glyphnames.json` del tag `v3.5.1` (10995 glifos).
- Pester `[5.9.0, 6.0.0)` y PSScriptAnalyzer `1.25.0`, instalados con `Install-PSResource -Scope CurrentUser`.
- **Ningún camino de código del módulo escribe a disco.** El import no lee datos.
- `Import-Module` en `pwsh -NoProfile`: mediana de 5 < 100 ms. Si no se cumple, se informa; no se relaja el umbral sin preguntar.
- API pública exacta: `Format-TerminalGlyph`, `Get-TerminalGlyph`, `Show-TerminalGlyphTheme`, `Find-NerdGlyph`, `Update-TerminalGlyphConfig`.
- Config de usuario: `$env:TERMINALGLYPHS_CONFIG` → `$env:XDG_CONFIG_HOME/terminalglyphs/config.jsonc` → `~/.config/terminalglyphs/config.jsonc`.
- Código, comentarios, nombres y mensajes de commit **en inglés**; commits en imperativo y *sentence case* como el upstream (`Add …`, `Fix …`).
- Cada commit termina con estas dos líneas (un solo `-m` para que queden juntas como trailers):
  `git commit -m "<Subject>" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"`
- Nunca `git push`, crear el repo remoto ni publicar en la Gallery. Se trabaja en una rama/worktree, nunca en `main`.
- Archivos en `src/`, `build.ps1` y `tools/`: **solo ASCII** (evita la regla `PSUseBOMForUnicodeEncodedFile`).
- En strings con comillas dobles nunca escribas `"$var: ..."` (PowerShell lo interpreta como variable con ámbito y falla al parsear): usa `"$($var): ..."` o `"${var}: ..."`.
- E/S de archivos con rutas absolutas y `[System.IO.File]`/`[System.IO.Path]::Combine` en `src/`, `build.ps1` y `tools/`. En `src/` usa parámetros con nombre en cmdlets.
- Los tests se ejecutan **siempre** con `./build.ps1 -Task Test` (compila y luego corre Pester), desde la raíz del repo/worktree.
- Rutas del upstream (solo lectura): `C:\Users\maurr\workspace\pwsh\Terminal-Icons`.

## Review Focus

1. **Nombres con caracteres comodín** (`[draft].md`) pasados por pipeline a `Get-TerminalGlyph`: deben resolverse literalmente, sin "no se encontró la ruta" → test en la Tarea 9.
2. **Config guardada con BOM UTF-8 o vacía** (Notepad, VS Code, editor a medio guardar): BOM se acepta sin avisos; archivo vacío → un aviso y tema integrado → tests en la Tarea 6.
3. **Nombres Unicode** (`año.ts`, `señal.go`): se resuelven por extensión y se formatean sin romper → tests en las Tareas 5 y 7.
4. **`LinkType = HardLink`**: no es un enlace "visible"; no debe usar el icono de enlace ni mostrar flecha → test en la Tarea 5.
5. **Nombre de tema con otra capitalización** (`"Dracula"`): se acepta sin aviso porque el usuario no tiene forma de saber que distingue mayúsculas → test en la Tarea 6.

---

## Mapa de archivos

| Archivo | Responsabilidad | Tarea |
|---|---|---|
| `.gitignore`, `.gitattributes` | Ignorar `out/`; normalizar EOL | 1 |
| `tests/TestHelpers.ps1` | Procesos pwsh aislados, rutas del módulo compilado, fixtures, snapshots | 1 |
| `tests/Upstream.Characterization.Tests.ps1` | Reproduce el bug de Terminal-Icons 0.11.0 | 1 |
| `vendor/nerd-fonts/{glyphnames.json,LICENSE,README.md}` | Datos oficiales de glifos v3.5.1 | 2 |
| `src/Private/ConvertTo-AnsiSequence.ps1` | Hex → secuencia ANSI 24 bits | 2 |
| `src/Private/Read-JsoncFile.ps1` | Leer JSONC a diccionario, con errores propios | 2 |
| `src/Private/Get-GlyphThemeEntry.ps1` | Aplanar un tema/override en entradas | 2 |
| `src/Private/Test-GlyphThemeEntry.ps1` | Validar una entrada (sección, glifo, color) | 2 |
| `tests/Helpers.Tests.ps1` | Tests de las 4 funciones puras | 2 |
| `tools/Convert-UpstreamTheme.ps1` | Migración única psd1 → JSONC con reparaciones | 3 |
| `themes/icons/default.jsonc`, `themes/colors/{default,light,dracula}.jsonc` | Temas integrados | 3, 8 |
| `tests/Themes.Tests.ps1` | Validez de los temas y reparaciones | 3 |
| `src/TerminalGlyphs.psd1` | Manifiesto | 4 |
| `src/TerminalGlyphs.psm1` | Cuerpo del módulo (variables, aviso de conflicto, formato) | 4, 7 |
| `src/TerminalGlyphs.format.ps1xml` | Vista de `Get-ChildItem` derivada del upstream | 4 |
| `build.ps1` | Validar, compilar, empaquetar, correr tests | 4 |
| `tests/Build.Tests.ps1` | Salida del build y validaciones | 4 |
| `src/Private/{Write-GlyphWarning,New-GlyphTable,Merge-GlyphConfig,Find-GlyphEntry,Resolve-TerminalGlyph}.ps1` | Núcleo de resolución | 5 |
| `tests/Resolve.Tests.ps1` | Reglas de resolución y fusión | 5 |
| `src/Private/{Get-ConfigPath,Read-UserConfig,Get-FullGlyphMap,Select-GlyphThemeName,Initialize-TerminalGlyph}.ps1` | Carga diferida y config | 6 |
| `tests/Config.Tests.ps1` | Config, temas, avisos, degradación | 6 |
| `src/Public/Format-TerminalGlyph.ps1` | Formateo de cada elemento | 7 |
| `tests/Format.Tests.ps1`, `tests/Regression.Tests.ps1` | Formato y regresión del bug | 7 |
| `tools/Set-ThemeEntry.ps1` | Añadir entradas a un tema JSONC conservando cabecera | 8 |
| `tests/Icons.Tests.ps1` | Iconos y colores del stack (spec §6) | 8 |
| `src/Public/{Get-TerminalGlyph,Show-TerminalGlyphTheme,Find-NerdGlyph,Update-TerminalGlyphConfig}.ps1` | Comandos públicos | 9 |
| `schema/config.schema.json` | JSON Schema de la config | 9 |
| `tests/Commands.Tests.ps1` | Comandos públicos y schema | 9 |
| `tests/PSScriptAnalyzerSettings.psd1`, `tests/Quality.Tests.ps1`, `tests/Performance.Tests.ps1` | Calidad y rendimiento | 10 |
| `LICENSE`, `THIRD_PARTY_NOTICES.md`, `README.md`, `CHANGELOG.md`, `.github/workflows/{ci,publish}.yml`, `tests/Meta.Tests.ps1` | Docs, licencias, CI | 11 |
| `tools/Install-NerdFont.ps1` | Actualizar Nerd Fonts del usuario (Windows) | 12 |

---

### Task 1: Andamiaje, dependencias de test y caracterización del bug del upstream

**Files:**
- Create: `.gitignore`, `.gitattributes`
- Create: `tests/TestHelpers.ps1`
- Test: `tests/Upstream.Characterization.Tests.ps1`

**Interfaces:**
- Consumes: nada.
- Produces (en `tests/TestHelpers.ps1`, dot-sourced desde `BeforeAll`):
  - `$script:RepoRoot` — raíz del repo.
  - `Get-BuiltManifestPath` → `[string]` ruta a `out/TerminalGlyphs/<version>/TerminalGlyphs.psd1` (lanza si no existe).
  - `Start-IsolatedPwsh -Command <string> [-Environment <hashtable>]` → handle `{ Process; Stdout; Stderr }`.
  - `Wait-IsolatedPwsh` (pipeline de handles) `[-TimeoutSeconds 120]` → `{ ExitCode; Output; Error; All }`.
  - `Invoke-IsolatedPwsh -Command <string> [-Environment <hashtable>] [-TimeoutSeconds 120]` → igual que `Wait-IsolatedPwsh`.
  - `Get-TreeSnapshot -Path <string[]>` → líneas `ruta|tamaño|ticks|sha256` ordenadas.
  - `New-FileFixture -Root <string> [-File <string[]>] [-Directory <string[]>]` → `[string]` raíz.
  - `Get-GlyphChar -Name <nf-...>` → `[string]` carácter según `vendor/nerd-fonts/glyphnames.json`.

- [ ] **Step 1: Instalar dependencias de test**

```powershell
Install-PSResource -Name Pester -Version '[5.9.0, 6.0.0)' -Scope CurrentUser -TrustRepository
Install-PSResource -Name PSScriptAnalyzer -Version '1.25.0' -Scope CurrentUser -TrustRepository
Get-Module -ListAvailable Pester, PSScriptAnalyzer | Select-Object Name, Version
```

Expected: aparece `Pester 5.9.1` (o la 5.x más alta) y `PSScriptAnalyzer 1.25.0`. El `Pester 3.4.0` de Windows puede seguir listado; no importa.

- [ ] **Step 2: Crear `.gitignore` y `.gitattributes`**

`.gitignore`:

```gitignore
out/
tests/testResults.xml
```

`.gitattributes`:

```gitattributes
* text=auto eol=lf
```

- [ ] **Step 3: Escribir el test de caracterización (reproduce el bug del upstream)**

Este test **pasa cuando el bug se reproduce**: documenta el defecto que motiva el proyecto (spec §2). Se omite si Terminal-Icons 0.11.0 no está instalado o no es Windows (CI).

`tests/Upstream.Characterization.Tests.ps1`:

```powershell
BeforeDiscovery {
    $upstream = Get-Module -ListAvailable -Name 'Terminal-Icons' | Where-Object Version -EQ '0.11.0' | Select-Object -First 1
    $canRun = $IsWindows -and $null -ne $upstream
}

Describe 'Terminal-Icons 0.11.0 (upstream) bug characterization' -Tag 'Upstream' -Skip:(-not $canRun) {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
        $appData = Join-Path $TestDrive 'appdata'
        [System.IO.Directory]::CreateDirectory($appData) | Out-Null
        $childEnv = @{ APPDATA = $appData }

        # The first import creates the theme XMLs inside the isolated APPDATA.
        $seed = Invoke-IsolatedPwsh -Environment $childEnv -Command 'Import-Module Terminal-Icons; "SEEDED"'
        $colorXml = Join-Path $appData 'powershell' 'Community' 'Terminal-Icons' 'devblackops_color.xml'

        # Emulate two sessions writing the same file at once: one <S N="Value"> line goes missing.
        $lines = [System.Collections.Generic.List[string]][System.IO.File]::ReadAllLines($colorXml)
        $valueIndex = $lines.FindIndex([Predicate[string]] { param($line) $line -match '<S N="Value">' })
        $lines.RemoveAt($valueIndex)
        [System.IO.File]::WriteAllLines($colorXml, $lines)
    }

    It 'seeds the theme XMLs on the first import' {
        $seed.Output | Should -Match 'SEEDED'
        $colorXml | Should -Exist
    }

    It 'fails to load inside try/catch (how Warp loads the profile) and leaves the XML corrupt' {
        $result = Invoke-IsolatedPwsh -Environment $childEnv -Command 'try { Import-Module Terminal-Icons } catch { "CAUGHT" }; "LOADED=" + [bool](Get-Module Terminal-Icons)'
        $result.Output | Should -Match 'LOADED=False'
        $result.All | Should -Match 'Import-Clixml'
        { Import-Clixml -LiteralPath $colorXml } | Should -Throw
    }

    It 'loads, and rewrites the XML, when imported outside try/catch' {
        $result = Invoke-IsolatedPwsh -Environment $childEnv -Command 'Import-Module Terminal-Icons; "LOADED=" + [bool](Get-Module Terminal-Icons)'
        $result.Output | Should -Match 'LOADED=True'
        { Import-Clixml -LiteralPath $colorXml } | Should -Not -Throw
    }
}
```

- [ ] **Step 4: Ejecutar y verificar que falla**

Run: `Import-Module Pester -MinimumVersion 5.9.0 -MaximumVersion 5.99.99; Invoke-Pester -Path ./tests/Upstream.Characterization.Tests.ps1 -Output Detailed`
Expected: FAIL en `BeforeAll` porque `TestHelpers.ps1` no existe.

- [ ] **Step 5: Escribir `tests/TestHelpers.ps1`**

```powershell
# Shared helpers for the TerminalGlyphs tests. Dot-source this file from BeforeAll.
$script:RepoRoot = Split-Path -Parent $PSScriptRoot

function Get-BuiltManifestPath {
    $version = (Import-PowerShellDataFile -Path (Join-Path $script:RepoRoot 'src' 'TerminalGlyphs.psd1')).ModuleVersion
    $path = Join-Path $script:RepoRoot 'out' 'TerminalGlyphs' $version 'TerminalGlyphs.psd1'
    if (-not (Test-Path -LiteralPath $path)) { throw "Module not built: $path. Run ./build.ps1 first." }
    $path
}

function Start-IsolatedPwsh {
    param(
        [Parameter(Mandatory)][string]$Command,
        [hashtable]$Environment = @{}
    )
    $psi = [System.Diagnostics.ProcessStartInfo]::new([Environment]::ProcessPath)
    $script = "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`n$Command"
    foreach ($argument in @('-NoProfile', '-NoLogo', '-NonInteractive', '-Command', $script)) {
        $psi.ArgumentList.Add($argument)
    }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    foreach ($name in $Environment.Keys) {
        if ($null -eq $Environment[$name]) { [void]$psi.Environment.Remove($name) }
        else { $psi.Environment[$name] = [string]$Environment[$name] }
    }
    $process = [System.Diagnostics.Process]::Start($psi)
    [pscustomobject]@{
        Process = $process
        Stdout  = $process.StandardOutput.ReadToEndAsync()
        Stderr  = $process.StandardError.ReadToEndAsync()
    }
}

function Wait-IsolatedPwsh {
    param(
        [Parameter(Mandatory, ValueFromPipeline)][psobject]$Handle,
        [int]$TimeoutSeconds = 120
    )
    process {
        if (-not $Handle.Process.WaitForExit($TimeoutSeconds * 1000)) {
            $Handle.Process.Kill($true)
            throw "Child pwsh did not exit within $TimeoutSeconds seconds."
        }
        $Handle.Process.WaitForExit()
        $stdout = $Handle.Stdout.GetAwaiter().GetResult()
        $stderr = $Handle.Stderr.GetAwaiter().GetResult()
        [pscustomobject]@{ ExitCode = $Handle.Process.ExitCode; Output = $stdout; Error = $stderr; All = $stdout + $stderr }
    }
}

function Invoke-IsolatedPwsh {
    param(
        [Parameter(Mandatory)][string]$Command,
        [hashtable]$Environment = @{},
        [int]$TimeoutSeconds = 120
    )
    Start-IsolatedPwsh -Command $Command -Environment $Environment | Wait-IsolatedPwsh -TimeoutSeconds $TimeoutSeconds
}

function Get-TreeSnapshot {
    param([Parameter(Mandatory)][string[]]$Path)
    foreach ($root in $Path) {
        if (-not (Test-Path -LiteralPath $root)) { "$root|<missing>"; continue }
        Get-ChildItem -LiteralPath $root -Recurse -Force -File | Sort-Object FullName | ForEach-Object {
            '{0}|{1}|{2}|{3}' -f $_.FullName, $_.Length, $_.LastWriteTimeUtc.Ticks, (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    }
}

function New-FileFixture {
    param(
        [Parameter(Mandatory)][string]$Root,
        [string[]]$File = @(),
        [string[]]$Directory = @()
    )
    [System.IO.Directory]::CreateDirectory($Root) | Out-Null
    foreach ($name in $Directory) { [System.IO.Directory]::CreateDirectory([System.IO.Path]::Combine($Root, $name)) | Out-Null }
    foreach ($name in $File) { [System.IO.File]::WriteAllText([System.IO.Path]::Combine($Root, $name), '') }
    $Root
}

function Get-GlyphChar {
    param([Parameter(Mandatory)][string]$Name)
    if (-not $script:NerdGlyphs) {
        $script:NerdGlyphs = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'vendor' 'nerd-fonts' 'glyphnames.json') -Raw | ConvertFrom-Json -AsHashtable
    }
    $entry = $script:NerdGlyphs[$Name.Substring(3)]
    if (-not $entry) { throw "Unknown glyph $Name" }
    [char]::ConvertFromUtf32([Convert]::ToInt32($entry['code'], 16))
}
```

- [ ] **Step 6: Ejecutar y verificar que pasa (el bug se reproduce)**

Run: `Import-Module Pester -MinimumVersion 5.9.0 -MaximumVersion 5.99.99; Invoke-Pester -Path ./tests/Upstream.Characterization.Tests.ps1 -Output Detailed`
Expected: `Tests Passed: 3`. Si Terminal-Icons 0.11.0 no estuviera instalado: `Skipped: 3` (en esta máquina sí está, en `C:\Users\maurr\OneDrive\Documentos\PowerShell\Modules\Terminal-Icons\0.11.0`).

- [ ] **Step 7: Commit**

```powershell
git add .gitignore .gitattributes tests/TestHelpers.ps1 tests/Upstream.Characterization.Tests.ps1
git commit -m "Add test harness and upstream bug characterization" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 2: Datos de Nerd Fonts y funciones puras de temas

**Files:**
- Create: `vendor/nerd-fonts/glyphnames.json`, `vendor/nerd-fonts/LICENSE`, `vendor/nerd-fonts/README.md`
- Create: `src/Private/ConvertTo-AnsiSequence.ps1`, `src/Private/Read-JsoncFile.ps1`, `src/Private/Get-GlyphThemeEntry.ps1`, `src/Private/Test-GlyphThemeEntry.ps1`
- Test: `tests/Helpers.Tests.ps1`

**Interfaces:**
- Consumes: nada del código anterior.
- Produces:
  - `ConvertTo-AnsiSequence -Hex <'RRGGBB'|'#RRGGBB'>` → `[string]` `"<ESC>[38;2;R;G;Bm"`; lanza si no es hex de 6 dígitos.
  - `Read-JsoncFile -Path <string>` → `[IDictionary]` (OrderedHashtable con claves que distinguen mayúsculas); lanza con mensaje propio si está vacío o la raíz no es objeto; lanza el error de `ConvertFrom-Json` si es JSONC inválido.
  - `Get-GlyphThemeEntry -Theme <IDictionary>` → `[pscustomobject]{ Kind; Section; Key; Value }` por entrada; omite `name` y `$schema`. `Section`/`Key` son `$null` cuando el valor no es un objeto.
  - `Test-GlyphThemeEntry -Entry <psobject> -ThemeType Icon|Color [-GlyphExists <scriptblock>]` → `$null` si es válida o `[string]` con el problema. Secciones y tipos de enlace distinguen mayúsculas.

- [ ] **Step 1: Descargar los datos oficiales de Nerd Fonts v3.5.1**

```powershell
$vendor = Join-Path (Get-Location) 'vendor' 'nerd-fonts'
[System.IO.Directory]::CreateDirectory($vendor) | Out-Null
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/ryanoasis/nerd-fonts/v3.5.1/glyphnames.json' -OutFile (Join-Path $vendor 'glyphnames.json')
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/ryanoasis/nerd-fonts/v3.5.1/LICENSE' -OutFile (Join-Path $vendor 'LICENSE')
$hash = (Get-FileHash -LiteralPath (Join-Path $vendor 'glyphnames.json') -Algorithm SHA256).Hash
$readme = @"
# Nerd Fonts glyph names

- Source: https://github.com/ryanoasis/nerd-fonts/blob/v3.5.1/glyphnames.json
- Version: 3.5.1
- SHA256: $hash
- License: MIT for source files outside folders with an explicit OFL license (see LICENSE in this folder).

``glyphnames.json`` is used at build time to validate theme glyph names and to generate the glyph maps.
"@
[System.IO.File]::WriteAllText((Join-Path $vendor 'README.md'), $readme + "`n")
(Get-Content -LiteralPath (Join-Path $vendor 'glyphnames.json') -Raw | ConvertFrom-Json -AsHashtable).METADATA.version
```

Expected: imprime `3.5.1`.

- [ ] **Step 2: Escribir los tests de las funciones puras**

`tests/Helpers.Tests.ps1`:

```powershell
BeforeAll {
    $root = Split-Path -Parent $PSScriptRoot
    foreach ($name in 'ConvertTo-AnsiSequence', 'Read-JsoncFile', 'Get-GlyphThemeEntry', 'Test-GlyphThemeEntry') {
        . (Join-Path $root 'src' 'Private' "$name.ps1")
    }
    function New-JsoncFile([string]$Content, [switch]$Bom) {
        $path = Join-Path $TestDrive "$([guid]::NewGuid()).jsonc"
        [System.IO.File]::WriteAllText($path, $Content, [System.Text.UTF8Encoding]::new([bool]$Bom))
        $path
    }
}

Describe 'vendored Nerd Fonts data' {
    It 'is version 3.5.1 with 10995 glyphs' {
        $raw = Read-JsoncFile -Path (Join-Path $root 'vendor' 'nerd-fonts' 'glyphnames.json')
        $raw['METADATA']['version'] | Should -Be '3.5.1'
        ($raw.Keys | Where-Object { $_ -ne 'METADATA' }).Count | Should -Be 10995
    }
}

Describe 'ConvertTo-AnsiSequence' {
    It 'converts <Hex> to a 24-bit foreground sequence' -ForEach @(
        @{ Hex = '00ADD8'; Expected = "`e[38;2;0;173;216m" }
        @{ Hex = '#ffffff'; Expected = "`e[38;2;255;255;255m" }
    ) {
        ConvertTo-AnsiSequence -Hex $Hex | Should -BeExactly $Expected
    }

    It 'rejects <Hex>' -ForEach @(@{ Hex = 'GGGGGG' }, @{ Hex = 'FFF' }, @{ Hex = '' }) {
        { ConvertTo-AnsiSequence -Hex $Hex } | Should -Throw
    }
}

Describe 'Read-JsoncFile' {
    It 'parses comments and trailing commas' {
        $path = New-JsoncFile "// header`n{ `"a`": 1, /* inline */ `"b`": [1, 2,], }"
        $result = Read-JsoncFile -Path $path
        $result['a'] | Should -Be 1
        $result['b'].Count | Should -Be 2
    }

    It 'accepts a UTF-8 BOM' {
        (Read-JsoncFile -Path (New-JsoncFile '{ "a": 1 }' -Bom))['a'] | Should -Be 1
    }

    It 'keeps keys that differ only in case' {
        $result = Read-JsoncFile -Path (New-JsoncFile '{ "justfile": 1, "Justfile": 2 }')
        $result.Count | Should -Be 2
    }

    It 'throws "is empty" for <Case>' -ForEach @(@{ Case = 'an empty file'; Content = '' }, @{ Case = 'whitespace'; Content = "  `n " }) {
        { Read-JsoncFile -Path (New-JsoncFile $Content) } | Should -Throw '*is empty*'
    }

    It 'throws when the root is <Case>' -ForEach @(@{ Case = 'an array'; Content = '[1, 2]' }, @{ Case = 'a number'; Content = '42' }) {
        { Read-JsoncFile -Path (New-JsoncFile $Content) } | Should -Throw '*must contain a JSON object*'
    }

    It 'throws on truncated JSONC' {
        { Read-JsoncFile -Path (New-JsoncFile '{ "iconTheme": "default", "icons": { "files": ') } | Should -Throw
    }
}

Describe 'Get-GlyphThemeEntry' {
    It 'flattens names, extensions, links and default, skipping name and $schema' {
        $theme = [ordered]@{
            '$schema'   = 'x'
            name        = 'demo'
            files       = [ordered]@{
                names      = [ordered]@{ 'go.mod' = 'nf-dev-go' }
                extensions = [ordered]@{ '.rs' = 'nf-dev-rust' }
                links      = [ordered]@{ symlink = 'nf-oct-file_symlink_file' }
                default    = 'nf-fa-file'
            }
            directories = [ordered]@{ names = [ordered]@{ '.claude' = 'nf-cod-claude' } }
        }
        $entries = @(Get-GlyphThemeEntry -Theme $theme)
        $entries.Count | Should -Be 5
        ($entries | Where-Object Key -EQ 'go.mod').Section | Should -Be 'names'
        ($entries | Where-Object Section -EQ 'default').Key | Should -BeNullOrEmpty
        ($entries | Where-Object Section -EQ 'default').Value | Should -Be 'nf-fa-file'
        ($entries | Where-Object Key -EQ '.claude').Kind | Should -Be 'directories'
    }

    It 'reports a non-object section with a null key' {
        $entries = @(Get-GlyphThemeEntry -Theme ([ordered]@{ files = [ordered]@{ names = 'oops' } }))
        $entries[0].Section | Should -Be 'names'
        $entries[0].Key | Should -BeNullOrEmpty
    }
}

Describe 'Test-GlyphThemeEntry' {
    BeforeAll {
        $known = { param($name) $name -in 'nf-dev-go', 'nf-fa-file' }
        function New-Entry($Kind, $Section, $Key, $Value) {
            [pscustomobject]@{ Kind = $Kind; Section = $Section; Key = $Key; Value = $Value }
        }
    }

    It 'accepts a valid icon entry' {
        Test-GlyphThemeEntry -Entry (New-Entry 'files' 'names' 'go.mod' 'nf-dev-go') -ThemeType Icon -GlyphExists $known | Should -BeNullOrEmpty
    }

    It 'accepts the default icon' {
        Test-GlyphThemeEntry -Entry (New-Entry 'files' 'default' $null 'nf-fa-file') -ThemeType Icon -GlyphExists $known | Should -BeNullOrEmpty
    }

    It 'accepts color <Value>' -ForEach @(@{ Value = '00ADD8' }, @{ Value = '#00add8' }) {
        Test-GlyphThemeEntry -Entry (New-Entry 'files' 'extensions' '.go' $Value) -ThemeType Color | Should -BeNullOrEmpty
    }

    It 'reports: <Expected>' -ForEach @(
        @{ Kind = 'Files'; Section = 'names'; Key = 'a'; Value = 'nf-dev-go'; Type = 'Icon'; Expected = "unknown section 'Files'" }
        @{ Kind = 'files'; Section = 'colors'; Key = 'a'; Value = 'nf-dev-go'; Type = 'Icon'; Expected = "unknown section 'files.colors[a]'" }
        @{ Kind = 'directories'; Section = 'extensions'; Key = '.x'; Value = 'nf-dev-go'; Type = 'Icon'; Expected = "unknown section 'directories.extensions[.x]'" }
        @{ Kind = 'files'; Section = 'links'; Key = 'hardlink'; Value = 'nf-dev-go'; Type = 'Icon'; Expected = "unknown link type at 'files.links[hardlink]'" }
        @{ Kind = 'files'; Section = 'extensions'; Key = 'rs'; Value = 'nf-dev-go'; Type = 'Icon'; Expected = "extension must start with '.' at 'files.extensions[rs]'" }
        @{ Kind = 'files'; Section = 'names'; Key = 'a'; Value = 'nf-nope'; Type = 'Icon'; Expected = "unknown glyph 'nf-nope' at 'files.names[a]'" }
        @{ Kind = 'files'; Section = 'names'; Key = 'a'; Value = 'blue'; Type = 'Color'; Expected = "invalid color 'blue' at 'files.names[a]'" }
        @{ Kind = 'files'; Section = 'names'; Key = $null; Value = 'oops'; Type = 'Icon'; Expected = "'files.names' must be an object" }
        @{ Kind = 'files'; Section = 'default'; Key = 'x'; Value = 'nf-dev-go'; Type = 'Icon'; Expected = "'files.default[x]' must be a string" }
        @{ Kind = 'files'; Section = $null; Key = $null; Value = 'oops'; Type = 'Icon'; Expected = "'files' must be an object" }
        @{ Kind = 'files'; Section = 'names'; Key = 'a'; Value = 42; Type = 'Icon'; Expected = "value at 'files.names[a]' must be a string" }
    ) {
        Test-GlyphThemeEntry -Entry (New-Entry $Kind $Section $Key $Value) -ThemeType $Type -GlyphExists $known | Should -BeExactly $Expected
    }
}
```

- [ ] **Step 3: Ejecutar y verificar que falla**

Run: `Import-Module Pester -MinimumVersion 5.9.0 -MaximumVersion 5.99.99; Invoke-Pester -Path ./tests/Helpers.Tests.ps1 -Output Detailed`
Expected: FAIL en `BeforeAll`: no existe `src/Private/ConvertTo-AnsiSequence.ps1`.

- [ ] **Step 4: Implementar las cuatro funciones**

`src/Private/ConvertTo-AnsiSequence.ps1`:

```powershell
function ConvertTo-AnsiSequence {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^#?[0-9A-Fa-f]{6}$')]
        [string]$Hex
    )

    $value = $Hex.TrimStart('#')
    $r = [Convert]::ToInt32($value.Substring(0, 2), 16)
    $g = [Convert]::ToInt32($value.Substring(2, 2), 16)
    $b = [Convert]::ToInt32($value.Substring(4, 2), 16)
    "$([char]27)[38;2;$r;$g;${b}m"
}
```

`src/Private/Read-JsoncFile.ps1`:

```powershell
function Read-JsoncFile {
    [OutputType([System.Collections.IDictionary])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $text = [System.IO.File]::ReadAllText($fullPath)
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "'$fullPath' is empty."
    }
    $value = ConvertFrom-Json -InputObject $text -AsHashtable -Depth 32 -ErrorAction Stop
    if ($value -isnot [System.Collections.IDictionary]) {
        throw "'$fullPath' must contain a JSON object at the root."
    }
    $value
}
```

`src/Private/Get-GlyphThemeEntry.ps1`:

```powershell
function Get-GlyphThemeEntry {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Theme
    )

    foreach ($kind in @($Theme.Keys)) {
        if ($kind -ceq 'name' -or $kind -ceq '$schema') { continue }
        $kindValue = $Theme[$kind]
        if ($kindValue -isnot [System.Collections.IDictionary]) {
            [pscustomobject]@{ Kind = $kind; Section = $null; Key = $null; Value = $kindValue }
            continue
        }
        foreach ($section in @($kindValue.Keys)) {
            $sectionValue = $kindValue[$section]
            if ($sectionValue -is [System.Collections.IDictionary]) {
                foreach ($key in @($sectionValue.Keys)) {
                    [pscustomobject]@{ Kind = $kind; Section = $section; Key = $key; Value = $sectionValue[$key] }
                }
            } else {
                [pscustomobject]@{ Kind = $kind; Section = $section; Key = $null; Value = $sectionValue }
            }
        }
    }
}
```

`src/Private/Test-GlyphThemeEntry.ps1`:

```powershell
function Test-GlyphThemeEntry {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Entry,

        [Parameter(Mandatory)]
        [ValidateSet('Icon', 'Color')]
        [string]$ThemeType,

        [scriptblock]$GlyphExists = { param($name) $true }
    )

    $where = if ($null -eq $Entry.Section) {
        "$($Entry.Kind)"
    } elseif ($null -eq $Entry.Key) {
        "$($Entry.Kind).$($Entry.Section)"
    } else {
        "$($Entry.Kind).$($Entry.Section)[$($Entry.Key)]"
    }

    if ($Entry.Kind -cnotin 'files', 'directories') { return "unknown section '$($Entry.Kind)'" }
    if ($null -eq $Entry.Section) { return "'$where' must be an object" }

    $sections = if ($Entry.Kind -ceq 'files') { 'names', 'extensions', 'links', 'default' } else { 'names', 'links', 'default' }
    if ($Entry.Section -cnotin $sections) { return "unknown section '$where'" }

    if ($Entry.Section -ceq 'default') {
        if ($null -ne $Entry.Key) { return "'$where' must be a string" }
    } elseif ($null -eq $Entry.Key) {
        return "'$where' must be an object"
    }

    if ($Entry.Section -ceq 'links' -and $Entry.Key -cnotin 'symlink', 'junction') { return "unknown link type at '$where'" }
    if ($Entry.Section -ceq 'extensions' -and -not $Entry.Key.StartsWith('.')) { return "extension must start with '.' at '$where'" }
    if ($Entry.Value -isnot [string]) { return "value at '$where' must be a string" }

    if ($ThemeType -eq 'Icon') {
        if (-not (& $GlyphExists $Entry.Value)) { return "unknown glyph '$($Entry.Value)' at '$where'" }
    } elseif ($Entry.Value -notmatch '^#?[0-9A-Fa-f]{6}$') {
        return "invalid color '$($Entry.Value)' at '$where'"
    }
}
```

- [ ] **Step 5: Ejecutar y verificar que pasa**

Run: `Import-Module Pester -MinimumVersion 5.9.0 -MaximumVersion 5.99.99; Invoke-Pester -Path ./tests/Helpers.Tests.ps1 -Output Detailed`
Expected: todos los tests en PASS, 0 fallos.

- [ ] **Step 6: Commit**

```powershell
git add vendor src/Private tests/Helpers.Tests.ps1
git commit -m "Add Nerd Fonts 3.5.1 glyph data and theme helpers" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 3: Migrar los temas del upstream a JSONC

**Files:**
- Create: `tools/Convert-UpstreamTheme.ps1`
- Create (generados): `themes/icons/default.jsonc`, `themes/colors/default.jsonc`, `themes/colors/light.jsonc`, `themes/colors/dracula.jsonc`
- Test: `tests/Themes.Tests.ps1`

**Interfaces:**
- Consumes: `Read-JsoncFile`, `Get-GlyphThemeEntry`, `Test-GlyphThemeEntry` (Tarea 2).
- Produces: temas con forma `{ name, files: { names, extensions, links, default? }, directories: { names, links, default? } }`. Nombres de tema = nombre de archivo (`default`, `light`, `dracula`).

- [ ] **Step 1: Escribir los tests de los temas**

`tests/Themes.Tests.ps1`:

```powershell
BeforeDiscovery {
    $root = Split-Path -Parent $PSScriptRoot
    $themeFiles = @(
        Get-ChildItem -LiteralPath (Join-Path $root 'themes' 'icons') -Filter '*.jsonc' -ErrorAction SilentlyContinue |
            ForEach-Object { @{ Path = $_.FullName; Name = $_.BaseName; Type = 'Icon' } }
        Get-ChildItem -LiteralPath (Join-Path $root 'themes' 'colors') -Filter '*.jsonc' -ErrorAction SilentlyContinue |
            ForEach-Object { @{ Path = $_.FullName; Name = $_.BaseName; Type = 'Color' } }
    )
}

BeforeAll {
    $root = Split-Path -Parent $PSScriptRoot
    foreach ($name in 'Read-JsoncFile', 'Get-GlyphThemeEntry', 'Test-GlyphThemeEntry') {
        . (Join-Path $root 'src' 'Private' "$name.ps1")
    }
    $script:nerd = Read-JsoncFile -Path (Join-Path $root 'vendor' 'nerd-fonts' 'glyphnames.json')
    $script:glyphExists = { param($name) $name -is [string] -and $name.StartsWith('nf-') -and $script:nerd.Contains($name.Substring(3)) }
}

Describe 'built-in themes' {
    It 'ships the default icon theme and the default, light and dracula color themes' {
        Join-Path $root 'themes' 'icons' 'default.jsonc' | Should -Exist
        foreach ($name in 'default', 'light', 'dracula') {
            Join-Path $root 'themes' 'colors' "$name.jsonc" | Should -Exist
        }
    }

    Context '<Name> (<Type>)' -ForEach $themeFiles {
        BeforeAll {
            $theme = Read-JsoncFile -Path $Path
            $entries = @(Get-GlyphThemeEntry -Theme $theme)
        }

        It 'declares a name equal to its file name' {
            $theme['name'] | Should -BeExactly $Name
        }

        It 'has only valid entries for Nerd Fonts 3.5.1' {
            $problems = foreach ($entry in $entries) {
                Test-GlyphThemeEntry -Entry $entry -ThemeType $Type -GlyphExists $script:glyphExists
            }
            $problems | Should -BeNullOrEmpty
        }

        It 'has no keys that differ only in case within a section' {
            $duplicates = $entries | Where-Object { $null -ne $_.Key } |
                Group-Object { "$($_.Kind).$($_.Section).$($_.Key.ToLowerInvariant())" } |
                Where-Object Count -GT 1
            $duplicates.Name | Should -BeNullOrEmpty
        }
    }

    Context 'migration from Terminal-Icons 0.11.0' {
        BeforeAll {
            $icons = Read-JsoncFile -Path (Join-Path $root 'themes' 'icons' 'default.jsonc')
            $colors = Read-JsoncFile -Path (Join-Path $root 'themes' 'colors' 'default.jsonc')
        }

        It 'repairs <Kind>.<Section>[<Key>] to <Glyph>' -ForEach @(
            @{ Kind = 'directories'; Section = 'names'; Key = 'media'; Glyph = 'nf-md-folder_play' }
            @{ Kind = 'directories'; Section = 'names'; Key = 'onedrive'; Glyph = 'nf-md-microsoft_onedrive' }
            @{ Kind = 'files'; Section = 'extensions'; Key = '.clixml'; Glyph = 'nf-md-xml' }
            @{ Kind = 'files'; Section = 'extensions'; Key = '.tf'; Glyph = 'nf-dev-terraform' }
            @{ Kind = 'files'; Section = 'extensions'; Key = '.tfvars'; Glyph = 'nf-dev-terraform' }
            @{ Kind = 'files'; Section = 'extensions'; Key = '.tf.json'; Glyph = 'nf-dev-terraform' }
            @{ Kind = 'files'; Section = 'extensions'; Key = '.tfvars.json'; Glyph = 'nf-dev-terraform' }
            @{ Kind = 'files'; Section = 'extensions'; Key = '.auto.tfvars'; Glyph = 'nf-dev-terraform' }
            @{ Kind = 'files'; Section = 'extensions'; Key = '.auto.tfvars.json'; Glyph = 'nf-dev-terraform' }
        ) {
            $icons[$Kind][$Section][$Key] | Should -BeExactly $Glyph
        }

        It 'moves the dot-less "rakefile" extension to files.names' {
            $icons['files']['names']['rakefile'] | Should -BeExactly 'nf-oct-ruby'
            $icons['files']['extensions'].Contains('rakefile') | Should -BeFalse
        }

        It 'keeps every upstream mapping' {
            $icons['files']['extensions'].Count | Should -Be 286
            $icons['files']['names'].Count | Should -BeGreaterOrEqual 75
            $icons['directories']['names'].Count | Should -Be 45
            $colors['files']['extensions'].Count | Should -Be 283
            $colors['directories']['names'].Count | Should -Be 45
        }

        It 'keeps per-kind link icons' {
            $icons['files']['links']['symlink'] | Should -BeExactly 'nf-oct-file_symlink_file'
            $icons['directories']['links']['symlink'] | Should -BeExactly 'nf-cod-file_symlink_directory'
            $icons['files']['default'] | Should -BeExactly 'nf-fa-file'
            $icons['directories']['default'] | Should -BeExactly 'nf-oct-file_directory'
        }
    }
}
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `Import-Module Pester -MinimumVersion 5.9.0 -MaximumVersion 5.99.99; Invoke-Pester -Path ./tests/Themes.Tests.ps1 -Output Detailed`
Expected: FAIL: `themes/icons/default.jsonc` no existe.

- [ ] **Step 3: Escribir la herramienta de migración**

`tools/Convert-UpstreamTheme.ps1`:

```powershell
<#
.SYNOPSIS
    One-time migration of the Terminal-Icons themes (.psd1) to TerminalGlyphs themes (.jsonc).
.DESCRIPTION
    Kept in the repository to document where the built-in themes come from.
    Terminal-Icons is MIT licensed, Copyright (c) 2019 Brandon Olin.
    Glyphs that no longer exist in Nerd Fonts 3.5.1 are replaced, and extension keys without a
    leading dot (which never matched in Terminal-Icons) are moved to files.names.
.EXAMPLE
    ./tools/Convert-UpstreamTheme.ps1 -UpstreamDataPath ../Terminal-Icons/Terminal-Icons/Data -OutputPath ./themes
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$UpstreamDataPath,

    [Parameter(Mandatory)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

$header = @(
    '// Migrated from Terminal-Icons v0.11.0 (https://github.com/devblackops/Terminal-Icons).'
    '// Copyright (c) 2019 Brandon Olin. MIT License. See THIRD_PARTY_NOTICES.md.'
)
$terraformKeys = '.tf', '.tfvars', '.tf.json', '.tfvars.json', '.auto.tfvars', '.auto.tfvars.json'

function Get-RepairedGlyph {
    param([string]$Key, [string]$Glyph)
    switch ($Glyph) {
        'nf-dev-html5_multimedia' { return 'nf-md-folder_play' }
        'nf-dev-onedrive' { return 'nf-md-microsoft_onedrive' }
        'nf-dev-code_badge' {
            if ($Key -eq '.clixml') { return 'nf-md-xml' }
            if ($Key -in $terraformKeys) { return 'nf-dev-terraform' }
            throw "Unexpected use of nf-dev-code_badge for '$Key'."
        }
        default { return $Glyph }
    }
}

function Get-SortedMap {
    param([System.Collections.IDictionary]$Map)
    $sorted = [ordered]@{}
    foreach ($key in ($Map.Keys | Sort-Object { $_.ToLowerInvariant() }, { $_ })) { $sorted[$key] = $Map[$key] }
    $sorted
}

function ConvertFrom-UpstreamTheme {
    param([hashtable]$Upstream, [string]$Name, [string]$ThemeType)
    $result = [ordered]@{ name = $Name }
    foreach ($kinds in @(@('Files', 'files'), @('Directories', 'directories'))) {
        $source = $Upstream.Types[$kinds[0]]
        $names = [ordered]@{}
        $extensions = [ordered]@{}
        $links = [ordered]@{}
        $default = $null
        # Non-WellKnown keys first, so WellKnown wins if both define the same name.
        foreach ($key in @($source.Keys | Where-Object { $_ -cne 'WellKnown' })) {
            $value = $source[$key]
            if ($ThemeType -eq 'Icon') { $value = Get-RepairedGlyph -Key $key -Glyph $value }
            if ($key -ceq '') { $default = $value }
            elseif ($key -ceq 'symlink' -or $key -ceq 'junction') { $links[$key] = $value }
            elseif ($kinds[1] -eq 'files' -and $key.StartsWith('.')) { $extensions[$key] = $value }
            else { $names[$key] = $value }
        }
        foreach ($key in $source['WellKnown'].Keys) {
            $value = $source['WellKnown'][$key]
            if ($ThemeType -eq 'Icon') { $value = Get-RepairedGlyph -Key $key -Glyph $value }
            $names[$key] = $value
        }
        $section = [ordered]@{ names = (Get-SortedMap -Map $names) }
        if ($kinds[1] -eq 'files') { $section['extensions'] = (Get-SortedMap -Map $extensions) }
        $section['links'] = (Get-SortedMap -Map $links)
        if ($null -ne $default) { $section['default'] = $default }
        $result[$kinds[1]] = $section
    }
    $result
}

$sources = @(
    @{ File = 'iconThemes/devblackops.psd1'; Name = 'default'; Type = 'Icon'; Out = 'icons/default.jsonc' }
    @{ File = 'colorThemes/devblackops.psd1'; Name = 'default'; Type = 'Color'; Out = 'colors/default.jsonc' }
    @{ File = 'colorThemes/devblackops_light.psd1'; Name = 'light'; Type = 'Color'; Out = 'colors/light.jsonc' }
    @{ File = 'colorThemes/dracula.psd1'; Name = 'dracula'; Type = 'Color'; Out = 'colors/dracula.jsonc' }
)

$utf8 = [System.Text.UTF8Encoding]::new($false)
foreach ($source in $sources) {
    $upstream = Import-PowerShellDataFile -LiteralPath ([System.IO.Path]::Combine($UpstreamDataPath, $source.File))
    $theme = ConvertFrom-UpstreamTheme -Upstream $upstream -Name $source.Name -ThemeType $source.Type
    $target = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($OutputPath, $source.Out))
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($target)) | Out-Null
    $json = $theme | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($target, ((@($header) + $json) -join "`n") + "`n", $utf8)
    "Wrote $target"
}
```

- [ ] **Step 4: Ejecutar la migración**

Run: `./tools/Convert-UpstreamTheme.ps1 -UpstreamDataPath 'C:\Users\maurr\workspace\pwsh\Terminal-Icons\Terminal-Icons\Data' -OutputPath (Join-Path (Get-Location) 'themes')`
Expected: cuatro líneas `Wrote ...\themes\...jsonc`.

- [ ] **Step 5: Ejecutar los tests y verificar que pasan**

Run: `Import-Module Pester -MinimumVersion 5.9.0 -MaximumVersion 5.99.99; Invoke-Pester -Path ./tests/Themes.Tests.ps1 -Output Detailed`
Expected: todos en PASS. Si `has only valid entries` falla con un glifo que no está en la lista de reparaciones de la spec, **para y repórtalo**: no inventes un sustituto.

- [ ] **Step 6: Commit**

```powershell
git add tools/Convert-UpstreamTheme.ps1 themes tests/Themes.Tests.ps1
git commit -m "Migrate Terminal-Icons themes to JSONC" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 4: Manifiesto, vista de formato y build

**Files:**
- Create: `src/TerminalGlyphs.psd1`, `src/TerminalGlyphs.psm1`, `src/TerminalGlyphs.format.ps1xml`, `build.ps1`
- Test: `tests/Build.Tests.ps1`

**Interfaces:**
- Consumes: funciones de la Tarea 2 (el build las carga con dot-source), temas de la Tarea 3.
- Produces:
  - `./build.ps1 [-Task Build|Test] [-ThemesPath <dir>] [-OutputPath <dir>] [-Tag <string[]>] [-ExcludeTag <string[]>]`. Por defecto `-ExcludeTag Performance`. Lanza `Theme validation failed:` con la lista de errores.
  - `out/TerminalGlyphs/0.1.0/`: `TerminalGlyphs.psd1`, `TerminalGlyphs.psm1` (todas las funciones de `src/Private` y `src/Public` + cuerpo), `TerminalGlyphs.format.ps1xml`, `TerminalGlyphs.data.json`, `glyphs.json`, y `LICENSE`/`THIRD_PARTY_NOTICES.md` si existen.
  - `TerminalGlyphs.data.json` = `{ nerdFontsVersion, glyphs: { "nf-...": "<char>" } (subconjunto usado + nf-md-arrow_right_thick), iconThemes: { <name>: tema }, colorThemes: { <name>: tema con hex RRGGBB en mayúsculas sin # } }`.
  - `glyphs.json` = `{ "nf-...": "<char>" }` con los 10995 glifos.
  - Variables de módulo (en `src/TerminalGlyphs.psm1`): `$script:DataPath`, `$script:GlyphsPath`, `$script:TGState` (`$null` hasta inicializar), `$script:FullGlyphs`, `$script:Warned` (`HashSet[string]`).

- [ ] **Step 1: Escribir los tests del build**

`tests/Build.Tests.ps1`:

```powershell
BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $buildScript = Join-Path $script:RepoRoot 'build.ps1'
    $manifestPath = Get-BuiltManifestPath
    $moduleDir = Split-Path -Parent $manifestPath
    $data = Get-Content -LiteralPath (Join-Path $moduleDir 'TerminalGlyphs.data.json') -Raw | ConvertFrom-Json -AsHashtable

    function New-ThemeFixture([string]$IconJson, [string]$ColorJson) {
        $dir = Join-Path $TestDrive ([guid]::NewGuid())
        [System.IO.Directory]::CreateDirectory((Join-Path $dir 'icons')) | Out-Null
        [System.IO.Directory]::CreateDirectory((Join-Path $dir 'colors')) | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $dir 'icons' 'default.jsonc'), $IconJson)
        [System.IO.File]::WriteAllText((Join-Path $dir 'colors' 'default.jsonc'), $ColorJson)
        $dir
    }
}

Describe 'build output' {
    It 'contains <File>' -ForEach @(
        @{ File = 'TerminalGlyphs.psd1' }, @{ File = 'TerminalGlyphs.psm1' }, @{ File = 'TerminalGlyphs.format.ps1xml' }
        @{ File = 'TerminalGlyphs.data.json' }, @{ File = 'glyphs.json' }
    ) {
        Join-Path $moduleDir $File | Should -Exist
    }

    It 'passes Test-ModuleManifest' {
        { Test-ModuleManifest -Path $manifestPath -ErrorAction Stop } | Should -Not -Throw
    }

    It 'records Nerd Fonts 3.5.1' {
        $data['nerdFontsVersion'] | Should -Be '3.5.1'
    }

    It 'includes every glyph used by the icon themes plus the link arrow' {
        $json = $data['iconThemes'] | ConvertTo-Json -Depth 10 -Compress
        $used = [regex]::Matches($json, '"(nf-[a-z0-9_-]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
        $used.Count | Should -BeGreaterThan 100
        foreach ($name in $used) { $data['glyphs'].Contains($name) | Should -BeTrue -Because $name }
        $data['glyphs'].Contains('nf-md-arrow_right_thick') | Should -BeTrue
    }

    It 'stores glyphs above U+FFFF as surrogate pairs' {
        [char]::ConvertToUtf32($data['glyphs']['nf-md-arrow_right_thick'], 0) | Should -Be 0xF0055
    }

    It 'ships the full glyph map' {
        (Get-Content -LiteralPath (Join-Path $moduleDir 'glyphs.json') -Raw | ConvertFrom-Json -AsHashtable).Count | Should -Be 10995
    }

    It 'compiles every function from src into the psm1' {
        $psm1 = Get-Content -LiteralPath (Join-Path $moduleDir 'TerminalGlyphs.psm1') -Raw
        $files = Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot 'src' 'Private'), (Join-Path $script:RepoRoot 'src' 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue
        foreach ($file in $files) { $psm1 | Should -Match ([regex]::Escape("function $($file.BaseName) {")) }
        $psm1 | Should -Match 'Update-FormatData'
    }

    It 'derives the Get-ChildItem view from Terminal-Icons' {
        $format = Get-Content -LiteralPath (Join-Path $moduleDir 'TerminalGlyphs.format.ps1xml') -Raw
        $format | Should -Not -Match 'Terminal-Icons\\Format-TerminalIcons'
        ([regex]::Matches($format, [regex]::Escape('TerminalGlyphs\Format-TerminalGlyph $_'))).Count | Should -Be 5
        ([regex]::Matches($format, [regex]::Escape('$_.LinkTarget'))).Count | Should -Be 2
        $format | Should -Match 'DirColors'
        { [xml]$format } | Should -Not -Throw
    }

    It 'imports in a clean session without errors' {
        $result = Invoke-IsolatedPwsh -Command "Import-Module '$manifestPath'; 'ERRORS=' + `$Error.Count"
        $result.Output | Should -Match 'ERRORS=0'
    }
}

Describe 'build validation' {
    It 'normalizes colors to upper-case hex without #' {
        $themes = New-ThemeFixture '{ "name": "default", "files": { "names": { "go.mod": "nf-dev-go" } } }' '{ "name": "default", "files": { "extensions": { ".go": "#00add8" } } }'
        $out = Join-Path $TestDrive 'ok'
        & $buildScript -ThemesPath $themes -OutputPath $out *> $null
        $built = Get-Content -LiteralPath (Join-Path $out 'TerminalGlyphs' '0.1.0' 'TerminalGlyphs.data.json') -Raw | ConvertFrom-Json -AsHashtable
        $built['colorThemes']['default']['files']['extensions']['.go'] | Should -BeExactly '00ADD8'
    }

    It 'fails on <Case>' -ForEach @(
        @{ Case = 'an unknown glyph'; Icons = '{ "name": "default", "files": { "names": { "go.mod": "nf-dev-nope" } } }'; Colors = '{ "name": "default" }'; Expected = "unknown glyph 'nf-dev-nope'" }
        @{ Case = 'an invalid color'; Icons = '{ "name": "default" }'; Colors = '{ "name": "default", "files": { "names": { "a": "blue" } } }'; Expected = "invalid color 'blue'" }
        @{ Case = 'keys that differ only in case'; Icons = '{ "name": "default", "files": { "names": { "justfile": "nf-dev-go", "Justfile": "nf-dev-go" } } }'; Colors = '{ "name": "default" }'; Expected = "duplicate key 'Justfile'" }
        @{ Case = 'a name that does not match the file'; Icons = '{ "name": "other" }'; Colors = '{ "name": "default" }'; Expected = "'name' must be 'default'" }
        @{ Case = 'malformed JSONC'; Icons = '{ "name": "default",'; Colors = '{ "name": "default" }'; Expected = 'default.jsonc' }
    ) {
        $themes = New-ThemeFixture $Icons $Colors
        { & $buildScript -ThemesPath $themes -OutputPath (Join-Path $TestDrive 'bad') *> $null } | Should -Throw "*$Expected*"
    }
}
```

- [ ] **Step 2: Crear el manifiesto `src/TerminalGlyphs.psd1`**

```powershell
@{
    RootModule           = 'TerminalGlyphs.psm1'
    ModuleVersion        = '0.1.0'
    CompatiblePSEditions = @('Core')
    GUID                 = '191db48e-7499-4eff-8584-fb8c62a2ddee'
    Author               = 'marr-cloud'
    CompanyName          = 'marr-cloud'
    Copyright            = '(c) 2026 marr-cloud. MIT License.'
    Description          = 'Nerd Font icons and colors for files and folders in Get-ChildItem. A reimplementation of Terminal-Icons that never writes to disk on import.'
    PowerShellVersion    = '7.4'
    FunctionsToExport    = @('Format-TerminalGlyph', 'Get-TerminalGlyph', 'Show-TerminalGlyphTheme', 'Find-NerdGlyph', 'Update-TerminalGlyphConfig')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags         = @('Terminal', 'Icons', 'NerdFonts', 'Glyphs', 'Color', 'PSEdition_Core', 'Windows', 'Linux', 'MacOS')
            LicenseUri   = 'https://github.com/marr-cloud/TerminalGlyphs/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/marr-cloud/TerminalGlyphs'
            ReleaseNotes = 'https://github.com/marr-cloud/TerminalGlyphs/blob/main/CHANGELOG.md'
        }
    }
}
```

- [ ] **Step 3: Crear el cuerpo del módulo `src/TerminalGlyphs.psm1`**

```powershell
# Module body. build.ps1 prepends every function from src/Private and src/Public above this point.
# Importing must stay cheap and must never read data files or write anything to disk.
$script:DataPath = [System.IO.Path]::Combine($PSScriptRoot, 'TerminalGlyphs.data.json')
$script:GlyphsPath = [System.IO.Path]::Combine($PSScriptRoot, 'glyphs.json')
$script:TGState = $null
$script:FullGlyphs = $null
$script:Warned = [System.Collections.Generic.HashSet[string]]::new()

Update-FormatData -PrependPath ([System.IO.Path]::Combine($PSScriptRoot, 'TerminalGlyphs.format.ps1xml'))
```

- [ ] **Step 4: Generar la vista `src/TerminalGlyphs.format.ps1xml` a partir del upstream**

Se verificó que `FormatsToProcess` **no** tiene precedencia sobre la vista integrada; por eso el cuerpo usa `Update-FormatData -PrependPath` (spec §4). Ejecuta una vez:

```powershell
$upstream = [System.IO.File]::ReadAllText('C:\Users\maurr\workspace\pwsh\Terminal-Icons\Terminal-Icons\Terminal-Icons.format.ps1xml')
# The list view "Target" rows called Format-TerminalIcons by mistake; show the real link target instead.
# In .NET replacement strings "$$" is a literal "$".
$xml = [regex]::Replace($upstream, '(?s)(<Label>Target</Label>\s*<ScriptBlock>)\s*Terminal-Icons\\Format-TerminalIcons \$_\s*(</ScriptBlock>)', '$1$$_.LinkTarget$2')
$xml = $xml.Replace('Terminal-Icons\Format-TerminalIcons $_', 'TerminalGlyphs\Format-TerminalGlyph $_')
$xml = $xml.Replace('<!-- Based on the format.ps1xml file from DirColors', '<!-- TerminalGlyphs view. Derived from Terminal-Icons (MIT, (c) 2019 Brandon Olin), which is based on the format.ps1xml file from DirColors (MIT, (c) 2017 Dustin L. Howett)')
[System.IO.File]::WriteAllText((Join-Path (Get-Location) 'src' 'TerminalGlyphs.format.ps1xml'), $xml, [System.Text.UTF8Encoding]::new($false))
$check = [System.IO.File]::ReadAllText((Join-Path (Get-Location) 'src' 'TerminalGlyphs.format.ps1xml'))
"Format-TerminalGlyph: {0}  LinkTarget: {1}  upstream calls left: {2}" -f ([regex]::Matches($check, 'Format-TerminalGlyph \$_')).Count, ([regex]::Matches($check, '\$_\.LinkTarget')).Count, ([regex]::Matches($check, 'Format-TerminalIcons')).Count
```

Expected: `Format-TerminalGlyph: 5  LinkTarget: 2  upstream calls left: 0`.

- [ ] **Step 5: Escribir `build.ps1`**

```powershell
<#
.SYNOPSIS
    Builds TerminalGlyphs into out/TerminalGlyphs/<version>/ and optionally runs the tests.
.EXAMPLE
    ./build.ps1
    Validates the themes and builds the module.
.EXAMPLE
    ./build.ps1 -Task Test
    Builds, then runs Pester (the Performance tag is excluded by default).
.EXAMPLE
    ./build.ps1 -Task Test -Tag Performance -ExcludeTag @()
    Builds, then runs only the performance tests.
#>
[CmdletBinding()]
param(
    [ValidateSet('Build', 'Test')]
    [string]$Task = 'Build',

    [string]$ThemesPath = ([System.IO.Path]::Combine($PSScriptRoot, 'themes')),

    [string]$OutputPath = ([System.IO.Path]::Combine($PSScriptRoot, 'out')),

    [string[]]$Tag,

    [string[]]$ExcludeTag = @('Performance')
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
foreach ($helper in 'Read-JsoncFile', 'Get-GlyphThemeEntry', 'Test-GlyphThemeEntry') {
    . ([System.IO.Path]::Combine($root, 'src', 'Private', "$helper.ps1"))
}

function Get-NerdGlyphSet {
    $raw = Read-JsoncFile -Path ([System.IO.Path]::Combine($root, 'vendor', 'nerd-fonts', 'glyphnames.json'))
    $map = [System.Collections.Generic.SortedDictionary[string, string]]::new([System.StringComparer]::Ordinal)
    foreach ($name in $raw.Keys) {
        if ($name -ceq 'METADATA') { continue }
        $map["nf-$name"] = [char]::ConvertFromUtf32([Convert]::ToInt32($raw[$name]['code'], 16))
    }
    [pscustomobject]@{ Version = [string]$raw['METADATA']['version']; Glyphs = $map }
}

function Read-ThemeDirectory {
    param(
        [string]$Path,
        [ValidateSet('Icon', 'Color')][string]$ThemeType,
        [System.Collections.Generic.SortedDictionary[string, string]]$Glyphs,
        [System.Collections.Generic.List[string]]$Errors
    )
    $themes = [ordered]@{}
    foreach ($file in (Get-ChildItem -LiteralPath $Path -Filter '*.jsonc' | Sort-Object Name)) {
        try {
            $theme = Read-JsoncFile -Path $file.FullName
        } catch {
            $Errors.Add("$($file.Name): $($_.Exception.Message)")
            continue
        }
        if ($theme['name'] -cne $file.BaseName) { $Errors.Add("$($file.Name): 'name' must be '$($file.BaseName)'") }
        $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($entry in (Get-GlyphThemeEntry -Theme $theme)) {
            $problem = Test-GlyphThemeEntry -Entry $entry -ThemeType $ThemeType -GlyphExists { param($name) $Glyphs.ContainsKey([string]$name) }
            if ($problem) { $Errors.Add("$($file.Name): $problem"); continue }
            if ($null -ne $entry.Key -and -not $seen.Add("$($entry.Kind).$($entry.Section).$($entry.Key)")) {
                $Errors.Add("$($file.Name): duplicate key '$($entry.Key)' in $($entry.Kind).$($entry.Section) (keys are case-insensitive)")
            }
            if ($ThemeType -eq 'Color') {
                $normalized = $entry.Value.TrimStart('#').ToUpperInvariant()
                if ($entry.Section -ceq 'default') { $theme[$entry.Kind]['default'] = $normalized }
                else { $theme[$entry.Kind][$entry.Section][$entry.Key] = $normalized }
            }
        }
        $themes[$file.BaseName] = $theme
    }
    $themes
}

function Invoke-ModuleBuild {
    $manifest = Import-PowerShellDataFile -LiteralPath ([System.IO.Path]::Combine($root, 'src', 'TerminalGlyphs.psd1'))
    $nerd = Get-NerdGlyphSet
    $errors = [System.Collections.Generic.List[string]]::new()
    $iconThemes = Read-ThemeDirectory -Path ([System.IO.Path]::Combine($ThemesPath, 'icons')) -ThemeType Icon -Glyphs $nerd.Glyphs -Errors $errors
    $colorThemes = Read-ThemeDirectory -Path ([System.IO.Path]::Combine($ThemesPath, 'colors')) -ThemeType Color -Glyphs $nerd.Glyphs -Errors $errors
    if (-not $iconThemes.Contains('default')) { $errors.Add('missing icons/default.jsonc') }
    if (-not $colorThemes.Contains('default')) { $errors.Add('missing colors/default.jsonc') }
    if ($errors.Count -gt 0) { throw "Theme validation failed:`n  - $($errors -join "`n  - ")" }

    $used = [System.Collections.Generic.SortedDictionary[string, string]]::new([System.StringComparer]::Ordinal)
    $used['nf-md-arrow_right_thick'] = $nerd.Glyphs['nf-md-arrow_right_thick']
    foreach ($theme in $iconThemes.Values) {
        foreach ($entry in (Get-GlyphThemeEntry -Theme $theme)) { $used[$entry.Value] = $nerd.Glyphs[$entry.Value] }
    }

    $moduleDir = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($OutputPath, 'TerminalGlyphs', $manifest.ModuleVersion))
    if (Test-Path -LiteralPath $moduleDir) { Remove-Item -LiteralPath $moduleDir -Recurse -Force }
    [System.IO.Directory]::CreateDirectory($moduleDir) | Out-Null
    $utf8 = [System.Text.UTF8Encoding]::new($false)

    $data = [ordered]@{ nerdFontsVersion = $nerd.Version; glyphs = $used; iconThemes = $iconThemes; colorThemes = $colorThemes }
    [System.IO.File]::WriteAllText([System.IO.Path]::Combine($moduleDir, 'TerminalGlyphs.data.json'), ($data | ConvertTo-Json -Depth 10 -Compress), $utf8)
    [System.IO.File]::WriteAllText([System.IO.Path]::Combine($moduleDir, 'glyphs.json'), ($nerd.Glyphs | ConvertTo-Json -Compress), $utf8)

    $psm1 = [System.Text.StringBuilder]::new()
    $sources = Get-ChildItem -LiteralPath ([System.IO.Path]::Combine($root, 'src', 'Private')), ([System.IO.Path]::Combine($root, 'src', 'Public')) -Filter '*.ps1' -ErrorAction SilentlyContinue | Sort-Object Name
    foreach ($file in $sources) { [void]$psm1.AppendLine([System.IO.File]::ReadAllText($file.FullName)) }
    [void]$psm1.Append([System.IO.File]::ReadAllText([System.IO.Path]::Combine($root, 'src', 'TerminalGlyphs.psm1')))
    [System.IO.File]::WriteAllText([System.IO.Path]::Combine($moduleDir, 'TerminalGlyphs.psm1'), $psm1.ToString(), $utf8)

    foreach ($file in 'TerminalGlyphs.psd1', 'TerminalGlyphs.format.ps1xml') {
        Copy-Item -LiteralPath ([System.IO.Path]::Combine($root, 'src', $file)) -Destination $moduleDir
    }
    foreach ($file in 'LICENSE', 'THIRD_PARTY_NOTICES.md') {
        $path = [System.IO.Path]::Combine($root, $file)
        if (Test-Path -LiteralPath $path) { Copy-Item -LiteralPath $path -Destination $moduleDir }
    }
    Write-Host "Built TerminalGlyphs $($manifest.ModuleVersion) -> $moduleDir"
}

Invoke-ModuleBuild

if ($Task -eq 'Test') {
    Import-Module Pester -MinimumVersion 5.9.0 -MaximumVersion 5.99.99 -ErrorAction Stop
    $configuration = New-PesterConfiguration
    $configuration.Run.Path = [System.IO.Path]::Combine($root, 'tests')
    $configuration.Run.Throw = $true
    $configuration.Output.Verbosity = 'Detailed'
    if ($Tag) { $configuration.Filter.Tag = $Tag }
    if ($ExcludeTag) { $configuration.Filter.ExcludeTag = $ExcludeTag }
    Invoke-Pester -Configuration $configuration
}
```

- [ ] **Step 6: Ejecutar todos los tests y verificar que pasan**

Run: `./build.ps1 -Task Test`
Expected: `Built TerminalGlyphs 0.1.0 -> ...` y luego todos los tests en PASS (Tareas 1–4). Si algún test de `build validation` falla porque el mensaje no contiene el texto esperado, revisa el mensaje real antes de cambiar el test.

- [ ] **Step 7: Commit**

```powershell
git add src/TerminalGlyphs.psd1 src/TerminalGlyphs.psm1 src/TerminalGlyphs.format.ps1xml build.ps1 tests/Build.Tests.ps1
git commit -m "Add module manifest, Get-ChildItem view and build script" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 5: Núcleo de resolución

**Files:**
- Create: `src/Private/Write-GlyphWarning.ps1`, `src/Private/New-GlyphTable.ps1`, `src/Private/Merge-GlyphConfig.ps1`, `src/Private/Find-GlyphEntry.ps1`, `src/Private/Resolve-TerminalGlyph.ps1`
- Test: `tests/Resolve.Tests.ps1`

**Interfaces:**
- Consumes: `Get-GlyphThemeEntry`, `Test-GlyphThemeEntry` (Tarea 2); `$script:Warned`, `$script:TGState` (Tarea 4).
- Produces:
  - `Write-GlyphWarning -Message <string>` → `Write-Warning "TerminalGlyphs: <Message>"` solo la primera vez por mensaje (usa `$script:Warned`).
  - `New-GlyphTable` → `@{ files = @{ names; extensions; links; default = $null }; directories = @{ names; links; default = $null } }`, diccionarios `OrdinalIgnoreCase`.
  - Entrada de tabla: `[pscustomobject]@{ Value; Name; Source }` (Value = carácter o secuencia ANSI; Name = nombre de glifo o hex).
  - `Merge-GlyphConfig -Table <hashtable> -Theme <IDictionary|$null> -ThemeType Icon|Color -Source <string> -Resolve <scriptblock> [-GlyphExists <scriptblock>] [-Origin <string>] [-Validate]`. Con `-Validate`, avisa (`"<Origin>: ignoring <problema>"`) y omite las entradas inválidas.
  - `Find-GlyphEntry -Table <hashtable de un tipo> -Kind files|directories -Name <string> [-LinkType <string>]` → `{ Entry; Rule }`.
  - `Resolve-TerminalGlyph -Name <string> [-Directory] [-LinkType <string>]` → `{ Icon; IconName; Color; ColorName; Rule; Source }` usando `$script:TGState.Icons` y `.Colors`.

- [ ] **Step 1: Escribir los tests de resolución**

`tests/Resolve.Tests.ps1`:

```powershell
BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    Import-Module (Get-BuiltManifestPath) -Force
}

AfterAll {
    Remove-Module TerminalGlyphs -ErrorAction SilentlyContinue
}

Describe 'Merge-GlyphConfig' {
    It 'adds every section to the table with its source' {
        InModuleScope TerminalGlyphs {
            $table = New-GlyphTable
            $theme = [ordered]@{
                name        = 't'
                files       = [ordered]@{
                    names      = [ordered]@{ 'go.mod' = 'G' }
                    extensions = [ordered]@{ '.rs' = 'R' }
                    links      = [ordered]@{ symlink = 'S' }
                    default    = 'F'
                }
                directories = [ordered]@{ names = [ordered]@{ '.claude' = 'C' }; default = 'D' }
            }
            Merge-GlyphConfig -Table $table -Theme $theme -ThemeType Icon -Source 'theme:t' -Resolve { param($v) "<$v>" }

            $table.files.names['GO.MOD'].Value | Should -Be '<G>'
            $table.files.names['go.mod'].Name | Should -Be 'G'
            $table.files.names['go.mod'].Source | Should -Be 'theme:t'
            $table.files.extensions['.rs'].Value | Should -Be '<R>'
            $table.files.links['symlink'].Value | Should -Be '<S>'
            $table.files.default.Value | Should -Be '<F>'
            $table.directories.names['.claude'].Value | Should -Be '<C>'
            $table.directories.default.Value | Should -Be '<D>'
        }
    }

    It 'lets a later layer override an earlier one' {
        InModuleScope TerminalGlyphs {
            $table = New-GlyphTable
            Merge-GlyphConfig -Table $table -Theme ([ordered]@{ files = [ordered]@{ names = [ordered]@{ 'a' = 'theme' } } }) -ThemeType Icon -Source 'theme:t' -Resolve { param($v) $v }
            Merge-GlyphConfig -Table $table -Theme ([ordered]@{ files = [ordered]@{ names = [ordered]@{ 'A' = 'user' } } }) -ThemeType Icon -Source 'user-config' -Resolve { param($v) $v }
            $table.files.names['a'].Value | Should -Be 'user'
            $table.files.names['a'].Source | Should -Be 'user-config'
        }
    }

    It 'with -Validate, warns once per problem and skips invalid entries' {
        InModuleScope TerminalGlyphs {
            $script:Warned.Clear()
            $table = New-GlyphTable
            $layer = [ordered]@{ files = [ordered]@{ names = [ordered]@{ ok = 'nf-dev-go'; bad = 'nf-nope' } } }
            $parameters = @{
                Table = $table; Theme = $layer; ThemeType = 'Icon'; Source = 'user-config'; Origin = 'cfg.jsonc'; Validate = $true
                GlyphExists = { param($n) $n -eq 'nf-dev-go' }; Resolve = { param($v) $v }
            }
            $warnings = @(
                Merge-GlyphConfig @parameters 3>&1
                Merge-GlyphConfig @parameters 3>&1
            )
            $warnings.Count | Should -Be 1
            "$($warnings[0])" | Should -BeExactly "TerminalGlyphs: cfg.jsonc: ignoring unknown glyph 'nf-nope' at 'files.names[bad]'"
            $table.files.names.ContainsKey('bad') | Should -BeFalse
            $table.files.names['ok'].Value | Should -Be 'nf-dev-go'
        }
    }

    It 'ignores a null theme' {
        InModuleScope TerminalGlyphs {
            $table = New-GlyphTable
            { Merge-GlyphConfig -Table $table -Theme $null -ThemeType Icon -Source 's' -Resolve { param($v) $v } } | Should -Not -Throw
            $table.files.names.Count | Should -Be 0
        }
    }
}

Describe 'Resolve-TerminalGlyph' {
    BeforeAll {
        InModuleScope TerminalGlyphs {
            $icons = New-GlyphTable
            $colors = New-GlyphTable
            $iconTheme = [ordered]@{
                files       = [ordered]@{
                    names      = [ordered]@{ 'go.mod' = 'NAME-go.mod' }
                    extensions = [ordered]@{ '.ts' = 'EXT-.ts'; '.d.ts' = 'EXT-.d.ts'; '.gz' = 'EXT-.gz'; '.env' = 'EXT-.env' }
                    links      = [ordered]@{ symlink = 'LINK-file-symlink'; junction = 'LINK-file-junction' }
                    default    = 'DEFAULT-file'
                }
                directories = [ordered]@{
                    names   = [ordered]@{ '.claude' = 'NAME-.claude' }
                    links   = [ordered]@{ symlink = 'LINK-dir-symlink' }
                    default = 'DEFAULT-dir'
                }
            }
            $colorTheme = [ordered]@{ files = [ordered]@{ extensions = [ordered]@{ '.ts' = 'COLOR-.ts' } } }
            Merge-GlyphConfig -Table $icons -Theme $iconTheme -ThemeType Icon -Source 'theme:test' -Resolve { param($v) $v }
            Merge-GlyphConfig -Table $colors -Theme $colorTheme -ThemeType Color -Source 'theme:test' -Resolve { param($v) "ansi:$v" }
            $script:TGState = @{ Icons = $icons; Colors = $colors; Arrow = '->' }
        }
    }

    It '<Name> (directory: <Directory>, link: <LinkType>) -> <Expected> via <Rule>' -ForEach @(
        @{ Name = 'go.mod'; Directory = $false; LinkType = ''; Expected = 'NAME-go.mod'; Rule = 'files.names[go.mod]' }
        @{ Name = 'GO.MOD'; Directory = $false; LinkType = ''; Expected = 'NAME-go.mod'; Rule = 'files.names[GO.MOD]' }
        @{ Name = 'app.d.ts'; Directory = $false; LinkType = ''; Expected = 'EXT-.d.ts'; Rule = 'files.extensions[.d.ts]' }
        @{ Name = 'app.test.d.ts'; Directory = $false; LinkType = ''; Expected = 'EXT-.d.ts'; Rule = 'files.extensions[.d.ts]' }
        @{ Name = 'main.ts'; Directory = $false; LinkType = ''; Expected = 'EXT-.ts'; Rule = 'files.extensions[.ts]' }
        @{ Name = 'archive.tar.gz'; Directory = $false; LinkType = ''; Expected = 'EXT-.gz'; Rule = 'files.extensions[.gz]' }
        @{ Name = '.env'; Directory = $false; LinkType = ''; Expected = 'EXT-.env'; Rule = 'files.extensions[.env]' }
        @{ Name = 'README'; Directory = $false; LinkType = ''; Expected = 'DEFAULT-file'; Rule = 'files.default' }
        @{ Name = 'año.ts'; Directory = $false; LinkType = ''; Expected = 'EXT-.ts'; Rule = 'files.extensions[.ts]' }
        @{ Name = 'link.ts'; Directory = $false; LinkType = 'SymbolicLink'; Expected = 'LINK-file-symlink'; Rule = 'files.links[symlink]' }
        @{ Name = 'link.ts'; Directory = $false; LinkType = 'Junction'; Expected = 'LINK-file-junction'; Rule = 'files.links[junction]' }
        @{ Name = 'hard.ts'; Directory = $false; LinkType = 'HardLink'; Expected = 'EXT-.ts'; Rule = 'files.extensions[.ts]' }
        @{ Name = '.claude'; Directory = $true; LinkType = ''; Expected = 'NAME-.claude'; Rule = 'directories.names[.claude]' }
        @{ Name = 'src.ts'; Directory = $true; LinkType = ''; Expected = 'DEFAULT-dir'; Rule = 'directories.default' }
        @{ Name = 'linked'; Directory = $true; LinkType = 'SymbolicLink'; Expected = 'LINK-dir-symlink'; Rule = 'directories.links[symlink]' }
        @{ Name = 'jdir'; Directory = $true; LinkType = 'Junction'; Expected = 'DEFAULT-dir'; Rule = 'directories.default' }
    ) {
        $result = InModuleScope TerminalGlyphs -Parameters @{ N = $Name; D = $Directory; L = $LinkType } {
            param($N, $D, $L)
            Resolve-TerminalGlyph -Name $N -Directory:$D -LinkType $L
        }
        $result.IconName | Should -BeExactly $Expected
        $result.Icon | Should -BeExactly $Expected
        $result.Rule | Should -BeExactly $Rule
        $result.Source | Should -Be 'theme:test'
    }

    It 'resolves the color independently of the icon' {
        InModuleScope TerminalGlyphs {
            $ts = Resolve-TerminalGlyph -Name 'main.ts'
            $ts.ColorName | Should -Be 'COLOR-.ts'
            $ts.Color | Should -Be 'ansi:COLOR-.ts'
            (Resolve-TerminalGlyph -Name 'go.mod').Color | Should -BeNullOrEmpty
        }
    }
}
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `./build.ps1 -Task Test`
Expected: FAIL en `Resolve.Tests.ps1` con `The term 'New-GlyphTable' is not recognized`; el resto en PASS.

- [ ] **Step 3: Implementar las cinco funciones**

`src/Private/Write-GlyphWarning.ps1`:

```powershell
function Write-GlyphWarning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    # Each distinct problem is reported once per session (Update-TerminalGlyphConfig resets this).
    if ($script:Warned.Add($Message)) {
        Write-Warning -Message "TerminalGlyphs: $Message"
    }
}
```

`src/Private/New-GlyphTable.ps1`:

```powershell
function New-GlyphTable {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory table only.')]
    [OutputType([hashtable])]
    [CmdletBinding()]
    param()

    $comparer = [System.StringComparer]::OrdinalIgnoreCase
    @{
        files       = @{
            names      = [hashtable]::new($comparer)
            extensions = [hashtable]::new($comparer)
            links      = [hashtable]::new($comparer)
            default    = $null
        }
        directories = @{
            names   = [hashtable]::new($comparer)
            links   = [hashtable]::new($comparer)
            default = $null
        }
    }
}
```

`src/Private/Merge-GlyphConfig.ps1`:

```powershell
function Merge-GlyphConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Table,

        [AllowNull()]
        [System.Collections.IDictionary]$Theme,

        [Parameter(Mandatory)]
        [ValidateSet('Icon', 'Color')]
        [string]$ThemeType,

        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [scriptblock]$Resolve,

        [scriptblock]$GlyphExists = { param($name) $true },

        [string]$Origin = $Source,

        [switch]$Validate
    )

    if ($null -eq $Theme) { return }
    foreach ($entry in (Get-GlyphThemeEntry -Theme $Theme)) {
        if ($Validate) {
            $problem = Test-GlyphThemeEntry -Entry $entry -ThemeType $ThemeType -GlyphExists $GlyphExists
            if ($problem) {
                Write-GlyphWarning -Message "$($Origin): ignoring $problem"
                continue
            }
        }
        $target = $Table[$entry.Kind]
        if ($null -eq $target -or $null -eq $entry.Section) { continue }
        $resolved = & $Resolve $entry.Value
        if ($null -eq $resolved) { continue }
        $item = [pscustomobject]@{ Value = $resolved; Name = $entry.Value; Source = $Source }
        if ($entry.Section -ceq 'default') {
            $target['default'] = $item
        } elseif ($null -ne $entry.Key -and $target.ContainsKey($entry.Section)) {
            $target[$entry.Section][$entry.Key] = $item
        }
    }
}
```

`src/Private/Find-GlyphEntry.ps1`:

```powershell
function Find-GlyphEntry {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Table,

        [Parameter(Mandatory)]
        [ValidateSet('files', 'directories')]
        [string]$Kind,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name,

        [string]$LinkType
    )

    $linkKey = switch ($LinkType) {
        'SymbolicLink' { 'symlink' }
        'Junction' { 'junction' }
        default { $null }
    }
    if ($linkKey -and $Table.links.ContainsKey($linkKey)) {
        return [pscustomobject]@{ Entry = $Table.links[$linkKey]; Rule = "$Kind.links[$linkKey]" }
    }
    if ($Name -and $Table.names.ContainsKey($Name)) {
        return [pscustomobject]@{ Entry = $Table.names[$Name]; Rule = "$Kind.names[$Name]" }
    }
    if ($Name -and $Table.ContainsKey('extensions')) {
        # Longest compound suffix first: app.test.d.ts tries .test.d.ts, then .d.ts, then .ts.
        $dot = $Name.IndexOf('.')
        while ($dot -ge 0) {
            $suffix = $Name.Substring($dot)
            if ($Table.extensions.ContainsKey($suffix)) {
                return [pscustomobject]@{ Entry = $Table.extensions[$suffix]; Rule = "$Kind.extensions[$suffix]" }
            }
            $dot = $Name.IndexOf('.', $dot + 1)
        }
    }
    [pscustomobject]@{ Entry = $Table.default; Rule = "$Kind.default" }
}
```

`src/Private/Resolve-TerminalGlyph.ps1`:

```powershell
function Resolve-TerminalGlyph {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name,

        [switch]$Directory,

        [string]$LinkType
    )

    $kind = if ($Directory) { 'directories' } else { 'files' }
    $icon = Find-GlyphEntry -Table $script:TGState.Icons[$kind] -Kind $kind -Name $Name -LinkType $LinkType
    $color = Find-GlyphEntry -Table $script:TGState.Colors[$kind] -Kind $kind -Name $Name -LinkType $LinkType
    [pscustomobject]@{
        Icon      = $icon.Entry.Value
        IconName  = $icon.Entry.Name
        Color     = $color.Entry.Value
        ColorName = $color.Entry.Name
        Rule      = $icon.Rule
        Source    = $icon.Entry.Source
    }
}
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

Run: `./build.ps1 -Task Test`
Expected: todos en PASS.

- [ ] **Step 5: Commit**

```powershell
git add src/Private tests/Resolve.Tests.ps1
git commit -m "Add icon and color resolution core" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 6: Carga diferida y config de usuario

**Files:**
- Create: `src/Private/Get-ConfigPath.ps1`, `src/Private/Read-UserConfig.ps1`, `src/Private/Get-FullGlyphMap.ps1`, `src/Private/Select-GlyphThemeName.ps1`, `src/Private/Initialize-TerminalGlyph.ps1`
- Test: `tests/Config.Tests.ps1`

**Interfaces:**
- Consumes: Tareas 2, 4 y 5.
- Produces:
  - `Get-ConfigPath` → `[string]` según la precedencia de los Global Constraints.
  - `Read-UserConfig -Path <string>` → `[IDictionary]` o `$null` (no existe, o es ilegible → un aviso `could not read config '<ruta>', using the built-in theme: ...`).
  - `Get-FullGlyphMap` → `[IDictionary]` con los 10995 glifos (carga perezosa en `$script:FullGlyphs`; si falla, avisa y devuelve `@{}`).
  - `Select-GlyphThemeName -Requested <obj> -Available <IDictionary> -Setting <string> -ConfigPath <string>` → nombre real del tema (sin distinguir mayúsculas) o `'default'` con aviso `<ruta>: unknown <Setting> '<valor>', using 'default'.`
  - `Initialize-TerminalGlyph [-Force]` → rellena `$script:TGState = @{ Icons; Colors; Arrow; IconTheme; ColorTheme; ConfigPath }`. Nunca lanza: ante un fallo inesperado avisa `could not initialize, showing names without icons: ...` y deja tablas vacías.

- [ ] **Step 1: Escribir los tests de config**

`tests/Config.Tests.ps1`:

```powershell
BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $savedConfig = $env:TERMINALGLYPHS_CONFIG
    $savedXdg = $env:XDG_CONFIG_HOME
    Import-Module (Get-BuiltManifestPath) -Force

    function Set-TestConfig([string]$Content, [switch]$Bom) {
        $path = Join-Path $TestDrive "$([guid]::NewGuid()).jsonc"
        [System.IO.File]::WriteAllText($path, $Content, [System.Text.UTF8Encoding]::new([bool]$Bom))
        $env:TERMINALGLYPHS_CONFIG = $path
        $path
    }

    # Initializes from scratch and returns the warnings it emitted.
    function Initialize-ForTest {
        InModuleScope TerminalGlyphs { $script:Warned.Clear(); Initialize-TerminalGlyph -Force 3>&1 }
    }

    function Get-State { InModuleScope TerminalGlyphs { $script:TGState } }

    function Resolve-ForTest([string]$Name, [switch]$Directory) {
        InModuleScope TerminalGlyphs -Parameters @{ N = $Name; D = [bool]$Directory } { param($N, $D) Resolve-TerminalGlyph -Name $N -Directory:$D }
    }
}

AfterAll {
    $env:TERMINALGLYPHS_CONFIG = $savedConfig
    $env:XDG_CONFIG_HOME = $savedXdg
    Remove-Module TerminalGlyphs -ErrorAction SilentlyContinue
}

Describe 'Get-ConfigPath' {
    AfterEach {
        $env:TERMINALGLYPHS_CONFIG = $savedConfig
        $env:XDG_CONFIG_HOME = $savedXdg
    }

    It 'prefers TERMINALGLYPHS_CONFIG' {
        $env:TERMINALGLYPHS_CONFIG = Join-Path $TestDrive 'explicit.jsonc'
        InModuleScope TerminalGlyphs { Get-ConfigPath } | Should -Be (Join-Path $TestDrive 'explicit.jsonc')
    }

    It 'falls back to XDG_CONFIG_HOME' {
        $env:TERMINALGLYPHS_CONFIG = $null
        $env:XDG_CONFIG_HOME = Join-Path $TestDrive 'xdg'
        InModuleScope TerminalGlyphs { Get-ConfigPath } | Should -Be (Join-Path $TestDrive 'xdg' 'terminalglyphs' 'config.jsonc')
    }

    It 'falls back to ~/.config' {
        $env:TERMINALGLYPHS_CONFIG = $null
        $env:XDG_CONFIG_HOME = $null
        $expected = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.config' 'terminalglyphs' 'config.jsonc'
        InModuleScope TerminalGlyphs { Get-ConfigPath } | Should -Be $expected
    }
}

Describe 'Initialize-TerminalGlyph' {
    It 'uses the built-in default themes without warnings when there is no config file' {
        $env:TERMINALGLYPHS_CONFIG = Join-Path $TestDrive 'missing.jsonc'
        Initialize-ForTest | Should -BeNullOrEmpty
        $state = Get-State
        $state.IconTheme | Should -Be 'default'
        $state.ColorTheme | Should -Be 'default'
        $state.Icons.files.extensions.Count | Should -BeGreaterThan 200
        $state.Arrow | Should -Be (Get-GlyphChar 'nf-md-arrow_right_thick')
    }

    It 'loads the main.go icon from the built-in data' {
        $env:TERMINALGLYPHS_CONFIG = Join-Path $TestDrive 'missing.jsonc'
        Initialize-ForTest | Out-Null
        $result = Resolve-ForTest 'main.go'
        $result.IconName | Should -Be 'nf-dev-go'
        $result.Icon | Should -Be (Get-GlyphChar 'nf-dev-go')
        $result.Color | Should -Match "^`e\[38;2;\d+;\d+;\d+m$"
        $result.Source | Should -Be 'theme:default'
    }

    It 'applies the theme choice and user overrides' {
        Set-TestConfig '{ "colorTheme": "dracula", "icons": { "files": { "names": { "justfile": "nf-md-format_list_checks" } } }, "colors": { "files": { "extensions": { ".go": "123456" } } } }' | Out-Null
        Initialize-ForTest | Should -BeNullOrEmpty
        (Get-State).ColorTheme | Should -Be 'dracula'
        $just = Resolve-ForTest 'JUSTFILE'
        $just.IconName | Should -Be 'nf-md-format_list_checks'
        $just.Source | Should -Be 'user-config'
        (Resolve-ForTest 'main.go').ColorName | Should -Be '123456'
        (Resolve-ForTest 'main.go').Color | Should -Be "`e[38;2;18;52;86m"
    }

    It 'resolves override glyphs that are not used by the built-in themes' {
        Set-TestConfig '{ "icons": { "files": { "names": { "robot.txt": "nf-md-robot_angry" } } } }' | Out-Null
        Initialize-ForTest | Should -BeNullOrEmpty
        (Resolve-ForTest 'robot.txt').Icon | Should -Be (Get-GlyphChar 'nf-md-robot_angry')
    }

    It 'accepts a theme name in another case' {
        Set-TestConfig '{ "colorTheme": "Dracula" }' | Out-Null
        Initialize-ForTest | Should -BeNullOrEmpty
        (Get-State).ColorTheme | Should -Be 'dracula'
    }

    It 'accepts a config saved with a UTF-8 BOM' {
        Set-TestConfig '{ "colorTheme": "light" }' -Bom | Out-Null
        Initialize-ForTest | Should -BeNullOrEmpty
        (Get-State).ColorTheme | Should -Be 'light'
    }

    It 'warns and uses the built-in theme when the config is <Case>' -ForEach @(
        @{ Case = 'truncated'; Content = '{ "iconTheme": "default", "icons": { "files": '; Expected = '*could not read config*' }
        @{ Case = 'empty'; Content = ''; Expected = '*is empty*' }
        @{ Case = 'an array'; Content = '[1]'; Expected = '*must contain a JSON object*' }
    ) {
        $path = Set-TestConfig $Content
        $warnings = @(Initialize-ForTest)
        $warnings.Count | Should -Be 1
        "$($warnings[0])" | Should -BeLike $Expected
        "$($warnings[0])" | Should -BeLike "*$path*"
        (Get-State).IconTheme | Should -Be 'default'
        (Resolve-ForTest 'main.go').IconName | Should -Be 'nf-dev-go'
    }

    It 'warns about an unknown theme and uses default' {
        Set-TestConfig '{ "colorTheme": "nope" }' | Out-Null
        $warnings = @(Initialize-ForTest)
        "$warnings" | Should -BeLike "*unknown colorTheme 'nope', using 'default'*"
        (Get-State).ColorTheme | Should -Be 'default'
    }

    It 'warns when icons is not an object' {
        Set-TestConfig '{ "icons": "nf-dev-go" }' | Out-Null
        "$(Initialize-ForTest)" | Should -BeLike "*'icons' must be an object*"
    }

    It 'skips only the invalid entries and warns once per session' {
        Set-TestConfig '{ "icons": { "files": { "names": { "ok.txt": "nf-dev-go", "bad.txt": "nf-nope" } } }, "colors": { "files": { "names": { "ok.txt": "blue" } } } }' | Out-Null
        $first = @(Initialize-ForTest)
        $first.Count | Should -Be 2
        $second = @(InModuleScope TerminalGlyphs { Initialize-TerminalGlyph -Force 3>&1 })
        $second.Count | Should -Be 0
        (Resolve-ForTest 'ok.txt').IconName | Should -Be 'nf-dev-go'
        (Resolve-ForTest 'bad.txt').Source | Should -Be 'theme:default'
    }

    It 'degrades to names without icons when the built-in data cannot be read' {
        $env:TERMINALGLYPHS_CONFIG = Join-Path $TestDrive 'missing.jsonc'
        # $TestDrive is not visible inside the module scope, so pass the path in.
        $warnings = InModuleScope TerminalGlyphs -Parameters @{ Missing = (Join-Path $TestDrive 'nope.json') } {
            param($Missing)
            $saved = $script:DataPath
            $script:DataPath = $Missing
            try { $script:Warned.Clear(); Initialize-TerminalGlyph -Force 3>&1 } finally { $script:DataPath = $saved }
        }
        "$warnings" | Should -BeLike '*could not initialize*'
        (Resolve-ForTest 'main.go').Icon | Should -BeNullOrEmpty
    }

    It 'does nothing on a second call without -Force' {
        $env:TERMINALGLYPHS_CONFIG = Join-Path $TestDrive 'missing.jsonc'
        Initialize-ForTest | Out-Null
        InModuleScope TerminalGlyphs {
            $before = $script:TGState
            Initialize-TerminalGlyph
            [object]::ReferenceEquals($before, $script:TGState) | Should -BeTrue
        }
    }
}
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `./build.ps1 -Task Test`
Expected: FAIL en `Config.Tests.ps1` con `The term 'Get-ConfigPath' is not recognized` / `Initialize-TerminalGlyph`.

- [ ] **Step 3: Implementar las cinco funciones**

`src/Private/Get-ConfigPath.ps1`:

```powershell
function Get-ConfigPath {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    if ($env:TERMINALGLYPHS_CONFIG) { return $env:TERMINALGLYPHS_CONFIG }
    $base = if ($env:XDG_CONFIG_HOME) {
        $env:XDG_CONFIG_HOME
    } else {
        [System.IO.Path]::Combine([Environment]::GetFolderPath('UserProfile'), '.config')
    }
    [System.IO.Path]::Combine($base, 'terminalglyphs', 'config.jsonc')
}
```

`src/Private/Read-UserConfig.ps1`:

```powershell
function Read-UserConfig {
    [OutputType([System.Collections.IDictionary])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    if (-not [System.IO.File]::Exists($fullPath)) { return $null }
    try {
        Read-JsoncFile -Path $fullPath
    } catch {
        Write-GlyphWarning -Message "could not read config '$fullPath', using the built-in theme: $($_.Exception.Message)"
        $null
    }
}
```

`src/Private/Get-FullGlyphMap.ps1`:

```powershell
function Get-FullGlyphMap {
    [OutputType([System.Collections.IDictionary])]
    [CmdletBinding()]
    param()

    if ($null -eq $script:FullGlyphs) {
        try {
            $script:FullGlyphs = Read-JsoncFile -Path $script:GlyphsPath
        } catch {
            Write-GlyphWarning -Message "could not load '$($script:GlyphsPath)': $($_.Exception.Message)"
            $script:FullGlyphs = @{}
        }
    }
    $script:FullGlyphs
}
```

`src/Private/Select-GlyphThemeName.ps1`:

```powershell
function Select-GlyphThemeName {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Requested,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Available,

        [Parameter(Mandatory)]
        [string]$Setting,

        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    if ($null -eq $Requested) { return 'default' }
    if ($Requested -is [string]) {
        $match = @($Available.Keys | Where-Object { $_ -eq $Requested })
        if ($match.Count -gt 0) { return [string]$match[0] }
    }
    Write-GlyphWarning -Message "$($ConfigPath): unknown $Setting '$Requested', using 'default'."
    'default'
}
```

`src/Private/Initialize-TerminalGlyph.ps1`:

```powershell
function Initialize-TerminalGlyph {
    [CmdletBinding()]
    param(
        [switch]$Force
    )

    if ($script:TGState -and -not $Force) { return }
    try {
        $data = Read-JsoncFile -Path $script:DataPath
        $builtinGlyphs = $data['glyphs']
        $configPath = Get-ConfigPath
        $config = Read-UserConfig -Path $configPath

        $requestedIcon = if ($config) { $config['iconTheme'] } else { $null }
        $requestedColor = if ($config) { $config['colorTheme'] } else { $null }
        $iconThemeName = Select-GlyphThemeName -Requested $requestedIcon -Available $data['iconThemes'] -Setting 'iconTheme' -ConfigPath $configPath
        $colorThemeName = Select-GlyphThemeName -Requested $requestedColor -Available $data['colorThemes'] -Setting 'colorTheme' -ConfigPath $configPath

        # These script blocks run inside Merge-GlyphConfig and see these variables through dynamic scoping.
        $glyphExists = { param($name) $name -is [string] -and ($builtinGlyphs.Contains($name) -or (Get-FullGlyphMap).Contains($name)) }
        $resolveIcon = {
            param($name)
            if ($builtinGlyphs.Contains($name)) { $builtinGlyphs[$name] } else { (Get-FullGlyphMap)[$name] }
        }
        $ansiCache = @{}
        $resolveColor = {
            param($hex)
            $key = $hex.TrimStart('#').ToUpperInvariant()
            if (-not $ansiCache.ContainsKey($key)) { $ansiCache[$key] = ConvertTo-AnsiSequence -Hex $key }
            $ansiCache[$key]
        }

        $icons = New-GlyphTable
        $colors = New-GlyphTable
        Merge-GlyphConfig -Table $icons -Theme $data['iconThemes'][$iconThemeName] -ThemeType Icon -Source "theme:$iconThemeName" -Resolve $resolveIcon
        Merge-GlyphConfig -Table $colors -Theme $data['colorThemes'][$colorThemeName] -ThemeType Color -Source "theme:$colorThemeName" -Resolve $resolveColor

        if ($config) {
            $layers = @(
                @{ Setting = 'icons'; Table = $icons; Type = 'Icon'; Resolve = $resolveIcon }
                @{ Setting = 'colors'; Table = $colors; Type = 'Color'; Resolve = $resolveColor }
            )
            foreach ($layer in $layers) {
                $section = $config[$layer.Setting]
                if ($null -eq $section) { continue }
                if ($section -isnot [System.Collections.IDictionary]) {
                    Write-GlyphWarning -Message "$($configPath): '$($layer.Setting)' must be an object, ignoring it."
                    continue
                }
                Merge-GlyphConfig -Table $layer.Table -Theme $section -ThemeType $layer.Type -Source 'user-config' -Origin $configPath -Validate -GlyphExists $glyphExists -Resolve $layer.Resolve
            }
        }

        $arrow = if ($builtinGlyphs.Contains('nf-md-arrow_right_thick')) { $builtinGlyphs['nf-md-arrow_right_thick'] } else { '->' }
        $script:TGState = @{
            Icons      = $icons
            Colors     = $colors
            Arrow      = $arrow
            IconTheme  = $iconThemeName
            ColorTheme = $colorThemeName
            ConfigPath = $configPath
        }
    } catch {
        Write-GlyphWarning -Message "could not initialize, showing names without icons: $($_.Exception.Message)"
        $script:TGState = @{
            Icons      = New-GlyphTable
            Colors     = New-GlyphTable
            Arrow      = '->'
            IconTheme  = $null
            ColorTheme = $null
            ConfigPath = $null
        }
    }
}
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

Run: `./build.ps1 -Task Test`
Expected: todos en PASS.

- [ ] **Step 5: Commit**

```powershell
git add src/Private tests/Config.Tests.ps1
git commit -m "Load themes and user config lazily" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 7: Format-TerminalGlyph y regresión del bug

**Files:**
- Create: `src/Public/Format-TerminalGlyph.ps1`
- Modify: `src/TerminalGlyphs.psm1` (aviso de conflicto con Terminal-Icons)
- Test: `tests/Format.Tests.ps1`, `tests/Regression.Tests.ps1`

**Interfaces:**
- Consumes: `Initialize-TerminalGlyph`, `Resolve-TerminalGlyph`, `$script:TGState.Arrow` (Tareas 5–6); la vista de la Tarea 4 llama a `TerminalGlyphs\Format-TerminalGlyph $_`.
- Produces:
  - `Format-TerminalGlyph [-InputObject] <FileSystemInfo>` (pipeline) → `[string]`: `"<color><icono>  <nombre>[ <flecha> <destino>]<reset>"`; sin color si `$PSStyle.OutputRendering -eq 'PlainText'`; solo el nombre si algo falla.
  - Al importar con `Terminal-Icons` cargado: aviso `Terminal-Icons is also loaded. ...`.

- [ ] **Step 1: Escribir los tests de formato**

`tests/Format.Tests.ps1`:

```powershell
BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $savedConfig = $env:TERMINALGLYPHS_CONFIG
    $env:TERMINALGLYPHS_CONFIG = Join-Path $TestDrive 'missing.jsonc'
    Import-Module (Get-BuiltManifestPath) -Force
    InModuleScope TerminalGlyphs { Initialize-TerminalGlyph -Force }
    $fixture = New-FileFixture -Root (Join-Path $TestDrive 'project') -File 'main.go', 'año.go' -Directory 'docs'
    $goGlyph = Get-GlyphChar 'nf-dev-go'
}

AfterAll {
    $env:TERMINALGLYPHS_CONFIG = $savedConfig
    Remove-Module TerminalGlyphs -ErrorAction SilentlyContinue
}

Describe 'Format-TerminalGlyph' {
    It 'prefixes the colored icon and resets the color' {
        $line = Get-Item -LiteralPath (Join-Path $fixture 'main.go') | Format-TerminalGlyph
        $line | Should -Match "^`e\[38;2;\d+;\d+;\d+m"
        $line | Should -BeLike "*$goGlyph  main.go*"
        # The reset sequence contains '[', a wildcard character for -BeLike.
        $line.EndsWith($PSStyle.Reset) | Should -BeTrue
    }

    It 'handles Unicode names' {
        Get-Item -LiteralPath (Join-Path $fixture 'año.go') | Format-TerminalGlyph | Should -BeLike "*$goGlyph  año.go*"
    }

    It 'formats directories' {
        Get-Item -LiteralPath (Join-Path $fixture 'docs') | Format-TerminalGlyph | Should -BeLike "*$(Get-GlyphChar 'nf-oct-repo')  docs*"
    }

    It 'omits ANSI sequences when OutputRendering is PlainText' {
        $saved = $PSStyle.OutputRendering
        try {
            $PSStyle.OutputRendering = 'PlainText'
            Get-Item -LiteralPath (Join-Path $fixture 'main.go') | Format-TerminalGlyph | Should -BeExactly "$goGlyph  main.go"
        } finally {
            $PSStyle.OutputRendering = $saved
        }
    }

    It 'shows the target of a junction' -Skip:(-not $IsWindows) {
        $link = Join-Path $TestDrive 'docs-link'
        New-Item -ItemType Junction -Path $link -Target (Join-Path $fixture 'docs') | Out-Null
        $line = Get-Item -LiteralPath $link | Format-TerminalGlyph
        $line | Should -BeLike "*docs-link $(Get-GlyphChar 'nf-md-arrow_right_thick') *docs*"
    }

    It 'returns the plain name when resolution fails' {
        Mock -ModuleName TerminalGlyphs Resolve-TerminalGlyph { throw 'boom' }
        Get-Item -LiteralPath (Join-Path $fixture 'main.go') | Format-TerminalGlyph | Should -BeExactly 'main.go'
    }

    It 'is used by Get-ChildItem' {
        Get-ChildItem -LiteralPath $fixture | Out-String | Should -BeLike "*$goGlyph  main.go*"
    }
}
```

- [ ] **Step 2: Escribir los tests de regresión del bug (spec §2)**

`tests/Regression.Tests.ps1`:

```powershell
BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $manifestPath = Get-BuiltManifestPath
    $goGlyph = Get-GlyphChar 'nf-dev-go'
    $fixture = New-FileFixture -Root (Join-Path $TestDrive 'project') -File 'main.go', 'README.md' -Directory 'docs'
    $configDir = Join-Path $TestDrive 'config'
    [System.IO.Directory]::CreateDirectory($configDir) | Out-Null
    $validConfig = Join-Path $configDir 'valid.jsonc'
    [System.IO.File]::WriteAllText($validConfig, '{ "colorTheme": "default" }')
    $appData = Join-Path $TestDrive 'appdata'
    [System.IO.Directory]::CreateDirectory($appData) | Out-Null
}

Describe 'regression: Terminal-Icons import failures (spec section 2)' {
    It 'loads inside try/catch with ErrorActionPreference Stop even when the config is truncated' {
        $config = Join-Path $configDir 'truncated.jsonc'
        [System.IO.File]::WriteAllText($config, '{ "iconTheme": "default", "icons": { "files": ')
        $mainGo = Join-Path $fixture 'main.go'
        $command = @"
`$ErrorActionPreference = 'Stop'
try {
    Import-Module '$manifestPath'
    `$line = Get-Item -LiteralPath '$mainGo' | Format-TerminalGlyph
    "LOADED=`$([bool](Get-Module TerminalGlyphs))"
    "LINE=`$line"
} catch {
    "CAUGHT=`$(`$_.Exception.Message)"
}
"@
        $result = Invoke-IsolatedPwsh -Command $command -Environment @{ TERMINALGLYPHS_CONFIG = $config; APPDATA = $appData }
        $plain = $result.All -replace "`e\[[0-9;]*m", ''
        $plain | Should -Match 'LOADED=True'
        $plain | Should -Not -Match 'CAUGHT='
        $plain | Should -Match 'could not read config'
        $plain | Should -Match ([regex]::Escape("LINE=$goGlyph  main.go"))
    }

    It 'never fails when many sessions import and list at the same time' {
        $failures = [System.Collections.Generic.List[string]]::new()
        foreach ($round in 1..3) {
            $barrier = [DateTime]::UtcNow.AddSeconds(5).Ticks
            $handles = foreach ($session in 1..8) {
                # Odd sessions start together; even sessions are staggered, like panes opening one after another.
                $delay = if ($session % 2) { 0 } else { Get-Random -Minimum 0 -Maximum 400 }
                $command = @"
while ([DateTime]::UtcNow.Ticks -lt $barrier) { }
Start-Sleep -Milliseconds $delay
try {
    Import-Module '$manifestPath'
    `$listing = Get-ChildItem -LiteralPath '$fixture' | Out-String -Width 200
    if (`$Error.Count -gt 0) { "FAIL: `$(`$Error -join ' | ')" }
    elseif (-not `$listing.Contains('$goGlyph')) { 'FAIL: no icon in listing' }
    else { 'OK' }
} catch {
    "FAIL: `$(`$_.Exception.Message)"
}
"@
                Start-IsolatedPwsh -Command $command -Environment @{ TERMINALGLYPHS_CONFIG = $validConfig; APPDATA = $appData }
            }
            foreach ($result in ($handles | Wait-IsolatedPwsh)) {
                if ($result.Output -notmatch '(?m)^OK\s*$') { $failures.Add("round $($round): $($result.All.Trim())") }
            }
        }
        $failures | Should -BeNullOrEmpty
    }

    It 'does not write to the module folder, the config folder or APPDATA' {
        $before = Get-TreeSnapshot -Path (Split-Path -Parent $manifestPath), $configDir, $appData
        $command = "Import-Module '$manifestPath'; Get-ChildItem -LiteralPath '$fixture' | Out-String | Out-Null; 'DONE'"
        $result = Invoke-IsolatedPwsh -Command $command -Environment @{ TERMINALGLYPHS_CONFIG = $validConfig; APPDATA = $appData }
        $result.Output | Should -Match 'DONE'
        Get-TreeSnapshot -Path (Split-Path -Parent $manifestPath), $configDir, $appData | Should -Be $before
        @(Get-ChildItem -LiteralPath $appData -Recurse -Force).Count | Should -Be 0
    }

    It 'warns when Terminal-Icons is also loaded' {
        $command = "New-Module -Name 'Terminal-Icons' -ScriptBlock { } | Import-Module; Import-Module '$manifestPath'; 'DONE'"
        $result = Invoke-IsolatedPwsh -Command $command -Environment @{ TERMINALGLYPHS_CONFIG = (Join-Path $configDir 'missing.jsonc') }
        $result.All | Should -Match 'Terminal-Icons is also loaded'
    }
}
```

- [ ] **Step 3: Ejecutar y verificar que falla**

Run: `./build.ps1 -Task Test`
Expected: FAIL en `Format.Tests.ps1` y `Regression.Tests.ps1` (`Format-TerminalGlyph` no existe; sin aviso de conflicto).

- [ ] **Step 4: Implementar `src/Public/Format-TerminalGlyph.ps1`**

```powershell
function Format-TerminalGlyph {
    <#
    .SYNOPSIS
        Prefixes a file or folder name with its Nerd Font icon and color.
    .DESCRIPTION
        Used by the TerminalGlyphs view of Get-ChildItem. Resolves the icon and color with the active themes
        and your config. Never throws: if anything goes wrong, it returns the plain name.
    .PARAMETER InputObject
        The file or folder to format.
    .EXAMPLE
        Get-ChildItem
        TerminalGlyphs formats every item automatically.
    .EXAMPLE
        Get-Item ./go.mod | Format-TerminalGlyph
    .INPUTS
        System.IO.FileSystemInfo
    .OUTPUTS
        System.String
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.IO.FileSystemInfo]$InputObject
    )

    process {
        try {
            Initialize-TerminalGlyph
            $resolved = Resolve-TerminalGlyph -Name $InputObject.Name -Directory:($InputObject -is [System.IO.DirectoryInfo]) -LinkType ([string]$InputObject.LinkType)
            $text = if ($resolved.Icon) { "$($resolved.Icon)  $($InputObject.Name)" } else { $InputObject.Name }
            if ($InputObject.LinkTarget) { $text = "$text $($script:TGState.Arrow) $($InputObject.LinkTarget)" }
            if ($resolved.Color -and $PSStyle.OutputRendering -ne 'PlainText') {
                "$($resolved.Color)$text$($PSStyle.Reset)"
            } else {
                $text
            }
        } catch {
            $InputObject.Name
        }
    }
}
```

- [ ] **Step 5: Añadir el aviso de conflicto a `src/TerminalGlyphs.psm1`**

Inserta este bloque justo antes de la línea `Update-FormatData`:

```powershell
if (Get-Module -Name 'Terminal-Icons') {
    Write-Warning -Message 'TerminalGlyphs: Terminal-Icons is also loaded. Both modules replace the Get-ChildItem view; remove "Import-Module Terminal-Icons" from your profile.'
}
```

- [ ] **Step 6: Ejecutar y verificar que pasa**

Run: `./build.ps1 -Task Test`
Expected: todos en PASS (incluido el test de concurrencia: 24 sesiones, 0 fallos).

- [ ] **Step 7: Commit**

```powershell
git add src/Public/Format-TerminalGlyph.ps1 src/TerminalGlyphs.psm1 tests/Format.Tests.ps1 tests/Regression.Tests.ps1
git commit -m "Add Format-TerminalGlyph and import regression tests" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 8: Iconos y colores del stack

**Files:**
- Create: `tools/Set-ThemeEntry.ps1`
- Modify: `themes/icons/default.jsonc`, `themes/colors/default.jsonc`, `themes/colors/light.jsonc`, `themes/colors/dracula.jsonc`
- Test: `tests/Icons.Tests.ps1`

**Interfaces:**
- Consumes: `Initialize-TerminalGlyph`, `Resolve-TerminalGlyph` (Tareas 5–6).
- Produces: `./tools/Set-ThemeEntry.ps1 -Path <jsonc> -Section files.names|files.extensions|files.links|directories.names|directories.links -Entries <hashtable>` (conserva la cabecera de comentarios, ordena claves, elimina variantes de mayúsculas de la misma clave).

- [ ] **Step 1: Escribir el test guiado por datos (spec §6)**

`tests/Icons.Tests.ps1`:

```powershell
BeforeDiscovery {
    $rows = @(
        @{ Glyph = 'nf-dev-go'; Color = '00ADD8'; Files = 'main.go', 'go.mod', 'go.sum', 'go.work', 'go.work.sum' }
        @{ Glyph = 'nf-dev-rust'; Color = 'DEA584'; Files = 'main.rs', 'Cargo.toml', 'Cargo.lock', 'rust-toolchain', 'rust-toolchain.toml', 'rustfmt.toml', '.rustfmt.toml', 'clippy.toml' }
        @{ Glyph = 'nf-dev-cloudflareworkers'; Color = 'F38020'; Files = 'wrangler.toml', 'wrangler.json', 'wrangler.jsonc' }
        @{ Glyph = 'nf-dev-cloudflare'; Color = 'F38020'; Directories = '.wrangler' }
        @{ Glyph = 'nf-md-file_key'; Color = 'F38020'; Files = '.dev.vars' }
        @{ Glyph = 'nf-dev-terraform'; Color = '844FBA'; Files = 'main.tf', 'prod.tfvars', 'terraform.tfstate', 'config.hcl', '.terraform.lock.hcl'; Directories = '.terraform' }
        @{ Glyph = 'nf-dev-aws'; Color = 'FF9900'; Files = 'stack.cfn.yaml', 'stack.cfn.yml', 'stack.cfn.json', 'samconfig.toml', 'cdk.json'; Directories = '.aws-sam', 'cdk.out' }
        @{ Glyph = 'nf-md-chef_hat'; Files = 'mise.toml', '.mise.toml', 'mise.local.toml', '.tool-versions' }
        @{ Glyph = 'nf-dev-python'; Color = '3776AB'; Files = 'uv.lock', '.python-version', 'pyproject.toml'; Directories = '.venv' }
        @{ Glyph = 'nf-dev-pnpm'; Color = 'F69220'; Files = 'pnpm-lock.yaml', 'pnpm-workspace.yaml', '.pnpmfile.cjs' }
        @{ Glyph = 'nf-dev-bun'; Color = 'FBF0DF'; Files = 'bun.lock', 'bun.lockb', 'bunfig.toml' }
        @{ Glyph = 'nf-dev-astro'; Color = 'FF5D01'; Files = 'index.astro', 'astro.config.mjs', 'astro.config.ts', 'astro.config.js', 'astro.config.mts'; Directories = '.astro' }
        @{ Glyph = 'nf-dev-vite'; Color = '646CFF'; Files = 'vite.config.ts', 'vite.config.js', 'vite.config.mjs', 'vite.config.mts'; Directories = '.vitepress' }
        @{ Glyph = 'nf-dev-vitest'; Color = '729B1B'; Files = 'vitest.config.ts', 'vitest.config.js', 'vitest.config.mjs', 'vitest.config.mts' }
        @{ Glyph = 'nf-dev-docker'; Color = '2496ED'; Files = 'Dockerfile', 'docker-compose.yml', 'app.dockerfile', 'Containerfile', '.dockerignore', 'compose.yaml', 'compose.yml', 'docker-compose.yaml' }
        @{ Glyph = 'nf-cod-claude'; Color = 'D97757'; Files = 'CLAUDE.md', 'CLAUDE.local.md'; Directories = '.claude' }
        @{ Glyph = 'nf-md-ghost'; Directories = '.kiro' }
        @{ Glyph = 'nf-cod-sparkle'; Files = 'AGENTS.md', 'GEMINI.md', 'llms.txt', '.mcp.json', '.cursorrules', 'copilot-instructions.md'; Directories = '.gemini', '.cursor', '.codex' }
        @{ Glyph = 'nf-dev-biome'; Files = 'biome.json', 'biome.jsonc' }
        @{ Glyph = 'nf-dev-denojs'; Files = 'deno.json', 'deno.jsonc' }
        @{ Glyph = 'nf-custom-toml'; Files = 'config.toml' }
        @{ Glyph = 'nf-md-format_list_checks'; Files = 'justfile', 'Justfile', '.justfile' }
    )
    $cases = foreach ($row in $rows) {
        foreach ($name in @($row.Files)) { if ($name) { @{ Name = $name; Directory = $false; Glyph = $row.Glyph; Color = $row.Color } } }
        foreach ($name in @($row.Directories)) { if ($name) { @{ Name = $name; Directory = $true; Glyph = $row.Glyph; Color = $row.Color } } }
    }
    $colorCases = @($cases | Where-Object { $_.Color })
}

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $savedConfig = $env:TERMINALGLYPHS_CONFIG
    Import-Module (Get-BuiltManifestPath) -Force

    function Resolve-ForTest([string]$Name, [bool]$Directory, [string]$ColorTheme = 'default') {
        $config = Join-Path $TestDrive "$ColorTheme.jsonc"
        [System.IO.File]::WriteAllText($config, "{ `"colorTheme`": `"$ColorTheme`" }")
        $env:TERMINALGLYPHS_CONFIG = $config
        InModuleScope TerminalGlyphs -Parameters @{ N = $Name; D = $Directory; T = $ColorTheme } {
            param($N, $D, $T)
            if ($null -eq $script:TGState -or $script:TGState.ColorTheme -ne $T) { Initialize-TerminalGlyph -Force }
            Resolve-TerminalGlyph -Name $N -Directory:$D
        }
    }
}

AfterAll {
    $env:TERMINALGLYPHS_CONFIG = $savedConfig
    Remove-Module TerminalGlyphs -ErrorAction SilentlyContinue
}

Describe 'stack icons (spec section 6)' {
    It '<Name> uses <Glyph>' -ForEach $cases {
        (Resolve-ForTest -Name $Name -Directory $Directory).IconName | Should -BeExactly $Glyph
    }

    It '<Name> uses brand color <Color> in the default theme' -ForEach $colorCases {
        (Resolve-ForTest -Name $Name -Directory $Directory).ColorName | Should -BeExactly $Color
    }

    It '<Name> has a color in the light theme' -ForEach $colorCases {
        (Resolve-ForTest -Name $Name -Directory $Directory -ColorTheme 'light').ColorName | Should -Not -BeNullOrEmpty
    }

    It '<Name> has a color in the dracula theme' -ForEach $colorCases {
        (Resolve-ForTest -Name $Name -Directory $Directory -ColorTheme 'dracula').ColorName | Should -Not -BeNullOrEmpty
    }

    It 'darkens Bun and AWS in the light theme' {
        (Resolve-ForTest -Name 'bun.lock' -Directory $false -ColorTheme 'light').ColorName | Should -BeExactly '8A6D3B'
        (Resolve-ForTest -Name 'cdk.json' -Directory $false -ColorTheme 'light').ColorName | Should -BeExactly 'B26B00'
    }

    It 'keeps brand colors in the dracula theme' {
        (Resolve-ForTest -Name 'go.mod' -Directory $false -ColorTheme 'dracula').ColorName | Should -BeExactly '00ADD8'
    }
}
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `./build.ps1 -Task Test`
Expected: FAIL en `Icons.Tests.ps1` (p. ej. `go.mod uses nf-dev-go` → se obtuvo `nf-fa-file`).

- [ ] **Step 3: Escribir `tools/Set-ThemeEntry.ps1`**

```powershell
<#
.SYNOPSIS
    Adds or replaces entries in a TerminalGlyphs theme file (.jsonc).
.DESCRIPTION
    Keeps the leading comment lines, sorts the keys of the edited section and removes keys that differ
    only in case from the new ones (lookups are case-insensitive).
.EXAMPLE
    ./tools/Set-ThemeEntry.ps1 -Path themes/icons/default.jsonc -Section files.names -Entries @{ 'go.mod' = 'nf-dev-go' }
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter(Mandatory)]
    [ValidateSet('files.names', 'files.extensions', 'files.links', 'directories.names', 'directories.links')]
    [string]$Section,

    [Parameter(Mandatory)]
    [hashtable]$Entries
)

$ErrorActionPreference = 'Stop'
$fullPath = (Resolve-Path -LiteralPath $Path).ProviderPath
$lines = [System.IO.File]::ReadAllLines($fullPath)
$headerCount = 0
while ($headerCount -lt $lines.Count -and $lines[$headerCount] -match '^\s*//') { $headerCount++ }
$header = if ($headerCount -gt 0) { @($lines[0..($headerCount - 1)]) } else { @() }
$body = ($lines | Select-Object -Skip $headerCount) -join "`n"
$theme = ConvertFrom-Json -InputObject $body -AsHashtable -Depth 32

$kind, $sectionName = $Section.Split('.')
if (-not $theme.Contains($kind)) { $theme[$kind] = [ordered]@{} }
if (-not $theme[$kind].Contains($sectionName)) { $theme[$kind][$sectionName] = [ordered]@{} }
$map = $theme[$kind][$sectionName]
foreach ($key in $Entries.Keys) {
    foreach ($old in @($map.Keys | Where-Object { $_ -eq $key -and $_ -cne $key })) { $map.Remove($old) }
    $map[$key] = $Entries[$key]
}
$sorted = [ordered]@{}
foreach ($key in ($map.Keys | Sort-Object { $_.ToLowerInvariant() }, { $_ })) { $sorted[$key] = $map[$key] }
$theme[$kind][$sectionName] = $sorted

if ($PSCmdlet.ShouldProcess($fullPath, "Set $($Entries.Count) entries in $Section")) {
    $json = $theme | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($fullPath, ((@($header) + $json) -join "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
}
```

- [ ] **Step 4: Aplicar los iconos y colores del stack**

Ejecuta desde la raíz del repo:

```powershell
$icons = 'themes/icons/default.jsonc'
./tools/Set-ThemeEntry.ps1 -Path $icons -Section files.extensions -Entries @{
    '.go' = 'nf-dev-go'; '.rs' = 'nf-dev-rust'
    '.tf' = 'nf-dev-terraform'; '.tfvars' = 'nf-dev-terraform'; '.tfstate' = 'nf-dev-terraform'; '.hcl' = 'nf-dev-terraform'
    '.cfn.yaml' = 'nf-dev-aws'; '.cfn.yml' = 'nf-dev-aws'; '.cfn.json' = 'nf-dev-aws'
    '.astro' = 'nf-dev-astro'; '.dockerfile' = 'nf-dev-docker'; '.toml' = 'nf-custom-toml'
}
./tools/Set-ThemeEntry.ps1 -Path $icons -Section files.names -Entries @{
    'go.mod' = 'nf-dev-go'; 'go.sum' = 'nf-dev-go'; 'go.work' = 'nf-dev-go'; 'go.work.sum' = 'nf-dev-go'
    'Cargo.toml' = 'nf-dev-rust'; 'Cargo.lock' = 'nf-dev-rust'; 'rust-toolchain' = 'nf-dev-rust'; 'rust-toolchain.toml' = 'nf-dev-rust'
    'rustfmt.toml' = 'nf-dev-rust'; '.rustfmt.toml' = 'nf-dev-rust'; 'clippy.toml' = 'nf-dev-rust'
    'wrangler.toml' = 'nf-dev-cloudflareworkers'; 'wrangler.json' = 'nf-dev-cloudflareworkers'; 'wrangler.jsonc' = 'nf-dev-cloudflareworkers'
    '.dev.vars' = 'nf-md-file_key'
    '.terraform.lock.hcl' = 'nf-dev-terraform'
    'samconfig.toml' = 'nf-dev-aws'; 'cdk.json' = 'nf-dev-aws'
    'mise.toml' = 'nf-md-chef_hat'; '.mise.toml' = 'nf-md-chef_hat'; 'mise.local.toml' = 'nf-md-chef_hat'; '.tool-versions' = 'nf-md-chef_hat'
    'uv.lock' = 'nf-dev-python'; '.python-version' = 'nf-dev-python'; 'pyproject.toml' = 'nf-dev-python'
    'pnpm-lock.yaml' = 'nf-dev-pnpm'; 'pnpm-workspace.yaml' = 'nf-dev-pnpm'; '.pnpmfile.cjs' = 'nf-dev-pnpm'
    'bun.lock' = 'nf-dev-bun'; 'bun.lockb' = 'nf-dev-bun'; 'bunfig.toml' = 'nf-dev-bun'
    'astro.config.mjs' = 'nf-dev-astro'; 'astro.config.ts' = 'nf-dev-astro'; 'astro.config.js' = 'nf-dev-astro'; 'astro.config.mts' = 'nf-dev-astro'
    'vite.config.ts' = 'nf-dev-vite'; 'vite.config.js' = 'nf-dev-vite'; 'vite.config.mjs' = 'nf-dev-vite'; 'vite.config.mts' = 'nf-dev-vite'
    'vitest.config.ts' = 'nf-dev-vitest'; 'vitest.config.js' = 'nf-dev-vitest'; 'vitest.config.mjs' = 'nf-dev-vitest'; 'vitest.config.mts' = 'nf-dev-vitest'
    'Dockerfile' = 'nf-dev-docker'; 'docker-compose.yml' = 'nf-dev-docker'; 'Containerfile' = 'nf-dev-docker'; '.dockerignore' = 'nf-dev-docker'
    'compose.yaml' = 'nf-dev-docker'; 'compose.yml' = 'nf-dev-docker'; 'docker-compose.yaml' = 'nf-dev-docker'
    'CLAUDE.md' = 'nf-cod-claude'; 'CLAUDE.local.md' = 'nf-cod-claude'
    'AGENTS.md' = 'nf-cod-sparkle'; 'GEMINI.md' = 'nf-cod-sparkle'; 'llms.txt' = 'nf-cod-sparkle'; '.mcp.json' = 'nf-cod-sparkle'
    '.cursorrules' = 'nf-cod-sparkle'; 'copilot-instructions.md' = 'nf-cod-sparkle'
    'biome.json' = 'nf-dev-biome'; 'biome.jsonc' = 'nf-dev-biome'
    'deno.json' = 'nf-dev-denojs'; 'deno.jsonc' = 'nf-dev-denojs'
    'justfile' = 'nf-md-format_list_checks'; '.justfile' = 'nf-md-format_list_checks'
}
./tools/Set-ThemeEntry.ps1 -Path $icons -Section directories.names -Entries @{
    '.wrangler' = 'nf-dev-cloudflare'; '.terraform' = 'nf-dev-terraform'; '.aws-sam' = 'nf-dev-aws'; 'cdk.out' = 'nf-dev-aws'
    '.venv' = 'nf-dev-python'; '.astro' = 'nf-dev-astro'; '.vitepress' = 'nf-dev-vite'; '.claude' = 'nf-cod-claude'
    '.kiro' = 'nf-md-ghost'; '.gemini' = 'nf-cod-sparkle'; '.cursor' = 'nf-cod-sparkle'; '.codex' = 'nf-cod-sparkle'
}

$colorExtensions = @{
    '.go' = '00ADD8'; '.rs' = 'DEA584'
    '.tf' = '844FBA'; '.tfvars' = '844FBA'; '.tfstate' = '844FBA'; '.hcl' = '844FBA'
    '.cfn.yaml' = 'FF9900'; '.cfn.yml' = 'FF9900'; '.cfn.json' = 'FF9900'
    '.astro' = 'FF5D01'; '.dockerfile' = '2496ED'
}
$colorNames = @{
    'go.mod' = '00ADD8'; 'go.sum' = '00ADD8'; 'go.work' = '00ADD8'; 'go.work.sum' = '00ADD8'
    'Cargo.toml' = 'DEA584'; 'Cargo.lock' = 'DEA584'; 'rust-toolchain' = 'DEA584'; 'rust-toolchain.toml' = 'DEA584'
    'rustfmt.toml' = 'DEA584'; '.rustfmt.toml' = 'DEA584'; 'clippy.toml' = 'DEA584'
    'wrangler.toml' = 'F38020'; 'wrangler.json' = 'F38020'; 'wrangler.jsonc' = 'F38020'; '.dev.vars' = 'F38020'
    '.terraform.lock.hcl' = '844FBA'
    'samconfig.toml' = 'FF9900'; 'cdk.json' = 'FF9900'
    'uv.lock' = '3776AB'; '.python-version' = '3776AB'; 'pyproject.toml' = '3776AB'
    'pnpm-lock.yaml' = 'F69220'; 'pnpm-workspace.yaml' = 'F69220'; '.pnpmfile.cjs' = 'F69220'
    'bun.lock' = 'FBF0DF'; 'bun.lockb' = 'FBF0DF'; 'bunfig.toml' = 'FBF0DF'
    'astro.config.mjs' = 'FF5D01'; 'astro.config.ts' = 'FF5D01'; 'astro.config.js' = 'FF5D01'; 'astro.config.mts' = 'FF5D01'
    'vite.config.ts' = '646CFF'; 'vite.config.js' = '646CFF'; 'vite.config.mjs' = '646CFF'; 'vite.config.mts' = '646CFF'
    'vitest.config.ts' = '729B1B'; 'vitest.config.js' = '729B1B'; 'vitest.config.mjs' = '729B1B'; 'vitest.config.mts' = '729B1B'
    'Dockerfile' = '2496ED'; 'docker-compose.yml' = '2496ED'; 'Containerfile' = '2496ED'; '.dockerignore' = '2496ED'
    'compose.yaml' = '2496ED'; 'compose.yml' = '2496ED'; 'docker-compose.yaml' = '2496ED'
    'CLAUDE.md' = 'D97757'; 'CLAUDE.local.md' = 'D97757'
}
$colorDirectories = @{
    '.wrangler' = 'F38020'; '.terraform' = '844FBA'; '.aws-sam' = 'FF9900'; 'cdk.out' = 'FF9900'
    '.venv' = '3776AB'; '.astro' = 'FF5D01'; '.vitepress' = '646CFF'; '.claude' = 'D97757'
}
foreach ($themeName in 'default', 'light', 'dracula') {
    # Light background: Bun cream and AWS orange do not have enough contrast.
    $adjust = if ($themeName -eq 'light') { @{ 'FBF0DF' = '8A6D3B'; 'FF9900' = 'B26B00' } } else { @{} }
    $path = "themes/colors/$themeName.jsonc"
    foreach ($pair in @(@('files.extensions', $colorExtensions), @('files.names', $colorNames), @('directories.names', $colorDirectories))) {
        $entries = @{}
        foreach ($key in $pair[1].Keys) {
            $value = $pair[1][$key]
            $entries[$key] = if ($adjust.ContainsKey($value)) { $adjust[$value] } else { $value }
        }
        ./tools/Set-ThemeEntry.ps1 -Path $path -Section $pair[0] -Entries $entries
    }
}
git diff --stat
```

Expected: `git diff --stat` muestra cambios en los 4 archivos de `themes/`; no hay errores.

- [ ] **Step 5: Ejecutar y verificar que pasa**

Run: `./build.ps1 -Task Test`
Expected: todos en PASS, incluidos `Icons.Tests.ps1` y `Themes.Tests.ps1` (sin duplicados por mayúsculas).

- [ ] **Step 6: Commit**

```powershell
git add tools/Set-ThemeEntry.ps1 themes tests/Icons.Tests.ps1
git commit -m "Add icons and colors for Go, Rust, Cloudflare, Terraform, AWS, JS tooling, Docker and AI tools" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 9: Comandos públicos y JSON Schema

**Files:**
- Create: `src/Public/Get-TerminalGlyph.ps1`, `src/Public/Show-TerminalGlyphTheme.ps1`, `src/Public/Find-NerdGlyph.ps1`, `src/Public/Update-TerminalGlyphConfig.ps1`
- Create: `schema/config.schema.json`
- Test: `tests/Commands.Tests.ps1`

**Interfaces:**
- Consumes: Tareas 5–7.
- Produces:
  - `Get-TerminalGlyph [-Path] <string[]>` | `-LiteralPath <string[]>` (alias `PSPath`, por pipeline) → `TerminalGlyphs.GlyphInfo { Name; Icon; IconName; Color (hex); Rule; Source }`.
  - `Show-TerminalGlyphTheme [-Kind files|directories]` → `[string]` por mapeo: `"<icono>  <clave padded 28> <kind>.<section>"` (con color salvo `PlainText`).
  - `Find-NerdGlyph [-Name] <string>` → `TerminalGlyphs.NerdGlyph { Name; Glyph; CodePoint 'U+XXXX' }`; sin comodines busca `*<Name>*`.
  - `Update-TerminalGlyphConfig` (`SupportsShouldProcess`) → limpia `$script:Warned` y llama a `Initialize-TerminalGlyph -Force`.

- [ ] **Step 1: Escribir los tests**

`tests/Commands.Tests.ps1`:

```powershell
BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $savedConfig = $env:TERMINALGLYPHS_CONFIG
    $configPath = Join-Path $TestDrive 'config.jsonc'
    $env:TERMINALGLYPHS_CONFIG = $configPath
    Import-Module (Get-BuiltManifestPath) -Force
    $fixture = New-FileFixture -Root (Join-Path $TestDrive 'project') -File 'go.mod', '[draft].md', 'robot.txt' -Directory '.claude'
    $schemaPath = Join-Path $script:RepoRoot 'schema' 'config.schema.json'
}

AfterAll {
    $env:TERMINALGLYPHS_CONFIG = $savedConfig
    Remove-Module TerminalGlyphs -ErrorAction SilentlyContinue
}

Describe 'Get-TerminalGlyph' {
    BeforeAll { Update-TerminalGlyphConfig }

    It 'explains which rule matched' {
        $info = Get-TerminalGlyph -Path (Join-Path $fixture 'go.mod')
        $info.PSObject.TypeNames[0] | Should -Be 'TerminalGlyphs.GlyphInfo'
        $info.Name | Should -Be 'go.mod'
        $info.IconName | Should -Be 'nf-dev-go'
        $info.Icon | Should -Be (Get-GlyphChar 'nf-dev-go')
        $info.Color | Should -Be '00ADD8'
        $info.Rule | Should -Be 'files.names[go.mod]'
        $info.Source | Should -Be 'theme:default'
    }

    It 'accepts Get-ChildItem output, including names with wildcard characters' {
        $infos = Get-ChildItem -LiteralPath $fixture -Force | Get-TerminalGlyph
        $infos.Name | Should -Contain '[draft].md'
        ($infos | Where-Object Name -EQ '.claude').IconName | Should -Be 'nf-cod-claude'
    }

    It 'accepts -LiteralPath' {
        (Get-TerminalGlyph -LiteralPath (Join-Path $fixture '[draft].md')).Rule | Should -Be 'files.extensions[.md]'
    }
}

Describe 'Update-TerminalGlyphConfig' {
    It 'reloads the config and shows warnings again' {
        [System.IO.File]::WriteAllText($configPath, '{ "icons": { "files": { "names": { "robot.txt": "nf-md-robot_angry", "x.txt": "nf-nope" } } } }')
        @(Update-TerminalGlyphConfig 3>&1).Count | Should -Be 1
        @(Update-TerminalGlyphConfig 3>&1).Count | Should -Be 1
        $info = Get-TerminalGlyph -Path (Join-Path $fixture 'robot.txt')
        $info.IconName | Should -Be 'nf-md-robot_angry'
        $info.Source | Should -Be 'user-config'
        [System.IO.File]::WriteAllText($configPath, '{ }')
        Update-TerminalGlyphConfig
        (Get-TerminalGlyph -Path (Join-Path $fixture 'robot.txt')).Source | Should -Be 'theme:default'
    }

    It 'supports -WhatIf' {
        { Update-TerminalGlyphConfig -WhatIf } | Should -Not -Throw
    }
}

Describe 'Find-NerdGlyph' {
    It 'finds glyphs by partial name' {
        $result = Find-NerdGlyph cloudflare
        $result.Name | Should -Contain 'nf-dev-cloudflare'
        ($result | Where-Object Name -EQ 'nf-dev-cloudflare').CodePoint | Should -Be 'U+E792'
    }

    It 'honors wildcards' {
        (Find-NerdGlyph 'nf-cod-claud?').Name | Should -Be 'nf-cod-claude'
    }

    It 'reports glyphs above U+FFFF' {
        (Find-NerdGlyph 'nf-md-arrow_right_thick' | Where-Object Name -EQ 'nf-md-arrow_right_thick').CodePoint | Should -Be 'U+F0055'
    }

    It 'returns nothing for unknown names' {
        Find-NerdGlyph 'zzz-no-such-glyph' | Should -BeNullOrEmpty
    }
}

Describe 'Show-TerminalGlyphTheme' {
    It 'lists one line per mapping' {
        Update-TerminalGlyphConfig
        $saved = $PSStyle.OutputRendering
        try {
            $PSStyle.OutputRendering = 'PlainText'
            $lines = Show-TerminalGlyphTheme -Kind files
        } finally {
            $PSStyle.OutputRendering = $saved
        }
        $lines | Should -Contain ('{0}  {1,-28} {2}' -f (Get-GlyphChar 'nf-dev-go'), 'go.mod', 'files.names')
        $lines | Should -Contain ('{0}  {1,-28} {2}' -f (Get-GlyphChar 'nf-dev-go'), '.go', 'files.extensions')
        ($lines | Where-Object { $_ -match 'directories\.' }) | Should -BeNullOrEmpty
    }
}

Describe 'config.schema.json' {
    It 'accepts a valid config' {
        $json = '{ "$schema": "x", "iconTheme": "default", "colorTheme": "dracula", "icons": { "files": { "names": { "justfile": "nf-md-format_list_checks" }, "extensions": { ".go": "nf-dev-go" }, "links": { "symlink": "nf-oct-file_symlink_file" }, "default": "nf-fa-file" }, "directories": { "names": { ".kiro": "nf-md-ghost" } } }, "colors": { "files": { "extensions": { ".go": "#00ADD8" } } } }'
        Test-Json -Json $json -SchemaFile $schemaPath | Should -BeTrue
    }

    It 'rejects <Case>' -ForEach @(
        @{ Case = 'an unknown theme'; Json = '{ "colorTheme": "nope" }' }
        @{ Case = 'an extension without a dot'; Json = '{ "icons": { "files": { "extensions": { "go": "nf-dev-go" } } } }' }
        @{ Case = 'a value that is not a glyph name'; Json = '{ "icons": { "files": { "names": { "a": "go" } } } }' }
        @{ Case = 'an invalid color'; Json = '{ "colors": { "files": { "names": { "a": "blue" } } } }' }
        @{ Case = 'an unknown property'; Json = '{ "theme": "default" }' }
        @{ Case = 'extensions under directories'; Json = '{ "icons": { "directories": { "extensions": { ".x": "nf-dev-go" } } } }' }
    ) {
        Test-Json -Json $Json -SchemaFile $schemaPath -ErrorAction SilentlyContinue | Should -BeFalse
    }

    It 'lists exactly the built-in themes' {
        $schema = Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json -AsHashtable
        $data = Get-Content -LiteralPath (Join-Path (Split-Path -Parent (Get-BuiltManifestPath)) 'TerminalGlyphs.data.json') -Raw | ConvertFrom-Json -AsHashtable
        @($schema['properties']['iconTheme']['enum'] | Sort-Object) | Should -Be @($data['iconThemes'].Keys | Sort-Object)
        @($schema['properties']['colorTheme']['enum'] | Sort-Object) | Should -Be @($data['colorThemes'].Keys | Sort-Object)
    }
}
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `./build.ps1 -Task Test`
Expected: FAIL en `Commands.Tests.ps1` (comandos y schema inexistentes).

- [ ] **Step 3: Implementar los comandos**

`src/Public/Get-TerminalGlyph.ps1`:

```powershell
function Get-TerminalGlyph {
    <#
    .SYNOPSIS
        Shows which icon and color TerminalGlyphs uses for a file or folder, and why.
    .DESCRIPTION
        Resolves the icon and color with the active themes and your config, and reports the rule that matched
        (for example files.names[go.mod]) and where it came from (theme:<name> or user-config).
    .PARAMETER Path
        Path to a file or folder. Supports wildcards.
    .PARAMETER LiteralPath
        Path used exactly as typed. Objects from Get-ChildItem bind here through PSPath.
    .EXAMPLE
        Get-TerminalGlyph ./go.mod
    .EXAMPLE
        Get-ChildItem | Get-TerminalGlyph
    .OUTPUTS
        TerminalGlyphs.GlyphInfo
    #>
    [OutputType('TerminalGlyphs.GlyphInfo')]
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ParameterSetName = 'Path')]
        [string[]]$Path,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'LiteralPath')]
        [Alias('PSPath')]
        [string[]]$LiteralPath
    )

    begin {
        Initialize-TerminalGlyph
    }

    process {
        $items = if ($PSCmdlet.ParameterSetName -eq 'Path') {
            Get-Item -Path $Path -Force
        } else {
            Get-Item -LiteralPath $LiteralPath -Force
        }
        foreach ($item in $items) {
            if ($item -isnot [System.IO.FileSystemInfo]) { continue }
            $resolved = Resolve-TerminalGlyph -Name $item.Name -Directory:($item -is [System.IO.DirectoryInfo]) -LinkType ([string]$item.LinkType)
            [pscustomobject]@{
                PSTypeName = 'TerminalGlyphs.GlyphInfo'
                Name       = $item.Name
                Icon       = $resolved.Icon
                IconName   = $resolved.IconName
                Color      = $resolved.ColorName
                Rule       = $resolved.Rule
                Source     = $resolved.Source
            }
        }
    }
}
```

`src/Public/Show-TerminalGlyphTheme.ps1`:

```powershell
function Show-TerminalGlyphTheme {
    <#
    .SYNOPSIS
        Previews the active icon and color themes, one line per mapping.
    .PARAMETER Kind
        Which mappings to show: files, directories or both (default).
    .EXAMPLE
        Show-TerminalGlyphTheme -Kind directories
    .OUTPUTS
        System.String
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [ValidateSet('files', 'directories')]
        [string[]]$Kind = @('directories', 'files')
    )

    Initialize-TerminalGlyph
    $plain = $PSStyle.OutputRendering -eq 'PlainText'
    foreach ($kindName in $Kind) {
        $sections = if ($kindName -eq 'files') { @('names', 'extensions') } else { @('names') }
        foreach ($section in $sections) {
            $map = $script:TGState.Icons[$kindName][$section]
            foreach ($key in ($map.Keys | Sort-Object)) {
                $sample = if ($section -eq 'extensions') { "example$key" } else { $key }
                $resolved = Resolve-TerminalGlyph -Name $sample -Directory:($kindName -eq 'directories')
                $text = '{0}  {1,-28} {2}' -f $resolved.Icon, $key, "$kindName.$section"
                if ($resolved.Color -and -not $plain) { "$($resolved.Color)$text$($PSStyle.Reset)" } else { $text }
            }
        }
    }
}
```

`src/Public/Find-NerdGlyph.ps1`:

```powershell
function Find-NerdGlyph {
    <#
    .SYNOPSIS
        Searches the Nerd Fonts 3.5.1 glyph names to use in your TerminalGlyphs config.
    .PARAMETER Name
        Part of a glyph name (for example cloudflare) or a wildcard pattern (nf-dev-*).
    .EXAMPLE
        Find-NerdGlyph cloudflare
    .EXAMPLE
        Find-NerdGlyph 'nf-md-folder_*'
    .OUTPUTS
        TerminalGlyphs.NerdGlyph
    #>
    [OutputType('TerminalGlyphs.NerdGlyph')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name
    )

    $pattern = if ([WildcardPattern]::ContainsWildcardCharacters($Name)) { $Name } else { "*$Name*" }
    $map = Get-FullGlyphMap
    foreach ($glyphName in ($map.Keys | Where-Object { $_ -like $pattern } | Sort-Object)) {
        $glyph = $map[$glyphName]
        [pscustomobject]@{
            PSTypeName = 'TerminalGlyphs.NerdGlyph'
            Name       = $glyphName
            Glyph      = $glyph
            CodePoint  = 'U+{0:X4}' -f [char]::ConvertToUtf32($glyph, 0)
        }
    }
}
```

`src/Public/Update-TerminalGlyphConfig.ps1`:

```powershell
function Update-TerminalGlyphConfig {
    <#
    .SYNOPSIS
        Reloads your TerminalGlyphs config without restarting the session.
    .DESCRIPTION
        Re-reads the config file and shows its validation warnings again, even if they were shown before.
        The config path is $env:TERMINALGLYPHS_CONFIG, $env:XDG_CONFIG_HOME/terminalglyphs/config.jsonc
        or ~/.config/terminalglyphs/config.jsonc.
    .EXAMPLE
        Update-TerminalGlyphConfig
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess((Get-ConfigPath), 'Reload TerminalGlyphs config')) {
        $script:Warned.Clear()
        Initialize-TerminalGlyph -Force
    }
}
```

- [ ] **Step 4: Crear `schema/config.schema.json`**

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://raw.githubusercontent.com/marr-cloud/TerminalGlyphs/main/schema/config.schema.json",
  "title": "TerminalGlyphs configuration",
  "description": "Optional user config for TerminalGlyphs. Entries in icons and colors are merged on top of the selected themes.",
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "$schema": { "type": "string" },
    "iconTheme": { "description": "Built-in icon theme.", "enum": ["default"] },
    "colorTheme": { "description": "Built-in color theme.", "enum": ["default", "light", "dracula"] },
    "icons": { "$ref": "#/$defs/iconLayer" },
    "colors": { "$ref": "#/$defs/colorLayer" }
  },
  "$defs": {
    "glyph": {
      "type": "string",
      "pattern": "^nf-[a-z0-9_-]+$",
      "description": "Nerd Fonts 3.5.1 glyph name, for example nf-dev-go. Search with Find-NerdGlyph."
    },
    "color": {
      "type": "string",
      "pattern": "^#?[0-9A-Fa-f]{6}$",
      "description": "Hex color RRGGBB, with or without #."
    },
    "glyphMap": { "type": "object", "additionalProperties": { "$ref": "#/$defs/glyph" } },
    "colorMap": { "type": "object", "additionalProperties": { "$ref": "#/$defs/color" } },
    "extensionNames": { "propertyNames": { "pattern": "^\\." } },
    "iconLinks": {
      "type": "object",
      "additionalProperties": false,
      "properties": { "symlink": { "$ref": "#/$defs/glyph" }, "junction": { "$ref": "#/$defs/glyph" } }
    },
    "colorLinks": {
      "type": "object",
      "additionalProperties": false,
      "properties": { "symlink": { "$ref": "#/$defs/color" }, "junction": { "$ref": "#/$defs/color" } }
    },
    "iconLayer": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "files": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "names": { "$ref": "#/$defs/glyphMap" },
            "extensions": { "allOf": [{ "$ref": "#/$defs/glyphMap" }, { "$ref": "#/$defs/extensionNames" }] },
            "links": { "$ref": "#/$defs/iconLinks" },
            "default": { "$ref": "#/$defs/glyph" }
          }
        },
        "directories": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "names": { "$ref": "#/$defs/glyphMap" },
            "links": { "$ref": "#/$defs/iconLinks" },
            "default": { "$ref": "#/$defs/glyph" }
          }
        }
      }
    },
    "colorLayer": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "files": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "names": { "$ref": "#/$defs/colorMap" },
            "extensions": { "allOf": [{ "$ref": "#/$defs/colorMap" }, { "$ref": "#/$defs/extensionNames" }] },
            "links": { "$ref": "#/$defs/colorLinks" },
            "default": { "$ref": "#/$defs/color" }
          }
        },
        "directories": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "names": { "$ref": "#/$defs/colorMap" },
            "links": { "$ref": "#/$defs/colorLinks" },
            "default": { "$ref": "#/$defs/color" }
          }
        }
      }
    }
  }
}
```

- [ ] **Step 5: Ejecutar y verificar que pasa**

Run: `./build.ps1 -Task Test`
Expected: todos en PASS.

- [ ] **Step 6: Commit**

```powershell
git add src/Public schema tests/Commands.Tests.ps1
git commit -m "Add Get-TerminalGlyph, Show-TerminalGlyphTheme, Find-NerdGlyph, Update-TerminalGlyphConfig and config schema" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 10: Calidad y rendimiento

**Files:**
- Create: `tests/PSScriptAnalyzerSettings.psd1`, `tests/Quality.Tests.ps1`, `tests/Performance.Tests.ps1`
- Modify (solo si los tests lo exigen): archivos de `src/`, `build.ps1`, `tools/` para corregir avisos del analizador.

**Interfaces:**
- Consumes: todo lo anterior.
- Produces: nada nuevo; puertas de calidad.

- [ ] **Step 1: Escribir la configuración y los tests**

`tests/PSScriptAnalyzerSettings.psd1`:

```powershell
@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @('PSAvoidUsingWriteHost')
}
```

`tests/Quality.Tests.ps1`:

```powershell
BeforeDiscovery {
    $publicFunctions = @('Format-TerminalGlyph', 'Get-TerminalGlyph', 'Show-TerminalGlyphTheme', 'Find-NerdGlyph', 'Update-TerminalGlyphConfig') |
        ForEach-Object { @{ Name = $_ } }
}

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $manifestPath = Get-BuiltManifestPath
    $module = Import-Module $manifestPath -Force -PassThru
}

AfterAll {
    Remove-Module TerminalGlyphs -ErrorAction SilentlyContinue
}

Describe 'module manifest' {
    It 'targets pwsh 7.4+ Core only' {
        $manifest = Test-ModuleManifest -Path $manifestPath
        $manifest.PowerShellVersion | Should -Be ([version]'7.4')
        $manifest.CompatiblePSEditions | Should -Be @('Core')
        $manifest.Version | Should -Be ([version]'0.1.0')
        $manifest.Guid | Should -Be ([guid]'191db48e-7499-4eff-8584-fb8c62a2ddee')
    }

    It 'exports exactly the public API' {
        @($module.ExportedFunctions.Keys | Sort-Object) | Should -Be @('Find-NerdGlyph', 'Format-TerminalGlyph', 'Get-TerminalGlyph', 'Show-TerminalGlyphTheme', 'Update-TerminalGlyphConfig')
        $module.ExportedCmdlets.Count | Should -Be 0
        $module.ExportedAliases.Count | Should -Be 0
    }
}

Describe '<Name> help' -ForEach $publicFunctions {
    BeforeAll { $help = Get-Help -Name $Name -Full }

    It 'has a synopsis' {
        $help.Synopsis | Should -Not -BeNullOrEmpty
        # Without comment-based help, Get-Help returns the syntax line ("Name [-Param] ...") as the synopsis.
        $help.Synopsis | Should -Not -Match ('^' + [regex]::Escape($Name) + '\s+\[')
    }

    It 'has at least one example' {
        @($help.Examples.Example).Count | Should -BeGreaterThan 0
    }
}

Describe 'PSScriptAnalyzer' {
    It 'reports no errors or warnings in <Target>' -ForEach @(
        @{ Target = 'src' }, @{ Target = 'build.ps1' }, @{ Target = 'tools' }
    ) {
        Import-Module PSScriptAnalyzer -RequiredVersion 1.25.0
        $results = Invoke-ScriptAnalyzer -Path (Join-Path $script:RepoRoot $Target) -Recurse -Settings (Join-Path $PSScriptRoot 'PSScriptAnalyzerSettings.psd1')
        $results | ForEach-Object { "$($_.ScriptName):$($_.Line) $($_.RuleName) $($_.Message)" } | Should -BeNullOrEmpty
    }

    It 'keeps source files ASCII-only' {
        $files = Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot 'src'), (Join-Path $script:RepoRoot 'tools') -Recurse -File -Include '*.ps1', '*.psm1', '*.psd1', '*.ps1xml'
        $files += Get-Item -LiteralPath (Join-Path $script:RepoRoot 'build.ps1')
        $nonAscii = $files | Where-Object { [System.IO.File]::ReadAllText($_.FullName) -match '[^\x00-\x7F]' }
        $nonAscii.FullName | Should -BeNullOrEmpty
    }
}
```

`tests/Performance.Tests.ps1`:

```powershell
Describe 'performance' -Tag 'Performance' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
        $manifestPath = Get-BuiltManifestPath
        $fixture = New-FileFixture -Root (Join-Path $TestDrive 'project') -File 'main.go', 'go.mod', 'README.md' -Directory '.claude'
        $childEnv = @{ TERMINALGLYPHS_CONFIG = (Join-Path $TestDrive 'missing.jsonc') }
    }

    It 'imports in under 100 ms (median of 5, pwsh -NoProfile)' {
        $times = foreach ($i in 1..5) {
            $result = Invoke-IsolatedPwsh -Environment $childEnv -Command "(Measure-Command { Import-Module '$manifestPath' }).TotalMilliseconds.ToString([cultureinfo]::InvariantCulture)"
            [double]::Parse($result.Output.Trim(), [cultureinfo]::InvariantCulture)
        }
        $median = ($times | Sort-Object)[2]
        Write-Host ("Import-Module: {0}  median {1:N1} ms" -f (($times | ForEach-Object { '{0:N1}' -f $_ }) -join ', '), $median)
        $median | Should -BeLessThan 100
    }

    It 'reports the first listing time' {
        $result = Invoke-IsolatedPwsh -Environment $childEnv -Command "Import-Module '$manifestPath'; (Measure-Command { Get-ChildItem -LiteralPath '$fixture' | Out-String }).TotalMilliseconds.ToString([cultureinfo]::InvariantCulture)"
        $firstListing = [double]::Parse($result.Output.Trim(), [cultureinfo]::InvariantCulture)
        Write-Host ("First Get-ChildItem (lazy initialization): {0:N1} ms" -f $firstListing)
        $firstListing | Should -BeLessThan 2000
    }
}
```

- [ ] **Step 2: Ejecutar los tests de calidad**

Run: `./build.ps1 -Task Test`
Expected: PASS. Si PSScriptAnalyzer reporta avisos, corrígelos en el código (p. ej. parámetros con nombre en vez de posicionales) y vuelve a ejecutar; **no** añadas reglas a `ExcludeRules` sin justificarlo en el informe de la tarea.

- [ ] **Step 3: Ejecutar los tests de rendimiento**

Run: `./build.ps1 -Task Test -Tag Performance -ExcludeTag @()`
Expected: PASS, con las líneas `Import-Module: ... median N ms` y `First Get-ChildItem ...`. Si la mediana ≥ 100 ms, **para e informa** de las cifras: no cambies el umbral (Global Constraints).

- [ ] **Step 4: Commit**

```powershell
git add tests/PSScriptAnalyzerSettings.psd1 tests/Quality.Tests.ps1 tests/Performance.Tests.ps1 src build.ps1 tools
git commit -m "Add quality and performance tests" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 11: Licencias, documentación y CI

**Files:**
- Create: `LICENSE`, `THIRD_PARTY_NOTICES.md`, `README.md`, `CHANGELOG.md`, `.github/workflows/ci.yml`, `.github/workflows/publish.yml`
- Test: `tests/Meta.Tests.ps1`

**Interfaces:**
- Consumes: `build.ps1` copia `LICENSE` y `THIRD_PARTY_NOTICES.md` al módulo (Tarea 4).
- Produces: documentación y workflows (no se suben a GitHub en este plan).

- [ ] **Step 1: Escribir los tests**

`tests/Meta.Tests.ps1`:

```powershell
BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    function Get-RepoText([string]$Path) { [System.IO.File]::ReadAllText((Join-Path $script:RepoRoot $Path)) }
}

Describe 'licensing' {
    It 'LICENSE is MIT with both copyright lines' {
        $license = Get-RepoText 'LICENSE'
        $license | Should -Match 'MIT License'
        $license | Should -Match ([regex]::Escape('Copyright (c) 2026 marr-cloud'))
        $license | Should -Match ([regex]::Escape('Copyright (c) 2019 Brandon Olin'))
    }

    It 'THIRD_PARTY_NOTICES.md credits <Project>' -ForEach @(
        @{ Project = 'Terminal-Icons'; Copyright = 'Copyright (c) 2019 Brandon Olin' }
        @{ Project = 'DirColors'; Copyright = 'Copyright 2017 Dustin L. Howett' }
        @{ Project = 'Nerd Fonts'; Copyright = 'Copyright (c) 2014 Ryan L McIntyre' }
    ) {
        $notices = Get-RepoText 'THIRD_PARTY_NOTICES.md'
        $notices | Should -Match ([regex]::Escape($Project))
        $notices | Should -Match ([regex]::Escape($Copyright))
    }

    It 'ships LICENSE and THIRD_PARTY_NOTICES.md with the built module' {
        $moduleDir = Split-Path -Parent (Get-BuiltManifestPath)
        Join-Path $moduleDir 'LICENSE' | Should -Exist
        Join-Path $moduleDir 'THIRD_PARTY_NOTICES.md' | Should -Exist
    }
}

Describe 'documentation' {
    It 'README states the requirements and the migration from Terminal-Icons' {
        $readme = Get-RepoText 'README.md'
        $readme | Should -Match 'PowerShell 7\.4'
        $readme | Should -Match 'Nerd Font.*3\.5\.1'
        $readme | Should -Match 'Import-Module TerminalGlyphs'
        $readme | Should -Match 'TERMINALGLYPHS_CONFIG'
    }

    It 'CHANGELOG follows Keep a Changelog' {
        $changelog = Get-RepoText 'CHANGELOG.md'
        $changelog | Should -Match 'keepachangelog\.com'
        $changelog | Should -Match '## \[Unreleased\]'
    }
}

Describe 'workflows' {
    It 'CI runs on Windows and Linux' {
        $ci = Get-RepoText '.github/workflows/ci.yml'
        $ci | Should -Match 'windows-latest'
        $ci | Should -Match 'ubuntu-latest'
        $ci | Should -Match ([regex]::Escape('./build.ps1 -Task Test'))
    }

    It 'publishing only runs manually' {
        $publish = Get-RepoText '.github/workflows/publish.yml'
        $publish | Should -Match 'workflow_dispatch'
        $publish | Should -Not -Match '(?m)^\s*(push|pull_request|release|schedule):'
        $publish | Should -Match 'Publish-PSResource'
    }
}
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `./build.ps1 -Task Test`
Expected: FAIL en `Meta.Tests.ps1` (archivos inexistentes).

- [ ] **Step 3: Crear `LICENSE`**

```text
MIT License

Copyright (c) 2026 marr-cloud
Copyright (c) 2019 Brandon Olin

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 4: Crear `THIRD_PARTY_NOTICES.md`**

```markdown
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
```

- [ ] **Step 5: Crear `README.md`**

````markdown
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
````

- [ ] **Step 6: Crear `CHANGELOG.md`**

```markdown
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
```

- [ ] **Step 7: Crear los workflows**

`.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    strategy:
      fail-fast: false
      matrix:
        os: [windows-latest, ubuntu-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v7
      - name: Install test dependencies
        shell: pwsh
        run: |
          Install-PSResource -Name Pester -Version '[5.9.0, 6.0.0)' -Scope CurrentUser -TrustRepository
          Install-PSResource -Name PSScriptAnalyzer -Version '1.25.0' -Scope CurrentUser -TrustRepository
      - name: Build and test
        shell: pwsh
        run: ./build.ps1 -Task Test
```

`.github/workflows/publish.yml`:

```yaml
name: Publish to PowerShell Gallery

on:
  workflow_dispatch:
    inputs:
      confirm:
        description: 'Type "publish" to publish the version in src/TerminalGlyphs.psd1'
        required: true

jobs:
  publish:
    if: github.event.inputs.confirm == 'publish'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - name: Build and test
        shell: pwsh
        run: |
          Install-PSResource -Name Pester -Version '[5.9.0, 6.0.0)' -Scope CurrentUser -TrustRepository
          Install-PSResource -Name PSScriptAnalyzer -Version '1.25.0' -Scope CurrentUser -TrustRepository
          ./build.ps1 -Task Test
      - name: Publish
        shell: pwsh
        env:
          PSGALLERY_API_KEY: ${{ secrets.PSGALLERY_API_KEY }}
        run: |
          $version = (Import-PowerShellDataFile ./src/TerminalGlyphs.psd1).ModuleVersion
          Publish-PSResource -Path "./out/TerminalGlyphs/$version" -Repository PSGallery -ApiKey $env:PSGALLERY_API_KEY
```

- [ ] **Step 8: Ejecutar y verificar que pasa**

Run: `./build.ps1 -Task Test`
Expected: todos en PASS.

- [ ] **Step 9: Commit**

```powershell
git add LICENSE THIRD_PARTY_NOTICES.md README.md CHANGELOG.md .github tests/Meta.Tests.ps1
git commit -m "Add license, third-party notices, docs and CI workflows" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

---

### Task 12: Actualizar las Nerd Fonts del usuario a 3.5.1

Configuración de la máquina, no código de producto: cambio directo + verificación (sin TDD). Autorizado explícitamente por el usuario. Fuentes instaladas **por usuario** en `%LOCALAPPDATA%\Microsoft\Windows\Fonts` (no requiere admin); Warp usa `JetBrainsMono Nerd Font Mono`.

**Files:**
- Create: `tools/Install-NerdFont.ps1`

**Interfaces:**
- Consumes: release `v3.5.1` de `ryanoasis/nerd-fonts` (`JetBrainsMono.tar.xz`, `FiraCode.tar.xz`).
- Produces: `./tools/Install-NerdFont.ps1 -Family <string[]> [-Version 3.5.1] [-WhatIf]`, que reemplaza solo los archivos de fuente ya instalados.

- [ ] **Step 1: Escribir `tools/Install-NerdFont.ps1`**

```powershell
<#
.SYNOPSIS
    Updates the Nerd Fonts installed for the current Windows user to a given release.
.DESCRIPTION
    Downloads <Family>.tar.xz from the ryanoasis/nerd-fonts GitHub release and replaces the font files that are
    already installed in %LOCALAPPDATA%\Microsoft\Windows\Fonts. Font files that are not installed are skipped.
    If a file is in use, it is renamed to <name>.old-nerdfont and the new file is copied in its place; the
    renamed files are deleted on the next run. Restart the apps that use the font afterwards.
.EXAMPLE
    ./tools/Install-NerdFont.ps1 -Family JetBrainsMono, FiraCode -Version 3.5.1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string[]]$Family,

    [string]$Version = '3.5.1'
)

$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'This script installs fonts for the current Windows user only.' }

$fontDir = [System.IO.Path]::Combine($env:LOCALAPPDATA, 'Microsoft', 'Windows', 'Fonts')
foreach ($stale in (Get-ChildItem -LiteralPath $fontDir -Filter '*.old-nerdfont' -ErrorAction SilentlyContinue)) {
    try { Remove-Item -LiteralPath $stale.FullName -Force } catch { Write-Verbose -Message "Still in use: $($stale.Name)" }
}

$work = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "nerd-fonts-$Version-$([guid]::NewGuid())")
[System.IO.Directory]::CreateDirectory($work) | Out-Null
try {
    foreach ($name in $Family) {
        $archive = [System.IO.Path]::Combine($work, "$name.tar.xz")
        Invoke-WebRequest -Uri "https://github.com/ryanoasis/nerd-fonts/releases/download/v$Version/$name.tar.xz" -OutFile $archive
        $extract = [System.IO.Path]::Combine($work, $name)
        [System.IO.Directory]::CreateDirectory($extract) | Out-Null
        tar -xf $archive -C $extract
        if ($LASTEXITCODE -ne 0) { throw "tar failed to extract $archive" }

        $replaced = 0
        $failed = [System.Collections.Generic.List[string]]::new()
        foreach ($font in (Get-ChildItem -LiteralPath $extract -Recurse -File -Include '*.ttf', '*.otf')) {
            $target = [System.IO.Path]::Combine($fontDir, $font.Name)
            if (-not [System.IO.File]::Exists($target)) { continue }
            if (-not $PSCmdlet.ShouldProcess($target, "Replace with Nerd Fonts $Version")) { continue }
            try {
                Copy-Item -LiteralPath $font.FullName -Destination $target -Force
                $replaced++
            } catch {
                try {
                    Move-Item -LiteralPath $target -Destination "$target.old-nerdfont" -Force
                    Copy-Item -LiteralPath $font.FullName -Destination $target
                    $replaced++
                } catch {
                    $failed.Add($font.Name)
                }
            }
        }
        "${name}: replaced $replaced file(s)"
        if ($failed.Count -gt 0) {
            Write-Warning -Message "${name}: $($failed.Count) file(s) could not be replaced (in use). Close the apps that use them and run again: $($failed -join ', ')"
        }
    }
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
```

- [ ] **Step 2: Simulación**

Run: `./tools/Install-NerdFont.ps1 -Family JetBrainsMono, FiraCode -WhatIf`
Expected: líneas `What if: Performing the operation "Replace with Nerd Fonts 3.5.1" on target "...\Fonts\JetBrainsMonoNerdFont-Regular.ttf"` y similares, y `JetBrainsMono: replaced 0 file(s)` / `FiraCode: replaced 0 file(s)` (nada cambia).

- [ ] **Step 3: Instalar**

Run: `./tools/Install-NerdFont.ps1 -Family JetBrainsMono, FiraCode`
Expected: `JetBrainsMono: replaced N file(s)` y `FiraCode: replaced M file(s)` con N > 0 y M > 0. Si hay un aviso de archivos en uso, informa al usuario: tendrá que cerrar Warp/VS Code y ejecutar el mismo comando desde otra terminal (p. ej. Windows Terminal). No cierres aplicaciones del usuario.

- [ ] **Step 4: Verificar en disco que los glifos nuevos existen**

```powershell
Add-Type -AssemblyName PresentationCore
$fontDir = [System.IO.Path]::Combine($env:LOCALAPPDATA, 'Microsoft', 'Windows', 'Fonts')
$en = [System.Globalization.CultureInfo]::GetCultureInfo('en-US')
foreach ($file in 'JetBrainsMonoNerdFontMono-Regular.ttf', 'JetBrainsMonoNerdFont-Regular.ttf', 'FiraCodeNerdFont-Regular.ttf') {
    $typeface = [System.Windows.Media.GlyphTypeface]::new([uri]([System.IO.Path]::Combine($fontDir, $file)))
    $missing = @(0xE792, 0xE735, 0xE76F, 0xE865, 0xE8D6, 0xE8BD, 0xEC82, 0xF0055) | Where-Object { -not $typeface.CharacterToGlyphMap.ContainsKey($_) }
    '{0}: {1} | faltan: {2}' -f $file, $typeface.VersionStrings[$en], ($(if ($missing) { ($missing | ForEach-Object { 'U+{0:X}' -f $_ }) -join ', ' } else { 'ninguno' }))
}
```

Expected: las tres líneas contienen `Nerd Fonts 3.5.1` y `faltan: ninguno`.

- [ ] **Step 5: Commit**

```powershell
git add tools/Install-NerdFont.ps1
git commit -m "Add Nerd Fonts updater for Windows" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01LnGdz67x5EkzZoVrMPQHaW"
```

- [ ] **Step 6: Pedir al usuario que reinicie Warp** para que cargue la fuente nueva (verificación visual en el paso 7 del flujo).

---

## Verificación final (paso 7 del flujo, `superpowers:verification-before-completion`)

Se ejecuta después de todas las tareas y se muestra la salida al usuario antes de afirmar nada:

1. `./build.ps1 -Task Test` → resumen de Pester con 0 fallos.
2. `./build.ps1 -Task Test -Tag Performance -ExcludeTag @()` → mediana del import.
3. Sesión limpia: `pwsh -NoProfile -Command "Import-Module '<repo>/out/TerminalGlyphs/0.1.0/TerminalGlyphs.psd1'; 'ERRORS=' + `$Error.Count"` → `ERRORS=0`.
4. `Get-ChildItem` real sobre una carpeta con archivos del stack (`go.mod`, `Cargo.toml`, `wrangler.jsonc`, `main.tf`, `mise.toml`, `uv.lock`, `pnpm-lock.yaml`, `bun.lock`, `astro.config.mjs`, `.vitepress/`, `Dockerfile`, `CLAUDE.md`, `.kiro/`, `AGENTS.md`) en `pwsh -NoProfile` con el módulo importado, mostrando la salida.
5. `Get-ChildItem <carpeta> | Get-TerminalGlyph | Format-Table Name, IconName, Color, Rule, Source`.
