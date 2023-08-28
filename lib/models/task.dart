class Task {
  String title;
  DateTime dueDateTime;
  bool isDone;

  Task({required this.title, required this.dueDateTime, this.isDone = false});
}
