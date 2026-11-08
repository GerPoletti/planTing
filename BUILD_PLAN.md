# Plan de desarrollo de Mirasol

Tres estados distintos, que no hay que mezclar:

- **Implementado:** el código está escrito.
- **Probado:** hay pruebas automáticas (`flutter test`) en verde, o se probó a mano en un teléfono (se indica cuál).
- **Validado:** personas reales lo usaron con sus plantas y confirmaron que les sirve (protocolo en `docs/VALIDACION.md`).

Estado al 7 de noviembre de 2026. Las pruebas nuevas (`test/plan_test.dart`) todavía no se corrieron: quedan «escritas» hasta la próxima compilación en GitHub Actions.

## Base (WP1 a WP16)

| Bloque | Implementado | Probado | Validado |
|---|---|---|---|
| Motores de sol, luz, mapa de luz y riego | Sí | Pruebas en verde (1.ª compilación) | No |
| Plugin nativo de luz (Kotlin / Swift) | Sí | Android: prueba básica a mano. iPhone: sin compilar | No |
| Almacenamiento JSON, contenido, idiomas | Sí | Pruebas en verde | No |
| Onboarding, Medir, Casa, Plantas, Hoy, Ajustes | Sí | Prueba básica a mano en Android | No |
| Consultorio, plagas, tratamientos, colección | Sí | Pruebas de datos | No (en segundo plano hasta validar el valor central) |

## Plan aprobado tras la auditoría (4 de noviembre de 2026)

Orden: estabilidad → valor central → validación.

| # | Cambio | Implementado | Probado |
|---|---|---|---|
| 1 | Avisos: lo atrasado pasa al próximo horario futuro; `travelingOn` en Hoy y Ajustes | Sí | Escrito (`plan_test`) |
| 2 | Clima: día que coincide con hoy, alertas sin días pasados, «actualizado», se invalida al volver a la app | Sí | Escrito |
| 3 | Onboarding transaccional: casa y planta se crean solo al terminar | Sí | Falta prueba de interfaz |
| 4 | `freeSpot` al agregar plantas | Sí | Escrito |
| 5 | Especie genérica «Todavía no sé qué es» (`desconocida`), fuera de la colección, sin toxicidad | Sí | Escrito |
| 6 | Riego: motivo `unknownLast`, «¿cuándo la regaste?», chip «Regué ayer», deshacer y borrar eventos | Sí | Escrito (motor y datos) |
| 7 | Jardín, ficha y `plantLightFactor` usan `lastPlantReading` (sin pruebas en otro lugar) | Sí | Escrito |
| 8 | Medición: pico individual, horas de lámpara, modo prueba (`/measure?plant=…&x=…&y=…`), cancelación real (`cancelMeasure`), aviso sin ubicación en Casa | Sí | Escrito (cálculo). Cancelación: probar a mano |
| 9 | «¿Dónde la pongo?»: `engine/placement.dart`, pantalla `/where`, entradas desde Casa, ficha de planta y ficha de especie | Sí | Escrito |
| 10 | Colección: fichas abiertas, insignia «adquirida», contador, «¿Dónde la pondría?» | Sí | Falta prueba de interfaz |
| 11 | Respaldo ZIP con fotos y restauración (`archive`, `file_picker`); aviso si falla el guardado | Sí | Escrito |
| 12 | Mover un ambiente mueve sus plantas; humedad sin temperatura | Sí | Escrito |
| 13 | Analizador: 4 avisos corregidos, `flutter analyze --no-fatal-infos` como puerta, `setup-java@v5` | Sí | Se verá en la compilación |
| 14 | Documentación y protocolo de validación | Sí | — |
| 15 | Pruebas actualizadas y una sola compilación | Pruebas escritas | **Pendiente: compilar** |

## Pedido del 8 de noviembre de 2026: exteriores y altura

| Cambio | Implementado | Probado |
|---|---|---|
| Espacios exteriores (balcón, terraza, jardín) con lados pared / baranda / abierto, techo, alturas y obstrucción alrededor; la luz entra por el cielo abierto, sin ventanas | Sí | Escrito (`light_map_test`) |
| Altura de cada maceta (suelo, mesa, estante alto, colgante, o cm) y de cada ventana (alféizar, borde superior, ancho; puerta-ventana) | Sí | Escrito |
| Nuevo modelo de luz: sol directo según si el rayo pasa por el hueco de la ventana (o por encima de barandas y debajo del techo), luz del cielo según lo que se ve, sol según la masa de aire y 60 % de horas despejadas | Sí | Escrito. **Valores a calibrar con luxómetro** |
| «¿Dónde la pongo?» con selector de altura y exteriores | Sí | Escrito |

## Auditoría QA del 8 de noviembre de 2026 (`QA_MIRASOL/INFORME_MIRASOL.md`)

Compilada en Windows con Flutter 3.29.3: análisis sin errores ni warnings, suite original 107/108. Las pruebas del auditor se sumaron como `test/qa_acceptance_test.dart` (QA15 adaptada a la decisión «lugares para probar») y `test/layout_test.dart`.

