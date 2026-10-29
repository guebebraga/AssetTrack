import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models.dart';

Future<ActionResult?> showReturnLoanDialog(
  BuildContext context,
  WidgetRef ref,
  Loan loan,
  String assetCode,
) {
  return showDialog<ActionResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ReturnLoanDialog(
      loan: loan,
      assetCode: assetCode,
      ref: ref,
    ),
  );
}

class _ReturnLoanDialog extends StatefulWidget {
  const _ReturnLoanDialog({
    required this.loan,
    required this.assetCode,
    required this.ref,
  });

  final Loan loan;
  final String assetCode;
  final WidgetRef ref;

  @override
  State<_ReturnLoanDialog> createState() => _ReturnLoanDialogState();
}

class _ReturnLoanDialogState extends State<_ReturnLoanDialog> {
  final _notes = TextEditingController();
  bool _confirmedInside = false;
  bool _correction = false;
  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _confirmedInside || _correction;
    return AlertDialog(
      title: const Text('Registrar devolución'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.assetCode} · ${widget.loan.borrower}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 14),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmedInside,
              onChanged: (value) => setState(() {
                _confirmedInside = value ?? false;
                if (_confirmedInside) _correction = false;
              }),
              title: const Text('Confirmo que el activo ingresó físicamente'),
              subtitle: const Text(
                'Actualiza la ubicación a "Dentro" y registra la entrada.',
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _correction,
              onChanged: (value) => setState(() {
                _correction = value ?? false;
                if (_correction) _confirmedInside = false;
              }),
              title: const Text('Corrección administrativa explícita'),
              subtitle: const Text(
                'Permite cerrar el préstamo sin confirmación física. Queda '
                'registrado en el historial como corrección.',
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (!canSave) ...[
              const SizedBox(height: 4),
              const Text(
                'Seleccioná una de las dos opciones para continuar.',
                style: TextStyle(color: AppColors.warning, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Observaciones',
                hintText: 'Detalle opcional de la devolución',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: !canSave || _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  final result = await widget.ref
                      .read(appControllerProvider.notifier)
                      .returnLoan(
                        loanId: widget.loan.id,
                        confirmedInside: _confirmedInside,
                        administrativeCorrection: _correction,
                        notes: _notes.text.trim(),
                      );
                  if (!context.mounted) return;
                  setState(() => _saving = false);
                  Navigator.pop(context, result);
                },
          child: Text(_saving ? 'Guardando...' : 'Registrar devolución'),
        ),
      ],
    );
  }
}
