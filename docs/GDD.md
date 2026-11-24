# Game Design Document (GDD) — Kroma (v2.0)

> **Estado del documento:** Actualizado a la versión **v2.0** implementada (cierre de Sprint 3).  
> **Equipo:** KROMA Dev Studio (Toledo, Christian Velázquez, Carlos, Ian)

---

## 1. Ficha Técnica, Logline y High Concept

### 1.1 Metadatos del Proyecto
* **Título Oficial:** *Kroma*
* **Género:** Puzle 2D minimalista / Lógica espacial determinista
* **Plataformas Objetivo:** Windows Desktop, Web (HTML5 / WASM), Dispositivos Móviles (táctil)
* **Público Objetivo:** Tweens y Teens tempranos (10 a 15 años); jugadores tipo *Achiever* orientados a la deducción lógica, patrones visuales y resolución sin presión temporal
* **Motor / Stack Tecnológico:** Godot Engine 4.7 (GDScript, renderer `mobile`)

### 1.2 Logline
*En una matriz digital en reposo, desliza bloques inerciales de energía pura para sintetizar colores secundarios y encajarlos en receptores terminales que transforman el tablero con cada acierto.*

### 1.3 High Concept
**Kroma** es un videojuego de lógica espacial bidimensional en cuadrícula ortogonal minimalista (de `5×5` a `7×7` en campaña y modo procedural; soporte estructural hasta `8×8`) donde los bloques activos carecen de fricción interna y se desplazan con inercia continua hasta colisionar. El diseño combina el desplazamiento inercial discreto con la síntesis cromática determinista y la metamorfosis del tablero: cada bloque encajado exitosamente deja de ser una pieza móvil para bloquearse (`LOCKED`) como un nuevo muro rígido, alterando las rutas y ángulos posibles para las piezas restantes.

### 1.4 Pilares de Diseño
1. **Determinismo Espacial Absoluto (Cero Azar):** Toda acción produce un resultado matemático predecible en cuatro ejes cardinales, sin físicas continuas imprecisas ni dispersión.
2. **Transformación Topológica Progresiva:** Resolver no consiste en vaciar la matriz; cada acierto reduce el espacio transitable y genera nuevos puntos de apoyo mecánicos para maniobras a 90°.
3. **Seguridad Psicológica y Experimentación Heurística:** Ausencia total de cronómetros, vidas o penalizaciones punitivas. Respaldado en una pila de *Undo* ilimitado y reinicio rápido, el error se convierte en una hipótesis descartada dentro del proceso deductivo.

### 1.5 Pitch de 1 Minuto
* **¿Qué experiencia ofrece?** Una experiencia de concentración reflexiva (*Mindful Puzzle Solving*), donde el usuario restaura el orden y la coherencia visual de un sistema apagado sin estrés motriz ni castigo de tiempo.
* **¿Cuál es el Core Loop?** Analizar la disposición geométrica, deducir trayectorias en reversa, deslizar bloques con inercia, fusionar colores primarios o usarlos como tope, y encajar cada bloque en su meta para convertirlo en un nuevo obstáculo físico hasta estabilizar el sector.
* **¿Cuál es el riesgo técnico principal?** El manejo de bloqueos irreversibles (*deadlocks*) y la verificación algorítmica de la solvencia matemática en campaña y generación procedural.

---

## 2. Historia y Narrativa Funcional

### 2.1 Enfoque *Meat & Salt*
Siguiendo la filosofía de Scott Rogers (*"si el gameplay es la carne del juego, la historia debe ser la sal"*), Kroma adopta una narrativa mínima y funcional: no existen cinemáticas, diálogos ni texto de exposición extenso. La "sal" narrativa se limita a nombrar y dar sentido temático a un sistema que, mecánicamente, ya funciona por sí solo.

### 2.2 Mundo y Premisa del Conflicto
* **Mundo:** Una matriz digital suspendida —un espacio abstracto, oscuro y translúcido (*glassmorphism*) que representa un sector de procesamiento en entropía. El "mundo" es literalmente el tablero de juego.
* **Premisa:** Los buses de datos del sector están apagados por la desalineación de sus núcleos cromáticos: la energía quedó fragmentada en bloques aislados. El jugador actúa como un operador implícito que restaura la alineación de los núcleos.
* **Justificación temática:**
  * *Fragmentación de energía cromática:* explica por qué los bloques inician dispersos.
  * *Estabilización de un núcleo:* explica la conversión de un bloque encajado en muro rígido (`LOCKED`).
  * *Reactivación del sector:* traduce el estado de victoria (`SECTOR COMPLETADO`) en iluminación y cierre armónico.

---

## 3. Perfil de Jugador y Experiencia Buscada

