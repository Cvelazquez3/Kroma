# Resumen de Participación en Git (`upstream`) — KROMA

**Repositorio oficial (`upstream`):** `https://github.com/Cvelazquez3/Kroma.git`  
**Periodo registrado:** 13 de octubre de 2026 – 18 de noviembre de 2026  
**Total de commits en `upstream`:** 60 commits  
**Total de Pull Requests integrados:** 13 (`#1`, `#2`, `#4`, `#5`, `#6`, `#7`, `#8`, `#9`, `#10`, `#11`, `#12`, `#14`, `#15`)

---

## 1. Resumen Cuantitativo por Integrante

> **Nota:** Algunos integrantes realizaron commits desde más de una configuración local de `git` (por ejemplo, distinto equipo o cliente GitHub). En la tabla se consolidan todas sus identidades verificadas en `upstream`.

| Integrante | Identidades Git en `upstream` | Commits | % del total | Ramas trabajadas | Pull Requests |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **Toledo** | `toledo.`, `toledo`, `ToIedo`, `toledo. -student`, `bytoledo` | **35** | 58.3% | `main`, `feat/greybox-nivel-1`, `feature/prototipo-completo`, `feature/v2-ui-and-gameplay` | `#2` (merge), `#5`, `#6` (merge), `#10`, `#11`, `#12`, `#14`, `#15` |
| **Christian Velázquez** | `Christian`, `Christian Velazquez` | **12** | 20.0% | `christian` | `#1`, `#8`, `#9` |
| **Carlos** | `Carcamp016` | **8** | 13.3% | `feat/carlos-controles-historial`, `integracion/carlos-christian`, `feat/carlos-sprint-2` | `#4`, `#7` |
| **Ian** | `Ian` | **5** | 8.3% | `feat/ian-logica-tablero`, `feat/ian-abismos-glifos` | `#2`, `#6` |
| **Total** | | **60** | **100%** | **11 ramas en `upstream`** | **13 PRs** |

---

## 2. Detalle de Aportes por Integrante

### Toledo (`toledo.`, `toledo`, `ToIedo`, `toledo. -student`, `bytoledo`) — 35 commits
* **Estructura e inicialización:** Estructura inicial del proyecto KROMA (`c3f1f51`).
* **Prototipo y mecánicas base:** Greybox funcional del Nivel 1 con inercia, metas y undo reactivo (`62dc3a1`, PR `#5`); prototipo funcional completo v1.0 con tutorial, banner responsivo y niveles JSON 01–04 (`f9fce34`, `e7709c7`, PR `#10`/`#12`).
* **Arquitectura y lógica avanzada (v2.0):** Refactorización de `level_01` a `gameplay`, condición formal de derrota (`is_defeated` con verificación cromática y de movimientos) y Par Óptimo BFS (`982723f`, `74158f1`, `84f4e34`).
* **Interfaz, modos y multiplataforma (v2.0):** Menú principal, selector de dificultad procedural, Racha Perfecta, controles táctiles y estética *glassmorphism* (`811c23a`, `f268abf`, `a3b20f8`).
* **Audio, exportación y Web/WASM:** Sincronización de SFX de UI/gameplay, filetes en muros, `icon.ico`, adaptación de glifos en Web/WASM y escala responsiva en móvil (`8714796`, `65499f9`).
* **Documentación e integración:** Redacción y formalización del `README.md` v2.0 y revisión/merge de PRs del equipo (`#2`, `#5`, `#6`, `#10`, `#11`, `#12`).

### Christian Velázquez (`Christian`, `Christian Velazquez`) — 12 commits
* **Carga y validación de niveles:** Definición del formato JSON de niveles y `LevelLoader` (`43c4c4d`, PR `#1`).
* **Lógica central del tablero y solver:** `BoardState` con inercia discreta, `snapshot`/`undo`, fusión cromática, inercia post-fusión, `preview_move` y pruebas (`91e6427`, `8453c45`); implementación del solver BFS y niveles 02–03 con soluciones verificadas (`aebfb73`, `8989b5b`, PR `#8`).
* **Integración visual y correcciones:** Integración de glifos en la escena principal, centrado dinámico para tableros `7×7`, `README.md` inicial (`14499c9`, PR `#9`) y correcciones de tipado/HUD (`6c6a971`, `2fd1431`).

### Carlos (`Carcamp016`) — 8 commits
* **Controles e historial:** Controles de movimiento, `undo` y reinicio (`54be8cc`, `e874de6`); integración con el `BoardState` de Christian y pruebas unitarias de historial y restauración tras victoria (`2b55b3b`, `3f7e09f`, `9154c0d`, PR `#4`).
* **HUD y flujo de niveles:** Selección de bloque, fusión cromática en escena, HUD y transición entre niveles (`ba00b03`, PR `#7`).

