import 'package:socket_io_client/socket_io_client.dart' as IO;

class AppCallService {
  static IO.Socket? socket;

  static void connect({
    required String phone,
    required String name,
  }) {
    socket ??= IO.io(
      'https://callnaija-backend.onrender.com',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .build(),
    );

    socket!.connect();

    socket!.onConnect((_) {
      socket!.emit('user-online', {
        'phone': phone,
        'name': name,
      });
    });
  }

  static void callUser({
    required String fromPhone,
    required String fromName,
    required String toPhone,
    required dynamic offer,
  }) {
    socket?.emit('call-user', {
      'fromPhone': fromPhone,
      'fromName': fromName,
      'toPhone': toPhone,
      'offer': offer,
    });
  }

  static void answerCall({
    required String toPhone,
    required dynamic answer,
  }) {
    socket?.emit('answer-call', {
      'toPhone': toPhone,
      'answer': answer,
    });
  }

  static void rejectCall({
    required String toPhone,
  }) {
    socket?.emit('reject-call', {
      'toPhone': toPhone,
    });
  }

  static void sendIceCandidate({
    required String toPhone,
    required dynamic candidate,
  }) {
    socket?.emit('ice-candidate', {
      'toPhone': toPhone,
      'candidate': candidate,
    });
  }

  static void endCall({
    required String toPhone,
  }) {
    socket?.emit('end-call', {
      'toPhone': toPhone,
    });
  }

  static void onIncomingCall(Function(dynamic data) callback) {
    socket?.off('incoming-call');
    socket?.on('incoming-call', callback);
  }

  static void onCallAnswered(Function(dynamic data) callback) {
    socket?.off('call-answered');
    socket?.on('call-answered', callback);
  }

  static void onCallRejected(Function() callback) {
    socket?.off('call-rejected');
    socket?.on('call-rejected', (_) => callback());
  }

  static void onIceCandidate(Function(dynamic data) callback) {
    socket?.off('ice-candidate');
    socket?.on('ice-candidate', callback);
  }

  static void onCallEnded(Function() callback) {
    socket?.off('call-ended');
    socket?.on('call-ended', (_) => callback());
  }
}