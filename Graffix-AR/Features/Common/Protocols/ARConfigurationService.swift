import ARKit
import SceneKit

@MainActor
protocol ARConfigurationService {
    func createConfiguration() -> ARWorldTrackingConfiguration
    func getDefaultRunOptions() -> ARSession.RunOptions
    func configureView(_ view: ARSCNView)
    func updateConfiguration(_ configuration: ARWorldTrackingConfiguration)
    
#if DEBUG
    func monitorPerformance(_ session: ARSession)
#endif
}
