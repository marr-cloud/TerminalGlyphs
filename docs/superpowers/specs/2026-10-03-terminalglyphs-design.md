# TerminalGlyphs — Diseño

- **Fecha:** 2026-10-03
- **Autor:** marr-cloud
- **Estado:** aprobado por secciones en el brainstorming; pendiente de revisión de la spec escrita
- **Upstream de referencia:** [devblackops/Terminal-Icons](https://github.com/devblackops/Terminal-Icons) v0.11.0 (último commit 2023-11-03, `46866e4`)

## 1. Contexto y objetivo

Terminal-Icons muestra iconos y colores de Nerd Fonts en `Get-ChildItem`. Lleva desde 2023 sin
mantenimiento y falla de forma intermitente al abrir varias sesiones de pwsh a la vez. TerminalGlyphs es
una **reimplementación nueva** con nombre propio que reutiliza, con atribución, los mapeos y colores del
upstream, elimina la causa raíz del fallo y agrega iconos para el stack del autor.

### Criterios de éxito

1. Abrir varias pestañas o paneles de Warp a la vez nunca rompe el `Import-Module`, ni siquiera con una
   config de usuario corrupta.
2. `Get-ChildItem` muestra los iconos nuevos (sección 6) con una Nerd Font ≥ 3.5.1.
3. `Import-Module TerminalGlyphs` en pwsh limpio tarda menos de 100 ms (mediana de 5). El upstream tarda
   ~640 ms en la máquina del autor.

### Fuera de alcance (v0.1)

- Windows PowerShell 5.1 y pwsh < 7.4.
- Migrar temas personalizados del almacén `%APPDATA%\powershell\Community\Terminal-Icons`.
- Cmdlets para añadir o quitar temas desde la consola (paridad con el upstream).
- Publicar en la PowerShell Gallery (se deja preparado, sin publicar).
- Migrar a Pester 6.

## 2. Causa raíz del fallo del upstream (evidencia)

Error observado en Warp:

```
Import-Clixml: No se ha especificado el valor de la entrada del diccionario. Line 451, position 41.
Import-Module: ... El módulo que se va a procesar "Terminal-Icons.psm1" ... no se procesó porque no se
encontró ningún módulo válido en ningún directorio de módulos.
```

Cadena causal, reproducida en aislamiento (con `APPDATA` apuntando a una carpeta temporal):

| # | Eslabón | Evidencia |
|---|---|---|
| 1 | En **cada** import, `Terminal-Icons.psm1` reescribe todos los XML de temas en `%APPDATA%\powershell\Community\Terminal-Icons` con `Export-Clixml -Force` (no atómico: trunca y escribe). | Código del módulo compilado, líneas 3433–3442; `LastWriteTime` cambia en cada import. |
| 2 | Varias sesiones que arrancan a la vez leen un archivo a medio escribir o lo escriben a la vez. Como .NET aleatoriza el hash de strings por proceso, cada proceso serializa el `Hashtable` en un orden distinto y el resultado es un XML "mezclado" que queda en disco. | Lector contra escritor: 583 de 737 lecturas fallan. Dos escritores: aparece el mensaje literal `No se ha especificado el valor de la entrada del diccionario`. Tres procesos producen tres órdenes de claves distintos. |
| 3 | El bucle de carga no maneja el fallo: el tema queda `$null` y `Themes.Color[$null] = …` lanza un error **terminante de instrucción**. | `InvalidOperation: Error en la operación de índice; el índice de matriz se evaluó como null`. |
| 4 | Warp ejecuta el perfil con `try { . $file } catch { }`. Con un `try` en la pila, ese error desenrolla todo el `.psm1`: el módulo no se carga **y el paso que reescribe los XML no se ejecuta**, así que el archivo corrupto persiste y el fallo se repite en cada pestaña nueva. | Bootstrap extraído de `warp.exe`; reproducción exacta de ambos mensajes; módulo mínimo con `$h[$null] = 1` que carga sin `try` y falla dentro de `try`. |

Fuera de un `try`, el mismo error no es terminante: el módulo carga con avisos y reescribe los XML,
"reparándolos". Por eso un `Import-Module` manual posterior funciona.

Issues upstream relacionados: #121, #126, #144, #148 (corrupción por codificación 5.1↔7) y #76 (tiempo de
carga). El PR #120 del autor (sin mergear desde 2023) también eliminaba la reescritura en cada carga.

