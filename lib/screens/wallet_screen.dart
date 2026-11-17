import 'package:flutter/material.dart';

import '../api/generated/money_api_client.dart';
import '../api/money_service.dart';
import '../app/app_services.dart';
import '../app/raad_app.dart';
import '../money/halalas.dart';
import '../ui/messages.dart';
import '../ui/raad_theme.dart';
import '../widgets/virtual_card.dart';
import 'history_list.dart';
import 'send_form_screen.dart';

/// US2.1 with US4.1 and US4.2: balance, the first history page and the way
/// into sending.
///
/// On first load it sets the wallet up with `PUT /wallet` (200 and 201 are
/// both success). Later reads use `GET /wallet`, which never creates a
/// wallet, and fall back to setup on `WALLET_NOT_FOUND`.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _setupDone = false;
  bool _settingUp = true;
  String? _setupError;
  Money? _balance;
  bool _balanceLoading = true;
  String? _balanceError;
  TransferPage? _page;
  bool _historyLoading = false;
  String? _historyError;
  bool _leaving = false;
  bool _obscureBalance = false;

  MoneyService get _money => AppServices.of(context).money;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _setUp();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _setUp() async {
    setState(() {
      _settingUp = true;
      _setupError = null;
      _balanceLoading = true;
    });
    try {
      final balance = await _money.ensureWallet();
      if (!mounted) return;
      setState(() {
        _setupDone = true;
        _settingUp = false;
        _balance = balance;
        _balanceLoading = false;
      });
    } on MoneyApiException catch (error) {
      if (!mounted || await _endSessionIfNeeded(error)) return;
      setState(() {
        _settingUp = false;
        _balanceLoading = false;
        _setupError = error.status == 409
            ? Messages.walletEmailInUse
            : Messages.walletSetupFailed;
      });
      return;
    }
    await _loadHistory();
  }

  Future<void> _refresh() async {
    if (!_setupDone) return _setUp();
    await Future.wait([_loadBalance(), _loadHistory()]);
  }

  Future<void> _loadBalance() async {
    setState(() {
      _balanceLoading = true;
      _balanceError = null;
    });
    try {
      Money balance;
      try {
        balance = await _money.getBalance();
      } on MoneyApiException catch (error) {
        if (error.code != MoneyErrorCode.walletNotFound) rethrow;
        balance = await _money.ensureWallet();
      }
      if (!mounted) return;
      setState(() {
        _balance = balance;
        _balanceLoading = false;
      });
    } on MoneyApiException catch (error) {
      if (!mounted || await _endSessionIfNeeded(error)) return;
      setState(() {
        _balanceLoading = false;
        _balanceError = Messages.forMoneyError(error);
      });
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    try {
      final page = await _money.firstHistoryPage();
      if (!mounted) return;
      setState(() {
        _page = page;
        _historyLoading = false;
      });
    } on MoneyApiException catch (error) {
      if (!mounted || await _endSessionIfNeeded(error)) return;
      setState(() {
        _historyLoading = false;
        _historyError =
            "We couldn't load your history. "
            '${Messages.forMoneyError(error)}';
      });
    }
  }

  Future<bool> _endSessionIfNeeded(MoneyApiException error) async {
    if (!error.isAuthenticationRequired) return false;
    if (!_leaving) {
      _leaving = true;
      await showSignIn(context, notice: Messages.sessionExpired);
    }
    return true;
  }

  Future<void> _openSend() async {
    final balance = _balance;
    if (balance == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SendFormScreen(balanceHalalas: balance.amountHalalas),
      ),
    );
    if (mounted && !_leaving) await _refresh();
  }

  void _scrollToHistory() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        380,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RaadColors.background,
      body: SafeArea(
        top: false,
        child: _setupError != null ? _setupFailed() : _content(),
      ),
    );
  }

  /// US1.2 AC1.2.5: wallet setup failed; Retry runs `PUT /wallet` again.
  Widget _setupFailed() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: RaadColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: RaadColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _setupError!,
                key: const ValueKey('walletSetup.error'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: RaadColors.error,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('walletSetup.retry'),
              onPressed: _settingUp ? null : _setUp,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    final balance = _balance;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        // Upper Atmospheric Hero Section (inspired by twilight horizon / desert night)
        Container(
          padding: EdgeInsets.fromLTRB(
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
              // Header Profile Bar
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF161B2B),
                      border: Border.all(
                        color: RaadColors.cyanAccent,
                        width: 1.5,
                      ),
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
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RAAD WALLET',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: RaadColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'individual account',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: RaadColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: RaadColors.textSecondary,
                              size: 16,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const EnvironmentChip(),
                  // Refresh glass button
                  _headerGlassButton(
                    key: const ValueKey('wallet.refresh'),
                    icon: Icons.sync_rounded,
                    tooltip: 'Refresh',
                    onPressed: _balanceLoading || _historyLoading
                        ? null
                        : _refresh,
                  ),
                  const SizedBox(width: 8),
                  // Sign out glass button
                  _headerGlassButton(
                    key: const ValueKey('wallet.signOut'),
                    icon: Icons.logout_rounded,
                    tooltip: 'Sign out',
                    onPressed: () {
                      _leaving = true;
                      showSignIn(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // Hero Balance Display
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Balance Text
                      if (balance != null)
                        Text(
                          _obscureBalance
                              ? '•••••• SAR'
                              : formatHalalas(balance.amountHalalas),
                          key: const ValueKey('wallet.balance'),
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: RaadColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        )
                      else if (_balanceLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: CircularProgressIndicator(
                            key: ValueKey('wallet.balanceLoading'),
                            color: RaadColors.cyanAccent,
                          ),
                        ),
                      if (balance != null) ...[
                        const SizedBox(width: 10),
                        // Show/Hide Balance Eye Toggle
                        GestureDetector(
                          onTap: () => setState(
                            () => _obscureBalance = !_obscureBalance,
                          ),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: RaadColors.surfaceElevated.withValues(
                                alpha: 0.6,
                              ),
                              border: Border.all(color: RaadColors.cardBorder),
                            ),
                            child: Icon(
                              _obscureBalance
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: RaadColors.textSecondary,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_balanceError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _balanceError!,
                        key: const ValueKey('wallet.balanceError'),
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  const SizedBox(height: 6),
                  const Text(
                    'Available balance',
                    style: TextStyle(
                      color: RaadColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // 3 Quick Action Circular Buttons Row (Add/Send, Transactions, Account)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _circleActionButton(
                    key: const ValueKey('wallet.send'),
                    icon: Icons.arrow_upward_rounded,
                    label: 'Send',
                    isPrimary: true,
                    onTap: balance == null ? null : _openSend,
                  ),
                  _circleActionButton(
                    icon: Icons.receipt_long_rounded,
                    label: 'Transactions',
                    onTap: _scrollToHistory,
                  ),
                  _circleActionButton(
                    icon: Icons.person_outline_rounded,
                    label: 'Account',
                    onTap: () {
                      _leaving = true;
                      showSignIn(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // Virtual Card Carousel Section
        const SizedBox(height: 20),
        const VirtualCardCarousel(),
        const SizedBox(height: 20),

        // Services & Quick Pay Section (inspired by the screenshot's service cards)
        Container(
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
                  const Text(
                    'Services',
                    style: TextStyle(
                      color: RaadColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      letterSpacing: -0.2,
                    ),
                  ),
                  InkWell(
                    onTap: balance == null ? null : _openSend,
                    child: const Text(
                      'View all',
                      style: TextStyle(
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
                children: [
                  Expanded(
                    child: _serviceCard(
                      icon: Icons.bolt_rounded,
                      iconColor: RaadColors.cyanAccent,
                      title: 'Transfer to\nRAAD wallet',
                      onTap: balance == null ? null : _openSend,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _serviceCard(
                      icon: Icons.language_rounded,
                      iconColor: const Color(0xFFFBBF24),
                      title: 'International\nTransfer',
                      onTap: null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _serviceCard(
                      icon: Icons.account_balance_rounded,
                      iconColor: const Color(0xFFFBBF24),
                      title: 'Local Bank\nTransfer',
                      onTap: null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // History Section
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'History',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const Text(
                'Recent activity',
                style: TextStyle(
                  color: RaadColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        HistoryList(
          page: _page,
          loading: _historyLoading,
          error: _historyError,
        ),
        const SizedBox(height: 24),
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
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: RaadColors.surfaceElevated.withValues(alpha: 0.6),
        border: Border.all(color: RaadColors.cardBorder),
      ),
      child: IconButton(
        key: key,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
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
              boxShadow: isPrimary
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
              color: isPrimary ? RaadColors.background : RaadColors.textPrimary,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: RaadColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _serviceCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 125,
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
              maxLines: 2,
              style: const TextStyle(
                color: RaadColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
