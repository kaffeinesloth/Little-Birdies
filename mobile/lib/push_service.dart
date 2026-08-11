class PushNotificationService {
  static const fcmSenderId = String.fromEnvironment('FCM_SENDER_ID');
  static const fcmProjectId = String.fromEnvironment('FCM_PROJECT_ID');

  bool get isMockMode => fcmSenderId.isEmpty || fcmProjectId.isEmpty;

  Future<String?> getDeviceToken() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (isMockMode) return null;
    // Placeholder for firebase_messaging integration.
    return 'fcm-placeholder-token';
  }
}
