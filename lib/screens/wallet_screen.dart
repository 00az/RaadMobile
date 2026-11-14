import 'package:flutter/material.dart';

import '../api/generated/money_api_client.dart';
import '../api/money_service.dart';
import '../app/app_services.dart';
import '../app/raad_app.dart';
import '../money/halalas.dart';
import '../ui/messages.dart';
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

  MoneyService get _money => AppServices.of(context).money;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _setUp();
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My wallet'),
        actions: [
          const EnvironmentChip(),
          IconButton(
            key: const ValueKey('wallet.refresh'),
            tooltip: 'Refresh',
            onPressed: _balanceLoading || _historyLoading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            key: const ValueKey('wallet.signOut'),
            tooltip: 'Sign out',
            onPressed: () {
              _leaving = true;
              showSignIn(context);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(child: _setupError != null ? _setupFailed() : _content()),
    );
  }

  /// US1.2 AC1.2.5: wallet setup failed; Retry runs `PUT /wallet` again.
  Widget _setupFailed() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _setupError!,
            key: const ValueKey('walletSetup.error'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('walletSetup.retry'),
            onPressed: _settingUp ? null : _setUp,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    final balance = _balance;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Balance', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  if (balance != null)
                    Text(
                      formatHalalas(balance.amountHalalas),
                      key: const ValueKey('wallet.balance'),
                      style: theme.textTheme.headlineMedium,
                    )
                  else if (_balanceLoading)
                    const CircularProgressIndicator(
                      key: ValueKey('wallet.balanceLoading'),
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
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const ValueKey('wallet.send'),
                    onPressed: balance == null ? null : _openSend,
                    icon: const Icon(Icons.send),
                    label: const Text('Send'),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text('History', style: theme.textTheme.titleMedium),
        ),
        HistoryList(
          page: _page,
          loading: _historyLoading,
          error: _historyError,
        ),
      ],
    );
  }
}