* **Taxonomía de LeBlanc:** Kroma apunta a **Challenge** (superación de problemas lógicos estructurados), **Discovery** (deducción progresiva de combinación e inercia) y **Submission** (concentración relajada en un sistema cerrado y determinista).
* **Taxonomía de Bartle (uso motivacional):** El jugador objetivo se describe como *Achiever* en sentido motivacional (satisfacción al dominar reglas y completar objetivos medibles en solitario, sin contexto multijugador).
* **Estructura de sesión:** Partidas *bite-sized* de 3 a 7 minutos con niveles de 45 a 90 segundos, organizadas en bandas de calibración:
  * **Banda introductoria:** Deslizar, frenar contra muros y encajar (Sector 01).
  * **Banda intermedia:** Uso de piezas como freno de conveniencia y síntesis cromática (Sectores 02–03).
  * **Banda avanzada:** Abismos estructurales, mutación topológica y deducción en reversa (Sector 04 y modo Procedural Normal/Difícil).

---

## 4. Flujo de Juego y Máquina de Estados (FSM)

### 4.1 Bucle de Interacción Principal
1. **Evaluación:** Lectura visual de la matriz, glifos y metas.
2. **Backtracking mental:** Inferencia inversa desde la meta receptora hacia los obstáculos disponibles.
3. **Entrada vectorial:** Selección de bloque y *swipe* cardinal / tecla direccional (`N, S, E, O`).
4. **Transición mecánica discreta:** Desplazamiento inercial celda a celda sobre la matriz lógica.
5. **Resolución y verificación:** Colisión (`MERGE`, `FRENO`, `VOID`, `SLOT`), evaluación de victoria o derrota (`is_defeated`), y retroalimentación audiovisual.

### 4.2 Especificación de la FSM
* **IDLE (Reposo):** Espera input válido sobre un bloque activo (`locked == false`). Al recibir dirección cardinal, guarda un *snapshot* en la pila de Undo y pasa a `SLIDING`.
* **SLIDING (Desplazamiento):** Evalúa iterativamente la celda siguiente:
  * *Celda vacía:* Avanza una celda y continúa en `SLIDING`.
  * *Bloque primario compatible:* Pasa a `MERGING` (absorbe al bloque objetivo, suma aditiva de color) y continúa en `SLIDING` conservando la inercia remanente.
  * *Muro, borde, bloque incompatible, bloque `LOCKED` o receptor de otro color:* Frena en la celda previa y retorna a `IDLE`.
  * *Celda nula (Abismo):* Pasa a `VOIDED`, elimina el bloque del tablero y evalúa derrota.
  * *Receptor coincidente:* Pasa a `SLOTTED` (`locked = true`, celda pasa a `LOCKED`).
* **SLOTTED (Encaje en Objetivo):** Si `remaining_receptors_count() == 0`, transiciona a `LEVEL_CLEAR`; de lo contrario vuelve a `IDLE` y evalúa si el tablero quedó en estado irresoluble.
* **REWINDING (Undo / Reinicio):** Disponible en cualquier estado activo en `IDLE`; desapila el último *snapshot* o restaura el estado inicial de forma síncrona.

---

## 5. Mecánicas y Reglas del Sistema

### 5.1 Verbos Operativos
1. **Deslizar (*Slide*):** Aplica un vector unitario cardinal (`UP`, `DOWN`, `LEFT`, `RIGHT`) al bloque seleccionado hasta colisionar o caer.
2. **Fusionar (*Merge*):** Consecuencia automática al impactar un bloque primario contra otro primario compatible:
   * `Rojo + Azul → Púrpura`
   * `Azul + Amarillo → Verde`
   * `Amarillo + Rojo → Naranja`
   * Los bloques secundarios no pueden volver a fusionarse; actúan como tope físico (**freno de conveniencia**).
3. **Encajar (*Slot*):** Al impactar un receptor del mismo color/glifo, el bloque queda fijado permanentemente (`LOCKED`) y pasa a comportarse como muro rígido para el resto de la partida.

### 5.2 Codificación Dual (Accesibilidad)
Para garantizar accesibilidad ante discromatopsia, cada color está acoplado de forma unívoca a un glifo geométrico de alto contraste:
* **Rojo:** Círculo (`circle`)
* **Azul:** Cuadrado (`square`)
* **Amarillo:** Triángulo (`triangle`)
* **Púrpura:** Rombo (`diamond`)
* **Verde:** Cruz (`cross`)
* **Naranja:** Hexágono (`hexagon`)

---

## 6. Condiciones de Victoria, Derrota y Progresión

### 6.1 Condición de Victoria y Evaluación (v2.0)
* **Victoria:** El 100% de los receptores del tablero están ocupados (`Cell.LOCKED`).
* **Par Óptimo y Rangos:** Al cargar cada nivel, `LevelSolver` (BFS) calcula el **Par Óptimo** (`PASOS XX / PAR YY`). Al completar el nivel se asigna rango:
  * **★★★ Rango S (Óptimo):** `Pasos <= Par`
  * **★★☆ Rango A (Eficiente):** `Pasos <= Par + 3`
  * **★☆☆ Rango B (Completado):** `Pasos > Par + 3`
* **Racha Perfecta:** Contabiliza sectores consecutivos resueltos en **Rango S** sin usar **Deshacer**, sin **Reiniciar** y sin caer en **abismos**. Se persiste el récord histórico localmente.

