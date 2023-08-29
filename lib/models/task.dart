class Task {
  String title;
  DateTime dueDateTime;
  String category;
  bool isDone;

  Task(
      {required this.title,
      required this.dueDateTime,
      this.category = 'single time',
      this.isDone = false});
}
