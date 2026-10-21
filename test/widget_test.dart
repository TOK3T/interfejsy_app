import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interfejsy_app/main.dart';
import 'package:interfejsy_app/udp_controller.dart';

void main() {
  test('sensor readings decode the Python app JSON keys', () {
    final readings = const SensorReadings().updateFromJson(
      utf8.encode(
        '{"Day_State":1,"Tryb":2,"temperatura":21.5,"wilgotnosc":48.2,'
        '"wilgotnosc_gleby":45,"poziom_swiatla":750,"stan_wody":1}',
      ),
    );

    expect(readings.dayState, 1);
    expect(readings.mode, 2);
    expect(readings.temperature, 21.5);
    expect(readings.humidity, 48.2);
    expect(readings.soilHumidity, 45);
    expect(readings.lightLevel, 750);
    expect(readings.waterState, 1);
  });

  test('partial readings preserve values from the previous packet', () {
    final initial = const SensorReadings().updateFromJson(
      utf8.encode('{"temperatura":21.5,"Day_State":1}'),
    );
    final updated = initial.updateFromJson(utf8.encode('{"temperatura":22.0}'));

    expect(updated.temperature, 22.0);
    expect(updated.dayState, 1);
  });

  testWidgets('dashboard shows connection, sensor and control sections', (
    tester,
  ) async {
    await tester.pumpWidget(const SensorApp());

    expect(find.text('Panel czujników'), findsOneWidget);
    expect(find.text('Adres IPv4 Raspberry Pi'), findsOneWidget);
    expect(find.text('Odczyty z Pico WH'), findsOneWidget);
    expect(find.text('Sterowanie Pico WH'), findsOneWidget);
    expect(find.text('Wyjście 1'), findsOneWidget);
    expect(find.text('Suwak 1'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
