import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ui/theme.dart';
import 'providers.dart';
import 'save_status.dart';

/// Estructura con la barra inferior: cuatro secciones y el botón central de medir.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);

    Widget item(int index, IconData icon, IconData activeIcon, String label) {
      final selected = shell.currentIndex == index;
      return Expanded(
        child: InkWell(
          onTap: () => shell.goBranch(index, initialLocation: index == shell.currentIndex),
          child: Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            // La barra tiene alto fijo: con fuentes grandes el ícono y el texto
            // se achican en vez de desbordar.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(selected ? activeIcon : icon, color: selected ? MC.ink : MC.muted, size: 26),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? MC.ink : MC.muted,
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SaveStatusFrame(child: shell),
      bottomNavigationBar: Material(
        color: MC.card,
        elevation: 0,
        child: Container(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE4DCCB)))),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 68,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  item(0, Icons.home_outlined, Icons.home, s.t('nav.home')),
                  item(1, Icons.task_alt_outlined, Icons.task_alt, s.t('nav.today')),
                  Expanded(
                    child: Transform.translate(
                      offset: const Offset(0, -18),
                      child: Center(
                        child: Semantics(
                          button: true,
                          label: s.t('nav.measure'),
                          child: Material(
                            color: MC.sun,
                            shape: const CircleBorder(),
                            elevation: 4,
                            shadowColor: const Color(0x4026302A),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => context.push('/measure'),
                              child: const SizedBox(
                                width: 60,
                                height: 60,
                                child: Icon(Icons.wb_sunny_outlined, size: 30, color: MC.ink),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  item(2, Icons.eco_outlined, Icons.eco, s.t('nav.garden')),
                  item(3, Icons.explore_outlined, Icons.explore, s.t('nav.discover')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
