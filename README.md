# Mirasol

App para medir la luz que reciben las plantas y cuidarlas con calma. Android e iOS, hecha con Flutter. Todo se guarda en el teléfono: no hay cuentas, nube ni anuncios.

## Qué incluye
- Medidor de luz (sensor en Android, cámara en iPhone), con estados de sensor saturado y medición fallida, y carga a ojo.
- Plano de la casa con ambientes y ventanas, trayectoria solar, mapa de luz que se ajusta con tus mediciones y sugerencias de qué medir.
- Plantas con ficha, historia con fotos, humedad de la tierra (con el dedo o con medidor) y riego recomendado según especie, estación, luz y lluvia.
- Consultorio (diagnóstico guiado), catálogo de plagas y tratamientos con tareas y seguimiento.
- Hoy, colección de especies, clima real (Open-Meteo), un aviso diario y modo viaje.
- Español de España, español rioplatense e italiano.

## Cómo compilar (en la nube, con GitHub)
1. Subí esta carpeta completa a un repositorio nuevo de GitHub (rama `main`).
2. En la pestaña **Actions** se ejecuta **Compilar Mirasol** sola (o con **Run workflow**).
3. Al terminar, bajá de **Artifacts**: `mirasol-android-apk` (APK para el Android) y `mirasol-ios-sin-firmar` (IPA sin firmar para el iPhone).
4. Si algo falla, copiá el error del paso que falló y mandalo.

Es la primera vez que se compila: puede haber errores de compilación que se corrigen con el texto del error.

## Instalar
- **Android:** pasá el APK al teléfono y permití instalar desde fuentes desconocidas.
- **iPhone:** el IPA no viene firmado. Con un Apple ID gratuito se instala con AltStore o Sideloadly desde una computadora y vale 7 días (máximo 3 apps). Con la cuenta de desarrollador de Apple (de pago) se firma y se reparte con TestFlight.

## Trabajar en tu computadora
Flutter 3.29.3. Corré `python3 tool/bootstrap.py`, luego `flutter pub get`, `flutter test` y `flutter run`. Variable opcional `MIRASOL_ORG` (por defecto `it.poletti`) para el identificador de la app (`<org>.plantapp`): **no se puede cambiar una vez publicada**.

## Estructura
- `lib/engine`: sol, luz, mapa de luz y riego (lógica pura con pruebas).
- `lib/data`: modelos, almacenamiento JSON y contenido. `assets/data`: especies, plagas y Consultorio.
- `lib/services`: ubicación, brújula, clima, avisos, fotos y exportar.
- `lib/features`: pantallas. `native/`: plugin de luz (Kotlin y Swift).
- `assets/l10n`: textos generados por `tool/gen_strings.py` desde `tool/strings/`.
- `tool/`: preparación del proyecto, generadores de contenido y revisiones.

## Pendientes conocidos
- Los datos de especies y plagas son borradores: verificarlos con fuentes (sobre todo toxicidad) antes de publicar.
- La estimación de luz con la cámara del iPhone usa una constante estándar y hay que calibrarla con un luxómetro.
- Open-Meteo es gratuito solo para uso no comercial.
- Falta el ícono definitivo, las tipografías (se usan las del sistema) y el diseño final de Romu.
- Revisión de un hablante nativo para el italiano, política de privacidad y revisión legal antes de publicar.