## 3. Decisiones

| Tema | Decisión |
|---|---|
| Base | Reimplementación nueva; se reutilizan los datos del upstream con atribución. |
| Nombre | `TerminalGlyphs` (libre en la PowerShell Gallery el 2026-10-03). |
| Compatibilidad | Solo pwsh 7.4+ (`CompatiblePSEditions = 'Core'`, `PowerShellVersion = '7.4'`). |
| Formato de datos | JSONC (comentarios y comas finales, verificado con `ConvertFrom-Json -AsHashtable`) + override de usuario. |
| Carga | Build que precompila los datos + carga diferida en el primer formateo. |
| Implementación | Módulo script (PowerShell puro); sin C#. |
| Nerd Fonts | Mínimo 3.5.1; se valida contra `glyphnames.json` v3.5.1 fijado en el repo. |
| API pública v0.1 | `Format-TerminalGlyph`, `Get-TerminalGlyph`, `Show-TerminalGlyphTheme`, `Find-NerdGlyph`, `Update-TerminalGlyphConfig`. |
| Licencia | MIT; aviso de copyright del upstream conservado. |
| Publicación | GitHub (`marr-cloud/TerminalGlyphs`) primero; Gallery preparada con un workflow manual. Ningún push ni publicación sin confirmación explícita. |
| Tests | Pester 5.9.x (`[5.9,6.0)`) + PSScriptAnalyzer 1.25. |

## 4. Arquitectura

```
TerminalGlyphs/
├─ src/
│  ├─ TerminalGlyphs.psd1
│  ├─ TerminalGlyphs.psm1          # en import: define funciones y Update-FormatData; no lee datos
│  ├─ TerminalGlyphs.format.ps1xml # vista de Get-ChildItem (derivada del upstream / DirColors)
│  ├─ Public/   Format-TerminalGlyph, Get-TerminalGlyph, Show-TerminalGlyphTheme,
│  │            Find-NerdGlyph, Update-TerminalGlyphConfig
│  └─ Private/  Initialize-TerminalGlyph, Resolve-TerminalGlyph, Read-JsoncFile,
│               Merge-GlyphConfig, ConvertTo-AnsiSequence, Get-ConfigPath
├─ themes/
│  ├─ icons/default.jsonc
│  └─ colors/default.jsonc, light.jsonc, dracula.jsonc
├─ schema/config.schema.json
├─ vendor/nerd-fonts/glyphnames.json (v3.5.1) + LICENSE
├─ build.ps1
├─ tests/
└─ docs/superpowers/{specs,plans}/
```

### Build (`./build.ps1`)

1. Lee los JSONC de `themes/` y valida que cada nombre `nf-*` exista en `vendor/nerd-fonts/glyphnames.json`
   y que cada color sea hexadecimal `RRGGBB`. Cualquier error hace fallar el build con la lista de
   entradas inválidas.
2. Genera `TerminalGlyphs.data.json`: iconos resueltos a caracteres y colores convertidos a secuencias ANSI
   de 24 bits, por tema.
3. Genera `glyphs.json` (mapa completo nombre → carácter) para resolver overrides con nombres no
   precompilados y para `Find-NerdGlyph`.
4. Une `Public/*.ps1` y `Private/*.ps1` en un único `.psm1`.
5. Salida: `out/TerminalGlyphs/<versión>/` (ignorada por git).

### Runtime

- `Import-Module` define funciones y ejecuta `Update-FormatData -PrependPath` con el `format.ps1xml`. No
  lee ni escribe ningún archivo de datos.
- El primer `Format-TerminalGlyph` llama a `Initialize-TerminalGlyph`, que carga `TerminalGlyphs.data.json`
  y la config de usuario, construye los diccionarios de resolución y los guarda en variables `$script:`.
