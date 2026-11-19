# Seguimiento Scrum y Cierre de Proyecto — KROMA

**Equipo:** KROMA Dev Studio (Toledo, Christian Velázquez, Carlos, Ian)  
**Repositorio `upstream`:** `https://github.com/Cvelazquez3/Kroma.git`  
**Periodo total:** 12 de octubre de 2026 – 18 de noviembre de 2026  

---

## 1. Resumen de Sprints

| Sprint | Fechas | Objetivo / Definición de Terminado | Estado | Evidencia en `upstream` |
| :--- | :--- | :--- | :---: | :--- |
| **Sprint 1** | 12 – 16 oct 2026 | Base técnica en Godot 4, formato JSON, `BoardState` puro, inercia discreta, encaje/victoria, Undo/reinicio y Nivel 01 jugable. | **Completado** | Commits `c3f1f51` – `ce05c47`, PR `#1` |
| **Sprint 2** | 19 – 23 oct 2026 *(cierre 24 oct)* | Fusión cromática, abismos (`voids`), Niveles 02–03, Solver BFS, glifos universales, HUD, transición de niveles y prototipo funcional. | **Completado** | PRs `#2`, `#4`, `#5`, `#6`, `#7`, `#8`, `#9`, `#10`–`#12` |
| **Sprint 3 (Cierre v2.0)** | 3 – 18 nov 2026 *(meta orig. 29 nov)* | Refactor `level_01` → `gameplay`, condición de derrota, Par Óptimo BFS en HUD, Menú Principal, dificultad procedural, Racha Perfecta, pausa, controles táctiles y exportación Web/Windows. | **Completado** | Commits `982723f` – `65499f9`, PRs `#14`, `#15` |

---

## 2. Sprint 1 (12 al 16 de octubre de 2026)

* **Jornadas:** 4 días activos | **Integrantes:** 4  
* **Ceremonias:** Google Meet (inicio y cierre, 18:00 hrs) + seguimiento diario por WhatsApp.  
* **Burndown (horas):**
  * **Tiempo ideal:** `35 → 26.25 → 19.69 → 13.13 → 6.56 → 0`
  * **Tiempo real:** `35 → 33 → 26 → 15 → 3 → 0` *(cumplido al 100%)*

| Elemento del backlog | Tarea | Responsable | Est. (h) | Estado final | Evidencia `upstream` |
| :--- | :--- | :--- | :---: | :---: | :--- |
| Base técnica y datos | Crear proyecto en Godot 4 y subirlo al repositorio | Toledo | 2 | Completado | `c3f1f51` |
| Base técnica y datos | Formato JSON de nivel y cargador (`LevelLoader`) | Christian | 3 | Completado | `43c4c4d`, PR `#1` |
| Base técnica y datos | Estado del tablero en lógica pura (`BoardState`) | Ian | 4 | Completado | `a38641e`, `1812080` |
| Movimiento y reglas | Tablero greybox desde JSON | Toledo | 4 | Completado | `62dc3a1`, PR `#5` |
| Movimiento y reglas | Entrada cardinal y FSM `IDLE/SLIDING` | Carlos | 4 | Completado | `54be8cc` |
| Movimiento y reglas | Inercia discreta y frenado en muros/bordes | Christian | 4 | Completado | `91e6427` |
| Movimiento y reglas | Encaje en receptor (muro rígido) y victoria | Ian | 4 | Completado | `187fa36`, PR `#2` |
| Undo y Nivel 01 | Snapshots, Undo ilimitado y reinicio rápido | Carlos | 4 | Completado | `54be8cc`, `e874de6`, PR `#4` |
| Undo y Nivel 01 | Diseñar y cargar Nivel 01 (`5×5`, giro 90°) | Toledo | 3 | Completado | `62dc3a1`, PR `#5` |
| Undo y Nivel 01 | Pruebas de determinismo y entrega v0.1 | Todos | 3 | Completado | `3f7e09f`, `9154c0d` |

---

## 3. Sprint 2 (19 al 23 de octubre de 2026)

* **Jornadas:** 4 días activos | **Integrantes:** 4  
* **Ceremonias:** Google Meet (lunes, jueves y viernes 18:00 hrs) + WhatsApp (martes y miércoles).  
* **Burndown (horas):**
  * **Tiempo ideal:** `35 → 26.25 → 19.69 → 13.13 → 6.56 → 0`
  * **Tiempo real:** `35 → 35 → 24 → 13 → 4 → 0` *(cerrado con la integración de los PRs `#7`–`#12` el 23–24 de octubre)*

