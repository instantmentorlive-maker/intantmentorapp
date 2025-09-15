import 'package:flutter/material.dart';
import 'wallet_screen.dart';

/// Temporary compatibility wrapper for older route references.
/// Delegates to the existing WalletScreen.
class EnhancedWalletScreen extends StatelessWidget {
  const EnhancedWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const WalletScreen();
  }
}