| Hallazgo | Estado (9/11, sin compilar) |
|---|---|
| F27 cambio de horario | Corregido: fechas de cuidado como días de calendario (`lib/data/dates.dart`) |
| F07 borrar todo | Corregido: espera la escritura en curso y borra `.bak`, `.tmp` y copias dañadas |
| F08 restaurar | Corregido: versión, partes obligatorias, IDs únicos, relaciones y rangos |
| F09 éxito sin guardar | Corregido: `flushOrThrow`, fotos por archivo temporal y vuelta atrás completa |
| F10 / F11 cronología del riego | Corregido: el último riego sale de los eventos; el riego inicial es un evento |
| F12 fotos huérfanas | Corregido: el respaldo lleva solo fotos referenciadas y se borran las que nadie usa |
| F02 / F03 / F13 / F19 evidencia de luz | Corregido: lectura válida solo en el lugar y altura actuales, sin manuales ni saturadas; calibración con lecturas independientes; mediciones se mueven con el ambiente; evaluación única `lib/engine/light_assessment.dart` en Casa, Jardín, ficha y ventana |
| F01 ubicaciones sin medir | Decidido: «lugares para probar» (solo «Medir este lugar»); «Ponerla acá» solo con mediciones |
| F04 especie desconocida | Corregido: sin ubicaciones ni veredicto; riego solo por lo que dice la tierra |
| F05 / F06 riego prudente | Corregido: el calendario y la lluvia piden revisar; solo una revisión reciente dice «regar»; la lluvia no cuenta con techo |
| F14 medición | Corregido: se guarda con la hora en que se tomó; cambiar de planta obliga a medir de nuevo |
| F17 formas de cultivo | Parcial: campo `medium` (tierra / corteza / aire); Tillandsia sin recordatorios, Phalaenopsis con nota de corteza |
| F21 viaje | Renombrado a «Pausar avisos» con aviso de dejar a alguien a cargo |
| F22 desbordes | Corregido en ficha de especie y Hoy (sin verificar con la prueba) |
| F23 colecciones grandes | Parcial: búsqueda en Jardín |
| F24 fechas futuras | Corregido en humedad |
| F25 permisos | Corregido: rechazar la ubicación abre la búsqueda de ciudad |
| F26 fallo de guardado | Corregido: aviso en todas las pantallas y guardado al pasar a segundo plano |
| F15 / F16 Consultorio y contenido | Pendiente: revisión botánica con fuentes. Toxicidad marcada «sin verificar» |
| F18 precisión de sensores | Pendiente físico |
| F20 recordatorios | Parcial: ahora avisan «para revisar», sin prometer alertas de clima |
| Hogar compartido | Pospuesto; opción simple a evaluar: combinar respaldos o sincronizar por wifi local |

## Segunda auditoría QA (`QA_MIRASOL_2/INFORME_SEGUNDA_REVISION.md`)

Compilada en Windows: análisis sin observaciones, suite entregada 172/175 (3 desbordes de «¿Dónde la pongo?» con texto doble). Sus casos nuevos se sumaron: `test/qa_round2_boundaries_test.dart`, `test/layout_extended_test.dart`; los flujos con tiempo real y la escala quedan en `test_extra/` (`flutter test test_extra`).

| Hallazgo | Estado (sin compilar) |
|---|---|
| N01 fotos con el mismo nombre | Corregido: se compara el contenido; si difiere se guarda con otro nombre y se remapea |
| N02 validación del respaldo | Corregido: versión entera, todas las listas, fechas legibles, relaciones (ambiente, ventana, planta), rangos (alturas, obstrucción, calibración, DLI, fuente), tareas 0..n-1 |
| N03 lectura inválida como evaluación | Corregido: regla común `AppStore.isUsableReading` (sin manual/saturada/futura/sol bajo/sin posición/vieja); Medir no da veredicto si no se puede estimar el día |
| N04 mediciones viejas habilitan acciones | Corregido: calibración con vigencia de 365 días; «Ponerla acá» solo con ajuste «Le sirve» |
| N05 cambiar de planta midiendo | Corregido: corta la sesión y pide medir de nuevo |
| N06 aviso de guardado oculto | Corregido: `SaveStatusFrame` en cada ruta de primer nivel |
| N07 migración del riego | Corregido: se recompone desde los eventos al cargar |
| N08 respaldo sin sus fotos | Corregido: falta una foto → no se restaura; límite de lo descomprimido (800 MB) |
| N09 deduplicación | Corregido: por ambiente y altura |
| N10 achicar ambiente | Decidido: las mediciones solo se trasladan, nunca se recortan |
| N11 desconocida con rango | Corregido en «¿Dónde la pongo?» y en su ficha |
| N12 desbordes | Corregido: etiquetas flexibles, selector de planta, avance de tratamiento, meses de la ventana |
| N13 cultivo | Parcial: la ficha ya no da frecuencia de riego para aérea ni corteza; falta protocolo revisado |
| N14 «DLI medido» | Corregido: «Luz diaria estimada… a partir de una medición» |

## Corrida en Windows del ZIP 09b

`flutter test`: **248/248**. `flutter analyze`: un warning y tres infos, todos en `test_extra/flows_test.dart` (imports y llaves): corregidos. `test_extra`: 10/13; FLOW01 y FLOW05 fallaban solo por desbordes (barra inferior de alto fijo y etiquetas del dial): corregidos. FLOW04 no llega a mostrar «Guardar medición» en la simulación (ya pasaba en la corrida anterior): queda para revisar el montaje de la prueba con el auditor.

## Pendientes conocidos
- Los números de ejemplo de la pantalla Medir de referencia no coinciden entre sí; la app calcula los reales.
- Identificador de la app por defecto: `it.poletti.plantapp`. Confirmar antes de publicar.
- Las mediciones de prueba guardan la posición donde se midió; si después se mueve el ambiente, esa posición no se corrige.
