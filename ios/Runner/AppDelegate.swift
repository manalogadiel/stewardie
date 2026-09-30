import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var orientationStream: StewardieOrientationStream?
  private var players: [String: AVAudioPlayer] = [:]
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  @objc private func stopActionSounds() { players.values.forEach { $0.stop() } }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "StewardieSounds") {
      for cue in ["capture", "success", "saved", "moment_shared", "space_ready", "mood_checked_in", "location_start", "location_stop", "reaction_pop", "attention"] {
        if let url = Bundle.main.url(forResource: cue, withExtension: "wav"),
           let player = try? AVAudioPlayer(contentsOf: url) {
          player.prepareToPlay()
          players[cue] = player
        }
      }
      FlutterMethodChannel(name: "stewardie/sounds", binaryMessenger: registrar.messenger()).setMethodCallHandler { [weak self] call, result in
        guard let self = self else { result(nil); return }
        if call.method == "stop" {
          self.players.values.forEach { $0.stop() }
        } else if call.method == "play",
                  UIApplication.shared.applicationState == .active,
                  let arguments = call.arguments as? [String: Any],
                  let cue = arguments["cue"] as? String,
                  let player = self.players[cue] {
          let gain = (arguments["gain"] as? NSNumber)?.floatValue ?? 0.8
          if gain.isFinite {
            do {
              // Ambient honors the silent switch and mixes with other audio.
              try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
              try AVAudioSession.sharedInstance().setActive(true)
              self.players.values.forEach { $0.stop() }
              player.currentTime = 0
              player.volume = min(1, max(0, gain))
              player.play()
            } catch { /* Feedback never blocks camera or application actions. */ }
          }
        }
        result(nil)
      }
      NotificationCenter.default.addObserver(self, selector: #selector(stopActionSounds), name: UIApplication.willResignActiveNotification, object: nil)
    }

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "StewardieOrientation") {
      let stream = StewardieOrientationStream()
      FlutterEventChannel(name: "stewardie/device_orientation", binaryMessenger: registrar.messenger()).setStreamHandler(stream)
      orientationStream = stream
    }
  }
}

class StewardieOrientationStream: NSObject, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    NotificationCenter.default.addObserver(self, selector: #selector(changed), name: UIDevice.orientationDidChangeNotification, object: nil)
    changed()
    return nil
  }
  @objc private func changed() {
    switch UIDevice.current.orientation {
    case .portrait: sink?(0.0)
    case .portraitUpsideDown: sink?(0.5)
    case .landscapeLeft: sink?(0.25)
    case .landscapeRight: sink?(-0.25)
    default: break
    }
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NotificationCenter.default.removeObserver(self)
    UIDevice.current.endGeneratingDeviceOrientationNotifications()
    sink = nil
    return nil
  }
}
