# KROMA — Videojuego de Lógica Espacial Minimalista

**Kroma** es un videojuego de puzles 2D en cuadrícula ortogonal minimalista (5×5 a 7×7 celdas) donde los bloques activos carecen de fricción y se desplazan con **inercia continua** en cuatro ejes cardinales hasta colisionar.

El juego combina desplazamiento inercial discreto, **síntesis cromática determinista** y **mutación topológica**: cada bloque encajado en su receptor meta se petrifica como un nuevo muro rígido, alterando las trayectorias posibles para las piezas restantes.

---

## 🎮 Controles

| Acción | Teclado | Función |
|---|---|---|
| **Mover bloque** | `Flechas` / `WASD` | Desliza el bloque activo con inercia hasta chocar |
| **Cambiar bloque activo** | `Tab` | Alterna entre los bloques disponibles en el sector |
| **Deshacer (Undo)** | `Z` / Botón UI | Revierte el último movimiento (pila de Undo ilimitada) |
| **Reiniciar nivel** | `R` / Botón UI | Restaura el sector a su estado inicial de carga |

---

## 🎨 Reglas Mecánicas y Síntesis Cromática

1. **Inercia Discreta:** Los bloques se deslizan en línea recta sin detenerse hasta impactar con un muro, el borde perimetral o un bloque inerte.
2. **Fusión Cromática (Primarios → Secundarios):**
   - 🔴 **Rojo** + 🔵 **Azul** = 🟣 **Púrpura**
   - 🔵 **Azul** + 🟡 **Amarillo** = 🟢 **Verde**
   - 🟡 **Amarillo** + 🔴 **Rojo** = 🟠 **Naranja**
   *(Los bloques secundarios ya no pueden volver a fusionarse).*
3. **Encaje y Mutación Topológica:** Cuando un bloque del color correcto alcanza su receptor meta, encaja y se convierte en un **muro rígido permanente**, sirviendo como nuevo punto de apoyo para giros a 90°.
4. **Glifos de Accesibilidad:** Cada color está emparejado con una forma geométrica para garantizar jugabilidad inclusiva:
   - 🔴 Círculo | 🔵 Cuadrado | 🟡 Triángulo | 🟣 Rombo | 🟢 Cruz | 🟠 Hexágono
5. **Abismos:** Celdas nulas donde los bloques caen si no se planifica la trayectoria adecuadamente.

---

## 🗺️ Estructura de Niveles (Sector 1)

* **Nivel 01 — Deslizar y Encajar (5×5):** Introducción al movimiento inercial y freno con muros a 90°.
* **Nivel 02 — Síntesis Cromática (5×5):** Fusión obligatoria de colores primarios para obtener el bloque secundario requerido.
* **Nivel 03 — Mutación Topológica (7×7):** Sector avanzado con 3 bloques y abismos donde el encaje de la primera pieza altera el espacio transitable para resolver la segunda.

---

## 🛠️ Tecnologías y Arquitectura

* **Motor:** Godot Engine 4.x (Mobile / Canvas Items)
* **Lógica pura y determinismo:** `scripts/board/board_state.gd` (desacoplada de nodos y render)
* **Formato de datos:** JSON validado mediante `scripts/levels/level_loader.gd`
* **Verificación algorítmica:** Solver BFS en `scripts/board/level_solver.gd` para garantizar solvencia matemática sin deadlocks.

---

## 👥 Equipo de Desarrollo

* **Christian:** Cargador de niveles JSON, lógica pura del tablero (`BoardState`), diseño de niveles y Solver BFS.
* **Carlos:** Arquitectura de controles cardinales, sistema de historial / Undo reactivo, HUD y flujo de niveles.
* **Ian:** Sistema de glifos geométricos de accesibilidad, lógica de colisión y abismos.
