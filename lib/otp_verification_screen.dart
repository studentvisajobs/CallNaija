import 'package:flutter/material.dart';

import 'call_service.dart';
import 'main.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phone;

  const OtpVerificationScreen({
    super.key,
    required this.phone,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final codeController = TextEditingController();

  bool loading = false;
  bool resending = false;

  Future<void> verifyCode() async {
    final code = codeController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your verification code')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final user = await CallService.verifyOtp(
        phone: widget.phone,
        code: code,
      );

      CallService.setCurrentUser(user);

      await CallService.saveUserLocally(
        phone: user['phone'],
        name: user['name'],
        isVerified: user['isVerified'] == true,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> resendCode() async {
    setState(() => resending = true);

    try {
      await CallService.sendOtp(phone: widget.phone);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification code sent')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not resend code: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => resending = false);
      }
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FBF7),
      appBar: AppBar(
        title: const Text('Verify phone'),
        backgroundColor: const Color(0xFFF5FBF7),
        foregroundColor: const Color(0xFF103D24),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 24),

                const CircleAvatar(
                  radius: 38,
                  backgroundColor: Color(0xFFEAF6EE),
                  child: Icon(
                    Icons.sms,
                    color: Color(0xFF0A7C3A),
                    size: 38,
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  'Enter verification code',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF103D24),
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'We sent a code to ${widget.phone}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF607568),
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 34),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  child: TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                    ),
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: '------',
                      border: InputBorder.none,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: loading ? null : verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A7C3A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Verify',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                ),

                const SizedBox(height: 14),

                OutlinedButton(
                  onPressed: resending ? null : resendCode,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0A7C3A),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: Text(
                    resending ? 'Sending...' : 'Resend code',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}