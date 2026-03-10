import Foundation
import WatchConnectivity
import SwiftData
import DiveCore

@Observable
final class WatchConnectivityManager: NSObject, WCSessionDelegate {
    var isWatchReachable: Bool = false
    var lastSyncDate: Date?

    private var modelContext: ModelContext?

    override init() {
        super.init()
        activateSession()
    }

    // MARK: - Setup

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    private func activateSession() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Send Settings

    func sendSettings(_ settings: DiveSettings) {
        guard WCSession.default.activationState == .activated else { return }

        let payload: [String: Any] = [
            "type": "settings",
            "unitSystem": settings.unitSystem,
            "defaultO2Percent": settings.defaultO2Percent,
            "gfLow": settings.gfLow,
            "gfHigh": settings.gfHigh,
            "ppO2Max": settings.ppO2Max,
            "ascentRateWarning": settings.ascentRateWarning,
            "ascentRateCritical": settings.ascentRateCritical,
            "targetAscentRate": settings.targetAscentRate
        ]

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil) { error in
                print("Failed to send settings: \(error.localizedDescription)")
            }
        } else {
            do {
                try WCSession.default.updateApplicationContext(payload)
            } catch {
                print("Failed to update application context: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        // No-op for iOS
    }

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleReceivedMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleReceivedMessage(message)
        replyHandler(["status": "received"])
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleReceivedMessage(applicationContext)
    }

    // MARK: - Message Handling

    private func handleReceivedMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String, type == "diveSession" else { return }
        guard let modelContext = modelContext else { return }

        DispatchQueue.main.async {
            self.persistDiveSession(from: message, context: modelContext)
            self.lastSyncDate = Date()
        }
    }

    private func validateDiveData(_ message: [String: Any]) -> Bool {
        let maxDepth = message["maxDepth"] as? Double ?? 0
        let avgDepth = message["avgDepth"] as? Double ?? 0
        let duration = message["duration"] as? TimeInterval ?? 0
        let o2Percent = message["o2Percent"] as? Int ?? 21
        let gfLow = message["gfLow"] as? Double ?? 0.40
        let gfHigh = message["gfHigh"] as? Double ?? 0.85

        guard (0...200).contains(maxDepth) else {
            print("[WatchSync] Invalid maxDepth: \(maxDepth). Must be 0...200.")
            return false
        }
        guard (0...maxDepth).contains(avgDepth) else {
            print("[WatchSync] Invalid avgDepth: \(avgDepth). Must be 0...\(maxDepth).")
            return false
        }
        guard (0...86400).contains(duration) else {
            print("[WatchSync] Invalid duration: \(duration). Must be 0...86400.")
            return false
        }
        guard (21...100).contains(o2Percent) else {
            print("[WatchSync] Invalid o2Percent: \(o2Percent). Must be 21...100.")
            return false
        }
        guard (0.1...1.0).contains(gfLow) else {
            print("[WatchSync] Invalid gfLow: \(gfLow). Must be 0.1...1.0.")
            return false
        }
        guard (0.1...1.0).contains(gfHigh) else {
            print("[WatchSync] Invalid gfHigh: \(gfHigh). Must be 0.1...1.0.")
            return false
        }
        guard gfLow <= gfHigh else {
            print("[WatchSync] Invalid gradient factors: gfLow (\(gfLow)) must be <= gfHigh (\(gfHigh)).")
            return false
        }

        return true
    }

    private func persistDiveSession(from message: [String: Any], context: ModelContext) {
        guard let startDateInterval = message["startDate"] as? TimeInterval else { return }

        guard validateDiveData(message) else { return }

        let session = DiveSession(startDate: Date(timeIntervalSince1970: startDateInterval))

        if let endDateInterval = message["endDate"] as? TimeInterval {
            session.endDate = Date(timeIntervalSince1970: endDateInterval)
        }
        session.maxDepth = message["maxDepth"] as? Double ?? 0
        session.avgDepth = message["avgDepth"] as? Double ?? 0
        session.duration = message["duration"] as? TimeInterval ?? 0
        session.minTemp = message["minTemp"] as? Double
        session.maxTemp = message["maxTemp"] as? Double
        session.o2Percent = message["o2Percent"] as? Int ?? 21
        session.gfLow = message["gfLow"] as? Double ?? 0.40
        session.gfHigh = message["gfHigh"] as? Double ?? 0.85
        session.cnsPercent = message["cnsPercent"] as? Double ?? 0
        session.otuTotal = message["otuTotal"] as? Double ?? 0
        session.phaseHistory = message["phaseHistory"] as? [String] ?? []
        session.tissueLoadingAtEnd = message["tissueLoadingAtEnd"] as? [Double] ?? []

        // Deserialize depth samples
        if let samplesData = message["depthSamples"] as? [[String: Any]] {
            var samples: [DepthSample] = []
            for sampleDict in samplesData {
                guard let ts = sampleDict["timestamp"] as? TimeInterval,
                      let depth = sampleDict["depth"] as? Double else { continue }

                let sample = DepthSample(
                    timestamp: Date(timeIntervalSince1970: ts),
                    depth: depth,
                    temperature: sampleDict["temperature"] as? Double,
                    ndl: sampleDict["ndl"] as? Int,
                    ceilingDepth: sampleDict["ceilingDepth"] as? Double,
                    ascentRate: sampleDict["ascentRate"] as? Double
                )
                sample.diveSession = session
                samples.append(sample)
            }
            session.depthSamples = samples
        }

        context.insert(session)
    }
}
