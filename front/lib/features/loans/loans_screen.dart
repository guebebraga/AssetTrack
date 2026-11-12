import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../widgets/common.dart';
import '../assets/asset_detail_screen.dart';
import 'loan_form_screen.dart';
import 'return_loan_dialog.dart';

enum _LoanFilter { open, overdue, returned, all }

class LoansScreen extends ConsumerStatefulWidget {
  const LoansScreen({super.key});

  @override
  ConsumerState<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends ConsumerState<LoansScreen> {
  _LoanFilter _filter = _LoanFilter.open;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider).requireValue;
    final now = DateTime.now();
    final all = [...state.loans]
      ..sort((a, b) {
        final aDue = a.dueAt;
        final bDue = b.dueAt;
        if (aDue == null && bDue == null) {
          return b.deliveredAt.compareTo(a.deliveredAt);
        }
        if (aDue == null) return 1;
        if (bDue == null) return -1;
        return aDue.compareTo(bDue);
      });
    final query = _search.text.trim().toLowerCase();
    final loans = all.where((loan) {
      final asset = state.assetById(loan.assetId);
      final matchesQuery =
          query.isEmpty ||
          loan.borrower.toLowerCase().contains(query) ||
          (asset?.code.toLowerCase().contains(query) ?? false) ||
          (asset?.name.toLowerCase().contains(query) ?? false);
      if (!matchesQuery) return false;
      return switch (_filter) {
        _LoanFilter.open => loan.isOpen,
        _LoanFilter.overdue => loan.effectiveStatus(now) == LoanStatus.overdue,
        _LoanFilter.returned => loan.status == LoanStatus.returned,
        _LoanFilter.all => true,
      };
    }).toList();

    final openCount = state.loans.where((loan) => loan.isOpen).length;
    final overdueCount = state.loans
        .where((loan) => loan.effectiveStatus(now) == LoanStatus.overdue)
        .length;
    final returnedCount = state.loans
        .where((loan) => loan.status == LoanStatus.returned)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Préstamos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoanFormScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo préstamo'),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 100),
          child: PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _LoanSummary(
                        label: 'Activos',
                        value: '$openCount',
                        color: AppColors.purple,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _LoanSummary(
                        label: 'Vencidos',
                        value: '$overdueCount',
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _LoanSummary(
                        label: 'Devueltos',
                        value: '$returnedCount',
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SearchInput(
                  controller: _search,
                  hint: 'Buscar por activo o responsable',
                  onChanged: (_) => setState(() {}),
                  onClear: () => setState(_search.clear),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterPill(
                        label: 'Pendientes',
                        selected: _filter == _LoanFilter.open,
                        onTap: () => setState(() => _filter = _LoanFilter.open),
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'Vencidos',
                        selected: _filter == _LoanFilter.overdue,
                        onTap: () =>
                            setState(() => _filter = _LoanFilter.overdue),
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'Devueltos',
                        selected: _filter == _LoanFilter.returned,
                        onTap: () =>
                            setState(() => _filter = _LoanFilter.returned),
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'Todos',
                        selected: _filter == _LoanFilter.all,
                        onTap: () => setState(() => _filter = _LoanFilter.all),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (loans.isEmpty)
                  const SectionCard(
                    child: EmptyState(
                      icon: Icons.handshake_outlined,
                      title: 'Sin préstamos',
                      message: 'No hay préstamos para el filtro seleccionado.',
                    ),
                  )
                else
                  for (final loan in loans)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _LoanCard(
                        loan: loan,
                        state: state,
                        now: now,
                        onOpen: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AssetDetailScreen(assetId: loan.assetId),
                            ),
                          );
                        },
                        onReturn: () async {
                          final result = await showReturnLoanDialog(
                            context,
                            ref,
                            loan,
                            state.assetById(loan.assetId)?.code ?? '',
                          );
                          if (result != null && context.mounted) {
                            showResultMessage(context, result);
                          }
                        },
                      ),
                    ),
                const SizedBox(height: 8),
                const DemoBanner(compact: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({
    required this.loan,
    required this.state,
    required this.now,
    required this.onOpen,
    required this.onReturn,
  });

  final Loan loan;
  final AppState state;
  final DateTime now;
  final VoidCallback onOpen;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final asset = state.assetById(loan.assetId);
    final status = loan.effectiveStatus(now);
    final color = switch (status) {
      LoanStatus.active => AppColors.purple,
      LoanStatus.overdue => AppColors.danger,
      LoanStatus.returned => AppColors.success,
      LoanStatus.pendingVerification => AppColors.warning,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.handshake_rounded, color: color, size: 20),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset?.code ?? loan.assetId,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontSize: 13),
                      ),
                      Text(
                        asset?.name ?? 'Activo no disponible',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                StatusPill(label: status.label, color: color, compact: true),
              ],
            ),
            const SizedBox(height: 12),
            InfoRow(
              label: 'Responsable',
              value: loan.borrower,
              icon: Icons.person_outline_rounded,
            ),
            InfoRow(
              label: 'Entrega',
              value: formatDateTime(loan.deliveredAt),
              icon: Icons.outbox_rounded,
            ),
            InfoRow(
              label: loan.status == LoanStatus.returned
                  ? 'Devuelto'
                  : 'Devolución prevista',
              value: loan.status == LoanStatus.returned
                  ? formatDateTime(loan.returnedAt)
                  : formatDateTime(loan.dueAt),
              icon: Icons.event_rounded,
              valueColor: status == LoanStatus.overdue
                  ? AppColors.danger
                  : null,
            ),
            if (loan.reason.isNotEmpty)
              InfoRow(
                label: 'Motivo',
                value: loan.reason,
                icon: Icons.notes_rounded,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (loan.isOpen) ...[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onReturn,
                      icon: const Icon(
                        Icons.assignment_return_rounded,
                        size: 18,
                      ),
                      label: const Text('Devolver'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: OutlinedButton(
                    onPressed: onOpen,
                    child: const Text('Ver activo'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoanSummary extends StatelessWidget {
  const _LoanSummary({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: color, fontSize: 21, height: 1),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.navy : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.text,
          ),
        ),
      ),
    );
  }
}
