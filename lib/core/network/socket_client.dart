import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/api_constants.dart';

class SocketClient {
  io.Socket? _socket;
  String? _accessToken;
  DateTime? _lastActivitySentAt;
  final _presenceController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _readController = StreamController<Map<String, dynamic>>.broadcast();

  io.Socket? get socket => _socket;
  Stream<Map<String, dynamic>> get presenceStream =>
      _presenceController.stream;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get readStream => _readController.stream;

  void connect({required String accessToken}) {
    if (_socket != null && _accessToken == accessToken) {
      return;
    }

    _socket?.dispose();
    _accessToken = accessToken;

    _socket = io.io(
      ApiConstants.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': accessToken})
          .disableAutoConnect()
          .build(),
    );

    _socket!.on('presence:updated', (data) {
      if (data is Map) {
        _presenceController.add(Map<String, dynamic>.from(data));
      }
    });
    _socket!.on('message:created', (data) {
      if (data is Map) {
        _messageController.add(Map<String, dynamic>.from(data));
      }
    });
    _socket!.on('message:read', (data) {
      if (data is Map) {
        _readController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _accessToken = null;
    unawaited(_presenceController.close());
    unawaited(_messageController.close());
    unawaited(_readController.close());
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    _accessToken = null;
  }

  void on(String event, Function(dynamic data) callback) {
    _socket?.on(event, callback);
  }

  void off(String event) {
    _socket?.off(event);
  }

  void emit(String event, [dynamic data]) {
    _socket?.emit(event, data);
  }

  void reportActivity() {
    final now = DateTime.now();
    final last = _lastActivitySentAt;
    if (last != null && now.difference(last) < const Duration(seconds: 20)) {
      return;
    }
    _lastActivitySentAt = now;
    _socket?.emit('presence:activity');
  }
}
