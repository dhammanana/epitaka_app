import Cocoa
import FlutterMacOS
import AppKit
import AVFoundation

class MainFlutterWindow: NSWindow {
  private let speechSynthesizer = AVSpeechSynthesizer()
  private var speechChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerNativeLookup(with: flutterViewController)
    registerNativeSpeech(with: flutterViewController)

    // Set up AVSpeechSynthesizer delegate for completion callbacks.
    // AVSpeechSynthesizer (not the deprecated NSSpeechSynthesizer) is the
    // API that reliably reports utterance completion inside Flutter macOS
    // apps — NSSpeechSynthesizer's didFinishSpeaking delegate callback was
    // never delivered in this app, so every TTS line waited for the Dart
    // side's full timeout before advancing (a 15–30s gap between lines).
    self.speechSynthesizer.delegate = self

    super.awakeFromNib()
  }

  /// Pick a voice for [languageCode] (e.g. "en-US", "th", "my").
  /// Falls back to the default voice when the language has no installed
  /// voice (nil utterance.voice = system default).
  private func resolveVoice(for languageCode: String?) -> AVSpeechSynthesisVoice? {
    guard let code = languageCode, !code.isEmpty else { return nil }
    if let voice = AVSpeechSynthesisVoice(language: code) {
      return voice
    }
    // Bare language code (e.g. "th"): match any installed voice whose
    // locale starts with that language prefix.
    guard let prefix = code.split(separator: "-").first.map(String.init) else {
      return nil
    }
    for voice in AVSpeechSynthesisVoice.speechVoices() {
      if voice.language.lowercased().hasPrefix(prefix.lowercased() + "-") {
        return voice
      }
    }
    return nil
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
          let utterance = AVSpeechUtterance(string: trimmedText)
          utterance.voice = self.resolveVoice(for: language)
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

// MARK: - AVSpeechSynthesizerDelegate
extension MainFlutterWindow: AVSpeechSynthesizerDelegate {
  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    DispatchQueue.main.async {
      self.speechChannel?.invokeMethod("onCompletion", arguments: nil)
    }
  }
}
