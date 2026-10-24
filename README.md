# KROMA

> Videojuego de lógica espacial minimalista en 2D desarrollado sobre Godot Engine 4.

**Kroma** es una experiencia de resolución de puzles basada en cuadrículas 
ortogonales discretas (dimensiones de 5×5 a 7×7 celdas), donde las entidades 
activas carecen de coeficiente de fricción y se desplazan mediante inercia 
continua sobre los cuatro ejes cardinales hasta encontrar un obstáculo perimetral
 o estructural.

La arquitectura del juego articula tres principios fundamentales: 
	**desplazamiento inercial discreto**, **síntesis cromática determinista** 
	y **mutación topológica progresiva**. Esta última determina que cada bloque 
	encajado exitosamente en su respectiva celda receptora se petrifica, 
	convirtiéndose en un obstáculo rígido permanente que modifica las trayectorias 
	e introduce nuevos puntos de apoyo para las piezas restantes.

---

## Reglas Mecánicas y Síntesis Cromática

1. **Inercia Discreta:** El vector cinemático de traslación se proyecta celda 
por celda sin pérdida de energía hasta registrar impacto directo contra un muro 
rígido, el límite perimetral del tablero o una entidad estática.
2. **Álgebra de Síntesis Cromática:** La colisión frontal entre entidades de 
pigmentación primaria genera una transición determinista hacia un estado secundario:
   * 🔴 **Rojo** + 🔵 **Azul** $\rightarrow$ 🟣 **Púrpura**
   * 🔵 **Azul** + 🟡 **Amarillo** $\rightarrow$ 🟢 **Verde**
   * 🟡 **Amarillo** + 🔴 **Rojo** $\rightarrow$ 🟠 **Naranja**  
   *(Las entidades secundarias resultantes constituyen estados terminales y no 
admiten recombinación ulterior).*
3. **Mutación Topológica:** Al consolidar un objetivo cromático sobre un receptor 
meta, la entidad pierde movilidad y transmuta su estado a muro sólido intransitable, 
alterando el grafo de adyacencias y habilitando nuevos giros a 90°.
4. **Glifos Geométricos de Accesibilidad:** Implementación de simbología unívoca 
emparejada con la paleta de color para garantizar accesibilidad universal y 
compatibilidad con afecciones de la percepción cromática:
   * 🔴 **Rojo:** Círculo
   * 🔵 **Azul:** Cuadrado
   * 🟡 **Amarillo:** Triángulo
   * 🟣 **Púrpura:** Rombo
   * 🟢 **Verde:** Cruz
   * 🟠 **Naranja:** Hexágono
5. **Abismos Estructurales (`voids`):** Celdas de disrupción topológica carentes 
de sustrato físico. Cruzar sus coordenadas conlleva la aniquilación de la pieza 
activa y requiere el retroceso temporal o reinicio del sector.

---

## Mapeo de Entradas y Controles

El esquema de control implementa amortiguación de comandos e interacción dual 
(teclado e interfaz gráfica), con soporte para reversión temporal determinista:

| Acción | Mapeo Primario | Mapeo Secundario / UI | Comportamiento Técnico |
| :--- | :--- | :--- | :--- |
| **Desplazamiento** | `W` `A` `S` `D` | `↑` `←` `↓` `→` | Aplica un vector de 
movimiento continuo al bloque activo hasta la colisión. |
| **Conmutación** | `Tab` | `Espacio` | Itera cíclicamente el selector de control 
entre los bloques libres del sector. |
| **Reversión (Undo)** | `Z` | Botón HUD | Restaura el estado inmediato anterior 
desde la pila LIFO (`history_stack`). |
| **Reinicio** | `R` | Botón HUD | Restablece el sector a su configuración inicial 
de serialización. |

---

## Desglose Curricular de Niveles (Sector 1)

* **Nivel 01 — Deslizar y Encajar ($5 \times 5$):** Introducción heurística a la 
cinemática sin fricción, topes ortogonales y direccionamiento a metas fijas.
* **Nivel 02 — Síntesis Cromática ($5 \times 5$):** Implementación de la interacción 
física entre entidades para la obtención del espectro secundario requerido por el 
receptor.
* **Nivel 03 — Mutación Topológica ($7 \times 7$):** Escenario de tres entidades 
y vacíos estructurales que exige planificación secuencial: el sellado de la primera 
pieza redefine el espacio transitable para la resolución de las subsecuentes.
* **Nivel 04 — Falla Estructural ($6 \times 6$):** Sector técnico con un foso 
central de abismos, donde la trayectoria hacia el receptor demanda rebotes 
perimetrales para eludir la zona de caída.

---

## Especificación Técnica y Arquitectura

* **Entorno de Ejecución:** Godot Engine 4.x (renderizado 2D / Canvas Items).
* **Simulación Determinista:** Lógica de tablero desacoplada de la jerarquía de 
nodos mediante `BoardState`, encapsulando el cálculo discreto de posiciones y 
colisiones.
* **Pipeline de Datos:** Ingestión y validación estructural de archivos JSON vía 
`LevelLoader`, asegurando integridad topológica y balances de solvencia previa 
a la instanciación.
* **Verificación Formal:** Algoritmo Solver basado en Búsqueda en Anchura (BFS) 
en `LevelSolver` para la demostración matemática de solvencia y descarte de 
situaciones de bloqueo irresoluble (*deadlocks*).
* **Paisaje Sonoro Paramétrico:** Módulo centralizado `AudioManager` con eventos 
de baja latencia asignados a traslación (`slide`), impacto elástico (`bump`), 
fijación de meta (`snap`), absorción por vacío (`void`) y resolución del sector 
(`victory`).
* **Generación Procedural Infinita:** Algoritmo dinámico que toma el control 
tras completar el Sector 1, generando cuadrículas procedurales con topología 
balanceada.
* **HUD Procedural y Respuesta Háptica:** Cálculo analítico de dimensiones en 
tiempo de ejecución para el anclaje del banner instructivo, complementado con 
deformaciones elásticas (*squash & stretch*) y micro-impacto visual ante vectores 
bloqueados.

