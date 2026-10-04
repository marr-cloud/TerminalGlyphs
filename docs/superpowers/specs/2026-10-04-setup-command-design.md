# TerminalGlyphs 0.2.0 — Comando de setup y publicación en la Gallery

- **Fecha:** 2026-10-04
- **Autor:** marr-cloud
- **Estado:** diseño aprobado por secciones en el brainstorming; pendiente de revisión de la spec escrita
- **Base:** TerminalGlyphs 0.1.0 (`main` = 8c3f4ac, spec `2026-10-03-terminalglyphs-design.md`)
- **Rama:** `feat/setup-command`

## Siguiente paso (para retomar tras compactar el contexto)

1. El usuario revisa esta spec.
2. Con su aprobación: `superpowers:writing-plans` → plan en `docs/superpowers/plans/2026-10-04-setup-command.md`.
3. Ejecución con `superpowers:subagent-driven-development` (TDD con Pester 5), en un worktree de esta rama.
4. Verificación, revisión final, `finishing-a-development-branch` (push y PR solo con confirmación).
5. Tras el merge: el usuario crea la API key de la Gallery y guarda el secreto. Publicar **solo** con confirmación explícita.

## 1. Objetivo

Simplificar la instalación para cualquiera (el repo es público) y corregir el problema de caché de fuentes que
causó `tools/Install-NerdFont.ps1` en la máquina del autor.

**Instalación objetivo en una máquina nueva (Windows, Linux o macOS):**

```powershell
Install-PSResource TerminalGlyphs
Import-Module TerminalGlyphs; Install-TerminalGlyphSetup
```

### Criterios de éxito

1. Una máquina sin Nerd Fonts queda con iconos tras los dos comandos (más elegir la fuente en la terminal).
2. Actualizar fuentes en uso en Windows nunca deja la caché de fuentes apuntando a archivos inexistentes.
3. El perfil queda importando TerminalGlyphs, con respaldo, y el comando es idempotente.
4. TerminalGlyphs 0.2.0 se instala desde la PowerShell Gallery.

### Fuera de alcance

- Modificar la configuración de la terminal (Warp, Windows Terminal, etc.): solo se indica qué fuente elegir.
- Script bootstrap `irm … | iex`.
- Instalar Nerd Fonts de forma global para todo el sistema (con admin).

## 2. Causa del bug que se corrige (evidencia del 2026-10-04)

`tools/Install-NerdFont.ps1` renombró las fuentes en uso a `*.old-nerdfont` y copió las nuevas. La caché de fuentes de
Windows (DirectWrite/FontCache) siguió referenciando los renombrados; al borrarlos, la enumeración de fuentes falló con
"Unable to find the specified file" y Warp dibujó los codepoints U+E7xx/U+E8xx con Segoe MDL2/Fluent Icons (disquete,
sol, batería, chincheta). Reiniciar Windows reconstruyó la caché y todo se vio bien (verificado: todas las familias
JetBrainsMono/FiraCode en 3.5.1, enumeración sin errores).

**Regla nueva:** un `.old-nerdfont` solo se borra si Windows arrancó después del momento en que se renombró.

## 3. Comando nuevo: `Install-TerminalGlyphSetup`

```
Install-TerminalGlyphSetup [-Family <string[]>] [-SkipFont] [-SkipProfile] [-WhatIf] [-Confirm]
```

- `-Family`: familias a instalar. Si se pasa explícitamente, se instalan (o actualizan) siempre esas familias. Si se
  omite, se instala `JetBrainsMono` solo cuando no hay ninguna Nerd Font. En ambos casos, las ya instaladas y
  desactualizadas se actualizan (salvo `-SkipFont`).
- `SupportsShouldProcess`: todo cambio pasa por `ShouldProcess`; `-WhatIf` no modifica nada salvo su propia carpeta
  temporal, que se borra siempre.
- Pasos independientes (un fallo no bloquea a los demás). Al final, un resumen por paso con estado
  `OK` | `Sin cambios` | `Omitido` | `Error: <motivo>`, la fuente a elegir en la terminal y, si quedaron fuentes en
  uso reemplazadas en Windows, el aviso de **reiniciar Windows** (cerrar sesión no basta: la limpieza depende de `LastBootUpTime`).
- Nunca se ejecuta al importar: el import sigue sin leer datos ni escribir nada.
- La API pública pasa de 5 a 6 comandos.

## 4. Fuentes

### Detección

- Archivos `*NerdFont*.ttf|otf` en la carpeta de fuentes del usuario de cada plataforma.
- Versión leída de la tabla OpenType `name` (ID 5, "Version …;Nerd Fonts X.Y.Z") con un lector propio, igual en las tres
  plataformas. Archivo corrupto o sin "Nerd Fonts" → `$null`, sin lanzar errores.
- Tabla de familias conocidas: nombre de archivo → paquete del release (`JetBrainsMono` incluye `JetBrainsMonoNL`;
  `CaskaydiaCove` → `CascadiaCode`; `FiraCode`; `Hack`; `Meslo`; …). Familia desconocida → aviso, no se toca.
- Desactualizada = versión < 3.5.1.

### Descarga

- `https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/<Paquete>.tar.xz` y `SHA-256.txt` del mismo
  release. Hash distinto → error de ese paso, sin instalar nada.
- Extracción con el `tar` del sistema (en Windows `$env:SystemRoot\System32\tar.exe`, bsdtar con liblzma: verificado
  bsdtar 3.8.8 / liblzma 5.8.1 en Windows 11) en una carpeta temporal que se borra siempre (`-WhatIf:$false` en la
  limpieza).
