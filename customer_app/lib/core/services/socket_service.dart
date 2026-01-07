import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';

import '../../features/auth/presentation/auth_provider.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService(ref);
});

class SocketService {
  IO.Socket? _socket;
  final Ref _ref;
  final Map<String, List<Function(dynamic)>> _pendingListeners = {};
  bool _initialized = false;

  SocketService(this._ref);

  IO.Socket? get socket => _socket; // Nullable safe getter

  void init(String token) {
    if (_socket != null && _socket!.connected) return;

    _socket = IO.io(
      AppConstants.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .build(),
    );

    _initialized = true;

    _socket!.onConnect((_) {
      debugPrint('Socket connected: ${_socket!.id}');
      _socket!.emit('passenger:rejoin', {});
      
      // Register pending listeners
      _pendingListeners.forEach((event, callbacks) {
        for (var callback in callbacks) {
          _socket!.on(event, callback);
        }
      });
    });

    _socket!.on('force_logout', (_) {
      debugPrint('Received force_logout event');
      _ref.read(authProvider.notifier).logout();
    });

    _socket!.onConnectError((data) => debugPrint('Socket connect error: $data'));
    _socket!.onDisconnect((_) => debugPrint('Socket disconnected'));
    
    // Check if we need to register listeners explicitly if they were added after init but before connect?
    // Actually simpler: Just register them immediately if socket exists.
    _pendingListeners.forEach((event, callbacks) {
        for (var callback in callbacks) {
          _socket!.on(event, callback);
        }
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _initialized = false;
  }

  void on(String event, Function(dynamic) callback) {
    // 1. Store in pending/active list
    if (!_pendingListeners.containsKey(event)) {
      _pendingListeners[event] = [];
    }
    // Remove if exists to avoid dups in our list? No, explicit add.
    // Client should call off() to remove.
    _pendingListeners[event]!.add(callback);

    // 2. Register if socket exists
    if (_socket != null) {
      debugPrint('SocketService: Registering listener for $event');
      _socket!.on(event, callback);
    } else {
      debugPrint('SocketService: Queuing listener for $event (socket null)');
    }
  }

  void off(String event) {
    // 1. Remove from pending list
    _pendingListeners.remove(event);

    // 2. Remove from socket
    _socket?.off(event);
  }

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }
  
  bool get isConnected => _socket?.connected ?? false;
}
