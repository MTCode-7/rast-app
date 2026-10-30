import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // خرائط جوجل (خريطة المختبرات واختيار العنوان). المفتاح مقيّد بمعرّف التطبيق من Google Cloud
    GMSServices.provideAPIKey("AIzaSyDe7LQFE6sCn3RVdFOqCsn5aNuFNfUpOVo")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
