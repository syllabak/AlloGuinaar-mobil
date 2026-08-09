// Routeur plateforme :
//   Web (Chrome)    → notification_service_stub.dart  (no-op)
//   Android / iOS   → notification_service_mobile.dart (réel)
export 'notification_service_mobile.dart'
    if (dart.library.html) 'notification_service_stub.dart';