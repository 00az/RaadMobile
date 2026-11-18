import 'package:flutter/material.dart';

import '../api/generated/money_api_client.dart';
import '../api/money_service.dart';
import '../app/app_services.dart';
import '../app/raad_app.dart';
import '../l10n/app_localizations.dart';
import '../money/pending_transfer.dart';
import '../money/submission_controller.dart';
import '../money/wallet_controller.dart';
import '../ui/formatting.dart';
import '../ui/messages.dart';
import '../ui/raad_theme.dart';
import '../widgets/status_banner.dart';
import '../widgets/virtual_card.dart';
import 'account_screen.dart';
import 'history_list.dart';
import 'history_screen.dart';
import 'send_form_screen.dart';
import 'send_review_screen.dart';

/// S6, the wallet (US1.2, US2.1, US2.2, US4.2, US5.3).
///
/// A new sign-in sets the wallet up with `PUT /wallet` before anything is
/// shown; a failure shows the set-up screen with Try again. The balance is
/// the last one the Money API confirmed: a failed refresh keeps it with an
/// out-of-date label and its time, and with nothing known the screen says
/// so instead of showing a zero. Refresh is a button and pull to refresh;
/// nothing refreshes by itself.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

/// How many of the newest transfers the wallet lists; History has the rest.
const int latestCount = 5;

class _WalletScreenState extends State<WalletScreen> {
  final ScrollController _scrollController = ScrollController();
  WalletController? _controller;

  /// The newest transfers, as the Money API ordered them.
  List<TransferListItem>? _latest;
  bool _historyLoading = false;
  bool _historyStarted = false;
  String? _historyError;
  bool _obscureBalance = false;

  /// An unresolved transfer of this account, found after a restart or a new
  /// sign-in. It is only shown; nothing is sent until the person chooses.
  PendingTransfer? _pending;

  WalletController get _wallet => _controller!;
  AppServices get _services => AppServices.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final services = _services;
    _controller = WalletController(
      money: services.money,
      session: services.session,
      balances: services.balances,
      environment: services.environmentName,
      now: services.now,
    )..addListener(_onWallet);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _wallet.start();
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onWallet() {
    if (!mounted) return;
    setState(() {});
    if (_wallet.setup == WalletSetup.ready && !_historyStarted) {
      _historyStarted = true;
      _loadHistory();
      _loadPending();
    }
  }

  Future<void> _loadPending() async {
    final services = _services;
    final owner = services.session.accountId;
    if (owner == null) return;
    final record = await services.session.whileCurrent(
      () => services.pendingTransfers.load(
        owner: owner,
        environment: services.environmentName,
      ),
    );
    if (mounted) setState(() => _pending = record);
  }

