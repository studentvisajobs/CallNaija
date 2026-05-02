import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  static RTCPeerConnection? _peerConnection;
  static MediaStream? _localStream;

  static final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  static Function(RTCIceCandidate candidate)? onIceCandidate;

  static Future<void> init() async {
    await remoteRenderer.initialize();

    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };

    _peerConnection = await createPeerConnection(config);

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        onIceCandidate?.call(candidate);
      }
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams[0];
      }
    };

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });

    for (final track in _localStream!.getTracks()) {
      _peerConnection!.addTrack(track, _localStream!);
    }
  }

  static Future<RTCSessionDescription> createOffer() async {
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  static Future<RTCSessionDescription> createAnswer() async {
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  static Future<void> setRemoteDescription(
    RTCSessionDescription description,
  ) async {
    await _peerConnection!.setRemoteDescription(description);
  }

  static Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    await _peerConnection!.addCandidate(candidate);
  }

  static void dispose() {
    _peerConnection?.close();
    _peerConnection = null;

    _localStream?.dispose();
    _localStream = null;

    remoteRenderer.srcObject = null;
    onIceCandidate = null;
  }
}