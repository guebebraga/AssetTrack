import 'package:flutter_test/flutter_test.dart';

import 'package:asset_track/domain/enums.dart';
import 'package:asset_track/domain/seed/demo_seed.dart';
import 'package:asset_track/services/inventory_service.dart';
import 'package:asset_track/services/loan_service.dart';
import 'package:asset_track/services/movement_service.dart';
import 'package:asset_track/services/supplier_service.dart';

void main() {
  final reference = DateTime(2026, 10, 29, 12);

  group('datos de demostración', () {
    test('genera 50 activos coherentes con EPC únicos', () {
      final state = DemoSeed.buildState(now: reference);
      expect(state.assets, hasLength(50));
      expect(state.assets.map((asset) => asset.code).toSet(), hasLength(50));
      expect(state.assets.map((asset) => asset.rfidEpc).toSet(), hasLength(50));
      expect(state.assets.first.code, 'O2-001');
      expect(state.assets.last.code, 'O2-050');
      expect(state.loans.where((loan) => loan.isOpen), hasLength(4));
      expect(
        state.assets.where(
          (asset) => asset.situation == AssetSituation.atSupplier,
        ),
        hasLength(3),
      );
    });

    test('el tablero refleja 37 dentro, 13 fuera y 28 movimientos de hoy', () {
      final state = DemoSeed.buildState(now: reference);
      final stats = const InventoryService().stats(state, reference);
      expect(stats.total, 50);
      expect(stats.inside, 37);
      expect(stats.outside, 13);
      expect(stats.todayMovements, 28);
      expect(stats.openAlerts, state.alerts.where((a) => a.isOpen).length);
    });
  });

  group('movimientos', () {
    test('una lectura repetida no genera un movimiento nuevo', () {
      final state = DemoSeed.buildState(now: reference);
      final asset = state.assets.firstWhere(
        (item) =>
            item.location == AssetLocation.inside &&
            item.situation == AssetSituation.available,
      );
      final service = MovementService(state, dedupeWindowSeconds: 30);
      final timestamp = reference.add(const Duration(hours: 2));
      final before = state.movements.length;

      final first = service.record(
        assetId: asset.id,
        type: MovementType.exit,
        timestamp: timestamp,
        origin: EventOrigin.rfidRead,
        accessId: 'ACC-1',
      );
      final repeated = service.record(
        assetId: asset.id,
        type: MovementType.exit,
        timestamp: timestamp.add(const Duration(seconds: 8)),
        origin: EventOrigin.rfidRead,
        accessId: 'ACC-1',
      );

      expect(first.success, isTrue);
      expect(repeated.duplicate, isTrue);
      expect(state.movements.length, before + 1);
      expect(state.assetById(asset.id)!.location, AssetLocation.outside);
    });

    test('una transición inválida queda pendiente sin alterar el activo', () {
      final state = DemoSeed.buildState(now: reference);
      final asset = state.assets.firstWhere(
        (item) => item.location == AssetLocation.inside,
      );
      final service = MovementService(state);
      final beforeLocation = asset.location;

      final result = service.record(
        assetId: asset.id,
        type: MovementType.entry,
        timestamp: reference.add(const Duration(hours: 3)),
        origin: EventOrigin.rfidRead,
        accessId: 'ACC-1',
      );

      expect(result.success, isFalse);
      expect(result.event?.status, MovementStatus.pendingReview);
      expect(state.assetById(asset.id)!.location, beforeLocation);
    });
  });

  group('habitaciones', () {
    test('registra salida, ingreso y traslado entre habitaciones', () {
      final state = DemoSeed.buildState(now: reference);
      final asset = state.assets.firstWhere(
        (item) => item.location == AssetLocation.inside && item.roomId != null,
      );
      final service = MovementService(state, dedupeWindowSeconds: 30);
      final origin = asset.roomId!;
      final destination = state.zones.firstWhere((zone) => zone.id != origin);

      final exit = service.record(
        assetId: asset.id,
        type: MovementType.roomExit,
        timestamp: reference.add(const Duration(hours: 1)),
        origin: EventOrigin.rfidRead,
        roomId: origin,
      );
      expect(exit.success, isTrue);
      expect(state.assetById(asset.id)!.roomId, isNull);
      expect(state.assetById(asset.id)!.location, AssetLocation.inside);

      final entry = service.record(
        assetId: asset.id,
        type: MovementType.roomEntry,
        timestamp: reference.add(const Duration(hours: 2)),
        origin: EventOrigin.rfidRead,
        roomId: origin,
      );
      expect(entry.success, isTrue);
      expect(state.assetById(asset.id)!.roomId, origin);

      final transfer = service.record(
        assetId: asset.id,
        type: MovementType.roomTransfer,
        timestamp: reference.add(const Duration(hours: 3)),
        origin: EventOrigin.rfidRead,
        roomId: destination.id,
      );
      expect(transfer.success, isTrue);
      expect(state.assetById(asset.id)!.roomId, destination.id);
      expect(state.movementsForAsset(asset.id).first.roomId, destination.id);
    });

    test('una salida sin habitación registrada queda pendiente', () {
      final state = DemoSeed.buildState(now: reference);
      final asset = state.assets.firstWhere(
        (item) => item.location == AssetLocation.inside && item.roomId != null,
      );
      final service = MovementService(state);
      service.record(
        assetId: asset.id,
        type: MovementType.roomExit,
        timestamp: reference.add(const Duration(hours: 1)),
        origin: EventOrigin.rfidRead,
        roomId: asset.roomId!,
      );
      final result = service.record(
        assetId: asset.id,
        type: MovementType.roomExit,
        timestamp: reference.add(const Duration(hours: 4)),
        origin: EventOrigin.rfidRead,
        roomId: state.zones.first.id,
      );
      expect(result.success, isFalse);
      expect(result.event?.status, MovementStatus.pendingReview);
      expect(state.assetById(asset.id)!.roomId, isNull);
    });
  });

  group('préstamos', () {
    test(
      'no permite devolver sin confirmar ingreso o corrección explícita',
      () {
        final state = DemoSeed.buildState(now: reference);
        final asset = state.assets.firstWhere(
          (item) =>
              item.location == AssetLocation.inside &&
              item.situation == AssetSituation.available &&
              state.openLoanForAsset(item.id) == null,
        );
        final movements = MovementService(state);
        final loans = LoanService(state, movementService: movements);
        final created = loans.createLoan(
          assetId: asset.id,
          borrower: 'Responsable de prueba',
          deliveredAt: reference.add(const Duration(hours: 2)),
          dueAt: reference.add(const Duration(days: 2)),
        );
        expect(created.success, isTrue);

        final rejected = loans.returnLoan(
          loanId: created.loan!.id,
          returnedAt: reference.add(const Duration(hours: 5)),
        );
        expect(rejected.success, isFalse);
        expect(state.loanById(created.loan!.id)!.isOpen, isTrue);

        final returned = loans.returnLoan(
          loanId: created.loan!.id,
          returnedAt: reference.add(const Duration(hours: 6)),
          confirmedInside: true,
        );
        expect(returned.success, isTrue);
        expect(state.loanById(created.loan!.id)!.isOpen, isFalse);
        expect(state.assetById(asset.id)!.location, AssetLocation.inside);
      },
    );
  });

  group('proveedores', () {
    test('soporta recepción parcial e intercambio con EPC distinto', () {
      final state = DemoSeed.buildState(now: reference);
      final available = state.assets
          .where(
            (item) =>
                item.location == AssetLocation.inside &&
                item.situation == AssetSituation.available,
          )
          .take(2)
          .toList();
      expect(available, hasLength(2));
      final supplier = state.suppliers.first;
      final movements = MovementService(state);
      final suppliers = SupplierService(state, movementService: movements);

      final created = suppliers.createDelivery(
        supplierId: supplier.id,
        assetIds: available.map((asset) => asset.id).toList(),
        deliveredAt: reference.add(const Duration(hours: 1)),
        dueAt: reference.add(const Duration(days: 3)),
      );
      expect(created.success, isTrue);
      final operation = created.operation!;
      expect(operation.status, SupplierOperationStatus.delivered);

      final partial = suppliers.receiveAssets(
        operationId: operation.id,
        receivedAssetIds: [available.first.id],
        receivedAt: reference.add(const Duration(days: 1)),
      );
      expect(partial.success, isTrue);
      expect(
        partial.operation!.status,
        SupplierOperationStatus.partiallyReceived,
      );
      expect(partial.operation!.pendingAssetIds, [available.last.id]);

      final replacement = state.assets.firstWhere(
        (item) =>
            item.location == AssetLocation.outside &&
            item.situation != AssetSituation.atSupplier &&
            item.situation != AssetSituation.onLoan &&
            !operation.deliveredAssetIds.contains(item.id),
      );
      final exchanged = suppliers.receiveAssets(
        operationId: operation.id,
        receivedAssetIds: [replacement.id],
        receivedAt: reference.add(const Duration(days: 1, hours: 2)),
      );
      expect(exchanged.success, isTrue);
      expect(exchanged.operation!.receivedAssetIds, contains(replacement.id));
      expect(exchanged.operation!.isExchange, isTrue);
      expect(
        exchanged.operation!.status,
        SupplierOperationStatus.partiallyReceived,
      );

      final closed = suppliers.completeWithPending(
        operationId: operation.id,
        closedAt: reference.add(const Duration(days: 2)),
      );
      expect(closed.success, isTrue);
      expect(closed.operation!.status, SupplierOperationStatus.completed);
      expect(closed.operation!.pendingAssetIds, isNotEmpty);
    });
  });
}
