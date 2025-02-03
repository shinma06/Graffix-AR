import ARKit

@MainActor
class ARServicesProvider: ARServices {
    let configurationService: ARConfigurationService
    private let arSession: ARSession
    private var coordinator: ARSceneCoordinator?
    
    init(arSession: ARSession = ARSession(),
         configurationService: ARConfigurationService? = nil) async {
        self.arSession = arSession
        if let configService = configurationService {
            self.configurationService = configService
        } else {
            let monitor = await DevicePerformanceMonitor.create()
            self.configurationService = ARConfigurationServiceImpl(performanceMonitor: monitor)
        }
    }
    
    func setupAR(_ view: ARSCNView) {
        let configuration = configurationService.createConfiguration()
        let options = configurationService.getDefaultRunOptions()
        
        view.session.run(configuration, options: options)
        configurationService.configureView(view)
    }
    
    func setCoordinator(_ coordinator: ARSceneCoordinator) {
        self.coordinator = coordinator
    }
    
    func lockWall(_ wall: ARPlaneAnchor) async {
        await coordinator?.lockWall(with: wall.identifier)
    }
    
    func unlockWall() async {
        await coordinator?.unlockWall()
    }
}
