import Flutter
import UIKit
import AVFoundation
import NaturalLanguage

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let speechSynthesizer = AVSpeechSynthesizer()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerNativeLookup(with: engineBridge.pluginRegistry)
    registerNativeSpeech(with: engineBridge.pluginRegistry)
  }

  private func registerNativeSpeech(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "NativeSpeechPlugin") else { return }
    let channel = FlutterMethodChannel(
      name: "epitaka/native_speech",
      binaryMessenger: registrar.messenger()
    )

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else {
        result(false)
        return
      }

      switch call.method {
      case "isSupported":
        result(true)
      case "speak":
        guard let args = call.arguments as? [String: Any],
              let text = args["text"] as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
          result(FlutterError(code: "INVALID_ARGS", message: "text is required", details: nil))
          return
        }

        let language = args["language"] as? String
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        DispatchQueue.main.async {
          if self.speechSynthesizer.isSpeaking {
            self.speechSynthesizer.stopSpeaking(at: .immediate)
          }

          do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
          } catch {
            // Audio session config error ignored
          }

          let utterance = AVSpeechUtterance(string: trimmedText)
          if let voice = self.findBestVoice(for: language, text: trimmedText) {
            utterance.voice = voice
          }
          self.speechSynthesizer.speak(utterance)
          result(true)
        }
      case "stop":
        DispatchQueue.main.async {
          if self.speechSynthesizer.isSpeaking {
            self.speechSynthesizer.stopSpeaking(at: .immediate)
          }
          result(true)
        }
      case "isSpeaking":
        result(self.speechSynthesizer.isSpeaking)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Finds the highest quality voice (Siri / Premium / Enhanced) matching the language or text content.
  /// Returns nil when the text matches the system language and no separate premium voice override
  /// is needed, allowing AVFoundation to use the user's default Siri System Voice.
  private func findBestVoice(for languageCode: String?, text: String? = nil) -> AVSpeechSynthesisVoice? {
    var targetLang = languageCode
    if (targetLang == nil || targetLang!.isEmpty), let sample = text, !sample.isEmpty {
      let recognizer = NLLanguageRecognizer()
      recognizer.processString(sample)
      if let dominant = recognizer.dominantLanguage?.rawValue {
        targetLang = dominant
      }
    }

    let currentSystemCode = AVSpeechSynthesisVoice.currentLanguageCode()
    let systemPrefix = currentSystemCode.split(separator: "-").first.map(String.init)?.lowercased() ?? "en"

    guard let resolvedLang = targetLang, !resolvedLang.isEmpty else {
      return nil // Use system default Siri voice
    }

    let langPrefix = resolvedLang.split(separator: "-").first.map(String.init)?.lowercased() ?? resolvedLang.lowercased()

    let allVoices = AVSpeechSynthesisVoice.speechVoices()
    let matchingVoices = allVoices.filter { voice in
      let vLang = voice.language.lowercased()
      return vLang == resolvedLang.lowercased() ||
             vLang.starts(with: "\(langPrefix)-") ||
             vLang == langPrefix
    }

    if matchingVoices.isEmpty {
      return langPrefix == systemPrefix ? nil : AVSpeechSynthesisVoice(language: resolvedLang)
    }

    // 1. Premium voices (iOS 16+ neural / Siri voices)
    if #available(iOS 16.0, *) {
      if let exactPremium = matchingVoices.first(where: { $0.quality == .premium && $0.language.caseInsensitiveCompare(resolvedLang) == .orderedSame }) {
        return exactPremium
      }
      if let anyPremium = matchingVoices.first(where: { $0.quality == .premium }) {
        return anyPremium
      }
    }

    // 2. Siri voice identifiers (e.g. com.apple.speech.siri... or com.apple.ttsbundle.siri...)
    if let exactSiri = matchingVoices.first(where: { $0.identifier.lowercased().contains("siri") && $0.language.caseInsensitiveCompare(resolvedLang) == .orderedSame }) {
      return exactSiri
    }
    if let anySiri = matchingVoices.first(where: { $0.identifier.lowercased().contains("siri") }) {
      return anySiri
    }

    // 3. Enhanced quality voices
    if let exactEnhanced = matchingVoices.first(where: { $0.quality == .enhanced && $0.language.caseInsensitiveCompare(resolvedLang) == .orderedSame }) {
      return exactEnhanced
    }
    if let anyEnhanced = matchingVoices.first(where: { $0.quality == .enhanced }) {
      return anyEnhanced
    }

    // If the text is in the system language and no premium/enhanced voice was in the list,
    // return nil so the system default Siri voice is used instead of a legacy compact/eloquence voice.
    if langPrefix == systemPrefix {
      return nil
    }

    // For other languages, avoid eloquence/novelty voices
    return matchingVoices.first(where: {
      let id = $0.identifier.lowercased()
      return !id.contains("eloquence") && !id.contains("synthesis.voice")
    }) ?? matchingVoices.first
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
