import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dial_screen.dart';
import 'call_service.dart';
import 'call_history_screen.dart';

void main() {
  runApp(const CallNaijaApp());
}

class CallNaijaApp extends StatelessWidget {
  const CallNaijaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CallNaija',
      debugShowCheckedModeBanner: false,
      home: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: const HomeScreen(),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final callerController = TextEditingController();

  String walletBalance = '0.00';
  bool walletLoading = true;

  @override
  void initState() {
    super.initState();
    loadWallet();
  }

  Future<void> loadWallet() async {
    try {
      final wallet = await CallService.getWallet();

      if (!mounted) return;

      setState(() {
        walletBalance = wallet['balance'] ?? '0.00';
        walletLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        walletLoading = false;
      });
    }
  }

  Future<void> startStripeTopUp(double amount) async {
    try {
      final checkoutUrl = await CallService.createCheckoutSession(amount);
      final uri = Uri.parse(checkoutUrl);

      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open Stripe checkout');
      }

      Future.delayed(const Duration(seconds: 5), loadWallet);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: $e')),
      );
    }
  }

  void showTopUpOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Top Up Wallet',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              topUpOption(5),
              topUpOption(10),
              topUpOption(20),
            ],
          ),
        );
      },
    );
  }

  Widget topUpOption(double amount) {
    return ListTile(
      leading: const Icon(Icons.account_balance_wallet),
      title: Text('Add £${amount.toStringAsFixed(0)}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.pop(context);
        startStripeTopUp(amount);
      },
    );
  }

  @override
  void dispose() {
    callerController.dispose();
    super.dispose();
  }

  void openDialScreen() {
    final callerNumber = callerController.text.trim();

    if (callerNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your phone number first')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DialScreen(callerNumber: callerNumber),
      ),
    ).then((_) => loadWallet());
  }

  void openCallHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CallHistoryScreen(),
      ),
    ).then((_) => loadWallet());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FDF9),
      appBar: AppBar(
        title: const Text('CallNaija'),
        backgroundColor: const Color(0xFF0A7C3A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Call Nigeria reliably',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF103D24),
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Enter your phone number first. CallNaija will call you, then connect you to Nigeria.',
              style: TextStyle(fontSize: 14, color: Color(0xFF607568)),
            ),

            const SizedBox(height: 24),

            TextField(
              controller: callerController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Your phone number',
                hintText: '+447123456789',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Wallet Balance',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    walletLoading ? 'Loading...' : '£$walletBalance',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A7C3A),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: openDialScreen,
              icon: const Icon(Icons.call),
              label: const Text('Call Nigeria'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A7C3A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: showTopUpOptions,
              icon: const Icon(Icons.account_balance_wallet),
              label: const Text('Top Up Wallet'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0A7C3A),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: openCallHistory,
              icon: const Icon(Icons.history),
              label: const Text('Call History'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0A7C3A),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}