/// [SyncStatusIndicator] — a compact affordance showing the current [SyncState]
/// (auth spec, Option B — R12.4).
///
/// Presentation-layer only: watches [syncControllerProvider] and renders a
/// small row (idle / syncing / offline / error). Never imports the SDK.
library wishable.presentation.account.sync_status_indicator;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/account/account.dart';
import '../../domain/account/accounts.dart';

/// Shows the live sync status as an icon + label.
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SyncState state = ref.watch(syncControllerProvider);
    final ThemeData theme = Theme.of(context);

    final (IconData icon, String label, Color color) = switch (state) {
      Syncing() => (
          Icons.sync,
          'Syncing…',
          theme.colorScheme.primary,
        ),
      SyncOffline() => (
          Icons.cloud_off_outlined,
          'Offline — changes will sync later',
          theme.colorScheme.onSurfaceVariant,
        ),
      SyncError(:final String message) => (
          Icons.sync_problem_outlined,
          message,
          theme.colorScheme.error,
        ),
      SyncIdle(:final DateTime? lastSyncedUtc) => (
          Icons.cloud_done_outlined,
          lastSyncedUtc == null ? 'Not synced yet' : 'Synced',
          theme.colorScheme.onSurfaceVariant,
        ),
    };

    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
