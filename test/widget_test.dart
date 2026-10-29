import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asset_track/app.dart';
import 'package:asset_track/application/app_controller.dart';
import 'package:asset_track/core/storage/local_store.dart';

void main() {
  testWidgets('la demo carga y muestra el aviso de datos simulados', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStoreProvider.overrideWithValue(MemoryStore())],
        child: const AssetTrackApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('DEMO — DATOS SIMULADOS — RFID NO CONECTADO'),
      findsWidgets,
    );
    expect(find.text('Inicio'), findsWidgets);
    expect(find.text('Activos'), findsWidgets);
  });
}
