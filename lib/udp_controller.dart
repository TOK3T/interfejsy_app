import 'dart:convert';
import 'dart:io';

class SensorReadings {
  const SensorReadings({
    this.dayState,
    this.mode,
    this.temperature,
    this.humidity,
    this.soilHumidity,
    this.lightLevel,
    this.waterState,
  });

  final int? dayState;
  final int? mode;
  final double? temperature;
  final double? humidity;
  final int? soilHumidity;
  final int? lightLevel;
  final int? waterState;

  SensorReadings updateFromJson(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Pakiet musi zawierać obiekt JSON.');
    }

    return SensorReadings(
      dayState: _readInt(decoded, 'Day_State') ?? dayState,
      mode: _readInt(decoded, 'Tryb') ?? mode,
      temperature: _readDouble(decoded, 'temperatura') ?? temperature,
      humidity: _readDouble(decoded, 'wilgotnosc') ?? humidity,
      soilHumidity: _readInt(decoded, 'wilgotnosc_gleby') ?? soilHumidity,
      lightLevel: _readInt(decoded, 'poziom_swiatla') ?? lightLevel,
      waterState: _readInt(decoded, 'stan_wody') ?? waterState,
    );
  }

  static int? _readInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _readDouble(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class UdpController {
  static const receivePort = 5005;
  static const controlPort = 5006;

  RawDatagramSocket? _socket;
  InternetAddress? _deviceAddress;
  SensorReadings? _latestReadings;

  void Function(SensorReadings readings)? onReadings;
  void Function(String error)? onError;

  Future<void> connect(String address) async {
    final parsedAddress = InternetAddress.tryParse(address);
    if (parsedAddress == null ||
        parsedAddress.type != InternetAddressType.IPv4) {
      throw const FormatException(
        'Wpisz poprawny adres IPv4, np. 192.168.1.20.',
      );
    }

    await disconnect();
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      receivePort,
      reuseAddress: true,
    );
    _deviceAddress = parsedAddress;
    _latestReadings = null;
    _socket = socket;
    socket.listen(
      _handleSocketEvent,
      onError: (Object error) {
        onError?.call('Błąd odbioru UDP: $error');
      },
    );
  }

  void _handleSocketEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;

    final socket = _socket;
    if (socket == null) return;
    Datagram? datagram;
    while ((datagram = socket.receive()) != null) {
      final packet = datagram!;
      if (packet.address.address != _deviceAddress?.address) continue;
      try {
        final current = _latestReadings ?? const SensorReadings();
        _latestReadings = current.updateFromJson(packet.data);
        onReadings?.call(_latestReadings!);
      } on FormatException catch (error) {
        onError?.call('Nie można odczytać danych JSON: ${error.message}');
      }
    }
  }

  void sendControls({
    required int output1,
    required int output2,
    required int value1,
    required int value2,
  }) {
    final socket = _socket;
    final address = _deviceAddress;
    if (socket == null || address == null) {
      throw StateError('Najpierw połącz się z Raspberry Pi.');
    }

    final message = utf8.encode(
      jsonEncode({
        'stan_1': output1,
        'stan_2': output2,
        'wartosc_1': value1,
        'wartosc_2': value2,
      }),
    );
    final sent = socket.send(message, address, controlPort);
    if (sent != message.length) {
      throw const SocketException('Nie udało się wysłać pełnego pakietu UDP.');
    }
  }

  Future<void> disconnect() async {
    _socket?.close();
    _socket = null;
    _deviceAddress = null;
    _latestReadings = null;
  }
}
