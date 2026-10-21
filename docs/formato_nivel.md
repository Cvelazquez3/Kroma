# Formato de nivel de Kroma (JSON, versión 1)

Cada nivel es un archivo en `res://data/levels/` (por ejemplo `level_01.json`).
Se carga con `LevelLoader` y el resultado es un `LevelData`. El código de juego
**nunca** lee el JSON directamente: siempre pasa por el cargador.

```gdscript
var level := LevelLoader.load_from_file("res://data/levels/level_01.json")
if not level.is_valid():
	push_error("\n".join(level.errors))
	return
```

## Coordenadas

- `x` = columna, empieza en 0 a la izquierda.
- `y` = fila, empieza en 0 **arriba**.
- Es la misma convención que `grid[x][y]` y que el 2D de Godot (arriba = `y` menor).

| Dirección | Cambio |
|-----------|--------|
| Arriba    | `y - 1` |
| Abajo     | `y + 1` |
| Izquierda | `x - 1` |
| Derecha   | `x + 1` |

## Campos

| Campo | Tipo | Obligatorio | Descripción |
|-------|------|-------------|-------------|
| `version` | entero | no (por defecto 1) | Versión del formato. Hoy solo existe la 1. |
| `id` | entero | no | Número del nivel. |
| `name` | texto | no | Nombre del nivel. |
| `sector` | entero | no (por defecto 1) | Sector para el HUD. |
| `size` | `{width, height}` | **sí** | Entre 5×5 y 8×8. |
| `walls` | lista de `{x, y}` | no | Muros rígidos. |
| `voids` | lista de `{x, y}` | no | Celdas nulas (abismo). |
| `blocks` | lista de `{id, x, y, color}` | **sí** (≥ 1) | Bloques iniciales. `id` es opcional (`b1`, `b2`… por orden). |
| `receptors` | lista de `{x, y, color}` | **sí** (≥ 1) | Metas. |

Colores válidos: `red`, `blue`, `yellow` (primarios) y `purple`, `green`, `orange` (secundarios).

## Reglas que valida el cargador

- Todas las celdas están dentro del tablero.
- Ninguna celda se usa dos veces (un muro, abismo, bloque o receptor por celda).
- Los colores son de la lista válida.
- Los `id` de bloques no se repiten.
- Hay al menos un bloque y un receptor, y no hay más receptores que bloques.

## Qué recibe el resto del equipo (`LevelData`)

| Propiedad | Tipo |
|-----------|------|
| `width`, `height` | `int` |
| `walls`, `voids` | `Array[Vector2i]` |
| `blocks` | `Array[Dictionary]` con `{"id": String, "pos": Vector2i, "color": String}` |
| `receptors` | `Array[Dictionary]` con `{"pos": Vector2i, "color": String}` |
| `id`, `level_name`, `sector` | `int`, `String`, `int` |

## Ejemplo: Nivel 01

```
	 x: 0 1 2 3 4
   y0:  . . . . .
   y1:  . . . . .
   y2:  . . # . R      R = receptor rojo (4,2)
   y3:  . . . B #      B = bloque rojo (3,3)
   y4:  . # . . #      # = muro
```

Una solución: arriba → derecha → abajo (dos giros de 90°). El muro en (4,3) frena el bloque sobre el receptor.

## Cómo agregar un nivel

1. Copia `level_01.json` a `level_02.json` y cambia los datos.
2. Cárgalo con `LevelLoader.load_from_file(...)` y revisa `is_valid()`.
3. Si algo está mal, `level.errors` dice exactamente qué y dónde.

## Probar el cargador

```
godot --headless --path . --script res://scripts/tests/test_level_loader.gd
```

(En Windows usa el ejecutable `..._console.exe` de Godot.) Debe terminar con `TODO OK`.

---

## Lógica pura del tablero (`BoardState`)

`BoardState` traduce un `LevelData` en un estado mutable y determinista.
**No conoce nodos de Godot ni señales visuales.** Toda la lógica de juego pasa por aquí.

### Inicializar

```gdscript
var state := BoardState.new()
state.init_from_level(level)   # level es un LevelData válido
```

### Tipos de celda (`BoardState.Cell`)

| Constante  | Valor | Significado |
|------------|-------|-------------|
| `EMPTY`    | 0 | Celda libre |
| `WALL`     | 1 | Muro rígido |
| `VOID`     | 2 | Abismo (bloque que cae → derrota) |
| `BLOCK`    | 3 | Bloque activo |
| `RECEPTOR` | 4 | Objetivo vacío |
| `LOCKED`   | 5 | Bloque encajado (actúa como muro) |

### Mover un bloque (`apply_move`)

```gdscript
var path: Array = []
var result := state.apply_move("b1", Vector2i.RIGHT, path)
# path contiene las celdas que recorrió el bloque (sin el origen).
```

El bloque se desplaza con **inercia discreta**: avanza celda a celda en la dirección indicada hasta que el siguiente paso sea un obstáculo (muro, borde, otro bloque o bloque encajado). Si cae en un abismo devuelve `FELL`; si encaja en un receptor del mismo color, `SNAPPED` o `VICTORY`.

### Resultados posibles (`BoardState.MoveResult`)

| Constante   | Significado |
|-------------|-------------|
| `OK`        | El bloque se movió al menos una celda |
| `BLOCKED`   | No había espacio para avanzar |
| `FELL`      | El bloque cayó en un abismo |
| `SNAPPED`   | Encajó en un receptor (quedan más por llenar) |
| `VICTORY`   | Todos los receptores cubiertos |
| `NOT_FOUND` | El id de bloque no existe |

### Undo y reinicio

```gdscript
# Guardar ANTES de mover:
var snap := state.snapshot()
state.apply_move("b1", Vector2i.UP)

# Deshacer:
state.restore(snap)

# Reinicio: guardar el snapshot inicial justo después de init_from_level().
var initial_snap := state.snapshot()
# ... (varios movimientos) ...
state.restore(initial_snap)   # reinicia al estado de carga
```

### Probar BoardState

```
godot --headless --path . --script res://scripts/tests/test_board_state.gd
```
