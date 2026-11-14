import 'api_client.dart';

class DayJobChatMessage {
  final int id;
  final String message;
  final DateTime? createdAt;
  final bool isMine;

  const DayJobChatMessage({
    required this.id,
    required this.message,
    required this.createdAt,
    required this.isMine,
  });

  factory DayJobChatMessage.fromJson(Map<String, dynamic> json) =>
      DayJobChatMessage(
        id: (json['id'] as num).toInt(),
        message: json['message'] as String? ?? '',
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
        isMine: json['is_mine'] == true,
      );
}

class DayJobChat {
  final int id;
  final int jobId;
  final String category;
  final String counterpartName;
  final String counterpartRole;
  final List<DayJobChatMessage> messages;

  const DayJobChat({
    required this.id,
    required this.jobId,
    required this.category,
    required this.counterpartName,
    required this.counterpartRole,
    required this.messages,
  });

  factory DayJobChat.fromJson(Map<String, dynamic> json) => DayJobChat(
    id: (json['id'] as num).toInt(),
    jobId: (json['job_id'] as num).toInt(),
    category: json['category'] as String? ?? 'Day job',
    counterpartName: json['counterpart_name'] as String? ?? 'User',
    counterpartRole: json['counterpart_role'] as String? ?? 'USER',
    messages: [
      for (final item in json['messages'] as List? ?? const [])
        DayJobChatMessage.fromJson(item as Map<String, dynamic>),
    ],
  );
}

class DayJobChatService {
  DayJobChatService._();

  static Future<int> openChat(int jobId, {int? workerId}) async {
    final data = await ApiClient.post('/api/day-job-chats', {
      'jobId': jobId,
      if (workerId != null) 'workerId': workerId,
    });
    return (data as Map<String, dynamic>)['id'] as int;
  }

  static Future<DayJobChat> getChat(int chatId) async {
    final data = await ApiClient.get('/api/day-job-chats/$chatId');
    return DayJobChat.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> send(int chatId, String message) async {
    await ApiClient.post('/api/day-job-chats/$chatId/messages', {
      'message': message,
    });
  }
}
