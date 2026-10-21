import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'udp_controller.dart';

void main() {
  runApp(const SensorApp());
}

class SensorApp extends StatelessWidget {
  const SensorApp({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF247A57);
    return MaterialApp(
      title: 'Panel czujników',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: green,
          surface: const Color(0xFFF5F7F4),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7F4),
      ),
      home: const SensorDashboard(),
    );
  }
}

class SensorDashboard extends StatefulWidget {
  const SensorDashboard({super.key});

  @override
  State<SensorDashboard> createState() => _SensorDashboardState();
}

class _SensorDashboardState extends State<SensorDashboard> {
  final _addressController = TextEditingController();
  final _udpController = UdpController();
  final _formKey = GlobalKey<FormState>();
  Timer? _statusTimer;

  SensorReadings _readings = const SensorReadings();
  DateTime? _lastPacketAt;
  String? _connectionError;
  bool _connecting = false;
  bool _connected = false;
  int _output1 = 0;
  int _output2 = 0;
  int _value1 = 0;
  int _value2 = 0;

  @override
  void initState() {
    super.initState();
    _udpController.onReadings = (readings) {
      if (!mounted) return;
      setState(() {
        _readings = readings;
        _lastPacketAt = DateTime.now();
        _connectionError = null;
      });
    };
    _udpController.onError = (error) {
      if (!mounted) return;
      setState(() => _connectionError = error);
    };
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _connected) setState(() {});
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _addressController.dispose();
    unawaited(_udpController.disconnect());
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _connecting = true;
      _connectionError = null;
    });

    try {
      await _udpController.connect(_addressController.text.trim());
      if (!mounted) return;
      setState(() {
        _connected = true;
        _readings = const SensorReadings();
        _lastPacketAt = null;
      });
      _sendControls();
    } on FormatException catch (error) {
      _setConnectionError(error.message);
    } on SocketException catch (error) {
      _setConnectionError(error.message);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _disconnect() async {
    await _udpController.disconnect();
    if (!mounted) return;
    setState(() {
      _connected = false;
      _lastPacketAt = null;
      _readings = const SensorReadings();
      _connectionError = null;
    });
  }

  void _sendControls() {
    if (!_connected) return;
    try {
      _udpController.sendControls(
        output1: _output1,
        output2: _output2,
        value1: _value1,
        value2: _value2,
      );
    } on StateError catch (error) {
      _reportConnectionError(error.message);
    } on SocketException catch (error) {
      _reportConnectionError(error.message);
    }
  }

  void _setConnectionError(String message) {
    if (!mounted) return;
    setState(() {
      _connected = false;
      _connectionError = message;
    });
  }

  void _reportConnectionError(String message) {
    if (!mounted) return;
    setState(() => _connectionError = message);
  }

  String get _connectionStatus {
    if (!_connected) return 'Niepołączono';
    if (_lastPacketAt == null) return 'Oczekiwanie na dane z Raspberry Pi';
    final seconds = DateTime.now().difference(_lastPacketAt!).inSeconds;
    if (seconds > 3) return 'Brak aktualizacji od ${seconds}s';
    return 'Połączono · aktualizacja ${seconds}s temu';
  }

  Color get _connectionColor {
    if (!_connected) return Colors.grey;
    if (_lastPacketAt == null ||
        DateTime.now().difference(_lastPacketAt!).inSeconds > 3) {
      return Colors.orange.shade800;
    }
    return Colors.green.shade700;
  }

  String _formatNumber(num? value, {int decimals = 0}) {
    if (value == null) return '---';
    return decimals == 0
        ? value.round().toString()
        : value.toStringAsFixed(decimals);
  }

  String _dayLabel(int? state) {
    if (state == null) return '---';
    return state == 1 ? 'Dzień' : 'Noc';
  }

  String _modeLabel(int? mode) {
    if (mode == null) return '---';
    return switch (mode) {
      0 => 'Brak',
      1 => 'Słonecznie',
      2 => 'Zachmurzenie',
      _ => 'Sucho',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel czujników'), centerTitle: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConnectionCard(),
              const SizedBox(height: 22),
              _SectionTitle(
                title: 'Odczyty z Pico WH',
                subtitle: 'Dane otrzymywane z Raspberry Pi',
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.55,
                children: [
                  _ReadingCard(
                    icon: Icons.thermostat,
                    title: 'Temperatura',
                    value: _formatNumber(_readings.temperature, decimals: 1),
                    unit: '°C',
                  ),
                  _ReadingCard(
                    icon: Icons.water_drop_outlined,
                    title: 'Wilgotność powietrza',
                    value: _formatNumber(_readings.humidity, decimals: 1),
                    unit: '%',
                  ),
                  _ReadingCard(
                    icon: Icons.grass,
                    title: 'Wilgotność gleby',
                    value: _formatNumber(_readings.soilHumidity),
                    unit: '%',
                  ),
                  _ReadingCard(
                    icon: Icons.wb_sunny_outlined,
                    title: 'Poziom światła',
                    value: _formatNumber(_readings.lightLevel),
                    unit: '',
                  ),
                  _ReadingCard(
                    icon: Icons.water,
                    title: 'Stan wody',
                    value: _formatNumber(_readings.waterState),
                    unit: '',
                  ),
                  _ReadingCard(
                    icon: Icons.light_mode_outlined,
                    title: 'Stan dnia',
                    value: _dayLabel(_readings.dayState),
                    unit: '',
                  ),
                  _ReadingCard(
                    icon: Icons.auto_awesome,
                    title: 'Tryb LED',
                    value: _modeLabel(_readings.mode),
                    unit: '',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _SectionTitle(
                title: 'Sterowanie Pico WH',
                subtitle: 'Zmiany są wysyłane po połączeniu z Raspberry Pi',
              ),
              const SizedBox(height: 12),
              _buildControlsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 12, color: _connectionColor),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _connectionStatus,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (_connected)
                  TextButton(
                    onPressed: _connecting ? null : _disconnect,
                    child: const Text('Rozłącz'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _addressController,
                enabled: !_connecting,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Adres IPv4 Raspberry Pi',
                  hintText: 'np. 192.168.1.20',
                  prefixIcon: Icon(Icons.router_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final address = value?.trim() ?? '';
                  final parts = address.split('.');
                  if (parts.length != 4 ||
                      parts.any(
                        (part) =>
                            part.isEmpty ||
                            int.tryParse(part) == null ||
                            int.parse(part) > 255 ||
                            int.parse(part) < 0,
                      )) {
                    return 'Wpisz poprawny adres IPv4.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _connect(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _connecting ? null : _connect,
                icon: _connecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi),
                label: Text(_connected ? 'Połącz z innym adresem' : 'Połącz'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Odbiór UDP: port ${UdpController.receivePort} · '
              'sterowanie: port ${UdpController.controlPort}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_connectionError != null) ...[
              const SizedBox(height: 8),
              Text(
                _connectionError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControlsCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Wyjście 1'),
              subtitle: Text(_output1 == 1 ? 'Włączone' : 'Wyłączone'),
              value: _output1 == 1,
              onChanged: (value) {
                setState(() => _output1 = value ? 1 : 0);
                _sendControls();
              },
            ),
            const Divider(height: 1),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Wyjście 2'),
              subtitle: Text(_output2 == 1 ? 'Włączone' : 'Wyłączone'),
              value: _output2 == 1,
              onChanged: (value) {
                setState(() => _output2 = value ? 1 : 0);
                _sendControls();
              },
            ),
            const SizedBox(height: 12),
            _buildSlider(
              title: 'Suwak 1',
              value: _value1,
              onChanged: (value) {
                setState(() => _value1 = value.round());
                _sendControls();
              },
            ),
            _buildSlider(
              title: 'Suwak 2',
              value: _value2,
              onChanged: (value) {
                setState(() => _value2 = value.round());
                _sendControls();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String title,
    required int value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title)),
            Text('$value / 255'),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 255,
          divisions: 255,
          label: value.toString(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final String title;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(unit, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
