import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
      sid: json['sid']?.toString(),
      status: json['status']?.toString(),
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
      status: json['status']?.toString() ?? 'unknown',
      callSid: json['callSid']?.toString(),
      duration: json['duration']?.toString(),
      cost: json['cost']?.toString(),
      walletBalance: json['walletBalance']?.toString(),
    );
  }
}

class CallService {
  static const String baseUrl = 'https://callnaija-backend.onrender.com';

  static String? currentUserPhone;
  static String? currentUserName;
  static bool currentUserVerified = false;

  static Map<String, String> get authHeaders {
    return {
      'Content-Type': 'application/json',
      if (currentUserPhone != null && currentUserPhone!.isNotEmpty)
        'x-user-phone': currentUserPhone!,
    };
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body);

      if (data is Map<String, dynamic>) {
        if (response.statusCode >= 400) {
          throw Exception(data['error'] ?? 'Server error');
        }

        return data;
      }

      throw Exception('Invalid server response');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Could not read server response');
    }
  }

  // AUTH
  static Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'password': password,
      }),
    );

    final data = _decodeResponse(response);

    if (data['success'] == true && data['user'] != null) {
      return Map<String, dynamic>.from(data['user']);
    }

    throw Exception(data['error'] ?? 'Registration failed');
  }

  static Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'password': password,
      }),
    );

    final data = _decodeResponse(response);

    if (data['success'] == true && data['user'] != null) {
      return Map<String, dynamic>.from(data['user']);
    }

    throw Exception(data['error'] ?? 'Login failed');
  }

  static Future<void> sendOtp({
    required String phone,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
      }),
    );

    final data = _decodeResponse(response);

    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Could not send verification code');
    }
  }

  static Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String code,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'code': code,
      }),
    );

    final data = _decodeResponse(response);

    if (data['success'] == true && data['user'] != null) {
      return Map<String, dynamic>.from(data['user']);
    }

    throw Exception(data['error'] ?? 'Verification failed');
  }

  // CALL
  static Future<CallResult> makeCall({
    required String callerNumber,
    required String receiverNumber,
  }) async {
    if (currentUserPhone == null) {
      throw Exception('Please login again');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/call'),
      headers: authHeaders,
      body: jsonEncode({
        'phone': currentUserPhone,
        'callerNumber': callerNumber,
        'receiverNumber': receiverNumber,
      }),
    );

    final data = _decodeResponse(response);
    return CallResult.fromJson(data);
  }

  static Future<CallStatusResult> getCallStatus(String callSid) async {
    final response = await http.get(
      Uri.parse('$baseUrl/call-status/$callSid'),
      headers: authHeaders,
    );

    final data = _decodeResponse(response);
    return CallStatusResult.fromJson(data);
  }

static Future<void> savePushToken(String token) async {
  if (currentUserPhone == null) return;

  try {
    final response = await http.post(
      Uri.parse('$baseUrl/save-push-token'),
      headers: authHeaders,
      body: jsonEncode({
        'phone': currentUserPhone,
        'token': token,
      }),
    );

    print('Push token save response: ${response.statusCode} ${response.body}');
  } catch (e) {
    print('Failed to save push token: $e');
  }
}

  // WALLET
  static Future<Map<String, dynamic>> getWallet() async {
    if (currentUserPhone == null) {
      throw Exception('Please login again');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/wallet'),
      headers: authHeaders,
    );

    return _decodeResponse(response);
  }

  static Future<String> createCheckoutSession(double amount) async {
    if (currentUserPhone == null) {
      throw Exception('Please login again');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/create-checkout-session'),
      headers: authHeaders,
      body: jsonEncode({
        'amount': amount,
        'phone': currentUserPhone,
      }),
    );

    final data = _decodeResponse(response);

    if (data['success'] == true && data['checkoutUrl'] != null) {
      return data['checkoutUrl'].toString();
    }

    throw Exception(data['error'] ?? 'Failed to create checkout session');
  }

  // HISTORY
  static Future<List<dynamic>> getCallHistory() async {
    if (currentUserPhone == null) {
      throw Exception('Please login again');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/call-history'),
      headers: authHeaders,
    );

    final data = _decodeResponse(response);

    if (data['success'] == true) {
      return data['history'] ?? [];
    }

    return [];
  }

  // SESSION
  static Future<void> saveUserLocally({
    required String phone,
    required String name,
    required bool isVerified,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_phone', phone);
    await prefs.setString('user_name', name);
    await prefs.setBool('user_verified', isVerified);
  }

  static Future<bool> loadSavedUser() async {
    final prefs = await SharedPreferences.getInstance();

    final phone = prefs.getString('user_phone');
    final name = prefs.getString('user_name');
    final verified = prefs.getBool('user_verified') ?? false;

    if (phone != null && name != null && verified == true) {
      currentUserPhone = phone;
      currentUserName = name;
      currentUserVerified = verified;
      return true;
    }

    return false;
  }

  static Future<void> clearSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_phone');
    await prefs.remove('user_name');
    await prefs.remove('user_verified');
  }

  static void setCurrentUser(Map<String, dynamic> user) {
    currentUserPhone = user['phone']?.toString();
    currentUserName = user['name']?.toString();
    currentUserVerified = user['isVerified'] == true;
  }

  static void logout() {
    currentUserPhone = null;
    currentUserName = null;
    currentUserVerified = false;
  }
}