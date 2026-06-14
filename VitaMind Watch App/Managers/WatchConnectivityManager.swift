import Foundation
import WatchConnectivity

/// Sends health data from Watch to iPhone via WCSession.
/// Uses a private delegate helper to avoid MainActor isolation conflicts with WCSessionDelegate.
@MainActor
@Observable
final class WatchConnectivityManager: NSObject {
    // MARK: - Published state

    private(set) var isReachable = false
    private(set) var isActivated = false

    /// Callback when iPhone requests a stress measurement.
    var onStartMeasurement: (() -> Void)?
    /// Samples that failed to send (phone unreachable). Retried when reachable again.
    private var pendingSamples: [HealthSample] = []
    private let maxPending = 100

    private var sessionDelegate: SessionDelegate?

    // MARK: - Init

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let delegate = SessionDelegate(owner: self)
        self.sessionDelegate = delegate
        let session = WCSession.default
        session.delegate = delegate
        session.activate()
    }

    // MARK: - Send

    /// Send a single health sample to the companion iPhone app.
    func sendSample(_ sample: HealthSample) {
        guard WCSession.isSupported() else { return }

        let message = buildMessage(for: sample)

        let session = WCSession.default

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    print("[Watch WCS] sendMessage failed: \(error.localizedDescription)")
                    self?.enqueuePending(sample)
                }
            }
        } else {
            session.transferUserInfo(message)
        }
    }

    /// Send multiple samples to the iPhone.
    func sendSamples(_ samples: [HealthSample]) {
        for sample in samples {
            sendSample(sample)
        }
    }

    /// Send a stress result to the iPhone.
    func sendStressResult(score: Int, sdnn: Double, level: String, timestamp: Date) {
        guard WCSession.isSupported() else { return }
        let message: [String: Any] = [
            "type": "stressResult",
            "score": score,
            "sdnn": sdnn,
            "level": level,
            "timestamp": timestamp.timeIntervalSince1970
        ]
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(message)
        }
    }

    /// Send diagnostic status to the iPhone.
    func sendWatchStatus(hkAuthorized: Bool, monitoring: Bool, errorText: String? = nil) {
        guard WCSession.isSupported() else { return }
        var message: [String: Any] = [
            "type": "watchStatus",
            "hkAuthorized": hkAuthorized,
            "stressMonitoring": monitoring,
            "timestamp": Date().timeIntervalSince1970
        ]
        if let errorText {
            message["errorText"] = errorText
        }
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(message)
        }
    }

    // MARK: - Receive (from iPhone)

    fileprivate func handleIncoming(_ message: [String: Any]) {
        let type = message["type"] as? String ?? ""
        if type == "startMeasurement" {
            onStartMeasurement?()
        }
    }

    // MARK: - Internal (called by SessionDelegate)

    fileprivate func handleActivation(state: WCSessionActivationState, reachable: Bool, error: Error?) {
        isActivated = state == .activated
        isReachable = reachable
        if let error {
            print("[Watch WCS] Activation error: \(error.localizedDescription)")
        }
    }

    fileprivate func handleReachabilityChange(_ reachable: Bool) {
        isReachable = reachable
        if reachable {
            flushPending()
        }
    }

    // MARK: - Private

    private func buildMessage(for sample: HealthSample) -> [String: Any] {
        var message: [String: Any] = [
            "type": sample.type.rawValue,
            "value": sample.value,
            "unit": sample.unit,
            "timestamp": sample.date.timeIntervalSince1970,
            "source": sample.source
        ]
        if let metadata = sample.metadata {
            message["metadata"] = metadata
        }
        return message
    }

    private func enqueuePending(_ sample: HealthSample) {
        pendingSamples.append(sample)
        if pendingSamples.count > maxPending {
            pendingSamples.removeFirst(pendingSamples.count - maxPending)
        }
    }

    private func flushPending() {
        let session = WCSession.default
        guard session.isReachable, !pendingSamples.isEmpty else { return }

        for sample in pendingSamples {
            let message = buildMessage(for: sample)
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        }
        pendingSamples.removeAll()
    }
}

// MARK: - Internal Delegate (non-isolated to match WCSessionDelegate)

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
            self?.owner?.handleActivation(
                state: activationState,
                reachable: session.isReachable,
                error: error
            )
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            self?.owner?.handleReachabilityChange(session.isReachable)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor [weak self] in
            self?.owner?.handleIncoming(message)
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}
