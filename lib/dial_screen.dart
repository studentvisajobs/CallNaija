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
  bool calling = false;

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
        walletBalance = wallet['balance']?.toString() ?? '0.00';
        ratePerMinute = wallet['ratePerMinute']?.toString() ?? '0.10';
        walletLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => walletLoading = false);
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
    if (number.isEmpty) return 'Enter Nigerian number';

    if (number.startsWith('+234')) return number;
    if (number.startsWith('234')) return '+$number';
    if (number.startsWith('0')) return '+234${number.substring(1)}';

    return '+234$number';
  }

  Future<void> startCall() async {
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the Nigerian number first')),
      );
      return;
    }

    setState(() => calling = true);

    try {
      final result = await CallService.makeCall(
        callerNumber: widget.callerNumber,
        receiverNumber: formattedReceiverNumber,
      );

      if (!mounted) return;

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
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Call failed'),
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
    } finally {
      if (mounted) {
        setState(() => calling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'];

    return Scaffold(
      backgroundColor: const Color(0xFFF5FBF7),
      appBar: AppBar(
        title: const Text(
          'Dial Nigeria',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: const Color(0xFFF5FBF7),
        foregroundColor: const Color(0xFF103D24),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            children: [
              walletCard(),

              const SizedBox(height: 6),

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
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
                child: Column(
                  children: [
                    const Text(
                      'CallNaija will call you first on',
                      style: TextStyle(
                        color: Color(0xFF607568),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.callerNumber,
                      style: const TextStyle(
                        color: Color(0xFF103D24),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  formattedReceiverNumber,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF103D24),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 34),
                  child: GridView.count(
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 18,
                    childAspectRatio: 1.15,
                    children: keys.map(dialButton).toList(),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton.filledTonal(
                      onPressed: deleteNumber,
                      icon: const Icon(Icons.backspace),
                    ),
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: FloatingActionButton(
                        onPressed: calling ? null : startCall,
                        backgroundColor: const Color(0xFF0A7C3A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        child: calling
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              )
                            : const Icon(Icons.call, size: 34),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => setState(() => number = ''),
                      icon: const Icon(Icons.close),
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

  Widget walletCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0A7C3A),
            Color(0xFF0E8F45),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.20),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(
              Icons.account_balance_wallet,
              color: Color(0xFF0A7C3A),
            ),
          ),
          const SizedBox(width: 14),
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
                        '£$walletBalance available',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Rate: £$ratePerMinute / min',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget dialButton(String val) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => addNumber(val),
        child: Center(
          child: Text(
            val,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: Color(0xFF103D24),
            ),
          ),
        ),
      ),
    );
  }
}