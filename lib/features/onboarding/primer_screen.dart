import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Permisos que se explican antes de pedirlos.
enum PrimerKind { location, camera, notifications }

/// Muestra la explicación previa. Devuelve true si la persona quiere continuar
/// (y entonces se pide el permiso del sistema) y false si elige otra opción.
Future<bool> showPrimer(BuildContext context, PrimerKind kind) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(fullscreenDialog: true, builder: (_) => PrimerScreen(kind)),
  );
  return result ?? false;
}

class PrimerScreen extends ConsumerWidget {
  const PrimerScreen(this.kind, {super.key});

  final PrimerKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final store = ref.read(storeProvider);
    final name = kind.name;
    final settings = store.settings;
    final time =
        '${settings.reminderHour}:${settings.reminderMinute.toString().padLeft(2, '0')}';

    final IconData icon;
    final Color bubble;
    final Color iconColor;
    switch (kind) {
      case PrimerKind.location:
        icon = Icons.place_outlined;
        bubble = MC.sage;
        iconColor = MC.olive;
      case PrimerKind.camera:
        icon = Icons.photo_camera_outlined;
        bubble = MC.sunLight;
        iconColor = MC.ink;
      case PrimerKind.notifications:
        icon = Icons.notifications_none;
        bubble = MC.terraLight;
        iconColor = MC.terraDark;
    }

    void markShown() {
      if (!settings.primersShown.contains(name)) {
        store.updateSettings((st) => st.primersShown.add(name));
      }
    }

    final goLabel = kind == PrimerKind.notifications
        ? s.t('primer.notifications.go')
        : s.t('common.continue');
    final altLabel = kind == PrimerKind.notifications
        ? s.t('common.not_now')
        : s.t('primer.$name.alt');

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: bubble, shape: BoxShape.circle),
                    child: Icon(icon, size: 36, color: iconColor),
                  ),
                  const SizedBox(height: 18),
                  Text(s.t('primer.$name.title'), style: displayStyle(28)),
                  const SizedBox(height: 10),
                  Text(
                    s.t('primer.$name.body'),
                    style: const TextStyle(fontSize: 15, height: 1.45, color: Color(0xFF3A453E)),
                  ),
                  const SizedBox(height: 14),
                  _InfoCard(
                    title: s.t('primer.how_title'),
                    text: s.t('primer.$name.how', {'time': time}),
                  ),
                  const SizedBox(height: 10),
                  _InfoCard(title: s.t('primer.not_title'), text: s.t('primer.$name.not')),
                  const SizedBox(height: 12),
                  Text(
                    s.t('primer.$name.note'),
                    style: const TextStyle(color: MC.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                children: [
                  FilledButton(
                    onPressed: () {
                      markShown();
                      Navigator.of(context).pop(true);
                    },
                    child: Text(goLabel),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () {
                      markShown();
                      Navigator.of(context).pop(false);
                    },
                    child: Text(altLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }
}
