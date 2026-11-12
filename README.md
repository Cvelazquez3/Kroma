# KROMA

> Videojuego de lógica espacial minimalista en 2D desarrollado sobre Godot Engine 4.

**Kroma** es una experiencia de resolución de puzles basada en cuadrículas ortogonales discretas (dimensiones de 5×5 a 7×7 celdas), donde las entidades activas carecen de coeficiente de fricción y se desplazan mediante inercia continua sobre los cuatro ejes cardinales hasta encontrar un obstáculo perimetral o estructural.

La arquitectura del juego articula tres principios fundamentales: **desplazamiento inercial discreto**, **síntesis cromática determinista** y **mutación topológica progresiva**. Esta última determina que cada bloque encajado exitosamente en su respectiva celda receptora se petrifica, convirtiéndose en un obstáculo rígido permanente que modifica las trayectorias e introduce nuevos puntos de apoyo para las piezas restantes.

---

## Reglas Mecánicas y Síntesis Cromática

1. **Inercia Discreta:** El vector cinemático de traslación se proyecta celda por celda sin pérdida de energía hasta registrar impacto directo contra un muro rígido, el límite perimetral del tablero o una entidad estática.
2. **Álgebra de Síntesis Cromática:** La colisión frontal entre entidades de pigmentación primaria genera una transición determinista hacia un estado secundario:
   * 🔴 **Rojo** + 🔵 **Azul** $\rightarrow$ 🟣 **Púrpura**
   * 🔵 **Azul** + 🟡 **Amarillo** $\rightarrow$ 🟢 **Verde**
   * 🟡 **Amarillo** + 🔴 **Rojo** $\rightarrow$ 🟠 **Naranja**  
   *(Las entidades secundarias resultantes constituyen estados terminales y no admiten recombinación ulterior).*
3. **Mutación Topológica:** Al consolidar un objetivo cromático sobre un receptor meta, la entidad pierde movilidad y transmuta su estado a muro sólido intransitable (`LOCKED`), alterando el grafo de adyacencias y habilitando nuevos giros a 90°.
4. **Glifos Geométricos de Accesibilidad:** Implementación de simbología unívoca emparejada con la paleta de color para garantizar accesibilidad universal y compatibilidad con afecciones de la percepción cromática (daltonismo):
   * 🔴 **Rojo:** Círculo
   * 🔵 **Azul:** Cuadrado
   * 🟡 **Amarillo:** Triángulo
   * 🟣 **Púrpura:** Rombo
   * 🟢 **Verde:** Cruz
   * 🟠 **Naranja:** Hexágono
5. **Abismos Estructurales (`voids`):** Celdas de disrupción topológica carentes de sustrato físico. Cruzar sus coordenadas conlleva la aniquilación de la pieza activa.
6. **Detección Formal de Derrota (*Fail State*):** El sistema lógico (`BoardState`) detecta automáticamente estados irresolubles y despliega el banner de advertencia `ESTADO DEL SISTEMA // IRRESOLUBLE`, permitiendo recuperar la partida inmediatamente mediante `[Z]` Deshacer o `[R]` Reiniciar:
   * *Piezas insuficientes:* Cuando los bloques libres en juego son menos que los receptores faltantes.
   * *Incompatibilidad cromática:* Cuando se pierde un bloque primario indispensable para sintetizar un secundario requerido por la meta.
   * *Deadlock cinemático:* Cuando ningún bloque activo tiene movimientos disponibles en ninguna de las cuatro direcciones cardinales.

---

## Mapeo de Entradas y Controles

El esquema de control implementa amortiguación de comandos e interacción dual (teclado e interfaz gráfica), con soporte para reversión temporal determinista:

| Acción | Mapeo Primario | Mapeo Secundario / UI | Comportamiento Técnico |
| :--- | :--- | :--- | :--- |
| **Desplazamiento** | `W` `A` `S` `D` | `↑` `←` `↓` `→` | Aplica un vector de movimiento continuo al bloque activo hasta la colisión. |
| **Conmutación** | `Tab` | `Espacio` | Itera cíclicamente el selector de control entre los bloques libres del sector. |
| **Reversión (Undo)** | `Z` | Botón HUD | Restaura el estado inmediato anterior desde la pila LIFO (`history_stack`). |
| **Reinicio** | `R` | Botón HUD | Restablece el sector a su configuración inicial de serialización. |

---

## Desglose Curricular de Niveles y Generación Procedural

* **Nivel 01 — Deslizar y Encajar ($5 \times 5$):** Introducción heurística a la cinemática sin fricción, topes ortogonales y direccionamiento a metas fijas.
* **Nivel 02 — Síntesis Cromática ($5 \times 5$):** Implementación de la interacción física entre entidades para la obtención del espectro secundario requerido por el receptor.
* **Nivel 03 — Mutación Topológica ($7 \times 7$):** Escenario de tres entidades y vacíos estructurales que exige planificación secuencial: el sellado de la primera pieza redefine el espacio transitable para la resolución de las subsecuentes.
* **Nivel 04 — Falla Estructural ($6 \times 6$):** Sector técnico con un foso central de abismos, donde la trayectoria hacia el receptor demanda rebotes perimetrales para eludir la zona de caída.
* **Modo Simulación Infinita (Procedural BFS):** Al completar los sectores de autor, el generador algorítmico toma el control creando cuadrículas procedurales infinitas con garantía matemática de solvencia calculada en tiempo real.

---

## Especificación Técnica y Arquitectura

