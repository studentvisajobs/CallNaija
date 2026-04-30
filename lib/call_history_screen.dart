import 'package:flutter/material.dart';
import 'call_service.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  bool loading = true;
  List<dynamic> history = [];

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    try {
      final data = await CallService.getCallHistory();

      if (!mounted) return;

      setState(() {
        history = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load call history: $e')),
      );
    }
  }

  String formatDate(String? value) {
    if (value == null) return '';

    try {
      final date = DateTime.parse(value).toLocal();
      final minute = date.minute.toString().padLeft(2, '0');

      return '${date.day}/${date.month}/${date.year} • ${date.hour}:$minute';
    } catch (_) {
      return value;
    }
  }

  String formatDuration(dynamic value) {
    final seconds = int.tryParse(value?.toString() ?? '0') ?? 0;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    if (minutes == 0) {
      return '${remainingSeconds}s';
    }

    return '${minutes}m ${remainingSeconds}s';
  }

  Color statusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF0A7C3A);
      case 'failed':
      case 'busy':
      case 'no-answer':
      case 'canceled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData statusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.call;
      case 'failed':
      case 'busy':
      case 'no-answer':
      case 'canceled':
        return Icons.call_end;
      default:
        return Icons.phone_in_talk;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FBF7),
      appBar: AppBar(
        title: const Text(
          'Call History',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: const Color(0xFFF5FBF7),
        foregroundColor: const Color(0xFF103D24),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF0A7C3A),
                  ),
                )
              : history.isEmpty
                  ? emptyState()
                  : RefreshIndicator(
                      onRefresh: loadHistory,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final call = history[index];
                          final status =
                              call['status']?.toString() ?? 'unknown';

                          return callCard(call, status);
                        },
                      ),
                    ),
        ),
      ),
    );
  }

  Widget emptyState() {
    return RefreshIndicator(
      onRefresh: loadHistory,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: Color(0xFFEAF6EE),
                  child: Icon(
                    Icons.history,
                    color: Color(0xFF0A7C3A),
                    size: 34,
                  ),
                ),
                SizedBox(height: 18),
                Text(
                  'No calls yet',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF103D24),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your completed calls will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF607568),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget callCard(dynamic call, String status) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 16,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: statusColor(status).withOpacity(0.12),
            child: Icon(
              statusIcon(status),
              color: statusColor(status),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  call['to']?.toString() ?? 'Unknown number',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF103D24),
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  formatDate(call['createdAt']?.toString()),
                  style: const TextStyle(
                    color: Color(0xFF607568),
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    pill(
                      text: status,
                      color: statusColor(status),
                    ),
                    pill(
                      text: formatDuration(call['duration']),
                      color: const Color(0xFF607568),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '£${call['cost'] ?? '0.00'}',
                style: const TextStyle(
                  color: Color(0xFF0A7C3A),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'cost',
                style: TextStyle(
                  color: Color(0xFF607568),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget pill({
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}