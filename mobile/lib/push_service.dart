import 'models.dart';

class PushNotificationService {
  static const fcmSenderId = String.fromEnvironment('FCM_SENDER_ID');
  static const fcmProjectId = String.fromEnvironment('FCM_PROJECT_ID');

  bool get isMockMode => fcmSenderId.isEmpty || fcmProjectId.isEmpty;

  Future<String?> getDeviceToken() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (isMockMode) return 'mock-fcm-token';
    // Placeholder for firebase_messaging integration.
    return 'fcm-placeholder-token';
  }

  NotificationItem mockUrgentTicketNotification() {
    return NotificationItem(
      id: 'NTF-MOCK-${DateTime.now().millisecondsSinceEpoch}',
      title: 'Mock urgent ticket',
      body: 'Tap to open Linh Tran refund complaint.',
      createdAt: DateTime.now(),
      isRead: false,
      ticketId: 'TCK-1024',
    );
  }
}
