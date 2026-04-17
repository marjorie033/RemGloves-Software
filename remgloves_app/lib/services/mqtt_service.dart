import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  static const String _host =
      'b001dac51f84483a87658bad6551b443.s1.eu.hivemq.cloud';
  static const String _username = 'Testing';
  static const String _password = 'Test.123';

  static const String topicStatus = 'esp/relay/status';
  static const String topicControl = 'esp/relay/control';

  MqttClient? _client;

  final _lightStateController = StreamController<bool>.broadcast();
  Stream<bool> get lightStateStream => _lightStateController.stream;

  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  final _errorController = StreamController<String?>.broadcast();
  Stream<String?> get errorStream => _errorController.stream;

  bool _lightOn = false;
  bool get lightOn => _lightOn;

  bool _connected = false;
  bool get isConnected => _connected;

  Future<void> connect() async {
    final clientId =
        'flutter-remglove-${DateTime.now().millisecondsSinceEpoch}';

    final MqttClient client = MqttServerClient.withPort(_host, clientId, 8883)
      ..secure = true
      ..onBadCertificate = (_) => true;

    _client = client;
    client.keepAlivePeriod = 60;
    client.connectTimeoutPeriod = 10000;
    client.logging(on: true);
    client.onDisconnected = _onDisconnected;

    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .withProtocolName('MQTT')
        .withProtocolVersion(4)
        .authenticateAs(_username, _password)
        .startClean();

    try {
      await client
          .connect(_username, _password)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Connection timed out after 15 s'),
          );
    } catch (e) {
      final msg = e.toString();
      print('MQTT connect error: $msg');
      _errorController.add(msg);
      client.disconnect();
      return;
    }

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      _connected = true;
      _errorController.add(null);
      _connectionController.add(true);
      client.subscribe(topicStatus, MqttQos.atLeastOnce);
      client.updates?.listen(_onMessage);
      print('MQTT connected');
    } else {
      final reason =
          'State: ${client.connectionStatus?.state}, '
          'Code: ${client.connectionStatus?.returnCode}';
      print('MQTT connection failed — $reason');
      _errorController.add(reason);
    }
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    final msg = messages[0];
    final payload = msg.payload as MqttPublishMessage;
    final message = MqttPublishPayload.bytesToStringAsString(
      payload.payload.message,
    );

    if (msg.topic == topicStatus) {
      _lightOn = message == 'ON';
      _lightStateController.add(_lightOn);
    }
  }

  void publishControl(String command) {
    final client = _client;
    if (client == null ||
        client.connectionStatus?.state != MqttConnectionState.connected) {
      print('MQTT publish skipped — not connected');
      return;
    }
    final builder = MqttClientPayloadBuilder()..addString(command);
    client.publishMessage(topicControl, MqttQos.atLeastOnce, builder.payload!);
    print('MQTT published: $command → $topicControl');
  }

  void _onDisconnected() {
    _connected = false;
    _connectionController.add(false);
    print('MQTT disconnected');
  }

  void dispose() {
    _lightStateController.close();
    _connectionController.close();
    _errorController.close();
    _client?.disconnect();
  }
}
