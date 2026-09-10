import Cocoa
import FlutterMacOS
import AppKit

/// REGRESSION GUARD — macOS speech MUST stay on NSSpeechSynthesizer.
///
/// Probed 2026-09: `AVSpeechSynthesisVoice.speechVoices()` exposes only
/// `siri_*_compact` voices — the neural "Siri Voice 1..5" family users
/// pick in System Settings → Accessibility → Spoken Content is invisible
/// to AVSpeech (and to the app's voice list). Switching macOS to
/// AVSpeech therefore sounded like a robot even with perfect scoring.
/// NSSpeechSynthesizer with no explicit voice follows the system default
/// voice — the user's Siri voice. Do NOT switch back to AVSpeech here.
/// Completion is reported via delegate + watchdog (see below), and voice
/// ranking lives in `AppleTtsVoicePolicy` on the Dart side
/// (test/apple_tts_voice_policy_test.dart).
class MainFlutterWindow: NSWindow {
  private let speechSynthesizer = NSSpeechSynthesizer()
  private var speechChannel: FlutterMethodChannel?
  private var utteranceGen = 0
  private var completionWatchdog: Timer?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerNativeLookup(with: flutterViewController)
    registerNativeSpeech(with: flutterViewController)

    self.speechSynthesizer.delegate = self

    super.awakeFromNib()
  }

  /// The user's chosen System Voice (System Settings → Accessibility →
  /// Spoken Content), used to flag it in `listVoices` so the Dart scorer
  /// (`AppleTtsVoicePolicy`) prefers it with premium-class weight.
  /// (NSSpeechSynthesizer is deprecated but remains the only API exposing
  /// the system default; used read-only here.)
  private static func systemDefaultVoiceName() -> String? {
    let attrs = NSSpeechSynthesizer.attributes(
      forVoice: NSSpeechSynthesizer.defaultVoice)
    guard let name = attrs[.name] as? String, !name.isEmpty else {
      return nil
    }
    return name
  }

  /// Starts tracking a new utterance; invalidates any previous watchdog.
  private func beginUtterance() -> Int {
    utteranceGen += 1
    completionWatchdog?.invalidate()
    completionWatchdog = nil
    return utteranceGen
  }

  /// Reports speech completion to Dart exactly once per utterance.
  private func completeUtterance(_ gen: Int) {
    guard gen == utteranceGen else { return }
    utteranceGen += 1
    completionWatchdog?.invalidate()
    completionWatchdog = nil
    speechChannel?.invokeMethod("onCompletion", arguments: nil)
  }

  /// Backup completion: if the delegate callback is ever not delivered,
  /// finish the utterance shortly after the engine goes quiet instead of
  /// leaving Dart waiting for the full per-line timeout.
  private func armCompletionWatchdog(_ gen: Int) {
    var quietCount = 0
    completionWatchdog = Timer.scheduledTimer(
      withTimeInterval: 0.3,
      repeats: true
    ) { [weak self] timer in
      guard let self = self else {
        timer.invalidate()
        return
      }
      guard gen == self.utteranceGen else {
        timer.invalidate()
        return
      }
      if self.speechSynthesizer.isSpeaking {
        quietCount = 0
        return
      }
      quietCount += 1
      if quietCount >= 2 {
        self.completeUtterance(gen)
      }
    }
  }

  private func registerNativeSpeech(with flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "epitaka/native_speech",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    self.speechChannel = channel

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else {
        result(false)
        return
      }

      switch call.method {
      case "isSupported":
        result(true)
      case "listVoices":
        let sysName = Self.systemDefaultVoiceName()
        let voices = NSSpeechSynthesizer.availableVoices.compactMap { vname -> [String: String]? in
          let attrs = NSSpeechSynthesizer.attributes(forVoice: vname)
          guard let name = attrs[.name] as? String, !name.isEmpty else {
            return nil
          }
          let lang = (attrs[.localeIdentifier] as? String) ?? ""
          return [
            "identifier": vname.rawValue,
            "name": name,
            "language": lang,
            "quality": "default",
            "systemDefault": (sysName != nil && name == sysName) ? "true" : "false",
          ]
        }
        result(voices)
      case "speak":
        guard let args = call.arguments as? [String: Any],
              let text = args["text"] as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
          result(FlutterError(code: "INVALID_ARGS", message: "text is required", details: nil))
          return
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        DispatchQueue.main.async {
          let gen = self.beginUtterance()
          if self.speechSynthesizer.isSpeaking {
            self.speechSynthesizer.stopSpeaking()
          }
          // NEVER call setVoice here — not even with nil. The pristine
          // synthesizer follows the system default voice (the user's Siri
          // voice); the original working build never set a voice, and any
          // explicit setVoice risks rerouting to a compact fallback. The
          // Dart `voiceIdentifier` pin is deliberately ignored for the
          // same reason: its heuristics cannot see the neural Siri family.
          self.speechSynthesizer.startSpeaking(trimmedText)
          self.armCompletionWatchdog(gen)
          result(true)
        }
      case "stop":
        DispatchQueue.main.async {
          self.utteranceGen += 1
          self.completionWatchdog?.invalidate()
          self.completionWatchdog = nil
          if self.speechSynthesizer.isSpeaking {
            self.speechSynthesizer.stopSpeaking()
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

  private func registerNativeLookup(with flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "epitaka/native_lookup",
      binaryMessenger: flutterViewController.engine.binaryMessenger
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
          let view = flutterViewController.view
          var point: NSPoint

          if let x = args["x"] as? Double, let y = args["y"] as? Double {
            // Flutter gives logical coordinates with top-left origin (0, 0).
            // AppKit NSView uses bottom-left origin (0, 0).
            point = NSPoint(x: CGFloat(x), y: view.bounds.height - CGFloat(y))
          } else if let window = view.window {
            let mouseLoc = NSEvent.mouseLocation
            let windowPoint = window.convertPoint(fromScreen: mouseLoc)
            point = view.convert(windowPoint, from: nil)
          } else {
            point = NSPoint(x: view.bounds.midX, y: view.bounds.midY)
          }

          let attrStr = NSAttributedString(string: term)
          view.showDefinition(for: attrStr, at: point)
          result(true)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

// MARK: - NSSpeechSynthesizerDelegate + watchdog completion
extension MainFlutterWindow: NSSpeechSynthesizerDelegate {
  func speechSynthesizer(
    _ sender: NSSpeechSynthesizer,
    didFinishSpeaking finishedSpeaking: Bool
  ) {
    DispatchQueue.main.async {
      self.completeUtterance(self.utteranceGen)
    }
  }
}
