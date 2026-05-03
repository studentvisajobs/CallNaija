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
    required this.offer,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  bool connecting = false;
  bool connected = false;

  Future<void> acceptCall() async {
    try {
      setState(() => connecting = true);

      await WebRTCService.init();

      WebRTCService.onRemoteStreamReady = () async {
        await WebRTCService.enableSpeaker();

        if (!mounted) return;

        setState(() {
          connected = true;
          connecting = false;
        });
      };

      WebRTCService.onIceCandidate = (candidate) {
        AppCallService.sendIceCandidate(
          toPhone: widget.fromPhone,
          candidate: candidate.toMap(),
        );
      };

      final offerData = widget.offer ?? AppCallService.latestOffer;

      if (offerData == null) {
        throw Exception('No WebRTC offer received');
      }

      final offer = RTCSessionDescription(
        offerData['sdp'],
        offerData['type'],
      );

      await WebRTCService.setRemoteDescription(offer);

      final answer = await WebRTCService.createAnswer();

      AppCallService.answerCall(
        toPhone: widget.fromPhone,
        answer: answer.toMap(),
      );

      if (!mounted) return;

      setState(() {
        connecting = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        connecting = false;
        connected = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept call: $e')),
      );
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
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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

                Icon(
                  connected ? Icons.volume_up : Icons.call,
                  color: Colors.white,
                  size: 80,
                ),

                const SizedBox(height: 20),

                Text(
                  widget.fromName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  widget.fromPhone,
                  style: const TextStyle(color: Colors.white70),
                ),

                const SizedBox(height: 12),

                Text(
                  connected
                      ? 'Connected — audio active'
                      : connecting
                          ? 'Connecting audio...'
                          : 'Incoming free call',
                  style: const TextStyle(color: Colors.white70),
                ),

                const SizedBox(height: 40),

                if (!connecting && !connected)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FloatingActionButton(
                        backgroundColor: Colors.red,
                        onPressed: rejectCall,
                        child: const Icon(Icons.call_end),
                      ),
                      const SizedBox(width: 40),
                      FloatingActionButton(
                        backgroundColor: Colors.green,
                        onPressed: acceptCall,
                        child: const Icon(Icons.call),
                      ),
                    ],
                  ),

                if (connecting)
                  const CircularProgressIndicator(color: Colors.white),

                if (connected)
                  FloatingActionButton(
                    backgroundColor: Colors.red,
                    onPressed: endCall,
                    child: const Icon(Icons.call_end),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}