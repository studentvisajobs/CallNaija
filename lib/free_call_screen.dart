import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'app_call_service.dart';
import 'call_service.dart';
import 'webrtc_service.dart';

class FreeCallScreen extends StatefulWidget {
  const FreeCallScreen({super.key});

  @override
  State<FreeCallScreen> createState() => _FreeCallScreenState();
}

class _FreeCallScreenState extends State<FreeCallScreen> {
  final phoneController = TextEditingController();

  bool calling = false;
  bool connected = false;
  String callStatus = 'Enter a CallNaija user phone number';

  Future<void> startFreeCall() async {
    final toPhone = phoneController.text.trim();

    if (toPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter user phone number')),
      );
      return;
    }

    final fromPhone = CallService.currentUserPhone;
    final fromName = CallService.currentUserName ?? 'CallNaija User';

    if (fromPhone == null || fromPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login again')),
      );
      return;
    }

    try {
      setState(() {
        calling = true;
        connected = false;
        callStatus = 'Calling $toPhone...';
      });

      await WebRTCService.init();

      WebRTCService.onRemoteStreamReady = () async {
        await WebRTCService.enableSpeaker();

        if (!mounted) return;

        setState(() {
          connected = true;
          callStatus = 'Connected — audio active';
        });
      };

      WebRTCService.onIceCandidate = (candidate) {
        AppCallService.sendIceCandidate(
          toPhone: toPhone,
          candidate: candidate.toMap(),
        );
      };

      final offer = await WebRTCService.createOffer();

      AppCallService.callUser(
        fromPhone: fromPhone,
        fromName: fromName,
        toPhone: toPhone,
        offer: offer.toMap(),
      );
    } catch (e) {
      WebRTCService.dispose();

      setState(() {
        calling = false;
        connected = false;
        callStatus = 'Call failed';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start call: $e')),
      );
    }
  }

  void endCall() {
    final toPhone = phoneController.text.trim();

    if (toPhone.isNotEmpty) {
      AppCallService.endCall(toPhone: toPhone);
    }

    WebRTCService.dispose();

    setState(() {
      calling = false;
      connected = false;
      callStatus = 'Call ended';
    });
  }

  @override
  void initState() {
    super.initState();

    AppCallService.onCallAnswered((data) async {
      if (!mounted) return;

      final answerData = data['answer'];

      if (answerData != null) {
        final answer = RTCSessionDescription(
          answerData['sdp'],
          answerData['type'],
        );

        await WebRTCService.setRemoteDescription(answer);
        await WebRTCService.enableSpeaker();
      }

      setState(() {
        calling = true;
        callStatus =
            connected ? 'Connected — audio active' : 'Connecting audio...';
      });
    });

    AppCallService.onIceCandidate((data) async {
      final candidateData = data['candidate'];
      if (candidateData == null) return;

      final candidate = RTCIceCandidate(
        candidateData['candidate'],
        candidateData['sdpMid'],
        candidateData['sdpMLineIndex'],
      );

      await WebRTCService.addIceCandidate(candidate);
    });

AppCallService.onCallRejected(() {
  if (!mounted) return;

  WebRTCService.dispose();

  setState(() {
    calling = false;
    connected = false;
    callStatus = 'Call rejected';
  });

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Call rejected')),
  );
});

AppCallService.onCallEnded(() {
  if (!mounted) return;

  WebRTCService.dispose();

  setState(() {
    calling = false;
    connected = false;
    callStatus = 'Call ended';
  });

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Call ended')),
  );
});
  }

  @override
  void dispose() {
    phoneController.dispose();
    WebRTCService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final toPhone = phoneController.text.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF5FBF7),
      appBar: AppBar(
        title: const Text(
          'Free App Call',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: const Color(0xFFF5FBF7),
        foregroundColor: const Color(0xFF103D24),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 24),

              Container(
                width: double.infinity,
                height: 120,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(18),
                ),
                child: RTCVideoView(
                    WebRTCService.remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                ),
                ),

              Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0A7C3A),
                      Color(0xFF0E8F45),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Icon(
                        connected ? Icons.volume_up : Icons.wifi_calling_3,
                        color: const Color(0xFF0A7C3A),
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Call another CallNaija user free',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      callStatus,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    if (calling && toPhone.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        toPhone,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 28),

              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                enabled: !calling,
                decoration: InputDecoration(
                  hintText: '+447123456789',
                  helperText:
                      'Enter the phone number of another CallNaija user.',
                  helperMaxLines: 2,
                  prefixIcon: const Icon(Icons.person_search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 22),

              if (!calling)
                ElevatedButton.icon(
                  onPressed: startFreeCall,
                  icon: const Icon(Icons.wifi_calling_3),
                  label: const Text('Start Free Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A7C3A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                ),

              if (calling)
                ElevatedButton.icon(
                  onPressed: endCall,
                  icon: const Icon(Icons.call_end),
                  label: const Text('End Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}