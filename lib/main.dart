import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() async {
  tz.initializeTimeZones();
  runApp(MyApp());
}

class Task {
  late final String title;
  late final DateTime dueDateTime;
  bool isDone;

  Task({required this.title, required this.dueDateTime, this.isDone = false});
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TodoListScreen(),
      theme: new ThemeData(scaffoldBackgroundColor: Color(0xFF353941)),
    );
  }
}

class TodoListScreen extends StatefulWidget {
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
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _scheduleDueDateNotification(Task task) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'due_date_notification_channel',
      'Due Date Notifications',
      channelShowBadge: true,
      importance: Importance.high,
      priority: Priority.high,
    );

    final NotificationDetails platformChannelSpecifics =
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

    if (editedTask != null) {
      setState(() {
        _tasks[index].title = editedTask['title'];
        _tasks[index].dueDateTime = editedTask['dueDate'];
        _tasks[index].isDone = !_tasks[index].isDone;
      });
    }
    _saveTask();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('To-Do List'),
        backgroundColor: Color(0xFF6663FA),
        elevation: 0,
      ),
      body: Container(
        padding: EdgeInsets.only(top: 10),
        child: ListView.builder(
          itemCount: _tasks.length,
          itemBuilder: (context, index) {
            return Card(
              margin: EdgeInsets.symmetric(vertical: 3, horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              color: Color.fromARGB(255, 255, 255, 255),
              child: ListTile(
                title: Text(
                  _tasks[index].title,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                  ),
                ),
                subtitle: Text(
                  '${_tasks[index].dueDateTime.toString()}',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon:
                          Icon(Icons.edit, size: 20, color: Color(0xFF6663FA)),
                      onPressed: () => _toggleTask(index),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Delete Task'),
                            content: Text(
                                'Are you sure you want to delete this task?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() async {
                                    _tasks.removeAt(index);
                                    await _prefs.remove('counter');
                                  });
                                  Navigator.pop(context);
                                },
                                child: Text('Delete'),
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
        child: Icon(Icons.add),
      ),
    );
  }
}

class EditTaskDialog extends StatefulWidget {
  final String initialTitle;
  final DateTime initialDueDate;

  EditTaskDialog({required this.initialTitle, required this.initialDueDate});

  @override
  _EditTaskDialogState createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<EditTaskDialog> {
  // ... rest of the code for the edit dialog
  late TextEditingController _textController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialTitle);
    _selectedDate = widget.initialDueDate;
    _selectedTime = TimeOfDay.fromDateTime(widget.initialDueDate);
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Task'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _textController,
            decoration: InputDecoration(labelText: 'Task Name'),
          ),
          SizedBox(height: 10),
          InkWell(
            onTap: () => _selectDate(context),
            child: Row(
              children: [
                Icon(Icons.calendar_today),
                SizedBox(width: 10),
                Text(
                  'Due Date: ${_selectedDate.toLocal()}'.split(' ')[0],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 10,
          ),
          InkWell(
            onTap: () => _selectTime(context),
            child: Row(
              children: [
                Icon(Icons.access_time),
                SizedBox(width: 10),
                Text('Due Time: ${_selectedTime.format(context)}')
              ],
            ),
          )
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_textController.text.isNotEmpty) {
              Navigator.pop(context, {
                'title': _textController.text,
                'dueDate': _selectedDate,
              });
            }
          },
          child: Text('Save'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}

class AddTaskDialog extends StatefulWidget {
  @override
  _AddTaskDialogState createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _textController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedTime = TimeOfDay.now();
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add a Task'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _textController,
            decoration: InputDecoration(labelText: 'Task Name'),
          ),
          SizedBox(height: 10),
          InkWell(
            onTap: () => _selectDate(context),
            child: Row(
              children: [
                Icon(Icons.calendar_today),
                SizedBox(width: 10),
                Text(
                  'Due Date: ${_selectedDate.toLocal()}'.split(' ')[0],
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          InkWell(
            onTap: () => _selectTime(context),
            child: Row(
              children: [
                Icon(Icons.access_time),
                SizedBox(width: 10),
                Text(
                  'Due Time: ${_selectedTime.format(context)}',
                )
              ],
            ),
          )
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_textController.text.isNotEmpty) {
              Navigator.pop(context, {
                'title': _textController.text,
                'dueDate': _selectedDate,
              });
            }
          },
          child: Text('Add'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
