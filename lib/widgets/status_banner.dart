/// A status line with an icon and text, announced to screen readers when it
/// appears (accessibility checklist R2) and never shown by colour alone
/// (P3, AC5.2.3).
library;

import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../l10n/app_localizations.dart';
import '../ui/raad_theme.dart';

enum StatusKind {
  info(Icons.info_outline_rounded, RaadColors.cyanAccent),
  warning(Icons.schedule_rounded, RaadColors.warning),
  error(Icons.error_outline_rounded, RaadColors.error),
  offline(Icons.wifi_off_rounded, RaadColors.warning);

  const StatusKind(this.icon, this.color);

  final IconData icon;
  final Color color;
}

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.kind,
    required this.text,
    this.textKey,
    this.action,
  });

  final StatusKind kind;
  final String text;

  /// The key of the text itself, for tests.
  final Key? textKey;

  /// An optional button under the text, such as Try again.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: kind.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kind.color.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(kind.icon, color: kind.color, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    key: textKey,
                    style: TextStyle(
                      color: kind.color,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (action != null)
              Align(alignment: AlignmentDirectional.centerEnd, child: action),
          ],
        ),
      ),
    );
  }
}

/// Rebuilds [builder] whenever the phone's connection signal changes.
class ConnectionBuilder extends StatelessWidget {
  const ConnectionBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, bool online) builder;

  @override
  Widget build(BuildContext context) {
    final signal = AppServices.of(context).connectivity;
    return ListenableBuilder(
      listenable: signal,
      builder: (context, _) => builder(context, signal.isOnline),
    );
  }
}

/// "No connection." at the top of a screen that needs the network.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectionBuilder(
      builder: (context, online) => online
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: StatusBanner(
                kind: StatusKind.offline,
                text: AppLocalizations.of(context).offlineBanner,
                textKey: const ValueKey('app.offline'),
              ),
            ),
    );
  }
}

/// "Sending needs a connection." while the phone looks offline (AC3.9.1);
/// nothing when it is online.
class SendingNeedsConnection extends StatelessWidget {
  const SendingNeedsConnection({super.key, required this.textKey});

  final Key textKey;

  @override
  Widget build(BuildContext context) {
    return ConnectionBuilder(
      builder: (context, online) => online
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: StatusBanner(
                kind: StatusKind.offline,
                text: AppLocalizations.of(context).sendingNeedsConnection,
                textKey: textKey,
              ),
            ),
    );
  }
}
