import Foundation
import WatchConnectivity

/// Receives health data from the Apple Watch via WCSession.
/// Uses an internal delegate helper to avoid MainActor isolation conflicts with WCSessionDelegate.
@MainActor
@Observable
final class WatchConnectivityManager: NSObject {
    // Published state — fileprivate(set) so the delegate can update them.
    fileprivate(set) var isReachable = false
    fileprivate(set) var isActivated = false
    /// Whether the watch app is installed on the paired Apple Watch.
    /// Reliable indicator after WCSession is activated.
    fileprivate(set) var isWatchAppInstalled = false

    /// Callback invoked when health data arrives from the watch.
    var onSampleReceived: ((HealthSample) -> Void)?
    /// Callback invoked when a stress result arrives from the watch.
    var onStressResultReceived: ((StressResult) -> Void)?
    /// Callback invoked when watch diagnostic status arrives.
    var onWatchStatusReceived: ((WatchDiagnostics) -> Void)?

    /// Send a measurement request to the watch.
    func requestMeasurement() {
        guard WCSession.isSupported(), WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(
            ["type": "startMeasurement"],
            replyHandler: nil,
            errorHandler: { error in
                print("[iPhone WCS] requestMeasurement failed: \(error.localizedDescription)")
            }
        )
    }

    /// Stress result received from the watch.
    struct StressResult {
        let score: Int
        let sdnn: Double
        let level: String
        let timestamp: Date
    }

    /// Diagnostic status from the watch.
    struct WatchDiagnostics {
        let healthKitAuthorized: Bool
        let stressMonitoring: Bool
        let errorText: String?
        let timestamp: Date
    }

    private var sessionDelegate: SessionDelegate?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let delegate = SessionDelegate(owner: self)
        self.sessionDelegate = delegate
        let session = WCSession.default
        session.delegate = delegate
        session.activate()
        // Populate state immediately for already-activated sessions.
        isActivated = session.activationState == .activated
        isReachable = session.isReachable
        #if os(iOS)
        isWatchAppInstalled = session.isWatchAppInstalled
        #endif
    }

    /// Process an incoming health sample message from the watch.
    fileprivate func handleIncoming(_ message: [String: Any]) {
        // Check if it's a stress result
        let typeRaw = message["type"] as? String ?? "heartRate"
        if typeRaw == "stressResult" {
            guard let score = message["score"] as? Int,
                  let sdnn = message["sdnn"] as? Double,
                  let level = message["level"] as? String else {
                print("[iPhone WCS] Invalid stressResult message")
                return
            }
            let timestamp: Date
            if let ts = message["timestamp"] as? TimeInterval {
                timestamp = Date(timeIntervalSince1970: ts)
            } else {
                timestamp = Date()
            }
            onStressResultReceived?(StressResult(score: score, sdnn: sdnn, level: level, timestamp: timestamp))
            return
        }
        // Watch diagnostic status
        if typeRaw == "watchStatus" {
            let hkAuth = message["hkAuthorized"] as? Bool ?? false
            let monitoring = message["stressMonitoring"] as? Bool ?? false
            let errorText = message["errorText"] as? String
            let timestamp: Date
            if let ts = message["timestamp"] as? TimeInterval {
                timestamp = Date(timeIntervalSince1970: ts)
            } else {
                timestamp = Date()
            }
            onWatchStatusReceived?(WatchDiagnostics(
                healthKitAuthorized: hkAuth,
                stressMonitoring: monitoring,
                errorText: errorText,
                timestamp: timestamp
            ))
            return
        }
        guard let metricType = HealthMetricType(rawValue: typeRaw) else {
            print("[iPhone WCS] Unknown metric type: \(typeRaw)")
            return
        }

        // Parse value — try "value" key first, fall back to "heartRate" for backward compat
        guard let value = message["value"] as? Double ?? message["heartRate"] as? Double else {
            print("[iPhone WCS] Missing value in message")
            return
        }

        let timestamp: Date
        if let ts = message["timestamp"] as? TimeInterval {
            timestamp = Date(timeIntervalSince1970: ts)
        } else {
            timestamp = Date()
        }

        let source = message["source"] as? String ?? "watch"
        let unit = message["unit"] as? String
        let metadata = message["metadata"] as? [String: String]

        let sample = HealthSample(
            type: metricType,
            value: value,
            unit: unit,
            date: timestamp,
            source: source,
            metadata: metadata
        )
        onSampleReceived?(sample)
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
            #if os(iOS)
            self?.owner?.isWatchAppInstalled = WCSession.default.isWatchAppInstalled
            #endif
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
