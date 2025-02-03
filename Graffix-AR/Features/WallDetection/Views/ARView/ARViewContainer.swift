import SwiftUI
import ARKit
import SceneKit

class ARViewHolder {
    weak var view: ARSCNView?
}

struct ARViewContainer: UIViewRepresentable {
    let viewModel: MeasurementViewModel
    let wallTargetingVM: WallTargetingViewModel
    let arServices: ARServices
    let memoryManager: MemoryManagementService
    
    final class Coordinator: NSObject {
        var parent: ARViewContainer
        var sceneCoordinator: ARSceneCoordinator?
        
        init(_ parent: ARViewContainer) {
            self.parent = parent
        }
    }
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        let sceneCoordinator = ARSceneCoordinator(
            self,
            wallTargetingVM: wallTargetingVM,
            memoryManager: memoryManager
        )
        context.coordinator.sceneCoordinator = sceneCoordinator
        sceneCoordinator.arViewHolder.view = arView
        
        if let provider = arServices as? ARServicesProvider {
            provider.setCoordinator(sceneCoordinator)
        }
        
        arServices.setupAR(arView)
        wallTargetingVM.setCoordinator(sceneCoordinator)
        
        arView.session.delegate = sceneCoordinator
        arView.delegate = sceneCoordinator
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}
