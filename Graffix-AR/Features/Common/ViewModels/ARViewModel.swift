import ARKit
import SwiftUI

class ARViewModel: BaseViewModel {
    @Published var trackingState: ARCamera.TrackingState?
    let arSession: ARSession
    
    init(arSession: ARSession = ARSession(),
         errorHandler: ErrorHandling = AppErrorHandler.shared) {
        self.arSession = arSession
        super.init(errorHandler: errorHandler)
    }
    
    func resetSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.vertical]
        arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
}
