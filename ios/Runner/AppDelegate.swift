import Flutter
import UIKit
import AVFoundation
import NaturalLanguage

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let speechSynthesizer = AVSpeechSynthesizer()
  private var dummyTextView: UITextView?

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

  private var speechChannel: FlutterMethodChannel?
  private var isUsingAccessibilitySpeak = false
  private var audioSessionConfigured = false

  /// Configures the AVAudioSession for speech playback once, lazily.
  ///
  /// Calling setCategory/setActive on EVERY line (the old inline code) made
  /// the audio session deactivate/reactivate between sentences, which on
  /// iOS adds an audible multi-second gap between lines.
  private func ensureAudioSession() {
    guard !audioSessionConfigured else { return }
    audioSessionConfigured = true
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
      try session.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      // Audio session config error ignored
    }
  }

  private func registerNativeSpeech(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "NativeSpeechPlugin") else { return }
    let channel = FlutterMethodChannel(
      name: "epitaka/native_speech",
      binaryMessenger: registrar.messenger()
    )
    self.speechChannel = channel

    // Set up AVSpeechSynthesizer delegate for completion callbacks
    self.speechSynthesizer.delegate = self

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
        // When completion reporting is required (line-by-line reading), use
        // AVSpeechSynthesizer directly — the accessibility "Speak Selection"
        // path is fire-and-forget and cannot signal when speech finishes.
        let needsCompletion = args["needsCompletion"] as? Bool ?? false

        DispatchQueue.main.async {
          if self.speechSynthesizer.isSpeaking {
            self.speechSynthesizer.stopSpeaking(at: .immediate)
          }
          self.stopSystemAccessibilitySpeak()
          self.isUsingAccessibilitySpeak = false

          // 1. Try system Accessibility Spoken Content (invokes system Siri voice like Chrome/Safari)
          if !needsCompletion, self.trySystemAccessibilitySpeak(trimmedText) {
            self.isUsingAccessibilitySpeak = true
            result(true)
            return
          }

          // 2. Fallback to AVSpeechSynthesizer with prioritized Siri/Premium voice
          self.ensureAudioSession()

          let utterance = AVSpeechUtterance(string: trimmedText)
          if let voice = self.findBestVoice(for: language, text: trimmedText) {
            utterance.voice = voice
          }
          self.speechSynthesizer.speak(utterance)
          result(true)
        }
      case "stop":
        DispatchQueue.main.async {
          self.stopSystemAccessibilitySpeak()
          self.isUsingAccessibilitySpeak = false
          if self.speechSynthesizer.isSpeaking {
            self.speechSynthesizer.stopSpeaking(at: .immediate)
          }
          result(true)
        }
      case "isSpeaking":
        if isUsingAccessibilitySpeak {
          // For accessibility speak, we can't easily check if it's still speaking
          // Return false to let Dart handle it via timeout
          result(false)
        } else {
          result(self.speechSynthesizer.isSpeaking)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Triggers the system Accessibility Spoken Content engine (the exact same engine used by
  /// iOS native text selection "Speak" in Safari, Chrome, and Notes) to speak using the system Siri voice.
  private func trySystemAccessibilitySpeak(_ text: String) -> Bool {
    guard let topVC = getTopViewController() else { return false }

    if dummyTextView == nil {
      let tv = UITextView(frame: CGRect(x: -500, y: -500, width: 10, height: 10))
      tv.isAccessibilityElement = true
      tv.alpha = 0.01
      topVC.view.addSubview(tv)
      dummyTextView = tv
    } else if let tv = dummyTextView, tv.superview == nil {
      topVC.view.addSubview(tv)
    }

    guard let tv = dummyTextView else { return false }
    tv.text = text
    tv.selectedRange = NSRange(location: 0, length: (text as NSString).length)

    let speakSelectors = [
      Selector(("_accessibilitySpeak:")),
      Selector(("_accessibilitySpeakSelection:")),
      Selector(("accessibilitySpeakSelection:")),
      Selector(("startSpeaking:"))
    ]

    for sel in speakSelectors {
      if tv.responds(to: sel) {
        tv.perform(sel, with: nil)
        return true
      }
    }

    return false
  }

  private func stopSystemAccessibilitySpeak() {
    guard let tv = dummyTextView else { return }
    let stopSelectors = [
      Selector(("_accessibilityPauseSpeaking:")),
      Selector(("_accessibilityStopSpeaking:")),
      Selector(("stopSpeaking:"))
    ]
    for sel in stopSelectors {
      if tv.responds(to: sel) {
        tv.perform(sel, with: nil)
      }
    }
  }

  /// Finds the highest quality voice (Siri / Premium / Enhanced) matching the language or text content.
  private func findBestVoice(for languageCode: String?, text: String? = nil) -> AVSpeechSynthesisVoice? {
    var targetLang = languageCode
    if (targetLang == nil || targetLang!.isEmpty), let sample = text, !sample.isEmpty {
      let recognizer = NLLanguageRecognizer()
      recognizer.processString(sample)
      if let dominant = recognizer.dominantLanguage?.rawValue {
        targetLang = dominant
      }
    }

    let systemCode = AVSpeechSynthesisVoice.currentLanguageCode()
    let resolvedLang = (targetLang != nil && !targetLang!.isEmpty) ? targetLang! : systemCode
    let targetPrefix = resolvedLang.split(separator: "-").first.map(String.init)?.lowercased() ?? resolvedLang.lowercased()
    let systemPrefix = systemCode.split(separator: "-").first.map(String.init)?.lowercased() ?? "en"

    let allVoices = AVSpeechSynthesisVoice.speechVoices()

    // Filter voices matching the language prefix (e.g. "en" matches "en-US", "en-GB", etc.)
    let matchingVoices = allVoices.filter { voice in
      let vLang = voice.language.lowercased()
      return vLang == resolvedLang.lowercased() ||
             vLang.starts(with: "\(targetPrefix)-") ||
             vLang == targetPrefix
    }

    func voiceScore(_ voice: AVSpeechSynthesisVoice) -> Int {
      var score = 0
      let idLower = voice.identifier.lowercased()
      let nameLower = voice.name.lowercased()

      // 1. Premium voices (iOS 16+ neural / Siri premium voices)
      if #available(iOS 16.0, *) {
        if voice.quality == .premium {
          score += 3000
        }
      }
      if idLower.contains("premium") {
        score += 3000
      }

      // 2. Siri voice detection
      if idLower.contains("siri") || nameLower.contains("siri") {
        score += 2000
      }

      // 3. Enhanced quality
      if voice.quality == .enhanced || idLower.contains("enhanced") {
        score += 1000
      }

      // 4. Dialect matching user system language (e.g. prefer en-US over en-ZA if system is en-US)
      if voice.language.caseInsensitiveCompare(systemCode) == .orderedSame {
        score += 200
      } else if voice.language.caseInsensitiveCompare(resolvedLang) == .orderedSame {
        score += 150
      }

      // 5. Penalize compact / novelty / eloquence
      if idLower.contains("eloquence") || idLower.contains("synthesis.voice") {
        score -= 1000
      }
      if idLower.contains("super-compact") {
        score -= 500
      } else if idLower.contains("compact") || voice.quality == .default {
        score -= 200
      }

      return score
    }

    // Pick matching voice with the highest score
    if let bestVoice = matchingVoices.max(by: { voiceScore($0) < voiceScore($1) }) {
      return bestVoice
    }

    // Fallback: system language voice or target language voice
    if targetPrefix == systemPrefix {
      return AVSpeechSynthesisVoice(language: systemCode) ?? AVSpeechSynthesisVoice(language: resolvedLang)
    }

    return AVSpeechSynthesisVoice(language: resolvedLang)
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

// MARK: - AVSpeechSynthesizerDelegate
extension AppDelegate: AVSpeechSynthesizerDelegate {
  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    DispatchQueue.main.async {
      self.speechChannel?.invokeMethod("onCompletion", arguments: nil)
      self.isUsingAccessibilitySpeak = false
    }
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    DispatchQueue.main.async {
      self.speechChannel?.invokeMethod("onCompletion", arguments: nil)
      self.isUsingAccessibilitySpeak = false
    }
  }
}