- La red queda detrás de una función privada para poder sustituirla en los tests.

### Windows (por usuario, sin admin)

- Carpeta: `%LOCALAPPDATA%\Microsoft\Windows\Fonts`.
- **Instalación nueva:** copiar, registrar en `HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts`
  (`"<nombre completo> (TrueType|OpenType)" = <ruta>`), `AddFontResource` + `WM_FONTCHANGE`. Usable sin reiniciar.
- **Actualización:** copiar sobre el archivo; si está en uso, renombrarlo a `<archivo>.<yyyyMMddHHmmss>.old-nerdfont` y
  copiar el nuevo; si esa copia falla, restaurar el original (nunca una fuente sin archivo). El registro no cambia
  (mismo nombre de archivo).
- **Limpieza:** borrar un `.old-nerdfont` solo si el último arranque (`Win32_OperatingSystem.LastBootUpTime`) es
  posterior a su marca de tiempo; si su original falta, restaurarlo. Si quedan pendientes, el resumen pide reiniciar
  Windows.

### Linux

- Carpeta `~/.local/share/fonts/NerdFonts/<Paquete>/`; después `fc-cache -f`. Sin `fc-cache` → aviso, no error.

### macOS

- Carpeta `~/Library/Fonts`; sin refresco de caché.

## 5. Perfil

- Archivo: el primero de los cuatro perfiles que ya contenga `Import-Module … Terminal-Icons` o `… TerminalGlyphs`; si
  ninguno, `$PROFILE` (CurrentUserCurrentHost). Si no existe, se crea con su carpeta.
- Línea `Import-Module [-Name] ['"]Terminal-Icons['"]` → `Import-Module -Name TerminalGlyphs`. Si TerminalGlyphs ya se
  importa → sin cambios. Si no hay ninguna → añadir al final `# Added by TerminalGlyphs` + `Import-Module -Name TerminalGlyphs`.
- Antes de escribir: respaldo `<perfil>.terminalglyphs-<yyyyMMddHHmmss>.bak` junto al perfil.
- Conserva codificación (BOM o no) y saltos de línea (CRLF/LF). Escritura atómica (temporal + reemplazo). No ejecuta el
  perfil.

## 6. Estructura

| Archivo | Responsabilidad |
|---|---|
| `src/Public/Install-TerminalGlyphSetup.ps1` | Orquesta los pasos y el resumen |
| `src/Private/Get-NerdFontInstallation.ps1` | Detecta familias, archivos y versiones |
| `src/Private/Read-FontVersion.ps1` | Lee la versión de la tabla `name` |
| `src/Private/Save-NerdFontRelease.ps1` | Descarga, verifica SHA-256 y extrae |
| `src/Private/Install-NerdFontFile.ps1` | Copia / registra / renombra según plataforma |
| `src/Private/Remove-StaleFontFile.ps1` | Limpia `.old-nerdfont` tras un reinicio |
| `src/Private/Update-ProfileImport.ps1` | Edita el perfil |

Rutas, clave de registro, URL base y hora de arranque son parámetros con valores por defecto reales (inyectables en
tests). Se elimina `tools/Install-NerdFont.ps1`.

## 7. Tests y CI

Pester 5.9.x, TDD, sin red ni efectos en la máquina real:

- `Read-FontVersion`: TTF mínimo generado en `TestDrive` con tabla `name`; versión correcta, no Nerd Font → `$null`,
  corrupto → `$null`.
- Detección: carpeta falsa con varias familias/versiones; desactualizadas y desconocidas.
- Descarga: función de red con mock; release falso (`tar -cJf` + `SHA-256.txt`); hash correcto/incorrecto; carpeta
  temporal borrada también con `-WhatIf`.
- Windows: carpeta falsa + clave `HKCU:\Software\TerminalGlyphs.Tests\Fonts` (borrada al terminar), `AddFontResource`
  con mock; archivo bloqueado → renombra; copia fallida → restaura; limpieza solo anterior al arranque.
- Linux/macOS: rutas falsas, `fc-cache` con mock.
- Perfil: sustituye, añade, idempotente, BOM y CRLF conservados, respaldo, `-WhatIf` sin cambios.
- Comando: estados del resumen y aislamiento de pasos fallidos.
- Se mantienen: el import no escribe; API exporta exactamente 6 comandos; PSScriptAnalyzer 0 hallazgos; ASCII en src/tools.
- CI: matriz `windows-latest`, `ubuntu-latest`, `macos-latest`; paso de ensayo de publicación contra un repositorio
  PSResourceGet local temporal dentro del runner (publicar e instalar desde él).

## 8. Publicación y documentación

- Versión `0.2.0`: `CHANGELOG.md` con su sección, manifiesto con 6 funciones, spec 0.1 actualizada en lo que cambia.
- README: instalación de dos líneas desde la Gallery, reinicio de Windows si se actualizaron fuentes en uso;
  "desde el código fuente" pasa a la sección de desarrollo.
- Gallery: el usuario crea la API key (powershellgallery.com → Account → API Keys; glob `TerminalGlyphs`, scope "Push
  new packages and package versions", ≤ 365 días) y la guarda con `! gh secret set PSGALLERY_API_KEY --repo
  marr-cloud/TerminalGlyphs`. El workflow `publish.yml` se lanza solo con su confirmación.
