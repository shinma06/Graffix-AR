import SwiftUI
import ARKit

struct MainView: View {
    var body: some View {
        ARContentContainer()
    }
}

private struct ARContentContainer: View {
    @State private var viewModel: MeasurementViewModel?
    @State private var wallTargetingVM = WallTargetingViewModel()
    @State private var arServices: ARServices?
    @State private var memoryManager: MemoryManagementService?
    
    var body: some View {
        ZStack {
            if let viewModel = viewModel,
               let arServices = arServices,
               let memoryManager = memoryManager {
                ARMainContentView(
                    viewModel: viewModel,
                    wallTargetingVM: wallTargetingVM,
                    arServices: arServices,
                    memoryManager: memoryManager
                )
            }
        }
        .task {
            let memoryManager = MemoryManagementServiceImpl()
            self.memoryManager = memoryManager
            
            let performanceMonitor = await DevicePerformanceMonitor.create()
            let configService = ARConfigurationServiceImpl(performanceMonitor: performanceMonitor)
            self.arServices = await ARServicesProvider(configurationService: configService)
            
            guard let arServices = self.arServices else { return }
            
            self.viewModel = await MeasurementViewModel(
                distanceViewModel: nil,  // デフォルトのViewModelが生成されます
                wallDetectionViewModel: WallDetectionViewModel(
                    wallDetectionService: WallDetectionService(arSession: ARSession())
                ),
                arServices: arServices,
                memoryManager: memoryManager
            )
        }
    }
}
