// lib/features/annotations/widgets/account_sync_tile.dart
//
// Settings tile showing the signed-in account + sync status, with Google
// sign-in / sign-out. Cloud sync is optional: without an account every
// annotation feature still works fully offline.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_localizations.dart';
import '../providers/annotations_provider.dart';
import '../services/auth_service.dart';

class AccountSyncTile extends ConsumerStatefulWidget {
  const AccountSyncTile({super.key});

  @override
  ConsumerState<AccountSyncTile> createState() => _AccountSyncTileState();
}

class _AccountSyncTileState extends ConsumerState<AccountSyncTile> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    final ok = await ref.read(authServiceProvider).signInWithGoogle();
    if (mounted) {
      setState(() => _busy = false);
      // The user cancelled the account picker or the exchange failed.
      // Surface it so a configuration problem isn't a silent no-op.
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).signInFailed)),
        );
      }
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).signOut();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final auth = ref.watch(authProvider);

    final authState = auth.valueOrNull ??
        const AuthState(status: AuthStatus.unknown);

    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar / icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: authState.isSignedIn
                    ? colors.primary.withValues(alpha: 0.12)
                    : colors.surfaceContainerHighest,
              ),
              child: authState.isSignedIn
                  ? (authState.avatarUrl != null
                        ? ClipOval(
                            child: Image.network(
                              authState.avatarUrl!,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.person),
                            ),
                          )
                        : const Icon(Icons.person, color: Colors.white))
                  : Icon(Icons.cloud_outlined, color: colors.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authState.isSignedIn
                        ? (authState.displayName ?? authState.email ?? '')
                        : loc.signInTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    authState.isSignedIn
                        ? loc.syncActive
                        : loc.syncDisabled,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              FilledButton.tonal(
                onPressed: authState.isSignedIn ? _signOut : _signIn,
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  authState.isSignedIn ? loc.signOut : loc.signIn,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
