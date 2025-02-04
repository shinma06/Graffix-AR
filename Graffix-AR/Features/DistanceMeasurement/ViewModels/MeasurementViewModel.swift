import ARKit
import SwiftUI
import Combine

final class MeasurementViewModel: BaseViewModel {
    @Published private(set) var currentDistance: DistanceData?
    @Published var detectedWalls: [ARPlaneAnchor]
    
    let wallDetectionViewModel: WallDetectionViewModel
    private let distanceViewModel: DistanceViewModel
    private let arServices: ARServices
    private var cancellables = Set<AnyCancellable>()
    
    var trackingState: ARCamera.TrackingState? { wallDetectionViewModel.trackingState }
    var detectionMode: WallDetectionMode { wallDetectionViewModel.detectionMode }
    
    init(distanceViewModel: DistanceViewModel? = nil,
         wallDetectionViewModel: WallDetectionViewModel = WallDetectionViewModel(
            wallDetectionService: WallDetectionService(arSession: ARSession())),
         arServices: ARServices,
         memoryManager: MemoryManagementService,
         errorHandler: ErrorHandling = AppErrorHandler.shared) async {
        if let distanceVM = distanceViewModel {
            self.distanceViewModel = distanceVM
        } else {
            self.distanceViewModel = await DistanceViewModel(
                memoryManager: memoryManager,
                errorHandler: errorHandler
            )
        }
        self.wallDetectionViewModel = wallDetectionViewModel
        self.arServices = arServices
        self.detectedWalls = []
        super.init(errorHandler: errorHandler)
        
        setupErrorMessageBinding()
        setupDistanceBinding()
        setupWallsBinding()
    }
    
    private func setupErrorMessageBinding() {
        distanceViewModel.objectWillChange.sink { [weak self] in
            if let error = self?.distanceViewModel.errorMessage {
                self?.errorMessage = error
            }
        }.store(in: &cancellables)
        
        wallDetectionViewModel.objectWillChange.sink { [weak self] in
            if let error = self?.wallDetectionViewModel.errorMessage {
                self?.errorMessage = error
            }
        }.store(in: &cancellables)
    }
    
    private func setupDistanceBinding() {
        distanceViewModel.$currentDistance
            .assign(to: \.currentDistance, on: self)
            .store(in: &cancellables)
    }
    
    private func setupWallsBinding() {
        wallDetectionViewModel.$detectedWalls
            .assign(to: \.detectedWalls, on: self)
            .store(in: &cancellables)
    }
    
    func startMeasurement() {
        distanceViewModel.startMeasurement()
    }
    
    func stopMeasurement() {
        distanceViewModel.stopMeasurement()
    }
    
    func lockToWall(_ wall: ARPlaneAnchor) async {
        await arServices.lockWall(wall)
    }
    
    func unlockWall() async {
        await arServices.unlockWall()
    }
    
    deinit {
        cancellables.removeAll()
    }
}