- `glyphs.json` solo se carga si la config de usuario usa un nombre que no está en los datos compilados o
  si se llama a `Find-NerdGlyph`.
- **Ningún camino de código escribe a disco.**

## 5. Formato de datos y configuración

### Tema de iconos

```jsonc
{
  "name": "default",
  "files": {
    "names":      { "go.mod": "nf-dev-go", "wrangler.jsonc": "nf-dev-cloudflareworkers" },
    "extensions": { ".go": "nf-dev-go", ".tf": "nf-dev-terraform", ".d.ts": "nf-dev-typescript" },
    "default":    "nf-fa-file"
  },
  "directories": {
    "names":   { ".claude": "nf-cod-claude", ".wrangler": "nf-dev-cloudflare" },
    "default": "nf-oct-file_directory"
  },
  "links": { "symlink": "nf-oct-file_symlink_file", "junction": "nf-fa-external_link" }
}
```

Los temas de color tienen la misma forma, con valores hexadecimales `RRGGBB` en lugar de nombres de glifo.

### Config de usuario (opcional)

Ruta: `$env:TERMINALGLYPHS_CONFIG` si está definida; si no, `$env:XDG_CONFIG_HOME/terminalglyphs/config.jsonc`;
si no, `~/.config/terminalglyphs/config.jsonc`.

```jsonc
{
  "$schema": "https://raw.githubusercontent.com/marr-cloud/TerminalGlyphs/main/schema/config.schema.json",
  "iconTheme":  "default",
  "colorTheme": "default",
  "icons":  { "files": { "names": { "Justfile": "nf-md-format_list_checks" } } },
  "colors": { "files": { "extensions": { ".go": "00ADD8" } } }
}
```

`icons` y `colors` se fusionan clave a clave **encima** del tema elegido.

### Reglas de resolución

Para cada `FileSystemInfo`, la primera regla que acierta gana:

1. `LinkType` es `SymbolicLink` o `Junction` → `links`. Se muestra además `→ destino`.
2. Nombre exacto → `files.names` o `directories.names`.
3. Solo archivos: el **sufijo compuesto más largo** presente en `files.extensions`. Para `app.test.d.ts` se
   prueba `.test.d.ts`, luego `.d.ts` y luego `.ts`.
4. `default` del tipo (archivo o directorio).

Todos los diccionarios usan `StringComparer.OrdinalIgnoreCase`. Icono y color se resuelven con las mismas
reglas pero de forma independiente.

`Get-TerminalGlyph <ruta>` devuelve un objeto con `Name`, `Icon`, `IconName`, `Color`, `Rule` (p. ej.
`files.names[go.mod]`) y `Source` (`theme:default` o `user-config`).

## 6. Iconos nuevos

Base: todos los mapeos del tema `devblackops` del upstream, migrados a JSONC. Encima, los siguientes. `≈`
indica que Nerd Fonts no tiene logo oficial y se usa una aproximación. Todos los glifos se verificaron en
`glyphnames.json` v3.5.1.

