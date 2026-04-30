import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dial_screen.dart';
import 'call_service.dart';
import 'call_history_screen.dart';
import 'login_screen.dart';

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
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5FBF7),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A7C3A),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    checkLogin();
  }

  Future<void> checkLogin() async {
    final loggedIn = await CallService.loadSavedUser();

    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => loggedIn ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A7C3A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.call, color: Colors.white, size: 64),
            SizedBox(height: 16),
            Text(
              'CallNaija',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final callerController = TextEditingController();

  String walletBalance = '0.00';
  bool walletLoading = true;
  bool paymentLoading = false;
  bool paymentInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    callerController.text = CallService.currentUserPhone ?? '';
    loadWallet();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    callerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadWallet();

      if (paymentInProgress) {
        setState(() => paymentInProgress = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallet refreshed')),
        );
      }
    }
  }

  Future<void> loadWallet() async {
    if (!mounted) return;

    setState(() => walletLoading = true);

    try {
      final wallet = await CallService.getWallet();

      if (!mounted) return;

      setState(() {
        walletBalance = wallet['balance']?.toString() ?? '0.00';
        walletLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() => walletLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not refresh wallet')),
      );
    }
  }

  Future<void> startStripeTopUp(double amount) async {
    setState(() {
      paymentLoading = true;
      paymentInProgress = true;
    });

    try {
      final checkoutUrl = await CallService.createCheckoutSession(amount);
      final uri = Uri.parse(checkoutUrl);

      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        throw Exception('Could not open Stripe checkout');
      }

      Future.delayed(const Duration(seconds: 3), loadWallet);
      Future.delayed(const Duration(seconds: 6), loadWallet);
      Future.delayed(const Duration(seconds: 10), loadWallet);
    } catch (e) {
      if (!mounted) return;

      setState(() => paymentInProgress = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => paymentLoading = false);
      }
    }
  }

  void showTopUpOptions() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Top up wallet',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F8F4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF0A7C3A),
          child: Icon(Icons.add, color: Colors.white),
        ),
        title: Text(
          'Add £${amount.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text('Secure payment with Stripe'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.pop(context);
          startStripeTopUp(amount);
        },
      ),
    );
  }

  void openDialScreen() {
    final callerNumber = callerController.text.trim();

    if (callerNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the phone number CallNaija should call first'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DialScreen(callerNumber: callerNumber),
      ),
    ).then((_) => loadWallet());
  }

  void openCallHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CallHistoryScreen()),
    ).then((_) => loadWallet());
  }

  Future<void> logout() async {
    await CallService.clearSavedUser();
    CallService.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName = CallService.currentUserName ?? 'User';

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: SafeArea(
            child: RefreshIndicator(
              onRefresh: loadWallet,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A7C3A),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.22),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.call, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CallNaija',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF103D24),
                              ),
                            ),
                            Text(
                              'Welcome, $userName',
                              style: const TextStyle(
                                color: Color(0xFF607568),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: logout,
                        icon: const Icon(Icons.logout),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  Container(
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF0A7C3A),
                          Color(0xFF0E8F45),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.24),
                          blurRadius: 30,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              color: Colors.white70,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Wallet balance',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          walletLoading ? 'Loading...' : '£$walletBalance',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: paymentLoading ? null : showTopUpOptions,
                            icon: paymentLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.add_card),
                            label: Text(
                              paymentLoading ? 'Opening Stripe...' : 'Top Up Wallet',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0A7C3A),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  sectionTitle('Your phone number'),

                  const SizedBox(height: 8),

                  TextField(
                    controller: callerController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '+447123456789',
                      helperText: 'This is the number CallNaija will call first.',
                      helperMaxLines: 2,
                      prefixIcon: const Icon(Icons.phone),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  ElevatedButton.icon(
                    onPressed: openDialScreen,
                    icon: const Icon(Icons.call),
                    label: const Text('Call Nigeria'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A7C3A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed: openCallHistory,
                    icon: const Icon(Icons.history),
                    label: const Text('Call History'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0A7C3A),
                      side: const BorderSide(color: Color(0xFF0A7C3A)),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),

                  const SizedBox(height: 28),

                  sectionTitle('How it works'),

                  const SizedBox(height: 12),
                  infoTile(Icons.phone_callback, 'We call your phone first'),
                  infoTile(Icons.public, 'Then connect you to Nigeria'),
                  infoTile(Icons.payments, 'You only pay from your wallet'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w900,
        color: Color(0xFF103D24),
      ),
    );
  }

  Widget infoTile(IconData icon, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0A7C3A)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}