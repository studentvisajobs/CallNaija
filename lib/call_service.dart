import 'dart:convert';
import 'package:http/http.dart' as http;

class CallResult {
  final bool success;
  final String message;
  final String? sid;
  final String? status;

  CallResult({
    required this.success,
    required this.message,
    this.sid,
    this.status,
  });

  factory CallResult.fromJson(Map<String, dynamic> json) {
    return CallResult(
      success: json['success'] == true,
      message: json['message'] ?? json['error'] ?? 'Unknown response',
      sid: json['sid'],
      status: json['status'],
    );
  }
}

class CallStatusResult {
  final bool success;
  final String status;
  final String? callSid;
  final String? duration;
  final String? cost;
  final String? walletBalance;

  CallStatusResult({
    required this.success,
    required this.status,
    this.callSid,
    this.duration,
    this.cost,
    this.walletBalance,
  });

  factory CallStatusResult.fromJson(Map<String, dynamic> json) {
    return CallStatusResult(
      success: json['success'] == true,
      status: json['status'] ?? 'unknown',
      callSid: json['callSid'],
      duration: json['duration']?.toString(),
      cost: json['cost']?.toString(),
      walletBalance: json['walletBalance']?.toString(),
    );
  }
}

class CallService {
  static const String baseUrl = 'https://callnaija-backend.onrender.com';

  static Future<CallResult> makeCall({
    required String callerNumber,
    required String receiverNumber,
  }) async {
    final url = Uri.parse('$baseUrl/call');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'callerNumber': callerNumber,
        'receiverNumber': receiverNumber,
      }),
    );

    final data = jsonDecode(response.body);
    return CallResult.fromJson(data);
  }

  static Future<CallStatusResult> getCallStatus(String callSid) async {
    final url = Uri.parse('$baseUrl/call-status/$callSid');

    final response = await http.get(url);

    final data = jsonDecode(response.body);
    return CallStatusResult.fromJson(data);
  }

  static Future<Map<String, dynamic>> getWallet() async {
    final url = Uri.parse('$baseUrl/wallet');

    final response = await http.get(url);

    final data = jsonDecode(response.body);
    return data;
  }

  static Future<Map<String, dynamic>> topUpWallet(double amount) async {
    final url = Uri.parse('$baseUrl/wallet/top-up');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'amount': amount,
      }),
    );

    final data = jsonDecode(response.body);
    return data;
  }

  static Future<List<dynamic>> getCallHistory() async {
    final url = Uri.parse('$baseUrl/call-history');

    final response = await http.get(url);

    final data = jsonDecode(response.body);

    if (data['success'] == true) {
      return data['history'] ?? [];
    }

    return [];
  }
}