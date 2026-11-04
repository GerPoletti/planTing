#!/usr/bin/env python3
"""Prepara el proyecto para compilar.

1. Genera las carpetas android/ e ios/ con `flutter create` (no se versionan).
2. Genera el plugin nativo de luz en packages/mirasol_light y copia encima
   las fuentes de la carpeta native/.
3. Aplica los permisos, textos y ajustes de Mirasol.

Se puede ejecutar varias veces sin romper nada.
Variable opcional: MIRASOL_ORG (por defecto it.poletti) define el
identificador de la app: <org>.plantapp
"""
import os
import pathlib
import re
import shutil
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
ORG = os.environ.get("MIRASOL_ORG", "it.poletti")
APP_NAME = "Mirasol"

LOCATION_TEXT = (
    "Mirasol usa tu ubicación aproximada, solo mientras la app está abierta, "
    "para calcular el sol de tu casa y consultar el clima de tu zona."
)
CAMERA_TEXT = (
    "Mirasol usa la cámara para estimar la luz mientras medís y para sacar fotos "
    "de tus plantas. La estimación de luz no guarda imágenes."
)
PHOTOS_TEXT = "Mirasol accede a tus fotos solo para que elijas una imagen de tu planta."


def run(cmd, cwd=ROOT):
    print("+", " ".join(cmd), flush=True)
    subprocess.check_call(cmd, cwd=str(cwd))


def read(path):
    return pathlib.Path(path).read_text(encoding="utf-8")


def write(path, text):
    pathlib.Path(path).write_text(text, encoding="utf-8")


def create_platforms():
    if (ROOT / "android").exists() and (ROOT / "ios").exists():
        print("android/ e ios/ ya existen")
        return
    keep = {}
    for name in ("pubspec.yaml", "lib/main.dart", "analysis_options.yaml", "README.md", ".gitignore"):
        p = ROOT / name
        if p.exists():
            keep[name] = read(p)
    # pubspec mínimo: el plugin local todavía no existe y haría fallar el pub get
    write(ROOT / "pubspec.yaml", (
        "name: plantapp\n"
        "publish_to: 'none'\n"
        "environment:\n  sdk: '>=3.7.0 <4.0.0'\n"
        "dependencies:\n  flutter:\n    sdk: flutter\n"
        "flutter:\n  uses-material-design: true\n"
    ))
    run([
        "flutter", "create", "--org", ORG, "--project-name", "plantapp",
        "--platforms", "android,ios", ".",
    ])
    for name, text in keep.items():
        write(ROOT / name, text)
    stray = ROOT / "test" / "widget_test.dart"
    if stray.exists():
        stray.unlink()


def create_plugin():
    plugin = ROOT / "packages" / "mirasol_light"
    if not (plugin / "pubspec.yaml").exists():
        (ROOT / "packages").mkdir(exist_ok=True)
        run([
            "flutter", "create", "--template=plugin", "--platforms", "android,ios",
            "--org", ORG, "--project-name", "mirasol_light", "mirasol_light",
        ], cwd=ROOT / "packages")
    native = ROOT / "native"

    # Dart
    shutil.copyfile(native / "mirasol_light.dart", plugin / "lib" / "mirasol_light.dart")
    for extra in ("mirasol_light_method_channel.dart", "mirasol_light_platform_interface.dart"):
        f = plugin / "lib" / extra
        if f.exists():
            f.unlink()
    for folder in ("test", "example"):
        shutil.rmtree(plugin / folder, ignore_errors=True)

    # Kotlin: se reemplaza donde lo haya dejado el generador
    kotlin_files = list((plugin / "android" / "src").rglob("MirasolLightPlugin.kt"))
    if not kotlin_files:
        raise SystemExit("No se encontró MirasolLightPlugin.kt generado")
    package = f"{ORG}.mirasol_light"
    text = read(native / "MirasolLightPlugin.kt").replace("__PACKAGE__", package)
    for f in kotlin_files:
        write(f, text)

    # Swift
    swift_files = list((plugin / "ios").rglob("MirasolLightPlugin.swift"))
    if not swift_files:
        raise SystemExit("No se encontró MirasolLightPlugin.swift generado")
    for f in swift_files:
        shutil.copyfile(native / "MirasolLightPlugin.swift", f)


def patch_android():
    manifest_path = ROOT / "android/app/src/main/AndroidManifest.xml"
    manifest = read(manifest_path)
    if "ACCESS_COARSE_LOCATION" not in manifest:
        permissions = (
            '    <uses-permission android:name="android.permission.INTERNET"/>\n'
            '    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>\n'
            '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n'
            '    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>\n'
            '    <uses-permission android:name="android.permission.VIBRATE"/>\n'
        )
        manifest = manifest.replace("<application", permissions + "    <application", 1)
    if "ScheduledNotificationReceiver" not in manifest:
        receivers = (
            '        <receiver android:exported="false" '
            'android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />\n'
            '        <receiver android:exported="false" '
            'android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">\n'
            "            <intent-filter>\n"
            '                <action android:name="android.intent.action.BOOT_COMPLETED"/>\n'
            '                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>\n'
            '                <action android:name="android.intent.action.QUICKBOOT_POWERON" />\n'
            '                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>\n'
            "            </intent-filter>\n"
            "        </receiver>\n"
        )
        manifest = manifest.replace("</application>", receivers + "    </application>", 1)
    manifest = re.sub(r'android:label="[^"]*"', f'android:label="{APP_NAME}"', manifest, count=1)
    write(manifest_path, manifest)

    # Desugaring que necesitan las notificaciones locales
    for name in ("build.gradle.kts", "build.gradle"):
        gradle_path = ROOT / "android/app" / name
        if not gradle_path.exists():
            continue
        gradle = read(gradle_path)
        if "coreLibraryDesugaring" in gradle:
            break
        kts = name.endswith(".kts")
        flag = "isCoreLibraryDesugaringEnabled = true" if kts else "coreLibraryDesugaringEnabled true"
        gradle = re.sub(r"compileOptions\s*\{", lambda m: m.group(0) + "\n        " + flag, gradle, count=1)
        dep = (
            '\n\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
            if kts
            else "\n\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
        )
        write(gradle_path, gradle + dep)
        break


def patch_ios():
    plist_path = ROOT / "ios/Runner/Info.plist"
    plist = read(plist_path)
    plist = re.sub(
        r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)",
        lambda m: m.group(1) + APP_NAME + m.group(2),
        plist,
        count=1,
    )
    additions = ""
    for key, text in (
        ("NSLocationWhenInUseUsageDescription", LOCATION_TEXT),
        ("NSCameraUsageDescription", CAMERA_TEXT),
        ("NSPhotoLibraryUsageDescription", PHOTOS_TEXT),
    ):
        if key not in plist:
            additions += f"\t<key>{key}</key>\n\t<string>{text}</string>\n"
    if additions:
        idx = plist.rfind("</dict>")
        plist = plist[:idx] + additions + plist[idx:]
    write(plist_path, plist)

    podfile_path = ROOT / "ios/Podfile"
    if podfile_path.exists():
        podfile = read(podfile_path)
        podfile = re.sub(r"^#?\s*platform :ios, '[^']*'", "platform :ios, '13.0'", podfile, count=1, flags=re.M)
        write(podfile_path, podfile)


if __name__ == "__main__":
    create_platforms()
    create_plugin()
    patch_android()
    patch_ios()
    print("Listo: ahora corré `flutter pub get`.")
