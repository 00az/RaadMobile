import 'package:flutter/material.dart';

import '../screens/sign_in_screen.dart';
import '../screens/wallet_screen.dart';
import 'app_services.dart';

class RaadApp extends StatelessWidget {
  const RaadApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: services,
      child: MaterialApp(
        title: 'RAAD',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B6E4F)),
        ),
        home: const AuthGate(),
      ),
    );
  }
}

/// Shows the wallet when a session exists, otherwise sign-in.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AppServices.of(context).auth;
    return FutureBuilder<bool>(
      future: auth.hasSession(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data! ? const WalletScreen() : const SignInScreen();
      },
    );
  }
}

/// Clears the stack and shows sign-in, for sign-out and an ended session.
Future<void> showSignIn(BuildContext context, {String? notice}) async {
  final navigator = Navigator.of(context);
  await AppServices.of(context).auth.signOut();
  navigator.pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => SignInScreen(notice: notice)),
    (_) => false,
  );
}

/// The DEV or STG chip of C4; production shows none.
class EnvironmentChip extends StatelessWidget {
  const EnvironmentChip({super.key});

  @override
  Widget build(BuildContext context) {
    final label = AppServices.of(context).environmentChip;
    if (label == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Chip(
        key: const ValueKey('app.environmentChip'),
        label: Text(label),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
