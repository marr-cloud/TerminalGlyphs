# TerminalGlyphs 0.3.0 — Más mapeos desde nvim-web-devicons y auditoría del tema

- **Fecha:** 2026-10-04
- **Autor:** marr-cloud
- **Estado:** aprobada; actualizada tras la revisión final (colores en las secciones 3 y 4)
- **Base:** TerminalGlyphs 0.2.2 (`main` = 2850f00)
- **Rama:** `feat/0.3.0-mappings`

## 1. Objetivo

Que los listados muestren iconos con sentido para muchos más archivos de desarrollo (por ejemplo `.prettierrc`,
`.editorconfig`, `.env`, `Makefile`, `eslint.config.js`, `.graphql`, `.proto`, `.nix`, `.zig`) y revisar que los
mapeos actuales estén bien configurados: glifo apropiado, con color en los tres temas y coherentes entre nombre y
extensión.

### Decisiones del brainstorming

1. **Referencia más curado.** Se toma como referencia [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons)
   (MIT, mantenido, con glifo y color por archivo). Sus glifos se traducen a nombres de Nerd Fonts 3.5.1 y se añade
   lo que falta, salvo lo que el usuario vete.
2. **Conflictos.** Los mapeos actuales no cambian solos: las diferencias con la referencia se listan en un informe y
   solo se cambian las que el usuario apruebe.
3. **Enfoque A.** Herramienta reproducible con la referencia vendorizada (no un script desechable ni carga en tiempo
   de ejecución).

### Medición (commit `58447c1fca354bbf184425e4a8d01deecbd6f3c4` de nvim-web-devicons)

| | En la referencia | Nuevas | Ya mapeadas | Con otro glifo |
|---|---|---|---|---|
| Nombres de archivo | 221 | 174 | 47 | 30 |
| Extensiones | 494 | 350 | 144 | 83 |

Todos los glifos de la referencia existen en Nerd Fonts 3.5.1. Tema actual: 135 nombres, 292 extensiones y 57
carpetas con icono; 14 nombres y 3 extensiones con icono pero sin color.

### Criterios de éxito

1. Las entradas nuevas aprobadas resuelven icono y color en los tres temas.
2. Ningún mapeo existente cambia sin estar en `adopt` del archivo de decisiones.
3. Cada clave con icono tiene color en `default`, `light` y `dracula` (invariante con test).
4. `Import-Module` sigue por debajo de 100 ms (mediana) y el primer listado no empeora de forma apreciable.
5. TerminalGlyphs 0.3.0 se publica en la Gallery con el crédito a nvim-web-devicons.

### Fuera de alcance

- Carpetas: la referencia no las cubre; solo entran en la auditoría.
- Iconos por sistema operativo, escritorio o gestor de ventanas de la referencia.
- Cambios en cómo se resuelven los iconos (orden de reglas, sufijos compuestos, mayúsculas).

## 2. Datos vendorizados

- `vendor/nvim-web-devicons/` con `icons_by_filename.lua` e `icons_by_file_extension.lua` del commit `58447c1`,
  su `LICENSE` (MIT) y un `manifest.json` con el commit y el SHA-256 de cada archivo, igual que
  `vendor/nerd-fonts/manifest.json`.
- La herramienta comprueba el manifest antes de leer; un test lo verifica también. El build del módulo no usa estos
  datos.
- Crédito en `THIRD_PARTY_NOTICES.md` y una línea en la cabecera de los temas modificados.

## 3. Herramienta `tools/Import-DeviconsMapping.ps1`

### Lectura

Cada entrada de la referencia tiene la forma `["<clave>"] = { icon = "<carácter>", color = "#RRGGBB", ..., name = "<Nombre>" }`.
En `icons_by_file_extension.lua` la clave no lleva el punto inicial (se añade). Las claves de nombre se comparan sin
distinguir mayúsculas, como en el módulo.

### Traducción del glifo

El carácter se convierte en su punto de código y se busca en `vendor/nerd-fonts/glyphnames.json`. Si hay varios
nombres para el mismo código:

1. el que ya usa el tema para ese código, por coherencia;
2. si no, el primero según el orden de familias `dev`, `seti`, `custom`, `md`, `fa`, `oct`, `cod` y el resto en orden
   alfabético; dentro de una familia, el nombre más corto y luego el orden alfabético.

Un carácter sin nombre en Nerd Fonts 3.5.1 se descarta y aparece en el informe.

### Modo `-Report <ruta>`

Genera `docs/mappings/devicons-0.3.0.md` con:

- resumen con recuentos;
- entradas nuevas agrupadas por el `name` de la referencia (p. ej. `PrettierConfig`: `.prettierrc`,
  `.prettierrc.json`, `prettier.config.js`…), con clave, glifo y color de cada una;