---

## Estructura del Proyecto

```
├```text
├── assets/
│   └── audio/              # Recursos sonoros y efectos reactivos
├── data/
│   ├── levels/             # Archivos de serialización de sectores en formato JSON
│   └── solutions/          # Soluciones algorítmicas validadas por el solver
├── docs/                   # Documentación técnica adicional y diagramas
├── scenes/                 # Escenas del motor (.tscn) de tablero, entidades e interfaz
├── scripts/
│   ├── board/              # Lógica pura del tablero (BoardState, Solver BFS)
│   ├── controllers/        # Controladores de entrada, flujo de juego y undo
│   ├── levels/             # Ingestión, carga y parsing de niveles (LevelLoader)
│   ├── tests/              # Pruebas unitarias y de solvencia
│   ├── view/               # Renderizado del tablero, visuales de celdas y HUD
│   ├── audio_manager.gd    # Módulo centralizado de eventos y modulación de audio
│   └── level_generator.gd  # Generador algorítmico procedural de sectores infinitos
├── export_presets.cfg      # Configuraciones de compilación y exportación de Godot
├── icon.svg                # Ícono vectorizado del proyecto
└── README.md               # Documentación técnica principal
└── project.godot           # Proyecto de Godot
```
---

## Estructura de un Nivel (JSON)

Los niveles se declaran bajo el siguiente esquema en `data/levels/level_XX.json`:

```json
{
  "version": 1,
  "id": 1,
  "name": "Deslizar y Encajar",
  "sector": 1,
  "instruction": "INERCIA // ESQUIVA LOS MUROS CON [WASD] O [FLECHAS] Y LLEGA A LA META",
  "size": { "width": 5, "height": 5 },
  "walls": [
	{ "x": 1, "y": 4 },
	{ "x": 2, "y": 2 }
  ],
  "voids": [],
  "blocks": [
	{ "id": "b1", "x": 3, "y": 3, "color": "red" }
  ],
  "receptors": [
	{ "x": 4, "y": 2, "color": "red" }
  ]
}
```

* `size`: Dimensiones mínimas de 5×5 y máximas de 7×7 celdas.
* `walls`: Coordenadas de obstáculos rígidos que detienen la inercia.
* `voids`: Celdas de abismo estructural donde la pieza se destruye al entrar 
(vacío en niveles introductorios).
* `blocks`: Entidades dinámicas con identificador unívoco, coordenadas iniciales 
y canal cromático.
* `receptors`: Posiciones objetivo que petrifican al bloque del color respectivo 
al encajar.
* `instruction`: Directiva técnica proyectada dinámicamente en el marco inferior 
del HUD.

---

## Despliegue y Ejecución

### Requisitos Previos
* **Godot Engine 4.x** (versión Standard o .NET).
* Cliente **Git** configurado en el entorno local.

### Instrucciones de Instalación
1. Clonar el repositorio fuente:
   ```
   git clone [https://github.com/Cvelazquez3/Kroma](https://github.com/Cvelazquez3/Kroma)]
   cd kroma
   ```
2. **Inicialización en el motor:**
   * Iniciar **Godot Engine 4.x** en el entorno local.
   * En la ventana del Administrador de Proyectos (*Project Manager*), pulsar el
 botón **Importar** (*Import*).
   * Localizar y seleccionar el archivo `project.godot` ubicado en la raíz del 
repositorio clonado.
   * Confirmar la carga del entorno mediante la opción **Importar y Editar** 
(*Import & Edit*).

3. **Compilación y Ejecución:**
   * Presionar la tecla `F5` (o el botón de reproducción en la barra superior 
del editor) para ejecutar el bucle principal del juego.

---

## Créditos del Proyecto

* **Christian:** Implementación base del motor de carga JSON (`LevelLoader`), 
abstracción lógica del estado del tablero (`BoardState`), diseño preliminar de 
sectores y desarrollo del verificador algorítmico Solver BFS.
* **Carlos:** Arquitectura del subsistema de control cardinal, pipeline del 
historial para reversión temporal (`history_stack`), maquetación inicial de la 
interfaz de usuario (HUD) y secuenciador de sectores.
* **Ian:** Diseño y especificación del sistema de glifos geométricos de 
accesibilidad, modelado del comportamiento físico de colisiones y gestión de 
celdas de abismo (`voids`).
* **Toledo:** Diseño e integración del generador algorítmico procedural para 
sectores infinitos, desarrollo del gestor de audio reactivo (`AudioManager`), 
pipeline de renderizado e ingestión dinámica de directivas técnicas JSON 
(`instruction`), implementación responsiva del banner HUD sobre el marco del 
tablero, estética y feedback visual de foco para entidades activas, 
retroalimentación cinemática elástica (*micro-bump*) continua ante vectores 
bloqueados y consolidación técnica del prototipo funcional v1.0.
