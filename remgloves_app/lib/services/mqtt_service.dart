import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  static const String _host =
      'b001dac51f84483a87658bad6551b443.s1.eu.hivemq.cloud';
  static const int    _port     = 8883;
  static const String _username = 'Testing';
  static const String _password = 'Test.123';

  static const String topicLightStatus  = 'esp/relay/status';
  static const String topicLightControl = 'esp/relay/control';
  static const String topicFanStatus    = 'esp/fan/status';
  static const String topicFanControl   = 'esp/fan/control';

  // Backoff ladder: 2 → 4 → 8 → 16 → 30 s (cap)
  static const List<int> _backoffSeconds = [2, 4, 8, 16, 30];

  MqttServerClient? _client;
  bool _disposed         = false;
  int  _reconnectAttempt = 0;
  // Guards against duplicate reconnect timers being scheduled simultaneously.
  bool _reconnectPending = false;

  final _lightStateController = StreamController<bool>.broadcast();
  Stream<bool> get lightStateStream => _lightStateController.stream;

  final _fanStateController = StreamController<bool>.broadcast();
  Stream<bool> get fanStateStream => _fanStateController.stream;

  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  final _errorController = StreamController<String?>.broadcast();
  Stream<String?> get errorStream => _errorController.stream;

  bool _lightOn = false;
  bool get lightOn => _lightOn;

  bool _fanOn = false;
  bool get fanOn => _fanOn;

  bool _connected = false;
  bool get isConnected => _connected;

  Future<void> connect() async {
    if (_disposed) return;
    // Clear the pending flag — we're now executing the attempt.
    _reconnectPending = false;

    final clientId =
        'flutter-remglove-${DateTime.now().millisecondsSinceEpoch}';

    final client = MqttServerClient.withPort(_host, clientId, _port);
    client.secure              = true;
    // withTrustedRoots: true loads Mozilla's CA bundle (includes DigiCert /
    // Let's Encrypt used by HiveMQ Cloud) so the handshake succeeds.
    client.securityContext     = SecurityContext(withTrustedRoots: true);
    // mqtt_client 10.x types this as ((Object) => bool)? internally.
    // Using X509Certificate here fails the cast; Object is the correct type.
    client.onBadCertificate    = (Object cert) => true;
    client.keepAlivePeriod     = 60;
    client.connectTimeoutPeriod = 15000;
    client.autoReconnect       = false;
    client.logging(on: false);
    client.onDisconnected      = _onDisconnected;

    // Explicit MQTT 3.1.1 so strict brokers (HiveMQ Cloud) don't reject us.
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .withProtocolName('MQTT')
        .withProtocolVersion(4)
        .startClean();

    _client = client;

    debugPrint('MQTT connecting to $_host:$_port as "$_username"...');

    try {
      // 30 s outer timeout — more headroom for mobile-data latency.
      final status = await client
          .connect(_username, _password)
          .timeout(const Duration(seconds: 30));

      if (status?.state == MqttConnectionState.connected) {
        _reconnectAttempt = 0;
        _connected = true;
        _errorController.add(null);
        _connectionController.add(true);
        client.subscribe(topicLightStatus, MqttQos.atLeastOnce);
        client.subscribe(topicFanStatus,   MqttQos.atLeastOnce);
        client.updates?.listen(_onMessage);
        debugPrint('MQTT connected ✓');
      } else {
        final state = status?.state;
        final code  = status?.returnCode;
        debugPrint('MQTT refused — state: $state | code: $code');
        _errorController.add('Refused: $code');
        _failedConnect(client);
      }
    } catch (e, st) {
      debugPrint('MQTT connect error: $e');
      debugPrint('$st');
      _errorController.add(e.toString());
      _failedConnect(client);
    }
  }

  // Called when our own connect() attempt fails (not an unexpected disconnect).
  // Nulls the onDisconnected callback BEFORE disconnecting so that
  // _onDisconnected does NOT fire and double-schedule a reconnect.
  void _failedConnect(MqttServerClient client) {
    client.onDisconnected = null;
    try {
      client.disconnect();
    } catch (_) {}
    _connected = false;
    if (!_connectionController.isClosed) _connectionController.add(false);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectPending) return;
    _reconnectPending = true;
    final delay =
        _backoffSeconds[_reconnectAttempt.clamp(0, _backoffSeconds.length - 1)];
    _reconnectAttempt++;
    debugPrint('MQTT retry #$_reconnectAttempt in ${delay}s...');
    Future.delayed(Duration(seconds: delay), connect);
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    final msg     = messages[0];
    final payload = msg.payload as MqttPublishMessage;
    final message = MqttPublishPayload.bytesToStringAsString(
      payload.payload.message,
    );

    if (msg.topic == topicLightStatus) {
      _lightOn = message == 'ON';
      _lightStateController.add(_lightOn);
    } else if (msg.topic == topicFanStatus) {
      _fanOn = message == 'ON';
      _fanStateController.add(_fanOn);
    }
  }

  void _publish(String topic, String command) {
    final client = _client;
    if (client == null ||
        client.connectionStatus?.state != MqttConnectionState.connected) {
      debugPrint('MQTT publish skipped — not connected');
      return;
    }
    final builder = MqttClientPayloadBuilder()..addString(command);
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    debugPrint('MQTT published: $command → $topic');
  }

  void publishLightControl(String command) =>
      _publish(topicLightControl, command);

  void publishFanControl(String command) =>
      _publish(topicFanControl, command);

  // Only fires for unexpected server-side disconnects (we clear the callback
  // before any intentional disconnect in _failedConnect).
  void _onDisconnected() {
    _connected = false;
    if (!_connectionController.isClosed) _connectionController.add(false);
    debugPrint('MQTT disconnected (unexpected)');
    _scheduleReconnect();
  }

  void dispose() {
    _disposed = true;
    _lightStateController.close();
    _fanStateController.close();
    _connectionController.close();
    _errorController.close();
    _client?.disconnect();
  }
}
