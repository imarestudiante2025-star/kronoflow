import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clasedos/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('La aplicación inicia correctamente', (tester) async {
    _useTallViewport(tester);
    await tester.pumpWidget(const TaskFlowApp());
    await tester.pumpAndSettle();

    expect(find.text('TaskFlow Pro'), findsOneWidget);
    expect(find.text('Tu productividad'), findsOneWidget);
  });

  testWidgets('Crea y persiste una tarea', (tester) async {
    _useTallViewport(tester);
    await tester.pumpWidget(const TaskFlowApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Preparar entrega');
    final agregar = find.widgetWithText(FilledButton, 'Agregar tarea');
    await tester.ensureVisible(agregar);
    await tester.tap(agregar);
    await tester.pumpAndSettle();

    final tarea = find.text('Preparar entrega');
    await tester.ensureVisible(tarea);
    expect(tarea, findsOneWidget);

    final preferences = await SharedPreferences.getInstance();
    final tareas =
        jsonDecode(preferences.getString('taskflow_pro_v1')!) as List;
    expect(tareas, hasLength(1));
    expect(tareas.single['titulo'], 'Preparar entrega');
  });

  testWidgets('Permite editar y eliminar una tarea', (tester) async {
    _useTallViewport(tester);
    await tester.pumpWidget(const TaskFlowApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Tarea inicial');
    final agregar = find.widgetWithText(FilledButton, 'Agregar tarea');
    await tester.ensureVisible(agregar);
    await tester.tap(agregar);
    await tester.pumpAndSettle();

    final editar = find.byTooltip('Editar tarea');
    await tester.ensureVisible(editar);
    await tester.tap(editar);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Tarea actualizada');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    final tarea = find.text('Tarea actualizada');
    await tester.ensureVisible(tarea);
    expect(tarea, findsOneWidget);

    final eliminar = find.byTooltip('Eliminar tarea');
    await tester.ensureVisible(eliminar);
    await tester.tap(eliminar);
    await tester.pumpAndSettle();

    expect(find.text('Tarea actualizada'), findsNothing);
    expect(find.text('Tarea eliminada'), findsOneWidget);
  });
}

void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
