import UIKit
import Flutter
import GoogleMaps
import Firebase
import FirebaseAuth
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    GMSServices.provideAPIKey("AIzaSyAo0EDk5sxDGBm7IXHDyEnNLVHIQtwsaRk")
    GeneratedPluginRegistrant.register(with: self)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    application.registerForRemoteNotifications()
    Messaging.messaging().delegate = self
    if(!UserDefaults.standard.bool(forKey: "Notification")) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UserDefaults.standard.set(true, forKey: "Notification")
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

    override func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
          let firebaseAuth = Auth.auth()
            Messaging.messaging().appDidReceiveMessage(userInfo)
            print(userInfo)
          if (firebaseAuth.canHandleNotification(userInfo)){
              completionHandler(.noData)
              return
          }
      }

        override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
          Messaging.messaging().apnsToken = deviceToken
          super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
        }

        func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
          print("FCM registration token: \(fcmToken ?? \"nil\")")
        }

}
