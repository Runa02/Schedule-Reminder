import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/task.dart';
import 'edittaskdialog.dart';
import 'addtaskdialog.dart';

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  _TodoListScreenState createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  late SharedPreferences _prefs;

  List<Task> _tasks = [];

  @override
  void initState() {
    super.initState();
    initializeNotifications();
    _loadTask();
  }

  Future<void> _loadTask() async {
    _prefs = await SharedPreferences.getInstance();
    List<String> taskStrings = _prefs.getStringList('tasks') ?? [];

    setState(() {
      _tasks = taskStrings.map((taskString) {
        Map<String, dynamic> taskMap = jsonDecode(taskString);
        return Task(
          title: taskMap['title'],
          dueDateTime: DateTime.parse(taskMap['dueDateTime']),
          isDone: taskMap['isDone'],
        );
      }).toList();
    });
  }

  Future<void> _saveTask() async {
    List<String> taskStrings = _tasks.map((task) {
      Map<String, dynamic> taskMap = {
        'title': task.title,
        'dueDateTime': task.dueDateTime.toIso8601String(),
        'isDone': task.isDone,
      };
      return jsonEncode(taskMap);
    }).toList();

    await _prefs.setStringList('tasks', taskStrings);
  }

  Future<void> initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _scheduleDueDateNotification(Task task) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'due_date_notification_channel',
      'Due Date Notifications',
      channelShowBadge: true,
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    final dueDateTime = tz.TZDateTime.from(task.dueDateTime, tz.local);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      task.hashCode,
      'Task Due',
      'Task: ${task.title} is due!',
      dueDateTime,
      platformChannelSpecifics,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  void _addTask(String title, DateTime dueDate, TimeOfDay dueTime) {
    final combinedDateTime = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      dueTime.hour,
      dueTime.minute,
    );

    setState(() {
      _tasks.add(Task(title: title, dueDateTime: combinedDateTime));
    });

    _scheduleDueDateNotification(_tasks.last);
    _saveTask();
  }

  Future<void> _toggleTask(int index) async {
    final editedTask = await showDialog(
      context: context,
      builder: (context) => EditTaskDialog(
        initialTitle: _tasks[index].title,
        initialDueDate: _tasks[index].dueDateTime,
      ),
    );
    final combinedDateTime = DateTime(
      editedTask["dueDate"].year,
      editedTask["dueDate"].month,
      editedTask["dueDate"].day,
      editedTask["dueTime"].hour,
      editedTask["dueTime"].minute,
    );

    if (editedTask != null) {
      setState(() {
        _tasks[index].title = editedTask['title'];
        _tasks[index].dueDateTime = combinedDateTime;
      });

      _scheduleDueDateNotification(_tasks[index]);
      // Save the updated tasks to SharedPreferences
      _saveTask();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('To-Do List'),
        backgroundColor: const Color(0xFF6663FA),
        elevation: 0,
      ),
      body: Container(
        padding: const EdgeInsets.only(top: 10),
        child: ListView.builder(
          itemCount: _tasks.length,
          itemBuilder: (context, index) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              color: const Color.fromARGB(255, 255, 255, 255),
              child: ListTile(
                title: Text(
                  _tasks[index].title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                  ),
                ),
                subtitle: Text(
                  _tasks[index]
                      .dueDateTime
                      .toString()
                      .replaceAll(':00.000', ''),
                  style: const TextStyle(
                    color: Colors.grey,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit,
                          size: 20, color: Color(0xFF6663FA)),
                      onPressed: () => _toggleTask(index),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Task'),
                            content: const Text(
                                'Are you sure you want to delete this task?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _tasks.removeAt(index);
                                    _prefs.remove('counter');
                                  });
                                  Navigator.pop(context);
                                },
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await showDialog(
            context: context,
            builder: (context) => AddTaskDialog(),
          );
          if (result != null) {
            final dateResult = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime(2101),
            );

            if (dateResult != null) {
              final timeResult = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );

              if (timeResult != null) {
                _addTask(result['title'], dateResult, timeResult);
              }
            }
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
