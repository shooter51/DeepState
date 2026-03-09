import WatchKit

class ExtendedRuntimeManager: NSObject, WKExtendedRuntimeSessionDelegate {
    var session: WKExtendedRuntimeSession?

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
        // Session about to expire — persist state
    }

    func extendedRuntimeSession(_ session: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: (any Error)?) {}
}
