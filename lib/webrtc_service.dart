import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  static RTCPeerConnection? _peerConnection;
  static MediaStream? _localStream;
  static MediaStream? _remoteStream;

  static final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  static Function(RTCIceCandidate candidate)? onIceCandidate;
  static Function()? onRemoteStreamReady;

  static final List<RTCIceCandidate> _pendingCandidates = [];

  static Future<void> init() async {
    await remoteRenderer.initialize();

final config = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {
      'urls': 'turn:openrelay.metered.ca:80',
      'username': 'openrelayproject',
      'credential': 'openrelayproject',
    },
    {
      'urls': 'turn:openrelay.metered.ca:443',
      'username': 'openrelayproject',
      'credential': 'openrelayproject',
    },
    {
      'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
      'username': 'openrelayproject',
      'credential': 'openrelayproject',
    },
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
        _remoteStream = event.streams.first;
        remoteRenderer.srcObject = _remoteStream;
        onRemoteStreamReady?.call();
      }
    };

    _peerConnection!.onAddStream = (stream) {
      _remoteStream = stream;
      remoteRenderer.srcObject = _remoteStream;
      onRemoteStreamReady?.call();
    };

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });

    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = true;
      await _peerConnection!.addTrack(track, _localStream!);
    }
  }

  static Future<RTCSessionDescription> createOffer() async {
    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });

    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  static Future<RTCSessionDescription> createAnswer() async {
    final answer = await _peerConnection!.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });

    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  static Future<void> setRemoteDescription(
    RTCSessionDescription description,
  ) async {
    await _peerConnection!.setRemoteDescription(description);

    for (final candidate in _pendingCandidates) {
      await _peerConnection!.addCandidate(candidate);
    }

    _pendingCandidates.clear();
  }

  static Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    final remoteDescription = await _peerConnection?.getRemoteDescription();

    if (remoteDescription == null) {
      _pendingCandidates.add(candidate);
      return;
    }

    await _peerConnection!.addCandidate(candidate);
  }

  static Future<void> enableSpeaker() async {
    await Helper.setSpeakerphoneOn(true);
  }

  static void dispose() {
    _peerConnection?.close();
    _peerConnection = null;

    _localStream?.getTracks().forEach((track) => track.stop());
    _remoteStream?.getTracks().forEach((track) => track.stop());

    _localStream?.dispose();
    _remoteStream?.dispose();

    _localStream = null;
    _remoteStream = null;

    remoteRenderer.srcObject = null;
    onIceCandidate = null;
    onRemoteStreamReady = null;
    _pendingCandidates.clear();
  }
}