import 'package:flutter/foundation.dart';
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

  String _selectedCategory = 'All';

  // final List<String> _categories = ['All', 'Personal', 'Work', 'Birthday'];

  List<Task> _tasks = [];

  List<Task> _filteredTask() {
    if (_selectedCategory == 'All') {
      return _tasks;
    } else {
      return _tasks
          .where((task) => task.category == _selectedCategory)
          .toList();
    }
  }

  @override
  void initState() {
    super.initState();
    initializeNotifications();
    _loadTask();
    // _selectedCategory.addListener(_handleTabSelection);
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
          category: taskMap['category'],
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
        'category': task.category,
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

  void _addTask(
      String title, DateTime dueDate, TimeOfDay dueTime, String category) {
    final combinedDateTime = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      dueTime.hour,
      dueTime.minute,
    );

    setState(() {
      _tasks.add(Task(
          title: title, dueDateTime: combinedDateTime, category: category));
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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFF6663FA),
          bottom: TabBar(
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(child: Text('All')),
              Tab(child: Text('Personal')),
              Tab(child: Text('Work')),
              // Tab(child: Text('Birthday')),
            ],
            onTap: (index) {
              setState(() {
                _selectedCategory =
                    index == 0 ? 'All' : ['Personal', 'Work'][index - 1];
              });
            },
          ),
          title: const Text('To-Do List'),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 15,
              ),
              // child: DropdownButton<String>(
              //     value: _selectedCategory,
              //     dropdownColor: Colors.black,
              //     onChanged: (newValue) {
              //       setState(() {
              //         _selectedCategory = newValue!;
              //       });
              //     },
              //     items: ['All', 'daily', 'single time']
              //         .map<DropdownMenuItem<String>>((String category) {
              //       return DropdownMenuItem<String>(
              //         value: category,
              //         child: Text(
              //           category,
              //           style: TextStyle(
              //             color: Colors.white,
              //           ),
              //         ),
              //       );
              //     }).toList()),
            ),
            Expanded(
                child: Container(
              padding: const EdgeInsets.only(top: 10),
              child: ListView.builder(
                itemCount: _filteredTask().length,
                itemBuilder: (context, index) {
                  // ignore: unused_local_variable
                  final task = _filteredTask()[index];
                  return Container(
                    width: 200,
                    height: 90,
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 3, horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.black,
                          width: 1,
                        ),
                      ),
                      elevation: 3,
                      color: const Color.fromARGB(255, 255, 255, 255),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ListTile(
                            title: Text(
                              task.title,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 18,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.dueDateTime
                                      .toString()
                                      .replaceAll(':00.000', ''),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  task.category, // Display the category
                                  style: const TextStyle(
                                    color: Colors.blueAccent,
                                  ),
                                ),
                              ],
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
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () {
                                              setState(() {
                                                _tasks.removeAt(index);
                                                _saveTask();
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
                        ],
                      ),
                    ),
                  );
                },
              ),
            ))
          ],
        ),
        floatingActionButton: Container(
          // margin: EdgeInsets.only(top: 500),
          height: 90,
          width: 100,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: ElevatedButton(
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
                      _addTask(
                        result['title'],
                        dateResult,
                        timeResult,
                        result['category'],
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(
                    color: Colors.black,
                    width: 1,
                  ),
                ),
                primary: Color(0xFF6663FA),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Icon(Icons.add_sharp)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