### Ian (`Ian`) — 5 commits
* **Base del tablero (`BoardState`):** Carga de tablero desde `LevelData` (`a38641e`), sistema `snapshot`/`restore` (`1812080`), encaje en receptor y detección de victoria (`187fa36`, `ce05c47`, PR `#2`).
* **Accesibilidad visual:** Implementación de glifos geométricos por color y escena de prueba (`f8be9f3`, PR `#6`).

---

## 3. Línea de Tiempo de Pull Requests e Integraciones en `upstream`

### Etapa 1 — Base, Mecánicas y Prototipo v1.0 (Pull Requests `#1` – `#12`)

| PR / Merge | Fecha | Rama | Autor / Integrador | Descripción |
| :---: | :---: | :--- | :--- | :--- |
| `#1` | 2026-10-15 | `christian` | Christian Velázquez | Formato JSON y cargador de niveles (`LevelLoader`). |
| `#4` | 2026-10-19 | `integracion/carlos-christian` | Carlos (`Carcamp016`) | Integración de controles, historial y `BoardState` con tests. |
| `#2` | 2026-10-19 | `feat/ian-logica-tablero` | Ian / Toledo | Carga de `LevelData`, snapshot/restore y detección de victoria. |
| `#5` | 2026-10-22 | `feat/greybox-nivel-1` | Toledo | Greybox funcional del nivel 1 con inercia, metas y undo. |
| `#6` | 2026-10-22 | `feat/ian-abismos-glifos` | Ian / Toledo | Glifos geométricos por color y escena de prueba. |
| `#7` | 2026-10-23 | `feat/carlos-sprint-2` | Carlos (`Carcamp016`) | Selección, fusión cromática, HUD y transición de niveles. |
| `#8` | 2026-10-23 | `christian` | Christian Velázquez | Nivel 03, solver BFS y soluciones verificadas (niveles 01–03). |
| `#9` | 2026-10-23 | `christian` | Christian Velázquez | Integración de glifos, centrado dinámico `7×7` y `README.md`. |
| `#10` | 2026-10-24 | `feature/prototipo-completo` | Toledo | Prototipo funcional v1.0: tutorial, banner responsivo y niveles 01–04. |
| `#11` | 2026-10-24 | `revert-10-feature/prototipo-completo` | Toledo | Reversión temporal de PR `#10`. |
| `#12` | 2026-10-24 | `feature/prototipo-completo` | Toledo | Reintegración limpia del prototipo funcional v1.0. |

### Etapa 2 — Evolución y Cierre Prototipo v2.0 (Ramas `main` y `feature/v2-ui-and-gameplay`, PRs `#14` – `#15`)

| PR / Commit | Fecha | Rama en `upstream` | Autor / Integrador | Descripción |
| :---: | :---: | :--- | :--- | :--- |
| `ab31363` | 2026-10-30 | `main` | Toledo | Estructura inicial y base del prototipo v2.0. |
| `982723f` – `84f4e34` | 2026-11-10/11 | `main` | Toledo | Refactor `level_01` → `gameplay`, condición de derrota (`is_defeated`), Par Óptimo BFS y documentación. |
| `7bee173` | 2026-11-11 | `main` | Toledo | Merge de `upstream/main` manteniendo el prototipo completo. |
| `941b766` – `a900d6d`, `83fe760` | 2026-11-11 | `main` / `feature/prototipo-completo` | Toledo | Formalización de `README.md` v2.0 (arquitectura, solver BFS, créditos e instrucciones). |
| **`#14`** (`d987ff5`) | 2026-11-17 | `feature/v2-ui-and-gameplay` → `main` | Toledo | Menú principal, dificultad procedural, Racha Perfecta, controles táctiles y *glassmorphism* (`811c23a`, `f268abf`, `a3b20f8`). |
| **`#15`** (`3e9792f`) | 2026-11-18 | `feature/v2-ui-and-gameplay` → `main` | Toledo | Sincronización de SFX UI/gameplay, filetes en muros, `icon.ico`, glifos Web/WASM y escala móvil (`8714796`, `65499f9`). |

---

## 4. Ramas Registradas en `upstream`

* `upstream/main`
* `upstream/christian`
* `upstream/feat/carlos-controles-historial`
* `upstream/feat/carlos-sprint-2`
* `upstream/feat/greybox-nivel-1`
* `upstream/feat/ian-abismos-glifos`
* `upstream/feat/ian-logica-tablero`
* `upstream/feature/prototipo-completo`
* `upstream/feature/v2-ui-and-gameplay`
* `upstream/integracion/carlos-christian`
* `upstream/revert-10-feature/prototipo-completo`
