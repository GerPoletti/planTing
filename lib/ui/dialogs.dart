import 'package:flutter/material.dart';

/// Pide confirmar una acción. Devuelve true si se confirmó.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(cancelLabel)),
        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(confirmLabel)),
      ],
    ),
  );
  return result ?? false;
}
