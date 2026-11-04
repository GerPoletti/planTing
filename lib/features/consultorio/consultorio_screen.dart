import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../app/strings.dart';
import '../../app/treatments.dart';
import '../../data/content.dart';
import '../../data/models.dart';
import '../../ui/pickers.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Consultorio: se elige un síntoma, se responde una pregunta y se llega a la
/// causa probable con un plan de pasos.
class ConsultorioScreen extends ConsumerStatefulWidget {
  const ConsultorioScreen({super.key, this.plantId});

  final String? plantId;

  @override
  ConsumerState<ConsultorioScreen> createState() => _ConsultorioScreenState();
}

class _ConsultorioScreenState extends ConsumerState<ConsultorioScreen> {
  String? _plantId;
  Symptom? _symptom;
  SymptomOption? _option;

  @override
  void initState() {
    super.initState();
    _plantId = widget.plantId;
  }

  void _restart() => setState(() {
        _symptom = null;
        _option = null;
      });

  Future<void> _choosePlant() async {
    final id = await pickPlant(context, ref, selectedId: _plantId);
    if (id != null && mounted) setState(() => _plantId = id);
  }

  void _log(Cause cause) {
    final s = ref.read(stringsProvider);
    final store = ref.read(storeProvider);
    final id = _plantId;
    if (id == null) return;
    store.addEvent(id, CareType.problem, note: cause.title(s.lang));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('consultorio.logged'))));
  }

  void _startTreatment(Cause cause) {
    final store = ref.read(storeProvider);
    final content = ref.read(contentProvider);
    final s = ref.read(stringsProvider);
    final id = _plantId;
    final pestId = cause.pestId;
    if (id == null || pestId == null) return;
    final t = startPestTreatment(store, content, id, pestId);
    if (t == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('treatment.started_snack'))));
    context.push('/treatment/${t.id}');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final store = ref.watch(storeProvider);
    final content = ref.watch(contentProvider);
    final plant = store.plantById(_plantId);

    return PageScaffold(
      title: s.t('consultorio.title'),
      showBack: true,
      children: [
        if (store.plants.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              avatar: const LeafGlyph(size: 20),
              label: Text(
                plant == null
                    ? s.t('consultorio.pick_plant')
                    : '${s.t('consultorio.plant')}: ${plantName(plant, content, s.lang)}',
              ),
              onPressed: _choosePlant,
              backgroundColor: MC.card,
              side: const BorderSide(color: MC.line, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
          ),
        const SizedBox(height: 14),
        if (_symptom == null)
          ..._symptomList(s, content)
        else if (_option == null)
          ..._question(s, _symptom!)
        else
          ..._result(s, content, _symptom!, _option!, plant),
      ],
    );
  }

  List<Widget> _symptomList(AppStrings s, Content content) {
    return [
      RomuSays(s.t('consultorio.intro')),
      const SizedBox(height: 14),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.35,
        children: [
          for (final sym in content.symptoms)
            AppCard(
              onTap: () => setState(() => _symptom = sym),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  sym.title(s.lang),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.2),
                ),
              ),
            ),
        ],
      ),
    ];
  }

  List<Widget> _question(AppStrings s, Symptom symptom) {
    return [
      Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: MC.ink,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(symptom.title(s.lang), style: const TextStyle(color: MC.cream, fontSize: 15)),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RomuFace(size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(
                symptom.question(s.lang),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      for (final option in symptom.options)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton(
            onPressed: () => setState(() => _option = option),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              alignment: Alignment.centerLeft,
              side: const BorderSide(color: MC.line, width: 1.5),
              backgroundColor: MC.card,
            ),
            child: Text(option.label(s.lang), textAlign: TextAlign.left),
          ),
        ),
      TextButton(onPressed: _restart, child: Text(s.t('common.back'))),
    ];
  }

  List<Widget> _result(
    AppStrings s,
    Content content,
    Symptom symptom,
    SymptomOption option,
    PlantItem? plant,
  ) {
    final cause = option.cause;
    final pest = content.pestById(cause.pestId);
    return [
      Align(alignment: Alignment.centerLeft, child: Tag(s.t('consultorio.cause'), color: MC.terraDark, background: MC.terraLight)),
      const SizedBox(height: 10),
      Text(cause.title(s.lang), style: displayStyle(26)),
      const SizedBox(height: 8),
      Text(cause.why(s.lang), style: const TextStyle(fontSize: 15, height: 1.45, color: Color(0xFF3A453E))),
      SectionTitle(s.t('consultorio.what_to_do')),
      for (final (i, step) in cause.steps(s.lang).indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: MC.olive,
                  child: Text('${i + 1}', style: const TextStyle(color: MC.card, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(step, style: const TextStyle(fontSize: 14, height: 1.4))),
              ],
            ),
          ),
        ),
      const SizedBox(height: 8),
      if (pest != null) ...[
        OutlinedButton(
          onPressed: () => context.push('/pest/${pest.id}${plant == null ? '' : '?plant=${plant.id}'}'),
          child: Text(s.t('consultorio.see_pest', {'name': pest.name(s.lang)})),
        ),
        const SizedBox(height: 8),
        if (plant != null)
          FilledButton(
            onPressed: () => _startTreatment(cause),
            child: Text(
              s.t('consultorio.start_treatment', {'plant': plantName(plant, content, s.lang)}),
              textAlign: TextAlign.center,
            ),
          ),
      ],
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: plant == null ? null : () => _log(cause),
        child: Text(s.t('consultorio.log')),
      ),
      const SizedBox(height: 6),
      TextButton(onPressed: _restart, child: Text(s.t('consultorio.new'))),
      const SizedBox(height: 6),
      Text(
        s.t('consultorio.disclaimer'),
        style: const TextStyle(color: MC.muted, fontSize: 12, height: 1.4),
      ),
    ];
  }
}
