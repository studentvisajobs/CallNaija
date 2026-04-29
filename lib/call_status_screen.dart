import 'dart:async';
import 'package:flutter/material.dart';
import 'call_service.dart';

class CallStatusScreen extends StatefulWidget {
  final String callerNumber;
  final String receiverNumber;
  final String callSid;

  const CallStatusScreen({
    super.key,
    required this.callerNumber,
    required this.receiverNumber,
    required this.callSid,
  });

  @override
  State<CallStatusScreen> createState() => _CallStatusScreenState();
}

class _CallStatusScreenState extends State<CallStatusScreen> {
  String callStatus = 'initiated';
  String? duration;
  String? cost;
  String? walletBalance;
  Timer? statusTimer;

  @override
  void initState() {
    super.initState();
    fetchStatusOnce();
    startStatusPolling();
  }

  Future<void> fetchStatusOnce() async {
    try {
      final result = await CallService.getCallStatus(widget.callSid);

      if (!mounted) return;

      setState(() {
        callStatus = result.status;
        duration = result.duration;
        cost = result.cost;
        walletBalance = result.walletBalance;
      });
    } catch (e) {
      debugPrint('Initial call status error: $e');
    }
  }

  void startStatusPolling() {
    statusTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final result = await CallService.getCallStatus(widget.callSid);

        if (!mounted) return;

        setState(() {
          callStatus = result.status;
          duration = result.duration;
          cost = result.cost;
          walletBalance = result.walletBalance;
        });

        if (isFinalStatus(callStatus)) {
          statusTimer?.cancel();
        }
      } catch (e) {
        debugPrint('Call status polling error: $e');
      }
    });
  }

  bool isFinalStatus(String status) {
    return status == 'completed' ||
        status == 'failed' ||
        status == 'busy' ||
        status == 'no-answer' ||
        status == 'canceled';
  }

  String formatDuration(String? secondsText) {
    if (secondsText == null) return '0s';

    final seconds = int.tryParse(secondsText) ?? 0;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    if (minutes == 0) {
      return '${remainingSeconds}s';
    }

    return '${minutes}m ${remainingSeconds}s';
  }

  String getStatusTitle() {
    switch (callStatus) {
      case 'initiated':
        return 'Starting call';
      case 'ringing':
        return 'Phone ringing';
      case 'in-progress':
      case 'answered':
        return 'Call connected';
      case 'completed':
        return 'Call completed';
      case 'busy':
        return 'Line busy';
      case 'no-answer':
        return 'No answer';
      case 'failed':
        return 'Call failed';
      case 'canceled':
        return 'Call cancelled';
      default:
        return 'Checking status';
    }
  }

  IconData getStatusIcon() {
    switch (callStatus) {
      case 'ringing':
        return Icons.phone_in_talk;
      case 'in-progress':
      case 'answered':
        return Icons.call;
      case 'completed':
        return Icons.check;
      case 'failed':
      case 'busy':
      case 'no-answer':
      case 'canceled':
        return Icons.call_end;
      default:
        return Icons.call;
    }
  }

  Color getIconColor() {
    if (callStatus == 'completed') {
      return const Color(0xFF0A7C3A);
    }

    if (callStatus == 'failed' ||
        callStatus == 'busy' ||
        callStatus == 'no-answer' ||
        callStatus == 'canceled') {
      return Colors.red;
    }

    return const Color(0xFF0A7C3A);
  }

  @override
  void dispose() {
    statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finished = isFinalStatus(callStatus);

    return Scaffold(
      backgroundColor: const Color(0xFF0A7C3A),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.white,
                  child: Icon(
                    getStatusIcon(),
                    size: 46,
                    color: getIconColor(),
                  ),
                ),

                const SizedBox(height: 28),

                Text(
                  getStatusTitle(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'Calling ${widget.callerNumber} first, then connecting to ${widget.receiverNumber}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Live Status',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        callStatus,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                if (finished) ...[
                  const SizedBox(height: 18),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Call Summary',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),

                        summaryRow(
                          label: 'Duration',
                          value: formatDuration(duration),
                        ),

                        const SizedBox(height: 8),

                        summaryRow(
                          label: 'Cost',
                          value: '£${cost ?? '0.00'}',
                        ),

                        const SizedBox(height: 8),

                        summaryRow(
                          label: 'Wallet Balance',
                          value: walletBalance == null
                              ? 'Updating...'
                              : '£$walletBalance',
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Call Reference',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.callSid,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                if (!finished)
                  const CircularProgressIndicator(
                    color: Colors.white,
                  ),

                if (finished)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('Back Home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0A7C3A),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget summaryRow({
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}