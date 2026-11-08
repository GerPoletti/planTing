# Mirasol: traspaso del proyecto

Fecha: 4 de noviembre de 2026. Responsable del proyecto: Gervasio José Poletti (residente en Italia). Idioma de trabajo: español rioplatense. Preferencia expresa: **usar los tokens con la mayor eficiencia posible** y no compilar ni probar de nuevo hasta terminar todos los cambios acordados.

## 1. Qué es
App Android e iOS (Flutter) para medir la luz que reciben las plantas y cuidarlas con calma: medidor de luz, plano de la casa con mapa de luz y sol por ventana, fichas con historia y fotos, humedad de la tierra con riego recomendado, Consultorio (diagnóstico guiado), plagas y tratamientos con tareas, colección de especies, clima real, un aviso diario y modo viaje. Para adultos, sin tono infantil. Nombre **Mirasol** (provisional; marca por revisar en TMview e INPI). Mascota **Romu**: gatito maine coon bebé gris, ilustración fija por ahora.

## 2. Decisiones tomadas
- 100 % gratis, sin anuncios, sin cuentas ni nube. Todo se guarda en el teléfono. Plus futuro descartado por ahora.
- Idiomas: español de España (tuteo, base), español rioplatense (voseo, solo lo que cambia) e italiano. Contenido en español neutro (infinitivos).
- Mercados: Italia, España y Argentina. Responsable de datos en Italia (GDPR). Esto no es asesoramiento legal: antes de publicar, revisión de un abogado.
- Antes de pedir ubicación, cámara o notificaciones hay una pantalla que explica para qué se usa, qué no se hace y cómo seguir sin darlo.
- Clima real con Open-Meteo (ubicación aproximada redondeada a 0,1°; gratis solo para uso no comercial).
- Sensores Bluetooth: fuera por ahora. Pruebas con un iPhone y un Xiaomi 13 Pro. Cuenta de Google Play anterior a noviembre de 2023 (no exige la prueba de 12 testers; confirmar en la Play Console).
- iPhone: sin cuenta de pago solo se instala 7 días con AltStore o Sideloadly; TestFlight requiere la cuenta de Apple de pago.
- Identificador de la app por defecto `it.poletti.plantapp` (no se puede cambiar una vez publicada).
- **Fichas de especies: siempre visibles** para investigar, con un estado «adquirida» (se gana al sumar una planta de esa especie) que motive sin bloquear la información.
- Humedad de la tierra por maceta: con el dedo (4 niveles) o con medidor (0 a 100 %). Recomienda riego según grupo de sed de la especie, estación (invertida en el sur), luz, última revisión y lluvia.

## 3. Estado técnico
- Flutter 3.29.3 fijado, Riverpod 2, go_router 14, sin generación de código. Datos en un archivo JSON atómico (`AppStore`). Textos en JSON generados desde `tool/strings/*.py` (`tool/gen_strings.py`), no ARB.
- Motores puros en `lib/engine` con pruebas: sol, luz, mapa de luz, riego. Plugin nativo local `mirasol_light` (Kotlin: sensor de luz; Swift: estimación con la cámara, lux ≈ 250·N²/(t·ISO)); `tool/bootstrap.py` lo genera junto con `android/` e `ios/`.
- Contenido: 46 especies y 9 plagas en borrador sin verificar, más 19 causas del Consultorio (`tool/gen_species.py`, `tool/gen_content.py`).
- Revisiones: `tool/check_strings.py`, `tool/static_check.py`. Se corren en la compilación.
- **Primera compilación en GitHub Actions (repo «planTing»):** Android OK (APK generado y pruebas en verde, 8 min). `flutter analyze`: 4 avisos (3 info y 1 warning): `plant_screen.dart:128` (usar `?.`), `plant_screen.dart:158` (interpolación), `home_screen.dart:336` (función en vez de variable), `test/services_test.dart:5` (import sin usar). iOS: falló por infraestructura de GitHub («job was not acquired by Runner», falta de capacidad de macOS); reintentar con «Re-run failed jobs». Avisos de versiones viejas de acciones (pasar setup-java a v5).
- En este chat nunca se pudo compilar ni correr nada (sin Flutter ni red): todo se validó solo en la nube por la persona usuaria.

## 4. Auditoría y plan aprobado
La persona usuaria hizo una auditoría (`docs/auditoria-mirasol-2026-11-04.html`) y aprobó este orden: estabilidad, valor central, validación. Oportunidad central: **ayudar a decidir dónde ubicar una planta según la luz de la casa**. Mientras no se valide, Consultorio, tratamientos y colección quedan en segundo plano.

**Hecho (solo capa de datos):** `Reading.probe`, `PlantItem.lampHours`, `Settings.travelingOn`; `AppStore`: carga segura con copia `.bak`, `loadFromJson`, escritura serializada con `saveFailed`, `saveClimate` que permite borrar, `freeSpot`, `removeEvent`, `peaksOfDay` sin duplicados de menos de 30 min y sin pruebas, `lastPlantReading`, `addPlant` sin riego asumido (`wateredAt` null = desconocido).

