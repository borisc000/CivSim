# CivSim Pixel Frontiers

MVP autocontenido de un juego por turnos inspirado en Civilization, hecho en 2D con estetica pixel art y sin dependencias externas.

## Incluye

- mapa procedural con niebla de guerra
- dos civilizaciones: jugador y IA basica
- unidades `colono`, `guerrero` y `explorador`
- ciudades con crecimiento, produccion y recursos
- captura de ciudades y condicion de victoria
- interfaz lateral con minimapa, seleccion y registro de eventos

## Ejecutar

No necesitas instalar nada. Abre `index.html` en tu navegador.

Si prefieres levantar un servidor local:

```bash
npx serve .
```

## Controles

- `Click izquierdo`: seleccionar y mover dentro del alcance
- `Click en enemigo adyacente`: atacar
- `F`: fundar ciudad con el colono seleccionado
- `Enter`: terminar turno
- `WASD` o flechas: mover camara

## Siguientes pasos razonables

1. anadir arbol tecnologico
2. introducir diplomacia y mas facciones
3. cambiar la grilla cuadrada por hexagonos
4. agregar sprites externos y animaciones de combate