| Stack | Archivos (F) / carpetas (D) / extensiones (E) | Glifo |
|---|---|---|
| Go | E `.go`; F `go.mod`, `go.sum`, `go.work`, `go.work.sum` | `nf-dev-go` |
| Rust | E `.rs`; F `Cargo.toml`, `Cargo.lock`, `rust-toolchain`, `rust-toolchain.toml`, `rustfmt.toml`, `.rustfmt.toml`, `clippy.toml` | `nf-dev-rust` |
| Cloudflare | F `wrangler.toml`, `wrangler.json`, `wrangler.jsonc` | `nf-dev-cloudflareworkers` |
| | D `.wrangler` | `nf-dev-cloudflare` |
| | F `.dev.vars` | `nf-md-file_key` |
| Terraform | E `.tf`, `.tfvars`, `.tfstate`, `.hcl`; F `.terraform.lock.hcl`; D `.terraform` | `nf-dev-terraform` |
| CloudFormation / SAM / CDK | E `.cfn.yaml`, `.cfn.yml`, `.cfn.json`; F `samconfig.toml`, `cdk.json`; D `.aws-sam`, `cdk.out` | `nf-dev-aws` ≈ |
| mise | F `mise.toml`, `.mise.toml`, `mise.local.toml`, `.tool-versions` | `nf-md-chef_hat` ≈ |
| uv / Python | F `uv.lock`, `.python-version`, `pyproject.toml`; D `.venv` | `nf-dev-python` ≈ |
| pnpm | F `pnpm-lock.yaml`, `pnpm-workspace.yaml`, `.pnpmfile.cjs` | `nf-dev-pnpm` |
| Bun | F `bun.lock`, `bun.lockb`, `bunfig.toml` | `nf-dev-bun` |
| Astro | E `.astro`; F `astro.config.mjs`, `astro.config.ts`, `astro.config.js`, `astro.config.mts`; D `.astro` | `nf-dev-astro` |
| Vite | F `vite.config.ts`, `vite.config.js`, `vite.config.mjs`, `vite.config.mts` | `nf-dev-vite` |
| VitePress | D `.vitepress` | `nf-dev-vite` |
| Vitest | F `vitest.config.ts`, `vitest.config.js`, `vitest.config.mjs`, `vitest.config.mts` | `nf-dev-vitest` |
| Docker | E `.dockerfile`; F `Containerfile`, `.dockerignore`, `compose.yaml`, `compose.yml`, `docker-compose.yaml` (además de los existentes `Dockerfile` y `docker-compose.yml`) | `nf-dev-docker` |
| Claude | F `CLAUDE.md`, `CLAUDE.local.md`; D `.claude` | `nf-cod-claude` |
| Kiro | D `.kiro` | `nf-md-ghost` ≈ |
| IA genérica | F `AGENTS.md`, `GEMINI.md`, `llms.txt`, `.mcp.json`, `.cursorrules`, `copilot-instructions.md`; D `.gemini`, `.cursor`, `.codex` | `nf-cod-sparkle` |
| Biome | F `biome.json`, `biome.jsonc` | `nf-dev-biome` |
| Deno | F `deno.json`, `deno.jsonc` | `nf-dev-denojs` |
| TOML | E `.toml` | `nf-custom-toml` |
| just | F `justfile`, `Justfile`, `.justfile` | `nf-md-format_list_checks` ≈ |

Hono no tiene un archivo de firma propio, así que no recibe mapeo.

**Colores**, aproximados a cada marca y presentes en los tres temas: Go `00ADD8`, Rust `DEA584`,
Cloudflare `F38020`, Terraform `844FBA`, AWS `FF9900`, pnpm `F69220`, Bun `FBF0DF`, Astro `FF5D01`,
Vite `646CFF`, Vitest `729B1B`, Docker `2496ED`, Claude `D97757`, Python `3776AB`. En el tema `light` se
oscurecen los que no tengan contraste suficiente sobre fondo blanco (Bun, AWS).

**Reparaciones:** los glifos del upstream que no existen en v3.5.1 se sustituyen (todos los sustitutos
verificados en v3.5.1):

| Uso en el upstream | Glifo roto | Sustituto |
|---|---|---|
| D `media` | `nf-dev-html5_multimedia` | `nf-md-folder_play` |
| D `onedrive` | `nf-dev-onedrive` | `nf-md-microsoft_onedrive` |
| E `.clixml` | `nf-dev-code_badge` | `nf-md-xml` |
| E `.tf`, `.tfvars`, `.tf.json`, `.tfvars.json`, `.auto.tfvars`, `.auto.tfvars.json` | `nf-dev-code_badge` | `nf-dev-terraform` |

## 7. Manejo de errores

1. El import no lee ni escribe datos, así que no puede fallar por datos.
2. Ningún camino de código escribe a disco.
3. `Initialize-TerminalGlyph` envuelve cada lectura en `try/catch` y emite como máximo un `Write-Warning`
   por problema y sesión, indicando archivo y, si se conoce, línea:
   - JSONC mal formado: se ignora la config de usuario y se usa el tema integrado.
   - Tema inexistente: se usa `default`.
   - Glifo desconocido o color no hexadecimal: se ignora esa entrada y se aplica el resto.
