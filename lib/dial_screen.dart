import 'package:flutter/material.dart';
import 'call_service.dart';
import 'call_status_screen.dart';

class DialScreen extends StatefulWidget {
  final String callerNumber;

  const DialScreen({
    super.key,
    required this.callerNumber,
  });

  @override
  State<DialScreen> createState() => _DialScreenState();
}

class _DialScreenState extends State<DialScreen> {
  String number = '';
  String walletBalance = '0.00';
  String ratePerMinute = '0.10';
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
        ratePerMinute = wallet['ratePerMinute'] ?? '0.10';
        walletLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        walletLoading = false;
      });
    }
  }

  void addNumber(String val) {
    setState(() => number += val);
  }

  void deleteNumber() {
    if (number.isNotEmpty) {
      setState(() => number = number.substring(0, number.length - 1));
    }
  }

  String get formattedReceiverNumber {
    if (number.isEmpty) return 'Enter receiver number';

    if (number.startsWith('0')) {
      return '+234${number.substring(1)}';
    }

    if (number.startsWith('234')) {
      return '+$number';
    }

    if (number.startsWith('+234')) {
      return number;
    }

    return '+234$number';
  }

  void startCall() async {
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter receiver number first')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await CallService.makeCall(
        callerNumber: widget.callerNumber,
        receiverNumber: formattedReceiverNumber,
      );

      Navigator.pop(context);

      if (!result.success || result.sid == null) {
        throw Exception(result.message);
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CallStatusScreen(
            callerNumber: widget.callerNumber,
            receiverNumber: formattedReceiverNumber,
            callSid: result.sid!,
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Call Failed'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                loadWallet();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Widget walletCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A7C3A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: walletLoading
                ? const Text(
                    'Loading wallet...',
                    style: TextStyle(color: Colors.white),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Balance: £$walletBalance',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Rate: £$ratePerMinute / min',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget dialButton(String val) {
    return ElevatedButton(
      onPressed: () => addNumber(val),
      style: ElevatedButton.styleFrom(
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(22),
        backgroundColor: Colors.white,
      ),
      child: Text(
        val,
        style: const TextStyle(fontSize: 22, color: Colors.black),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FDF9),
      appBar: AppBar(
        title: const Text('Dial Nigeria'),
        backgroundColor: const Color(0xFF0A7C3A),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            children: [
              const SizedBox(height: 16),
              walletCard(),
              const SizedBox(height: 16),
              Text(
                'Caller: ${widget.callerNumber}',
                style: const TextStyle(color: Color(0xFF607568)),
              ),
              const SizedBox(height: 8),
              Text(
                formattedReceiverNumber,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF103D24),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  children: [
                    ...[
                      '1',
                      '2',
                      '3',
                      '4',
                      '5',
                      '6',
                      '7',
                      '8',
                      '9',
                      '*',
                      '0',
                      '#'
                    ].map(dialButton),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: deleteNumber,
                      icon: const Icon(Icons.backspace, size: 30),
                    ),
                    FloatingActionButton(
                      onPressed: startCall,
                      backgroundColor: const Color(0xFF0A7C3A),
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.call),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}