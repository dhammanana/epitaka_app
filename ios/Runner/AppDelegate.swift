import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerNativeLookup(with: engineBridge.pluginRegistry)
  }

  private func registerNativeLookup(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "NativeLookupPlugin") else { return }
    let channel = FlutterMethodChannel(
      name: "epitaka/native_lookup",
      binaryMessenger: registrar.messenger()
    )

    channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "isSupported":
        result(true)
      case "lookUp":
        guard let args = call.arguments as? [String: Any],
              let text = args["text"] as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
          result(FlutterError(code: "INVALID_ARGS", message: "text is required", details: nil))
          return
        }

        DispatchQueue.main.async {
          let term = text.trimmingCharacters(in: .whitespacesAndNewlines)
          guard let topVC = self.getTopViewController() else {
            result(false)
            return
          }

          let refVC = UIReferenceLibraryViewController(term: term)
          topVC.present(refVC, animated: true) {
            result(true)
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func getTopViewController(base: UIViewController? = nil) -> UIViewController? {
    let root: UIViewController?
    if let base = base {
      root = base
    } else {
      if #available(iOS 13.0, *) {
        let scenes = UIApplication.shared.connectedScenes
          .compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        let window = activeScene?.windows.first { $0.isKeyWindow } ?? activeScene?.windows.first
        root = window?.rootViewController
      } else {
        root = UIApplication.shared.keyWindow?.rootViewController
      }
    }

    if let nav = root as? UINavigationController {
      return getTopViewController(base: nav.visibleViewController)
    }
    if let tab = root as? UITabBarController {
      return getTopViewController(base: tab.selectedViewController)
    }
    if let presented = root?.presentedViewController {
      return getTopViewController(base: presented)
    }
    return root
  }
}
