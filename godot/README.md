# CivSim Godot MVP

MVP de estrategia por turnos inspirado en Civilization, construido en Godot 4 con grilla cuadrada y arquitectura preparada para migrar a hexagonal.

## Estado actual

- mapa procedural con terrenos y niebla de guerra
- jugador humano + IA que explora, funda ciudades, produce y combate
- unidades: `colono`, `guerrero`, `explorador`
- ciudades con crecimiento, produccion y recursos
- combate simple de contacto (chocar y resolver)
- captura de ciudades y victoria por dominacion
- UI lateral de estado, seleccion, acciones y log de eventos

## Estructura

- `project.godot`: configuracion del proyecto
- `scenes/main.tscn`: escena principal
- `scripts/main.gd`: orquestacion del juego y loop de turnos
- `scripts/core/`: estado, reglas, generacion de mapa, combate, IA
- `scripts/core/grid/`: adaptadores de grilla (`square` activo, `hex` placeholder)
- `scripts/ui/`: render de mundo y HUD

## Controles

- `Click izquierdo`: seleccionar unidad/ciudad o dar orden de movimiento
- `Click derecho`: dar orden a la unidad seleccionada
- `Rueda del mouse`: zoom in / zoom out
- `F`: fundar ciudad con colono seleccionado
- `Enter`: terminar turno
- `WASD` o flechas: mover camara
- `N`: reiniciar partida

## Abrir en Godot 4

1. Instala Godot 4.x (recomendado 4.2 o superior).
2. Abre Godot y elige `Import`.
3. Selecciona `godot/project.godot`.
4. Presiona `Run Project`.

## Siguiente iteracion sugerida

1. pathfinding tactico completo por costos y zonas de control
2. arbol tecnologico y edificios por ciudad
3. diplomacia y mas facciones
4. migracion real a hex adaptando render + vecindad
