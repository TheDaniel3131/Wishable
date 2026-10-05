// Sync convergence tests (auth task 15).
//
// Validates: Requirements 12.2 (last-write-wins by updatedAtUtc; tombstone
// resolves delete-vs-edit), 12.5 (identity by Wish UUID, no duplication).
//
// Exercises the pure mergeSync function directly: no backend, no database.

import 'package:flutter_test/flutter_test.dart';
import 'package:wishable/domain/account/sync_merge.dart';
import 'package:wishable/domain/lifecycle_status.dart';
import 'package:wishable/domain/priority.dart';
import 'package:wishable/domain/wish.dart';

Wish _wish(String id, {required DateTime updated, String title = 'T'}) => Wish(
      id: id,
      title: title,
      description: null,
      categoryId: 'cat',
      priority: Priority.medium,
      status: LifecycleStatus.active,
      progress: 0,
      createdAtUtc: DateTime.utc(2026, 1, 1),
      updatedAtUtc: updated,
    );

void main() {
  final DateTime t1 = DateTime.utc(2026, 1, 1, 10);
  final DateTime t2 = DateTime.utc(2026, 1, 1, 11);
  final DateTime t3 = DateTime.utc(2026, 1, 1, 12);

  test('remote-only wish is upserted locally', () {
    final MergeResult r = mergeSync(
      local: const <Wish>[],
      localTombstones: const <LocalTombstone>[],
      remote: <RemoteDelta>[RemoteDelta.upsert(_wish('a', updated: t1))],
    );
    expect(r.upserts.map((Wish w) => w.id), <String>['a']);
    expect(r.deletions, isEmpty);
  });

  test('local-only wish is left untouched (kept until pushed)', () {
    final MergeResult r = mergeSync(
      local: <Wish>[_wish('a', updated: t1)],
      localTombstones: const <LocalTombstone>[],
      remote: const <RemoteDelta>[],
    );
    expect(r.upserts, isEmpty);
    expect(r.deletions, isEmpty);
  });

  test('newer remote edit wins over older local (last-write-wins)', () {
    final MergeResult r = mergeSync(
      local: <Wish>[_wish('a', updated: t1, title: 'local')],
      localTombstones: const <LocalTombstone>[],
      remote: <RemoteDelta>[
        RemoteDelta.upsert(_wish('a', updated: t2, title: 'remote')),
      ],
    );
    expect(r.upserts.single.title, 'remote');
  });

  test('older remote edit loses to newer local (no change applied)', () {
    final MergeResult r = mergeSync(
      local: <Wish>[_wish('a', updated: t2, title: 'local')],
      localTombstones: const <LocalTombstone>[],
      remote: <RemoteDelta>[
        RemoteDelta.upsert(_wish('a', updated: t1, title: 'remote')),
      ],
    );
    expect(r.upserts, isEmpty);
    expect(r.deletions, isEmpty);
  });

  test('newer remote delete removes a locally-present wish', () {
    final MergeResult r = mergeSync(
      local: <Wish>[_wish('a', updated: t1)],
      localTombstones: const <LocalTombstone>[],
      remote: <RemoteDelta>[RemoteDelta.delete('a', t2)],
    );
    expect(r.deletions, <String>{'a'});
    expect(r.upserts, isEmpty);
  });

  test('older remote delete loses to a newer local edit (wish survives)', () {
    final MergeResult r = mergeSync(
      local: <Wish>[_wish('a', updated: t3)],
      localTombstones: const <LocalTombstone>[],
      remote: <RemoteDelta>[RemoteDelta.delete('a', t1)],
    );
    expect(r.deletions, isEmpty);
    expect(r.upserts, isEmpty);
  });

  test('newer remote edit resurrects a locally-tombstoned wish', () {
    final MergeResult r = mergeSync(
      local: const <Wish>[],
      localTombstones: <LocalTombstone>[LocalTombstone('a', t1)],
      remote: <RemoteDelta>[RemoteDelta.upsert(_wish('a', updated: t2))],
    );
    expect(r.upserts.single.id, 'a');
    expect(r.deletions, isNot(contains('a')));
  });

  test('tie on timestamp: remote wins deterministically', () {
    final MergeResult r = mergeSync(
      local: <Wish>[_wish('a', updated: t1, title: 'local')],
      localTombstones: const <LocalTombstone>[],
      remote: <RemoteDelta>[
        RemoteDelta.upsert(_wish('a', updated: t1, title: 'remote')),
      ],
    );
    expect(r.upserts.single.title, 'remote');
  });

  test('identity is the UUID: same id never duplicates', () {
    final MergeResult r = mergeSync(
      local: <Wish>[_wish('a', updated: t1)],
      localTombstones: const <LocalTombstone>[],
      remote: <RemoteDelta>[RemoteDelta.upsert(_wish('a', updated: t2))],
    );
    // Applying the upsert over the existing local 'a' replaces, not adds.
    expect(r.upserts.where((Wish w) => w.id == 'a').length, 1);
  });
}