| Elemento del backlog | Tarea | Responsable | Est. (h) | Estado final | Evidencia `upstream` |
| :--- | :--- | :--- | :---: | :---: | :--- |
| Fusión y abismos | Selección de bloque activo y fusión cromática | Carlos | 4 | Completado | `ba00b03`, PR `#7` |
| Fusión y abismos | Inercia post-fusión (freno) y celdas nulas (abismos) | Ian / Christian | 4 | Completado | `8453c45`, PR `#6` |
| Niveles y solver | Diseñar Nivel 02 (`6×6`, fusión obligatoria) | Christian / Carlos | 3 | Completado | `aebfb73`, `ec8ae6a` |
| Niveles y solver | Diseñar Nivel 03 (`7×7`, 2 receptores, abismos) | Toledo / Christian | 4 | Completado | `8989b5b`, PR `#8` |
| Niveles y solver | Programar Solver BFS sobre lógica pura | Christian / Toledo | 4 | Completado | `aebfb73`, `8989b5b` |
| Niveles y solver | Validar Niveles 01–03 y guardar soluciones | Christian | 2 | Completado | `8989b5b`, PR `#8` |
| Flujo, UI y feedback | Transición entre niveles y HUD mínimo | Carlos | 3 | Completado | `ba00b03`, PR `#7` |
| Flujo, UI y feedback | Glifos geométricos y feedback audiovisual | Ian / Toledo | 4 | Completado | `f8be9f3`, `14499c9`, PR `#6`, `#9` |
| Pruebas y entrega | Playtest, corrección de bugs y regresión | Todos | 4 | Completado | `6c6a971`, `2fd1431` |
| Pruebas y entrega | Prototipo funcional, README y entrega | Todos | 3 | Completado | `f9fce34`, `e7709c7`, PR `#12` |

---

## 4. Sprint 3 — Cierre de Curso y Versión v2.0 (3 al 18 de noviembre de 2026)

A partir de la evaluación de avances emitida el **3 de noviembre de 2026**, el equipo ejecutó el plan de cierre y completó todas las prioridades indispensables (además de la exportación Web HTML5 marcada originalmente como opcional) antes de la entrega final:

| Prioridad (Plan 3 nov) | Actividad | Responsable principal | Estado | Evidencia `upstream` |
| :--- | :--- | :--- | :---: | :--- |
| **1. Indispensable** | Refactorizar `level_01` a `gameplay` y actualizar `project.godot` | Toledo | **Completado** | `982723f` |
| **2. Indispensable** | Pantalla de inicio (`main_menu.tscn`), selector de dificultad y créditos | Toledo | **Completado** | PR `#14` (`811c23a`, `f268abf`, `a3b20f8`) |
| **3. Indispensable** | Ajuste de dificultad procedural (`5×5`, `6×6`, `7×7`, muros, abismos, acoples) | Toledo | **Completado** | PR `#14` (`811c23a`, `a3b20f8`) |
| **4. Indispensable** | Condición formal de derrota (`is_defeated`: piezas, compatibilidad cromática, deadlock) | Toledo | **Completado** | `982723f`, `74158f1`, `84f4e34` |
| **5. Indispensable** | Par Óptimo BFS en HUD y sistema de Racha Perfecta (`user://save.cfg`) | Toledo | **Completado** | `982723f`, PR `#14` (`a3b20f8`) |
| **6. Indispensable** | Menú de pausa (`ESC` / botón móvil) y controles táctiles (*swipe/tap*) | Toledo | **Completado** | PR `#14` (`a3b20f8`) |
| **Opcional ejecutada** | Estética *glassmorphism*, SFX sincronizados, presets Windows/Web y fixes Web/WASM | Toledo | **Completado** | PR `#15` (`8714796`, `65499f9`) |
| **Documentación** | Formalización del `README.md` v2.0 y registro de participación Git/Scrum | Equipo | **Completado** | `37d2bf2`, `c3ed7e2`, `docs/` |

---

## 5. Checklist de Entrega Final (19 de noviembre de 2026)

* **a) Juego instalable / desplegado:** Presets configurados (`Windows Desktop` y `Web`), assets de tienda/itch.io en `export/`.
* **b) Video tráiler:** Por grabar y editar (~50s, guion definido).
* **c) Documentación y registros Git/Scrum:**
  * [README.md](../README.md) (arquitectura, mecánicas, glifos, controles, pruebas, créditos).
  * [formato_nivel.md](formato_nivel.md) (especificación JSON).
  * [RESUMEN_PARTICIPACION_GIT.md](RESUMEN_PARTICIPACION_GIT.md) (métricas exclusivas de `upstream`).
  * [SEGUIMIENTO_SCRUM_Y_CIERRE.md](SEGUIMIENTO_SCRUM_Y_CIERRE.md) (Sprints 1–3, burndown y cierre).
  * Tablas CSV originales de Sprint 1 y Sprint 2 + Reporte del 3 de noviembre (PDF).
