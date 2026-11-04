import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../services/compass_service.dart';
import '../../ui/theme.dart';

/// Hoja para indicar hacia dónde mira la pared de arriba del plano.
Future<void> showOrientationSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _OrientationSheet(),
  );
}

class _OrientationSheet extends ConsumerStatefulWidget {
  const _OrientationSheet();

  @override
  ConsumerState<_OrientationSheet> createState() => _OrientationSheetState();
}

class _OrientationSheetState extends ConsumerState<_OrientationSheet> {
  bool _busy = false;
  String? _message;

  Future<void> _useCompass() async {
    final s = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _message = null;
    });
    final heading = await CompassService.readOnce();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (heading == null) {
        _message = s.t('onb.where.compass_fail');
      } else {
        final snapped = CompassService.snapToEight(heading);
        ref.read(storeProvider).updateSettings((st) => st.northOffset = snapped);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final offset = ref.watch(storeProvider.select((st) => st.settings.northOffset));
    final dir = directionName(s, offset);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.t('home.orientation'), style: displayStyle(22)),
            const SizedBox(height: 6),
            Text(
              s.t('home.orientation.body', {'dir': dir}),
              style: const TextStyle(color: MC.muted, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _busy ? null : _useCompass,
              icon: const Icon(Icons.explore_outlined),
              label: Text(_busy ? s.t('onb.where.compass_busy') : s.t('home.orientation.compass')),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_message!, style: const TextStyle(color: MC.muted, fontSize: 13)),
              ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 3.6,
              children: [
                for (var i = 0; i < 8; i++)
                  OutlinedButton(
                    onPressed: () => ref
                        .read(storeProvider)
                        .updateSettings((st) => st.northOffset = i * 45.0),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: offset.round() == i * 45 ? MC.sage : null,
                      side: BorderSide(
                        color: offset.round() == i * 45 ? MC.olive : MC.line,
                        width: 1.5,
                      ),
                    ),
                    child: Text(s.t('home.orientation.top', {'dir': directionName(s, i * 45.0)})),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