  Future<void> _openPending() async {
    final record = _pending;
    if (record == null) return;
    final services = _services;
    final controller = SubmissionController.restore(
      record,
      money: services.money,
      pending: services.pendingTransfers,
      now: services.now,
    );
    final navigator = Navigator.of(context);
    final balance = _wallet.snapshot?.halalas ?? record.balanceBeforeHalalas;
    final outcome = await navigator.push<ChangeDetails>(
      MaterialPageRoute<ChangeDetails>(
        builder: (_) => SendReviewScreen(
          controller: controller,
          balanceHalalas: balance,
          restored: true,
        ),
      ),
    );
    if (outcome != null && mounted) {
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => SendFormScreen(
            balanceHalalas: balance,
            controller: controller,
            initialEmail: outcome.email,
            initialAmount: outcome.amount,
          ),
        ),
      );
    }
    controller.dispose();
    if (mounted && services.session.isActive) {
      await Future.wait([_loadPending(), _refresh()]);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_wallet.refresh(), _loadHistory()]);
  }

  Future<void> _loadHistory() async {
    if (_wallet.setup != WalletSetup.ready) return;
    final session = _services.session;
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    try {
      final page = await session.whileCurrent(
        () => _services.money.historyPage(limit: latestCount),
      );
      if (!mounted || page == null) return;
      setState(() {
        _latest = page.items;
        _historyLoading = false;
      });
    } on MoneyApiException catch (error) {
      if (!mounted) return;
      if (error.isAuthenticationRequired) {
        await session.expire();
        return;
      }
      setState(() {
        _historyLoading = false;
        _historyError = Messages.forMoneyError(
          AppLocalizations.of(context),
          error,
        );
      });
    }
  }

  Future<void> _openSend() async {
    final snapshot = _wallet.snapshot;
    if (snapshot == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SendFormScreen(balanceHalalas: snapshot.halalas),
      ),
    );
    if (mounted && _services.session.isActive) {
      await Future.wait([_loadPending(), _refresh()]);
    }
  }

  void _signOut() => _services.session.signOut();

  void _openAccount() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const AccountScreen()));
  }

  Future<void> _openHistory() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const HistoryScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: RaadColors.background,
      body: SafeArea(
        top: false,
        child: switch (_wallet.setup) {
          WalletSetup.settingUp when _wallet.snapshot == null => _settingUp(
            l10n,
          ),
          WalletSetup.failed => _setupFailed(l10n),
          _ => _content(l10n),
        },
      ),
    );
  }

  Widget _settingUp(AppLocalizations l10n) {
    return Center(
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              key: ValueKey('walletSetup.loading'),
              color: RaadColors.cyanAccent,
            ),
            const SizedBox(height: 16),
            Text(l10n.walletSettingUp),
          ],
        ),
      ),
    );
  }

  /// AC1.2.5: wallet set-up failed; Try again runs `PUT /wallet` again and
  /// never credits the opening balance twice.
  Widget _setupFailed(AppLocalizations l10n) {
    final settingUp = _wallet.setup == WalletSetup.settingUp;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 48),
          const Icon(
            Icons.error_outline_rounded,
            color: RaadColors.error,
            size: 40,
          ),
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            header: true,
            child: Text(
              l10n.walletSetupFailedTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _wallet.emailInUse
                ? l10n.walletSetupEmailInUse
                : l10n.walletSetupFailedBody,
            key: const ValueKey('walletSetup.error'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: RaadColors.textSecondary),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('walletSetup.retry'),
            onPressed: settingUp ? null : _wallet.setUp,
            child: Text(l10n.tryAgain),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const ValueKey('walletSetup.signOut'),
            onPressed: _signOut,
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );
  }

  Widget _content(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final canSend = _wallet.snapshot != null;

    return RefreshIndicator(
      key: const ValueKey('wallet.pullToRefresh'),
      onRefresh: _refresh,
      color: RaadColors.cyanAccent,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Upper hero section (twilight horizon / desert night).
            Container(
              padding: EdgeInsetsDirectional.fromSTEB(
                20,
                MediaQuery.of(context).padding.top + 12,
                20,
                24,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF07080D),
                    Color(0xFF131726),
                    Color(0xFF1B1924),
                    Color(0xFF12141F),
                    Color(0xFF07080D),
                  ],
                  stops: [0.0, 0.35, 0.65, 0.85, 1.0],
                ),
              ),
              child: Column(
                children: [
                  _header(l10n),
                  if (_pending case final pending?) ...[
                    const SizedBox(height: 16),
                    _pendingBanner(l10n, pending),
                  ],
                  const SizedBox(height: 36),
                  _balance(l10n),
                  const SizedBox(height: 32),
                  ConnectionBuilder(
                    builder: (context, online) => Column(
                      children: [
                        _quickActions(l10n, canSend: canSend && online),
                        if (!online) ...[
                          const SizedBox(height: 12),
                          StatusBanner(
                            kind: StatusKind.offline,
                            text: l10n.walletSendOffline,
                            textKey: const ValueKey('wallet.sendOffline'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Virtual card carousel (decorative).
            const SizedBox(height: 20),
            const VirtualCardCarousel(),
            const SizedBox(height: 20),

            _servicesCard(l10n, canSend: canSend),

            // History section.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.walletHistory,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('wallet.seeAll'),
                    onPressed: _openHistory,
                    child: Text(l10n.historySeeAll),
                  ),
                ],
              ),
            ),
            HistoryList(
              items: _latest,
              loading: _historyLoading,
              error: _historyError,
              onRetry: _loadHistory,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _pendingBanner(AppLocalizations l10n, PendingTransfer pending) {
    final formats = Formats.of(context);
    return StatusBanner(
      kind: StatusKind.warning,
      text:
          '${l10n.walletPendingTitle}. '
          '${l10n.walletPendingBody(formats.money(pending.amountHalalas), pending.recipientName)}',
      textKey: const ValueKey('wallet.pending'),
      action: TextButton(
        key: const ValueKey('wallet.pendingReview'),
        onPressed: _openPending,
        child: Text(l10n.walletPendingReview),
      ),
    );
  }

  Widget _header(AppLocalizations l10n) {
    return Row(
      children: [
        ExcludeSemantics(
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF161B2B),
              border: Border.all(color: RaadColors.cyanAccent, width: 1.5),
              boxShadow: const [
                BoxShadow(color: RaadColors.cyanGlow, blurRadius: 14),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.bolt_rounded,
                color: RaadColors.cyanAccent,
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.walletTitle,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: RaadColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.walletAccountType,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: RaadColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const EnvironmentChip(),
        _headerGlassButton(
          key: const ValueKey('wallet.refresh'),
          icon: Icons.sync_rounded,
          tooltip: l10n.refresh,
          onPressed: _wallet.isLoading || _historyLoading ? null : _refresh,
        ),
        const SizedBox(width: 8),
        _headerGlassButton(
          key: const ValueKey('wallet.signOut'),
          icon: Icons.logout_rounded,
          tooltip: l10n.signOut,
          onPressed: _signOut,
        ),
      ],
    );
  }

  /// The balance card: loaded, out of date, loading or error, never a
  /// fabricated zero (BR3.5).
  Widget _balance(AppLocalizations l10n) {
    final formats = Formats.of(context);
    final snapshot = _wallet.snapshot;
    if (snapshot == null) {
      if (_wallet.isLoading || _wallet.setup == WalletSetup.settingUp) {
        return Semantics(
          label: l10n.loading,
          liveRegion: true,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: CircularProgressIndicator(
              key: ValueKey('wallet.balanceLoading'),
              color: RaadColors.cyanAccent,
            ),
          ),
        );
      }
      return Semantics(
        liveRegion: true,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: RaadColors.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.walletBalanceError,
                    key: const ValueKey('wallet.balanceError'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: RaadColors.error),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey('wallet.balanceRetry'),
              onPressed: _wallet.refresh,
              child: Text(l10n.tryAgain),
            ),
          ],
        ),
      );
    }

    final amount = formats.money(snapshot.halalas);
    final time = formats.updatedAt(snapshot.updatedAt, _services.now());
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Semantics(
                label: _obscureBalance
                    ? l10n.walletBalanceHidden
                    : l10n.walletBalanceSemantics(amount),
                excludeSemantics: true,
                child: Text(
                  _obscureBalance ? '••••••' : amount,
                  key: const ValueKey('wallet.balance'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: RaadColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              key: const ValueKey('wallet.toggleBalance'),
              tooltip: _obscureBalance
                  ? l10n.walletShowBalance
                  : l10n.walletHideBalance,
              onPressed: () =>
                  setState(() => _obscureBalance = !_obscureBalance),
              icon: Icon(
                _obscureBalance
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: RaadColors.textSecondary,
                size: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          l10n.walletAvailableBalance,
          style: const TextStyle(
            color: RaadColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        if (_wallet.isStale)
          Semantics(
            liveRegion: true,
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  color: RaadColors.warning,
                  size: 16,
                ),
                Text(
                  l10n.walletBalanceStale(time),
                  key: const ValueKey('wallet.stale'),
                  style: const TextStyle(
                    color: RaadColors.warning,
                    fontSize: 12,
                  ),
                ),
                TextButton(
                  key: const ValueKey('wallet.staleRetry'),
                  onPressed: _wallet.isLoading ? null : _refresh,
                  child: Text(l10n.tryAgain),
                ),
              ],
            ),
          )
        else
          Text(
            l10n.walletBalanceUpdated(time),
            key: const ValueKey('wallet.updated'),
            style: const TextStyle(color: RaadColors.textMuted, fontSize: 12),
          ),
      ],
    );
  }

  Widget _quickActions(AppLocalizations l10n, {required bool canSend}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _circleActionButton(
            key: const ValueKey('wallet.send'),
            icon: Icons.arrow_upward_rounded,
            label: l10n.walletActionSend,
            isPrimary: true,
            onTap: canSend ? _openSend : null,
          ),
        ),
        Expanded(
          child: _circleActionButton(
            key: const ValueKey('wallet.transactions'),
            icon: Icons.receipt_long_rounded,
            label: l10n.walletActionTransactions,
            onTap: _openHistory,
          ),
        ),
        Expanded(
          child: _circleActionButton(
            key: const ValueKey('wallet.account'),
            icon: Icons.person_outline_rounded,
            label: l10n.walletActionAccount,
            onTap: _openAccount,
          ),
        ),
      ],
    );
  }

  /// The services card. Only the RAAD transfer works; the other two tiles
  /// are part of the design and are announced as not available. No card or
  /// bank detail is ever asked for.
  Widget _servicesCard(AppLocalizations l10n, {required bool canSend}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RaadColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: RaadColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.walletServices,
                    style: const TextStyle(
                      color: RaadColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('wallet.viewAll'),
                onPressed: canSend ? _openSend : null,
                child: Text(
                  l10n.walletViewAll,
                  style: const TextStyle(
                    color: RaadColors.cyanAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _serviceCard(
                  key: const ValueKey('wallet.service.raad'),
                  icon: Icons.bolt_rounded,
                  iconColor: RaadColors.cyanAccent,
                  title: l10n.walletServiceRaad,
                  onTap: canSend ? _openSend : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _serviceCard(
                  key: const ValueKey('wallet.service.international'),
                  icon: Icons.language_rounded,
                  iconColor: RaadColors.gold,
                  title: l10n.walletServiceInternational,
                  unavailable: l10n.notAvailableYet,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _serviceCard(
                  key: const ValueKey('wallet.service.bank'),
                  icon: Icons.account_balance_rounded,
                  iconColor: RaadColors.gold,
                  title: l10n.walletServiceBank,
                  unavailable: l10n.notAvailableYet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerGlassButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Key? key,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: RaadColors.surfaceElevated.withValues(alpha: 0.6),
        border: Border.all(color: RaadColors.cardBorder),
      ),
      child: IconButton(
        key: key,
        tooltip: tooltip,
        icon: Icon(icon, color: RaadColors.textPrimary, size: 20),
        onPressed: onPressed,
      ),
    );
  }

  Widget _circleActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Key? key,
    bool isPrimary = false,
  }) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: enabled ? 1 : 0.45,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPrimary
                        ? RaadColors.cyanAccent
                        : RaadColors.surfaceElevated.withValues(alpha: 0.8),
                    border: Border.all(
                      color: isPrimary
                          ? RaadColors.cyanAccent
                          : RaadColors.cardBorder,
                      width: 1.2,
                    ),
                    boxShadow: isPrimary && enabled
                        ? const [
                            BoxShadow(
                              color: RaadColors.cyanGlow,
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    color: isPrimary
                        ? RaadColors.background
                        : RaadColors.textPrimary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: RaadColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _serviceCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    VoidCallback? onTap,
    String? unavailable,
    Key? key,
  }) {
    return Semantics(
      key: key,
      button: unavailable == null,
      enabled: onTap != null,
      label: unavailable == null ? title : '$title. $unavailable',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 125),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          decoration: BoxDecoration(
            color: RaadColors.surfaceElevated.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RaadColors.cardBorder),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: 0.15),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: RaadColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              if (unavailable != null) ...[
                const SizedBox(height: 4),
                Text(
                  unavailable,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: RaadColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
