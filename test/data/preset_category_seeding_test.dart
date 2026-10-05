/// Smoke test for preset category seeding (task 2.3).
///
/// On a fresh in-memory database, the migration `onCreate` must seed exactly
/// the five preset categories (Learn, Travel, Buy, Save, Achieve), each marked
/// `isPreset == true` (design R3.2).
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishable/data/app_database.dart';

void main() {
  test('fresh in-memory database seeds exactly the five preset categories',
      () async {
    final AppDatabase db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    // Force the database to open and run the onCreate migration.
    final List<CategoryRow> rows = await db.select(db.categories).get();

    // Exactly five categories exist.
    expect(rows, hasLength(5));

    // Every seeded category is a preset.
    expect(rows.every((CategoryRow c) => c.isPreset), isTrue);

    // The names are exactly the five expected presets (order-independent).
    final Set<String> names = rows.map((CategoryRow c) => c.name).toSet();
    expect(
        names, equals(<String>{'Learn', 'Travel', 'Buy', 'Save', 'Achieve'}));

    // Guard against duplicate names collapsing into fewer than five.
    expect(names, hasLength(5));
  });
}
