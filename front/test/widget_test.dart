import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asset_track/app.dart';

void main() {
  testWidgets('la app renderiza el shell o la vista de estado', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AssetTrackApp())),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(Scaffold), findsWidgets);
  });
}
