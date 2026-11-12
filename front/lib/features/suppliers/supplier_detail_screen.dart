import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../widgets/common.dart';
import 'supplier_delivery_screen.dart';
import 'supplier_operation_screen.dart';

class SupplierDetailScreen extends ConsumerWidget {
  const SupplierDetailScreen({super.key, required this.supplierId});

  final String supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider).requireValue;
    final supplier = state.supplierById(supplierId);
    if (supplier == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Proveedor')),
        body: const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Proveedor no encontrado',
        ),
      );
    }
    final operations =
        state.supplierOperations
            .where((operation) => operation.supplierId == supplier.id)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final atSupplier = state.assets
        .where((asset) => asset.supplierId == supplier.id && asset.isAtSupplier)
        .length;
    final pendingUnits = operations.fold<int>(
      0,
      (sum, operation) => sum + operation.pendingAssetIds.length,
    );

    return Scaffold(
      appBar: AppBar(title: Text(supplier.name)),
      floatingActionButton: supplier.active
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SupplierDeliveryScreen(initialSupplierId: supplier.id),
                  ),
                );
                if (result == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Entrega registrada.')),
                  );
                }
              },
              icon: const Icon(Icons.add_box_rounded),
              label: const Text('Nueva entrega'),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 100),
          child: PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.navyMid, AppColors.navyDark],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.local_shipping_rounded,
                              color: Colors.white,
                              size: 23,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  supplier.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                Text(
                                  supplier.serviceType.isEmpty
                                      ? 'Servicio no especificado'
                                      : supplier.serviceType,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.65),
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusPill(
                            label: supplier.active ? 'Activo' : 'Inactivo',
                            color: supplier.active
                                ? AppColors.success
                                : AppColors.muted,
                            compact: true,
                          ),
                        ],
                      ),
                      if (supplier.contact.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Icon(
                              Icons.mail_outline_rounded,
                              size: 15,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              supplier.contact,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (supplier.notes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          supplier.notes,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        value: '$atSupplier',
                        label: 'Activos en proveedor',
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _Stat(
                        value: '${operations.length}',
                        label: 'Operaciones',
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _Stat(
                        value: '$pendingUnits',
                        label: 'Unidades pendientes',
                        color: AppColors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SectionHeader(
                  title: 'Operaciones',
                  subtitle: 'Entregas, recepciones e intercambios',
                ),
                const SizedBox(height: 10),
                if (operations.isEmpty)
                  const SectionCard(
                    child: EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Sin operaciones',
                      message:
                          'Registrá una entrega para iniciar la trazabilidad '
                          'con este proveedor.',
                    ),
                  )
                else
                  for (final operation in operations)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _OperationCard(
                        operation: operation,
                        state: state,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SupplierOperationScreen(
                              operationId: operation.id,
                            ),
                          ),
                        ),
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

class _OperationCard extends StatelessWidget {
  const _OperationCard({
    required this.operation,
    required this.state,
    required this.onTap,
  });

  final SupplierOperation operation;
  final AppState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = operationColor(operation.status);
    final pending = operation.pendingAssetIds.length;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      color: color,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Operación ${operation.id.split('-').last}',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontSize: 13),
                        ),
                        Text(
                          operation.reason.isEmpty
                              ? 'Sin motivo especificado'
                              : operation.reason,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(
                    label: operation.status.label,
                    color: color,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MiniMetric(
                    label: 'Entregados',
                    value: '${operation.deliveredAssetIds.length}',
                  ),
                  const SizedBox(width: 16),
                  _MiniMetric(
                    label: 'Recibidos',
                    value: '${operation.receivedAssetIds.length}',
                  ),
                  const SizedBox(width: 16),
                  _MiniMetric(label: 'Pendientes', value: '$pending'),
                  const Spacer(),
                  if (operation.isExchange)
                    const StatusPill(
                      label: 'Intercambio',
                      color: AppColors.purple,
                      compact: true,
                      icon: Icons.swap_horiz_rounded,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${formatDateTime(operation.deliveredAt ?? operation.createdAt)}'
                '${operation.dueAt == null ? '' : ' · Retorno previsto ${formatDate(operation.dueAt)}'}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontSize: 10.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 13),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 9.5),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
            maxLines: 2,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontSize: 9.5, height: 1.2),
          ),
        ],
      ),
    );
  }
}