* **Entorno de Ejecución:** Godot Engine 4.x (renderizado 2D / Canvas Items).
* **Simulación Determinista:** Lógica de tablero desacoplada de la jerarquía de nodos mediante `BoardState`, encapsulando el cálculo discreto de posiciones, colisiones y condiciones de victoria/derrota.
* **Controlador General de Juego (`gameplay.gd`):** Escena universal desacoplada que gestiona la carga dinámica de cualquier sector JSON o procedural, animaciones con Tweens, FSM de turnos y sincronización visual.
* **Pipeline de Datos:** Ingestión y validación estructural de archivos JSON vía `LevelLoader`, asegurando integridad topológica y balances de solvencia previa a la instanciación.
* **Verificación Formal y Par Óptimo:** Algoritmo Solver basado en Búsqueda en Anchura (BFS) en `LevelSolver` para demostrar matemáticamente la solvencia y proyectar en el HUD el **Par Óptimo de Movimientos** (`PASOS: XX // PAR: YY`).
* **Sistema de Calificación por Estrellas:** Al resolver cada sector se evalúa la eficiencia frente al par BFS:
  * ⭐⭐⭐ **Rango S (Óptimo):** $\text{Pasos} \le \text{Par}$
  * ⭐⭐ **Rango A (Eficiente):** $\text{Pasos} \le \text{Par} + 3$
  * ⭐ **Rango B (Completado):** $\text{Pasos} > \text{Par} + 3$
* **Paisaje Sonoro Paramétrico:** Módulo centralizado `AudioManager` con eventos de baja latencia asignados a traslación (`slide`), impacto elástico (`bump`), fijación de meta (`snap`), absorción por vacío (`void`), reversión (`undo`) y resolución del sector (`victory`).
* **HUD Responsivo y Respuesta Háptica Visual:** Anclaje dinámico del banner instructivo contextual, deformaciones elásticas (*squash & stretch*) y micro-impacto continuo (*bump*) ante vectores bloqueados.

---

## Estructura del Proyecto

```
├── assets/
│   └── audio/              # Recursos sonoros (.wav) y archivos de importación
├── data/
│   ├── levels/             # Archivos de serialización de sectores en formato JSON (01 a 04)
│   └── solutions/          # Soluciones algorítmicas validadas por el solver BFS
├── docs/                   # Documentación técnica, scripts de reporte y planeación
├── scenes/                 # Escenas del motor (.tscn) e interfaz
│   ├── gameplay.gd         # Controlador principal de partida y vista de tablero
│   ├── gameplay.tscn       # Escena principal de juego
│   ├── glyph_preview.tscn  # Vista previa de glifos vectoriales
│   └── test_input.tscn     # Escena de prueba de entrada y controles
├── scripts/
│   ├── board/              # Lógica pura del tablero (BoardState, LevelSolver BFS)
│   ├── controllers/        # Controladores de entrada, flujo de juego y undo
│   ├── levels/             # Ingestión, carga y parsing de niveles (LevelLoader, LevelData)
│   ├── tests/              # Suites de pruebas unitarias y de solvencia
│   ├── view/               # Renderizado de celdas, glifos vectoriales y HUD
│   ├── audio_manager.gd    # Módulo centralizado de eventos y modulación de audio
│   └── level_generator.gd  # Generador algorítmico procedural de sectores infinitos
├── export_presets.cfg      # Configuraciones de compilación y exportación de Godot
├── icon.svg                # Ícono vectorizado del proyecto
├── project.godot           # Archivo de configuración del proyecto Godot
└── README.md               # Documentación técnica principal
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
* `voids`: Celdas de abismo estructural donde la pieza se destruye al entrar.
* `blocks`: Entidades dinámicas con identificador unívoco, coordenadas iniciales y canal cromático.
* `receptors`: Posiciones objetivo que petrifican al bloque del color respectivo al encajar.
* `instruction`: Directiva técnica proyectada dinámicamente en el marco inferior del HUD.

---

## Despliegue y Ejecución

### Requisitos Previos
* **Godot Engine 4.x** (versión Standard recomendada).
* Cliente **Git** configurado en el entorno local.

### Instrucciones de Instalación
1. Clonar el repositorio fuente:
   ```bash
   git clone https://github.com/Cvelazquez3/Kroma.git
   cd kroma
   ```

2. **Inicialización en el motor:**
   * Iniciar **Godot Engine 4.x** en el entorno local.
   * En la ventana del Administrador de Proyectos (*Project Manager*), pulsar el botón **Importar** (*Import*).
   * Localizar y seleccionar el archivo `project.godot` ubicado en la raíz del repositorio clonado.
   * Confirmar la carga mediante la opción **Importar y Editar** (*Import & Edit*).

3. **Compilación y Ejecución:**
   * Presionar la tecla `F5` (o el botón de reproducción en la barra superior del editor) para ejecutar el bucle principal del juego.

---

## Créditos del Proyecto

* **Toledo (Líder Técnico & Arquitectura Central):** Diseño e integración del generador algorítmico procedural para sectores infinitos, gestor de audio reactivo (`AudioManager`), pipeline de renderizado general (`gameplay.gd`), lógica matemática de derrota e incompatibilidad cromática en `BoardState`, cálculo del Par Óptimo BFS y sistema de evaluación por estrellas, banner instructivo contextual dinámico y consolidación técnica del prototipo v2.0.
* **Christian:** Implementación base del motor de carga JSON (`LevelLoader`), abstracción lógica inicial del estado del tablero (`BoardState`), diseño preliminar de sectores y desarrollo del verificador algorítmico Solver BFS.
* **Carlos:** Arquitectura del subsistema de control cardinal, pipeline del historial para reversión temporal (`history_stack`), maquetación inicial de la interfaz de usuario (HUD) y secuenciador de sectores.
* **Ian:** Diseño y especificación del sistema de glifos geométricos de accesibilidad, modelado del comportamiento físico de colisiones y gestión de celdas de abismo (`voids`).