**7 de noviembre de 2026 (Cowork): puntos 1 a 14 implementados y pruebas escritas (punto 15), sin compilar.** En la nube de Cowork no hay Flutter ni acceso a pub.dev/Google Storage, así que no se pudo correr `flutter analyze` ni `flutter test`. Sí pasan `gen_strings.py`, `check_strings.py` y `static_check.py`. Detalle por punto en `mirasol_app/BUILD_PLAN.md`.

Archivos nuevos: `lib/engine/placement.dart`, `lib/features/placement/where_screen.dart` (ruta `/where?plant=…` o `?species=…`), `lib/data/backup.dart`, `tool/strings/placement.py`, `test/plan_test.dart`, `docs/VALIDACION.md`. Dependencias nuevas: `file_picker ^8.3.7`, `archive 3.6.1`. Método nativo nuevo `cancelMeasure` (Kotlin y Swift). Medición de prueba: `/measure?plant=…&x=…&y=…`.

**8 de noviembre de 2026: exteriores y altura (sin compilar).** Ambientes con `Room.kind` (`indoor`, `balcony`, `terrace`, `garden`), `sides` (pared / baranda / abierto por lado del plano), `covered`, `wallCm`, `railingCm`, `skyObstruction`; los exteriores viejos con ventanas se migran solos. Ventanas con `sillCm`, `topCm`, `widthCm`. Plantas y mediciones con `heightCm` (niveles `PlantLevel`; sin dato = mesa, 75 cm). `LightMap` reescrito: sol directo por geometría (hueco de la ventana, barandas, techo) y luz del cielo por lo que se ve; supuestos en `LightModel` (masa de aire, 60 % despejado, vidrio 0,75), a calibrar. Pruebas nuevas en `test/light_map_test.dart`; los valores se revisaron con una simulación en Python, no con Dart.

**9 de noviembre de 2026: correcciones de la auditoría QA del 8/11 (sin compilar).** El auditor compiló el ZIP del 8/11 en Windows (Flutter 3.29.3): análisis limpio, 107/108 pruebas. Se corrigieron F01–F14, F21, F22, F24–F27 y parte de F17, F20 y F23 (tabla en `BUILD_PLAN.md`). Decisiones: sin mediciones, «¿Dónde la pongo?» muestra «lugares para probar»; hogar compartido pospuesto (evaluar algo simple: combinar respaldos o wifi local). Pruebas del auditor en `test/qa_acceptance_test.dart` y `test/layout_test.dart`. El entorno del auditor (Flutter de Windows) está en `tst/qa-tools`.

**9 de noviembre de 2026 (tarde): segunda auditoría QA.** El ZIP del 9/11 compiló limpio en Windows y pasó 172/175. Se corrigieron N01–N12 y N14, N13 en parte (tabla en `BUILD_PLAN.md`). Decisión N10: al achicar un ambiente, las mediciones no se recortan. Las pruebas del auditor están en `test/` (deterministas) y `test_extra/` (flujos con tiempo real y escala).

**9 de noviembre de 2026 (noche): corrida del 09b en Windows.** Suite principal 248/248. Corregidos el warning de análisis en `test_extra/flows_test.dart` y los desbordes de la barra inferior y del dial. Pendiente: FLOW04 (simulación de captura que no llega al resultado).

**Siguiente paso:** subir `mirasol_app/` al repo «planTing», dejar correr GitHub Actions una sola vez y corregir lo que falle (el análisis ahora es puerta con `--no-fatal-infos`). Luego, parte B de `docs/VALIDACION.md` (luxómetro) y parte A (amigos).

## 5. Historial relevante (resumen)
1. Se pidió una app de luz y salud de plantas inspirada en Solis, Photone, Plant Light Meter y Solspot; se definió Flutter, offline primero. Faltó mencionar al competidor Planta (medidor de luz, habitaciones, «Dr. Planta»): por eso la función se llama **Consultorio**.
2. Prototipo web funcional (`design/prototipo-funcional-web.html`): medidor, plano, sol por ventana, calibración, plagas, tratamientos, humedad.
3. Documento de diseño v1.0 (Claude Doc, enlace en la cuenta anterior: https://claude.ai/artifact/FDEzaVenDWHjXNwKwHgBkN; exportable a Word, PDF o Markdown desde su menú) y 20 pantallas de referencia (`design/*.dc.html` y `canvas.json`).
4. Nombre: Heliotropo, Folia (descartado por existir apps similares), Mirasol (elegido), «Dr. Planta» (descartado: es una función de Planta).
5. Desarrollo del código en 16 bloques sin compilar; luego la persona usuaria compiló en GitHub, hizo pruebas básicas y una auditoría.

## 6. Cómo retomar en Claude Code
Abrir `mirasol_app/` y pedir: «Leé HANDOFF.md y mirasol_app/README.md. Instalá Flutter 3.29.3, corré `python3 tool/bootstrap.py`, `flutter pub get`, `flutter analyze` y `flutter test`. Después aplicá la sección 4 de HANDOFF.md en el orden indicado, compilá una sola vez al final y mostrame los errores.» Con Claude Code sí se puede compilar y probar localmente, a diferencia de este chat.

## 7. Contenido del export
`mirasol_app/` (proyecto completo), `design/` (pantallas y prototipo en HTML), `docs/` (auditoría y, si existe, transcripción de la conversación). Los enlaces de artefactos de claude.ai no funcionan desde otra cuenta: usar los archivos de `design/`.
