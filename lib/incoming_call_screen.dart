import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'app_call_service.dart';
import 'webrtc_service.dart';

class IncomingCallScreen extends StatefulWidget {
  final String fromPhone;
  final String fromName;
  final dynamic offer;

  const IncomingCallScreen({
    super.key,
    required this.fromPhone,
    required this.fromName,
    this.offer,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  bool accepting = false;

  Future<void> acceptCall() async {
    try {
      setState(() => accepting = true);

      await WebRTCService.init();

      WebRTCService.onIceCandidate = (candidate) {
        AppCallService.sendIceCandidate(
          toPhone: widget.fromPhone,
          candidate: candidate.toMap(),
        );
      };

      final offer = RTCSessionDescription(
        widget.offer['sdp'],
        widget.offer['type'],
      );

      await WebRTCService.setRemoteDescription(offer);

      final answer = await WebRTCService.createAnswer();

      AppCallService.answerCall(
        toPhone: widget.fromPhone,
        answer: answer.toMap(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Call connected')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not accept call: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => accepting = false);
      }
    }
  }

  void rejectCall() {
    AppCallService.rejectCall(toPhone: widget.fromPhone);
    WebRTCService.dispose();
    Navigator.pop(context);
  }

  void endCall() {
    AppCallService.endCall(toPhone: widget.fromPhone);
    WebRTCService.dispose();
    Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();

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

    AppCallService.onCallEnded(() {
      if (!mounted) return;

      WebRTCService.dispose();
      Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    WebRTCService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A7C3A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.call, size: 80, color: Colors.white),
              const SizedBox(height: 20),
              Text(
                widget.fromName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.fromPhone,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 40),
              if (!accepting)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FloatingActionButton(
                      backgroundColor: Colors.red,
                      onPressed: rejectCall,
                      child: const Icon(Icons.call_end),
                    ),
                    FloatingActionButton(
                      backgroundColor: Colors.green,
                      onPressed: acceptCall,
                      child: const Icon(Icons.call),
                    ),
                  ],
                ),
              if (accepting)
                const CircularProgressIndicator(
                  color: Colors.white,
                ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: endCall,
                icon: const Icon(Icons.call_end),
                label: const Text('End Call'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}