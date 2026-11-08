# Protocolo de validación de Mirasol

Objetivo: saber si **«¿Dónde la pongo?»** ayuda de verdad a decidir dónde ubicar una planta, y si las estimaciones de luz son lo bastante precisas para eso. Mientras esto no esté validado, Consultorio, tratamientos y colección quedan en segundo plano.

Esto no reemplaza una revisión legal: si se juntan datos de otras personas, pedirles permiso por escrito y no guardar nada que las identifique.

## Parte A. Prueba con amigos (2 semanas)

**Quiénes:** 5 a 8 personas con al menos 3 plantas de interior, en Italia, España y Argentina. Al menos dos con iPhone y dos con Android. Mezclar casas luminosas y oscuras.

**Antes de empezar**
1. Instalar la APK (Android) o el IPA con AltStore o Sideloadly (iPhone, vale 7 días: reinstalar a mitad de la prueba).
2. Pedir que no lean ayudas ni este documento: queremos ver si la app se entiende sola.

**Día 1 (sesión guiada de 20 minutos, por videollamada o en persona)**
1. Hacer el primer uso completo sin ayuda. Anotar dónde dudan y cuánto tardan.
2. Dibujar en Casa los ambientes donde tienen plantas, con sus ventanas.
3. Agregar 3 plantas. Al menos una con «Todavía no sé qué es» si tienen alguna sin identificar.
4. Abrir **¿Dónde la pongo?** para una planta y preguntar:
   - ¿Entendés por qué sugiere ese lugar? (sí / más o menos / no)
   - ¿Coincide con lo que vos pensabas? (sí / no / no sabía)
   - ¿La moverías? (sí / no / ya está ahí)

**Días 2 a 13 (sin ayuda)**
- Medir cada planta al menos 3 veces en días distintos, cerca del mediodía.
- Usar «Medir este lugar» en al menos un lugar sugerido que no sea donde está la planta.
- Registrar riegos y revisiones de tierra como les resulte natural.

**Día 14 (entrevista de 15 minutos)**
1. ¿Moviste alguna planta por lo que dijo la app? ¿Cuál y adónde?
2. ¿Cambió la sugerencia después de medir? ¿Te pareció más confiable?
3. ¿Algo te pareció falso o exagerado?
4. Del 1 al 5: ¿qué tan útil te resultó para decidir dónde poner una planta?
5. ¿Qué es lo primero que sacarías? ¿Qué es lo que más extrañarías?

Pedir que exporten un respaldo (Ajustes → Guardar un respaldo) **solo si están de acuerdo**, para revisar las mediciones.

**Qué cuenta como validado**
- Al menos 4 de cada 6 personas entienden la explicación sin ayuda.
- Al menos la mitad mueve o decide ubicar una planta gracias a la sugerencia.
- Puntaje medio de utilidad de 4 o más.
- Ninguna sugerencia claramente absurda (por ejemplo, una suculenta en el lugar más oscuro de la casa).

## Parte B. Calibración de la luz con luxómetro

**Equipo:** un luxómetro (cualquiera con rango de al menos 50 000 lux), el iPhone y el Xiaomi 13 Pro. Una planilla con: lugar, hora, cielo (despejado / nublado), lux del luxómetro, lux de Android, lux de iPhone.

**Procedimiento**
1. Elegir 8 puntos que cubran todo el rango: sombra (≈100 lux), interior lejos de la ventana, interior junto a la ventana, sol filtrado por cortina, sol directo detrás del vidrio, exterior a la sombra, exterior al sol, y una lámpara de cultivo si hay.
2. En cada punto apoyar el luxómetro y el teléfono en el mismo lugar, mirando hacia la ventana (o hacia arriba en exterior), con la pantalla o la cámara frontal apuntando al mismo lado que el sensor del luxómetro.
3. Medir 3 veces cada uno, alternando, con menos de 1 minuto entre medidas. Anotar el promedio.
4. Repetir con cielo despejado y con cielo nublado.

**Análisis**
- Para cada teléfono, calcular el cociente luxómetro / teléfono en cada punto.
- Si el cociente es parecido en todo el rango (variación menor a ±20 %), usar la media geométrica como factor: en iPhone va en `Settings.cameraCalibration`; en Android hoy no hay factor y se agregaría uno igual.
- Si el cociente cambia mucho con la luz, anotar en qué tramo y no corregir con un solo número.
- Marcar dónde el teléfono se satura (deja de subir) y comprobar que la app muestre el estado «sensor al máximo».

**Mapa de luz**
- En 2 ambientes, comparar el DLI que estima Casa en 4 puntos con el que da medir esos puntos (3 mediciones cada uno, días distintos). Si la diferencia media pasa de ±40 % sin mediciones, revisar los supuestos de `LightModel.windowDli` y `distanceFalloff`.

**Exteriores y altura**
- En un balcón o terraza, medir a la altura del suelo y a 1 m en el mismo punto, a mediodía, y comparar con lo que estima la app para esas dos alturas.
- Junto a una ventana, medir en el suelo, en una mesa y en un estante alto. El orden (cuál recibe más) tiene que coincidir con el de la app aunque los números no coincidan.

## Registro
Guardar los resultados en `docs/validacion-resultados-AAAA-MM-DD.md` (sin nombres ni datos personales) y actualizar la columna «Validado» de `BUILD_PLAN.md`.
