import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'todo/todoscreen.dart';

void main() async {
  tz.initializeTimeZones();
  runApp(const MyApp());
}

class Task {
  late final String title;
  late final DateTime dueDateTime;
  bool isDone;

  Task({required this.title, required this.dueDateTime, this.isDone = false});
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const TodoListScreen(),
      theme: ThemeData(scaffoldBackgroundColor: const Color(0xFF353941)),
    );
  }
}
