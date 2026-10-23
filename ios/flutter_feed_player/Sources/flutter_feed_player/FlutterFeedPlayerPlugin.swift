import AVFoundation
import AVKit
import Flutter
import UIKit

@objc(FlutterFeedPlayerPlugin)
public class FlutterFeedPlayerPlugin: NSObject, FlutterPlugin, AVPictureInPictureControllerDelegate {
    private var channel: FlutterMethodChannel?
    private var eligible = false
    private var pipController: AVPictureInPictureController?
    private var boundLayer: AVPlayerLayer?
    private var bindScheduled = false
    private var bindAttempts = 0

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = FlutterFeedPlayerPlugin()
        let channel = FlutterMethodChannel(
            name: "flutter_feed_player/pip",
            binaryMessenger: registrar.messenger()
        )
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.publish(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setEligible":
            let args = call.arguments as? [String: Any]
            eligible = args?["eligible"] as? Bool ?? false
            if eligible {
                bindAttempts = 0
                bindPlayingLayer()
            } else if pipController?.isPictureInPictureActive != true {
                disarm()
            }
            result(nil)
        case "enter":
            result(pipController?.isPictureInPictureActive == true)
        case "isActive":
            result(pipController?.isPictureInPictureActive ?? false)
        case "keepPlaying":
            result(shouldKeepPlaying())
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func shouldKeepPlaying() -> Bool {
        guard let pip = pipController else { return false }
        if pip.isPictureInPictureActive { return true }
        return eligible && pip.isPictureInPicturePossible
    }

    private func disarm() {
        bindScheduled = false
        bindAttempts = 0
        if #available(iOS 14.2, *) {
            pipController?.canStartPictureInPictureAutomaticallyFromInline = false
        }
        pipController = nil
        boundLayer = nil
    }

    /// Arm automatic PiP while the video is on screen. The system starts the
    /// window when the app actually backgrounds, not when Control Center opens.
    private func bindPlayingLayer() {
        guard eligible else { return }
        passTouchesThroughPlayerViews()
        guard let root = rootView(), let layer = findBestPlayingLayer(in: root) else {
            scheduleBindRetry()
            return
        }
        bindAttempts = 0
        if pipController != nil, boundLayer === layer {
            if #available(iOS 14.2, *) {
                pipController?.canStartPictureInPictureAutomaticallyFromInline = true
            }
            return
        }
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        prepareAudioSession()
        let controller: AVPictureInPictureController?
        if #available(iOS 15.0, *) {
            let source = AVPictureInPictureController.ContentSource(playerLayer: layer)
            controller = AVPictureInPictureController(contentSource: source)
        } else {
            controller = AVPictureInPictureController(playerLayer: layer)
        }
        controller?.delegate = self
        if #available(iOS 14.2, *) {
            controller?.canStartPictureInPictureAutomaticallyFromInline = true
        }
        pipController = controller
        boundLayer = layer
    }

    private func scheduleBindRetry() {
        guard eligible, !bindScheduled, bindAttempts < 10 else { return }
        bindScheduled = true
        bindAttempts += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }
            self.bindScheduled = false
            self.bindPlayingLayer()
        }
    }

    private func prepareAudioSession() {
        let session = AVAudioSession.sharedInstance()
        if session.category != .playback {
            try? session.setCategory(.playback, mode: .moviePlayback)
        }
        try? session.setActive(true)
    }

    private func rootView() -> UIView? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? scenes.flatMap(\.windows).first
        return window?.rootViewController?.view
    }

    /// Platform views sit above Flutter and swallow the feed's taps and swipes.
    /// PiP only needs the layer, so the player view itself should not hit-test.
    private func passTouchesThroughPlayerViews() {
        guard let root = rootView() else { return }
        func visit(_ view: UIView) {
            if view.layer is AVPlayerLayer {
                view.isUserInteractionEnabled = false
            }
            for subview in view.subviews {
                visit(subview)
            }
        }
        visit(root)
    }

    /// Prefer the on-screen playing layer. A preloaded page can also be playing
    /// for a moment, but it sits outside the window.
    private func findBestPlayingLayer(in root: UIView) -> AVPlayerLayer? {
        var best: AVPlayerLayer?
        var bestArea: CGFloat = 0
        func visit(_ view: UIView) {
            if let playerLayer = view.layer as? AVPlayerLayer, isPlaying(playerLayer) {
                let frame = view.convert(view.bounds, to: root)
                let visible = frame.intersection(root.bounds)
                let area = max(0, visible.width) * max(0, visible.height)
                if area > bestArea {
                    bestArea = area
                    best = playerLayer
                }
            }
            for subview in view.subviews {
                visit(subview)
            }
        }
        visit(root)
        return best
    }

    private func isPlaying(_ layer: AVPlayerLayer) -> Bool {
        guard let player = layer.player else { return false }
        return player.rate > 0.01
    }

    private func notify(active: Bool) {
        channel?.invokeMethod("onPipModeChanged", arguments: active)
    }

    public func pictureInPictureControllerDidStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        notify(active: true)
    }

    public func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        notify(active: false)
    }

    public func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(true)
    }
}
