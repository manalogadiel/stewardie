import Flutter
import UIKit
import AudioToolbox

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var orientationStream: StewardieOrientationStream?
  private var soundIDs: [String: SystemSoundID] = [:]
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "StewardieSounds") {
      for cue in ["capture", "success"] {
        if let url = Bundle.main.url(forResource: cue, withExtension: "wav") {
          var id: SystemSoundID = 0
          if AudioServicesCreateSystemSoundID(url as CFURL, &id) == kAudioServicesNoError { soundIDs[cue] = id }
        }
      }
      FlutterMethodChannel(name: "stewardie/sounds", binaryMessenger: registrar.messenger()).setMethodCallHandler { [weak self] call, result in
        if call.method == "play", let cue = call.arguments as? String, let id = self?.soundIDs[cue] { AudioServicesPlaySystemSound(id) }
        result(nil)
      }
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
