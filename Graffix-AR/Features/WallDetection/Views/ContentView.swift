import SwiftUI
import ARKit

struct ContentView: View {
    var body: some View {
        let performanceMonitor = DevicePerformanceMonitor()
        let configService = ARConfigurationServiceImpl(performanceMonitor: performanceMonitor)
        let arServices = ARServicesProvider(configurationService: configService)
        
        let viewModel = MeasurementViewModel(
            distanceViewModel: DistanceViewModel(),
            wallDetectionViewModel: WallDetectionViewModel(
                wallDetectionService: WallDetectionService(arSession: ARSession())
            ),
            arServices: arServices
        )
        
        ARContentView(
            viewModel: viewModel,
            wallTargetingVM: WallTargetingViewModel()
        )
    }
}
