class BulletItem {
  final String id;
  final String content;
  final String type;
  bool completed;

  BulletItem({
    required this.id,
    required this.content,
    this.type = 'task',
    this.completed = false,
  });

  Map<String, dynamic> toJson() {
    return {'id': id, 'content': content, 'type': type, 'completed': completed};
  }

  factory BulletItem.fromJson(Map<String, dynamic> json) {
    return BulletItem(
      id: json['id'],
      content: json['content'],
      type: json['type'] ?? 'task',
      completed: json['completed'] ?? false,
    );
  }
}
