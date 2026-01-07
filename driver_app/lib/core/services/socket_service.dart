import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import '../../features/auth/presentation/auth_provider.dart';

part 'socket_service.g.dart';

@Riverpod(keepAlive: true)
SocketService socketService(Ref ref) {
  return SocketService(const FlutterSecureStorage(), ref);
}

class SocketService {
  late IO.Socket _socket;
  bool _initialized = false;
  final FlutterSecureStorage _storage;
  final Ref _ref;
  
  // Store listeners to re-register on reconnect/re-init
  final Map<String, List<Function(dynamic)>> _activeListeners = {};

  SocketService(this._storage, this._ref);

  Future<void> connect() async {
    // If already connected, do nothing
    if (isSocketConnected) return;

    final token = await _storage.read(key: 'accessToken');
    debugPrint('Socket connecting with token: ${token?.substring(0, 10)}...');
    
    // If socket exists, try to reuse or reconnect
    try {
      if (_initialized) {
        if (_socket.disconnected) {
            _socket.io.options?['extraHeaders'] = {'Authorization': 'Bearer $token'};
            _socket.io.options?['auth'] = {'token': token};
            _socket.connect();
        }
        return;
      }
    } catch (_) {
      // _socket might be uninitialized
    }

    _socket = IO.io(AppConstants.baseUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token})
        .setExtraHeaders({'Authorization': 'Bearer $token'})
        .enableAutoConnect() // Enable auto connect
        .setReconnectionDelay(1000)
        .build());

    _initialized = true;
    _setupListeners();
    
    // Re-register all stored listeners to the new socket instance
    _activeListeners.forEach((event, handlers) {
        for (final handler in handlers) {
            _socket.on(event, handler);
        }
    });
  }
  
  // Initialize with token (synonym for connect but usually called at app start)
  Future<void> init(String token) async {
      await _storage.write(key: 'accessToken', value: token);
      await connect();
  }

  void _setupListeners() {
    _socket.onConnect((_) {
      debugPrint('Socket connected: ${_socket.id}');
      // Re-register listeners just in case socket internal state was wiped (rare but safe)
      _activeListeners.forEach((event, handlers) {
          for (final handler in handlers) {
               // Avoid duplicate registration if socket.io client handles it. 
               // Standard socket.io-client usually keeps listeners, but if we recreated _socket, we need this.
               // Since we recreated _socket in connect(), we are good.
          }
      });
      _socket.emit('driver:rejoin', {});
    });

    _socket.onDisconnect((_) {
      debugPrint('Socket disconnected');
    });

    _socket.onConnectError((data) {
      debugPrint('Socket connection error: $data');
    });

    _socket.on('error', (data) {
      debugPrint('Socket error: $data');
    });

    _socket.on('force_logout', (_) {
      debugPrint('Received force_logout event');
      _ref.read(authProvider.notifier).logout();
    });
  }

  void emitAvailability(bool isAvailable, {double? lat, double? lng, String? vehicleType}) {
    if (isSocketConnected) {
      _emitAvailabilityInternal(isAvailable, lat, lng, vehicleType);
    } else {
      // Wait for connection then emit
      _socket.once('connect', (_) {
        _emitAvailabilityInternal(isAvailable, lat, lng, vehicleType);
      });
      // Ensure we are trying to connect
      connect(); 
    }
  }

  void _emitAvailabilityInternal(bool isAvailable, double? lat, double? lng, String? vehicleType) {
    debugPrint('Emitting availability: $isAvailable');
    if (!isAvailable) {
       debugPrint('Stack trace for availability false: ${StackTrace.current}');
    }
    _socket.emit('driver:set_availability', {
      'available': isAvailable,
      'lat': lat,
      'lng': lng,
      'vehicle_type': vehicleType ?? 'sari',
    });
  }

  void emitLocationUpdate(double lat, double lng, {String? vehicleType}) {
    if (isSocketConnected) {
      _socket.emit('driver:update_location', {
        'lat': lat,
        'lng': lng,
        'vehicle_type': vehicleType ?? 'sari',
      });
    }
  }

  void emitEndRide({required String rideId, required double fareActual}) {
    if (isSocketConnected) {
      _socket.emit('driver:end_ride', {
        'ride_id': rideId,
        'fare_actual': fareActual,
      });
    }
  }

  void emitCancelRide({required String rideId, required String reason}) {
    if (isSocketConnected) {
      _socket.emit('driver:cancel_ride', {
        'ride_id': rideId,
        'reason': reason,
      });
    }
  }


  void emit(String event, [dynamic data]) {
    if (isSocketConnected) {
      _socket.emit(event, data);
    }
  }

  void on(String event, Function(dynamic) handler) {
    // 1. Store in our persistence map
    if (!_activeListeners.containsKey(event)) {
      _activeListeners[event] = [];
    }
    _activeListeners[event]!.add(handler);

    // 2. Register to actual socket if ready
    if (_initialized) {
       _socket.on(event, handler);
    }
  }

  void off(String event, [dynamic handler]) {
    // 1. Remove from persistence map
    if (_activeListeners.containsKey(event)) {
        if (handler != null) {
            _activeListeners[event]!.remove(handler);
        } else {
            _activeListeners.remove(event); // Remove all for this event
        }
    }

    // 2. Remove from actual socket
    if (_initialized) {
      try {
        _socket.off(event, handler);
      } catch (_) {}
    }
  }

  void disconnect() {
    if (isSocketConnected) {
      _socket.disconnect();
    }
  }
  
  IO.Socket get socket => _socket;
  
  bool get isSocketConnected {
    try {
      return _initialized && _socket.connected;
    } catch (_) {
      return false;
    }
  }
}