### 6.2 Detección Formal de Derrota y Recuperación
Aunque no existen vidas ni límite de tiempo, el sistema sí detecta automáticamente tras cada movimiento si el estado actual se volvió matemáticamente irresoluble (`BoardState.is_defeated()`):
1. **Insuficiencia numérica:** Hay menos bloques activos que receptores pendientes.
2. **Incompatibilidad cromática:** Los colores disponibles no alcanzan para satisfacer o sintetizar los receptores restantes.
3. **Deadlock cinemático:** Ningún bloque activo puede desplazarse en ninguna de las 4 direcciones.

Ante cualquiera de estos casos se presenta un modal de estado irresoluble con recuperación inmediata mediante **Deshacer** o **Reiniciar**, preservando la seguridad psicológica.

---

## 7. Modos de Juego y Contenido

### 7.1 Campaña Curada (Sectores 01 – 04)
1. **Sector 01 — Inercia de Vector (`5×5`):** Desplazamiento sin fricción y frenado contra muros.
2. **Sector 02 — Pivote y Freno (`6×6`):** Alternancia de bloques para usar piezas activas como apoyo y freno.
3. **Sector 03 — Enlace de Espectro (`5×5`):** Síntesis cromática entre primarios para activar metas secundarias.
4. **Sector 04 — Falla Estructural (`6×6`):** Navegación alrededor de abismos y rebotes perimetrales.

Los primeros sectores integran un **tutorial interactivo dual**: un *pill* contextual inferior que confirma cada mecánica ejecutada y una guía visual sobre el bloque/dirección (`TutorialGuideOverlay`) basada en la solución óptima del solver.

### 7.2 Modo Simulación Infinita (Procedural)
Generación automática validada previamente por BFS (`LevelGenerator`) seleccionable desde el menú principal en tres perfiles:
* **Fácil:** `5×5`, `3–5` pasos, `8%` muros, `0` abismos, `1` receptor.
* **Normal:** `6×6`, `5–9` pasos, `14%` muros, `1–3` abismos, `50%` bloque extra, `15%` multi-receptor.
* **Difícil:** `7×7`, `8–14` pasos, `20%` muros, `3–6` abismos, `70%` bloque extra, `75%` multi-receptor.

Cada 3 sectores superados en una corrida procedural, la dificultad escala progresivamente en pasos mínimos y probabilidad de multi-receptor.

---

## 8. Interfaz de Usuario (UI/HUD), Controles y Audio

### 8.1 Estética y HUD (*Glassmorphism*)
* **Estética unificada:** Paleta gris carbón, tarjetas translúcidas con bisel especular y fondo continuo desenfocado mediante shader (`frosted_blur.gdshader`).
* **HUD en partida:**
  * **Cabecera centrada:** Nombre del sector y *pills* de `PASOS / PAR` y `RACHA PERFECTA`.
  * **Esquina superior derecha:** Botón `|| PAUSA`.
  * **Encima del dock:** *Pill* de tutorial contextual (cuando aplica).
  * **Dock inferior:** Botones `↶ DESHACER`, `↺ REINICIAR` y `⇄ CAMBIAR` (para alternar bloque activo).

### 8.2 Controles Multiplataforma
* **Mover bloque:** `W A S D` / Flechas direccionales (PC/Web) o *Swipe* en pantalla (Táctil/Mouse).
* **Cambiar bloque:** `Tab` / `Espacio` (PC/Web) o *Tap* directo / botón `⇄ CAMBIAR`.
* **Deshacer:** `Z` / `Ctrl+Z` (PC/Web) o botón `↶ DESHACER`.
* **Reiniciar:** `R` (PC/Web) o botón `↺ REINICIAR`.
* **Pausa:** `ESC` o botón `|| PAUSA`.

### 8.3 Feedback Audiovisual
* **Canales implementados:** Animaciones interpoladas de movimiento, destellos/transiciones cromáticas en fusión y encaje, y efectos sonoros sincronizados (`slide`, `bump`, `merge`, `snap`, `void`, `undo`, `victory_1..3`, `ui_*`) gestionados por `AudioManager`.
* **Nota de alcance:** El feedforward de líneas punteadas (`BoardState.preview_move()`) existe en la capa lógica y está disponible para integración visual futura; la vibración háptica móvil no está activa en la versión v2.0.

---

## 9. Matriz de Riesgos y Trade-offs

| Riesgo / Decisión | Impacto | Mitigación / Trade-off implementado |
| :--- | :--- | :--- |
| **Deadlocks silenciosos** | Pérdida de agencia si el jugador queda atascado sin saberlo | Detección determinista en `BoardState.is_defeated()` + Undo ilimitado y Reinicio rápido |
| **Discromatopsia (~8% hombres)** | Imposibilidad de distinguir Rojo/Verde o Azul/Púrpura | Codificación dual obligatoria: cada color tiene un glifo geométrico único (`Glyph`) |
| **Cuello de botella en diseño de niveles** | Diseñar niveles sin atajos ni errores consume tiempo | `LevelSolver` (BFS) valida solvencia y calcula el Par; `LevelGenerator` produce niveles verificados |
| **Física continua vs. Determinismo** | Bugs sub-píxel y dificultad para implementar Undo | Matriz discreta `grid[x][y]` con lógica pura e interpolación visual (*tweens*) |
