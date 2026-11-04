# Plan de desarrollo de Mirasol

Estado: [x] hecho · [ ] pendiente

- [x] WP1 Fundaciones: pubspec, motores de sol y de luz con pruebas, script de preparación, compilación en la nube, README
- [x] WP2 Plugin nativo de luz (`native/`: Dart, Kotlin para Android, Swift para iOS)
- [x] WP3 Modelos y almacenamiento local en JSON (plantas, espacios, mediciones, eventos, tratamientos, fotos)
- [x] WP4 Contenido: especies y plagas en JSON, español e italiano, con fuente y confianza
- [x] WP5 Servicios: ubicación, brújula, clima (Open-Meteo con caché), notificaciones, exportar y borrar
- [x] WP6 Idiomas: textos en JSON (es-ES, es-AR, it) con generador y verificación; los textos de cada pantalla se agregan junto con la pantalla
- [x] WP7 Interfaz base: tema, rutas, navegación inferior
- [x] WP8 Onboarding y avisos previos a cada permiso
- [x] WP9 Medir: dial, mantener o tocar, estados especiales, carga a ojo, calibración
- [x] WP10 Casa: plano, ventanas, trayectoria solar, mapa de luz, qué medir
- [x] WP11 Plantas: ficha, historia con fotos, cuidados y recordatorios
- [x] WP12 Consultorio, plagas y tratamientos con tareas
- [x] WP13 Hoy: rituales, tareas, clima, modo viaje
- [x] WP14 Colección de especies y plagas
- [x] WP15 Ajustes: idioma, aviso diario, exportar y borrar, atribuciones
- [x] WP16 Revisión final, pruebas, README y empaquetado

Pendientes de coherencia con las pantallas de referencia:
- Los números de ejemplo de la pantalla Medir (lux, PPFD y DLI) no coinciden entre sí; la app calcula los reales.
- Identificador de la app por defecto: it.poletti.plantapp. Confirmar antes de publicar.
