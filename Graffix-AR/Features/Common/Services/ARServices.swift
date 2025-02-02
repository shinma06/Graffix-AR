import ARKit

@MainActor
protocol ARServices: AnyObject {
    var configurationService: ARConfigurationService { get }
    func setupAR(_ view: ARSCNView)
    func lockWall(_ wall: ARPlaneAnchor) async
    func unlockWall() async
}
