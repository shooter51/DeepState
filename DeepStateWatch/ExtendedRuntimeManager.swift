import WatchKit

class ExtendedRuntimeManager: NSObject, WKExtendedRuntimeSessionDelegate {
    var session: WKExtendedRuntimeSession?
    var onSessionExpiring: (() -> Void)?
    var onSessionError: ((WKExtendedRuntimeSessionInvalidationReason, Error?) -> Void)?

    func startSession() {
        let session = WKExtendedRuntimeSession()
        session.delegate = self
        session.start()
        self.session = session
    }

    func endSession() {
        session?.invalidate()
        session = nil
    }

    func extendedRuntimeSessionDidStart(_ session: WKExtendedRuntimeSession) {}

    func extendedRuntimeSessionWillExpire(_ session: WKExtendedRuntimeSession) {
        onSessionExpiring?()
    }

    func extendedRuntimeSession(_ session: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: (any Error)?) {
        if let error {
            print("[DeepState] Extended runtime session invalidated: \(reason.rawValue), error: \(error)")
        }
        onSessionError?(reason, error)
    }
}