4. La ruta de carga no genera errores terminantes de instrucción: nunca se indexa un diccionario con una
   clave que pueda ser `$null`.
5. `Format-TerminalGlyph` nunca propaga excepciones: si la resolución falla, devuelve el nombre sin icono ni
   color.
6. Si `Terminal-Icons` está cargado al importar, se emite un aviso de conflicto de formato.
7. Si `$PSStyle.OutputRendering` es `PlainText`, no se emiten secuencias ANSI (los iconos sí).
8. `Update-TerminalGlyphConfig` vuelve a leer la config y muestra de nuevo los avisos de validación.

## 8. Tests y verificación

Pester 5.9.x, instalado con `Install-PSResource -Scope CurrentUser`. Orden TDD:

1. **Regresión del bug**
   - Import dentro de `try { }` y con `$ErrorActionPreference = 'Stop'` con una config corrupta: el módulo
     carga, avisa y usa el tema integrado.
   - N sesiones pwsh concurrentes (barrera de tiempo y arranques escalonados) que importan y listan: 0 errores.
   - El import no escribe: hashes y `LastWriteTime` de la carpeta de config y del módulo sin cambios.
2. **Iconos nuevos**: test guiado por datos (`-ForEach`) con cada fila de la sección 6, más sufijos
   compuestos, mayúsculas y enlaces.
3. **Build**: falla ante un glifo inexistente o un color inválido; los datos compilados coinciden con las
   fuentes.
4. **Config**: fusión, overrides y cada caso de aviso de la sección 7.
5. **Calidad**: `Test-ModuleManifest`, PSScriptAnalyzer sin errores, rendimiento (tag `Performance`: import
   en `pwsh -NoProfile`, mediana de 5 < 100 ms).

Verificación final: Pester completo, `Import-Module` en una sesión `pwsh -NoProfile` limpia y un
`Get-ChildItem` real sobre una carpeta con archivos del stack, mostrando la salida.

## 9. CI, publicación y documentación

- `.github/workflows/ci.yml`: `windows-latest` y `ubuntu-latest`; build, Pester y PSScriptAnalyzer.
- `.github/workflows/publish.yml`: solo `workflow_dispatch`; `Publish-PSResource` con el secreto
  `PSGALLERY_API_KEY`. No se ejecuta sin decisión explícita.
- Versión inicial `0.1.0`; `CHANGELOG.md` con formato Keep a Changelog.
- `README.md` en inglés: instalación, migración desde Terminal-Icons (cambiar la línea del perfil),
  requisito Nerd Font ≥ 3.5.1 y cómo actualizar la fuente, formato de la config y créditos.

## 10. Licencia y atribución

- `LICENSE`: MIT con `Copyright (c) 2026 marr-cloud` y `Copyright (c) 2019 Brandon Olin` (mapeos y colores
  reutilizados de Terminal-Icons).
- `THIRD_PARTY_NOTICES.md`:
  - Terminal-Icons, devblackops/Brandon Olin — MIT.
  - DirColors, DHowett — MIT (origen del `format.ps1xml` del upstream).
  - Nerd Fonts `glyphnames.json`, ryanoasis — MIT (su licencia aplica MIT a los archivos fuente fuera de
    carpetas con licencia OFL explícita).

## 11. Requisito en la máquina del autor

Las fuentes instaladas son JetBrainsMono Nerd Font 3.0.2 y FiraCode Nerd Font 3.1.1. Los devicons de
Cloudflare, Astro, Bun, pnpm, Vite, Terraform, YAML y Kubernetes existen desde Nerd Fonts 3.3.0, y
`nf-cod-claude` desde la serie 3.5 (verificado en 3.5.1). En 3.0.2 los codepoints de `nf-dev-cloudflare`
(U+E792) y `nf-dev-astro` (U+E735) dibujan otros logos (Komodo y HTML5 3D). Hace falta actualizar la fuente
a 3.5.1, cosa que se hará solo con confirmación del autor.
