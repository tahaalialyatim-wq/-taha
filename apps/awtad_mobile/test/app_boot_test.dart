import 'dart:io';

import 'package:awtad_mobile/core/database/database_service.dart';
import 'package:awtad_mobile/core/database/retail_session.dart';
import 'package:awtad_mobile/presentation/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('splash then loads Arabic shell after sqlite init',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('awtad-boot-');
    addTearDown(() {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });

    await tester.pumpWidget(
      AwtadApp(
        sessionFactory: () async {
          final database = DatabaseService(
            databasePath: DatabaseService.pathIn(dir.path),
          );
          await database.initialize();
          return RetailSession(database);
        },
      ),
    );

    expect(find.text('الأوتاد'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    await tester.pump();
    expect(find.text('الأوتاد للمبيعات'), findsWidgets);
    expect(find.text('الرئيسية'), findsWidgets);
  });
}
