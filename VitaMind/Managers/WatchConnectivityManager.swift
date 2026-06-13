import Foundation
import WatchConnectivity

/// Receives heart rate data from the Apple Watch via WCSession.
/// Uses an internal delegate helper to avoid MainActor isolation conflicts with WCSessionDelegate.
@MainActor
@Observable
final class WatchConnectivityManager: NSObject {
    // Published state — fileprivate(set) so the delegate can update them.
    fileprivate(set) var isReachable = false
    fileprivate(set) var isActivated = false

    /// Callback invoked when heart rate data arrives from the watch.
    var onHeartRateReceived: ((HeartRateSample) -> Void)?

    private var sessionDelegate: SessionDelegate?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let delegate = SessionDelegate(owner: self)
        self.sessionDelegate = delegate
        let session = WCSession.default
        session.delegate = delegate
        session.activate()
    }

    /// Process an incoming heart rate message from the watch.
    fileprivate func handleIncoming(_ message: [String: Any]) {
        guard let bpm = message["heartRate"] as? Double else {
            print("[iPhone WCS] Missing heartRate in message")
            return
        }

        let timestamp: Date
        if let ts = message["timestamp"] as? TimeInterval {
            timestamp = Date(timeIntervalSince1970: ts)
        } else {
            timestamp = Date()
        }

        let source = message["source"] as? String ?? "watch"

        let sample = HeartRateSample(bpm: bpm, date: timestamp, source: source)
        onHeartRateReceived?(sample)
    }
}

// MARK: - Internal Delegate

private final class SessionDelegate: NSObject, WCSessionDelegate {
    private weak var owner: WatchConnectivityManager?

    init(owner: WatchConnectivityManager) {
        self.owner = owner
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        Task { @MainActor [weak self] in
            self?.owner?.isActivated = activationState == .activated
            self?.owner?.isReachable = session.isReachable
            if let error {
                print("[iPhone WCS] Activation error: \(error.localizedDescription)")
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            self?.owner?.isReachable = session.isReachable
        }
    }

    // These are unavailable on watchOS but required on iOS.
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        session.activate()
    }

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor [weak self] in
            self?.owner?.handleIncoming(message)
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor [weak self] in
            self?.owner?.handleIncoming(userInfo)
        }
    }
}
