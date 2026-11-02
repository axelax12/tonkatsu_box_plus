import 'dart:convert';

import 'package:core/plus/analytics/path_exchange.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonkatsu_box/features/paths/widgets/path_import_dialog.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('showPathImportDialog', () {
    Future<void> open(
      WidgetTester tester,
      void Function(SharedPath?) onResult,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpApp(
        Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async =>
                onResult(await showPathImportDialog(context)),
            child: const Text('open'),
          ),
        ),
        wrapInScaffold: true,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Finder confirm() => find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextButton),
        )
        .last;

    testWidgets('keeps the dialog open on text that is not a path', (
      WidgetTester tester,
    ) async {
      SharedPath? result;
      bool closed = false;
      await open(tester, (SharedPath? r) {
        closed = true;
        result = r;
      });
      await tester.enterText(find.byType(TextField), 'not a path');
      await tester.pump();
      await tester.tap(confirm());
      await tester.pumpAndSettle();
      expect(closed, isFalse);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(result, isNull);
    });

    testWidgets('returns the decoded path', (WidgetTester tester) async {
      SharedPath? result;
      await open(tester, (SharedPath? r) => result = r);
      await tester.enterText(
        find.byType(TextField),
        jsonEncode(<String, Object>{
          'format': PathExchange.format,
          'version': PathExchange.version,
          'name': 'Gundam UC',
          'stops': <Object>[],
        }),
      );
      await tester.pump();
      await tester.tap(confirm());
      await tester.pumpAndSettle();
      expect(result?.name, 'Gundam UC');
    });
  });
}
