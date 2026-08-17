import Cocoa
import FlutterMacOS
import AppKit

class MainFlutterWindow: NSWindow {
  private let speechSynthesizer = NSSpeechSynthesizer()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerNativeLookup(with: flutterViewController)
    registerNativeSpeech(with: flutterViewController)

    super.awakeFromNib()
  }

  private func registerNativeSpeech(with flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "epitaka/native_speech",
      binaryMessenger: flutterViewController.engine.binaryMessenger
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

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        DispatchQueue.main.async {
          if self.speechSynthesizer.isSpeaking {
            self.speechSynthesizer.stopSpeaking()
          }
          self.speechSynthesizer.startSpeaking(trimmedText)
          result(true)
        }
      case "stop":
        DispatchQueue.main.async {
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