- diferencias con lo existente: clave, glifo actual, glifo de la referencia, color actual y color de la referencia;
- entradas con icono y sin color en algún tema, indicando si la referencia aporta color;
- carpetas con icono y sin color (solo informativo).

### Modo `-Apply -Decisions <archivo>`

`tools/devicons-decisions.jsonc` (versionado) contiene:

- `exclude`: claves (`.foo`, `Foofile`) o grupos (`group:PrettierConfig`) que no entran;
- `adopt`: claves existentes cuyo glifo y color se sustituyen por los de la referencia (en `light` y `dracula` con las
  derivaciones de la sección 4);
- `colors`: colores elegidos a mano para entradas sin color que la referencia no cubre.
- `folders`: colores para carpetas con icono y sin color (añadido tras la revisión, a petición del usuario).
- `aliases`: nombres de archivo que se mapean como una clave de la referencia (`config.ru` → `.config.ru`, que la
  referencia solo tiene como extensión).

El archivo se valida antes de escribir: ajustes desconocidos, listas u objetos con otro tipo y colores que no son
`#RRGGBB` se rechazan; las entradas que no coinciden con nada (claves, grupos, carpetas) generan un aviso.

Escribe en `themes/icons/default.jsonc` y en `themes/colors/{default,light,dracula}.jsonc` reutilizando la lógica de
`tools/Set-ThemeEntry.ps1` (conserva la cabecera, ordena claves, evita duplicados por mayúsculas). Es idempotente: una
segunda ejecución con los mismos datos no cambia nada. Con datos nuevos de la referencia solo aparece lo nuevo.

## 4. Colores

- **default:** el color de la referencia salvo que su contraste sobre `#1E1E1E` sea menor de 3:1; entonces se sube la
  luminosidad HSL, conservando tono y croma, hasta alcanzar 3:1 (añadido tras la revisión: 64 entradas de la
  referencia eran casi ilegibles sobre fondo oscuro).
- **light:** el mismo color salvo que su contraste sobre `#FFFFFF` sea menor de 3:1 (WCAG para elementos que no son
  texto); entonces se baja la luminosidad HSL, conservando tono y croma, hasta alcanzar 3:1. (La versión inicial
  conservaba la saturación HSL, que es alta en los blancos con un leve tinte y los volvía colores vivos.)
- **dracula:** el color más cercano de la paleta Dracula (`FF5555`, `FFB86C`, `F1FA8C`, `50FA7B`, `8BE9FD`, `BD93F9`,
  `FF79C6`) por tono; los colores con saturación HSV menor de 0,2 (grises y blancos con un leve tinte) van a `F8F8F2`
  si su luminosidad es al menos 0,5 y a `6272A4` si no. Los colores de marca existentes en `dracula` no se tocan.
- Las tres reglas solo se aplican a lo que escribe la herramienta; los colores existentes no cambian salvo `adopt`.
- **Sin color:** las entradas con icono y sin color toman el color de la referencia si existe; si no, el de `colors`
  en el archivo de decisiones.
- Ambas derivaciones son funciones puras con tests de casos fijos.

## 5. Tests

- `tests/Devicons.Tests.ps1`, con datos de ejemplo en TestDrive y sin red: lectura de los dos formatos, traducción y
  preferencia de nombres, derivación de colores `light` y `dracula`, `-Apply` sobre una copia de los temas
  (respeta `exclude`, `adopt` y `colors`, no cambia lo existente sin `adopt`, conserva la cabecera, es idempotente) y
  contenido del informe.
- Test del `manifest.json` de `vendor/nvim-web-devicons/`.
- Invariante del tema: cada clave con icono en `files` tiene color en los tres temas de color.
- Se mantienen: import sin lecturas ni escrituras, API de 6 comandos, PSScriptAnalyzer sin hallazgos, ASCII en
  `src`, `tools` y `build.ps1`, rendimiento de import < 100 ms; se compara el tiempo del primer listado con 0.2.2.

## 6. Flujo y publicación

1. Spec aprobada → plan en `docs/superpowers/plans/2026-10-04-devicons-mappings.md`.
2. Implementación de la herramienta con TDD.
3. Se genera el informe y el usuario veta grupos o entradas y elige diferencias a adoptar.
4. Se aplica, se revisan los temas resultantes y se comprueba el build.
5. Versión `0.3.0`, README (alcance y crédito), `THIRD_PARTY_NOTICES.md` y CHANGELOG.
6. Revisión independiente, PR y publicación en la Gallery, ambos con confirmación del usuario.
