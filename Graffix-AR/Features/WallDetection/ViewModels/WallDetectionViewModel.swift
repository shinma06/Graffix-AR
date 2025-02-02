import ARKit
import SwiftUI

final class WallDetectionViewModel: BaseViewModel {
    @Published var detectionMode: WallDetectionMode = .free
    @Published var detectedWalls: [ARPlaneAnchor] = []
    @Published var trackingState: ARCamera.TrackingState?
    
    private let wallDetectionService: WallDetectionService
    private var eventProcessingTask: Task<Void, Never>?
    private var wallUpdateDebouncer: Task<Void, Never>?
    private let wallUpdateInterval: TimeInterval = 0.1
    
    init(wallDetectionService: WallDetectionService,
         arSession: ARSession = ARSession(),
         errorHandler: ErrorHandling = AppErrorHandler.shared) {
        self.wallDetectionService = wallDetectionService
        super.init(errorHandler: errorHandler)
        setupDelegates()
        setupEventProcessing()
    }
    
    private func setupDelegates() {
        wallDetectionService.delegate = self
    }
    
    private func setupEventProcessing() {
        eventProcessingTask = Task { [weak self] in
            guard let self = self else { return }
            
            for await event in wallDetectionService.events() {
                if Task.isCancelled { break }
                await self.processWallDetectionEvent(event)
            }
        }
    }
    
    private func processWallDetectionEvent(_ event: WallDetectionEvent) async {
        switch event {
        case .wallsUpdated(let walls):
            wallUpdateDebouncer?.cancel()
            wallUpdateDebouncer = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(self?.wallUpdateInterval ?? 0.1 * 1_000_000_000))
                await self?.handleWallsUpdate(walls)
            }
            
        case .wallLocked(let wall):
            detectionMode = .locked
            if let index = detectedWalls.firstIndex(where: { $0.identifier == wall.identifier }) {
                detectedWalls[index] = wall
            }
            
        case .wallUnlocked:
            detectionMode = .free
            
        case .trackingStateChanged(let state):
            trackingState = state
            handleTrackingStateChange(state)
            
        case .sessionInterrupted:
            errorMessage = "ARセッションが中断されました"
            
        case .sessionResumes:
            errorMessage = nil
            
        case .error(let error):
            handleError(error)
        }
    }
    
    private func handleWallsUpdate(_ walls: [ARPlaneAnchor]) async {
        guard detectionMode == .free else { return }
        
        var updatedWalls = detectedWalls
        for wall in walls {
            if let index = updatedWalls.firstIndex(where: { $0.identifier == wall.identifier }) {
                updatedWalls[index] = wall
            } else {
                updatedWalls.append(wall)
            }
        }
        
        updatedWalls.removeAll { wall in
            !walls.contains { $0.identifier == wall.identifier }
        }
        
        detectedWalls = updatedWalls
    }
    
    private func handleTrackingStateChange(_ state: ARCamera.TrackingState) {
        switch state {
        case .normal:
            errorMessage = nil
        case .limited(let reason):
            let error = AppError.ar(.trackingStateChanged(.limited(reason)))
            handleError(error)
        case .notAvailable:
            let error = AppError.ar(.trackingStateChanged(.notAvailable))
            handleError(error)
        }
    }
    
    deinit {
        eventProcessingTask?.cancel()
        wallUpdateDebouncer?.cancel()
    }
}

// MARK: - WallDetectionServiceDelegate
extension WallDetectionViewModel: WallDetectionServiceDelegate {
    nonisolated func wallDetectionService(_ service: WallDetectionService, didUpdateWalls walls: [ARPlaneAnchor]) async {
        await MainActor.run {
            if self.detectionMode == .free {
                self.detectedWalls = walls
            }
        }
    }
    
    nonisolated func wallDetectionService(_ service: WallDetectionService, didLockToWall wall: ARPlaneAnchor) async {
        await MainActor.run {
            self.detectionMode = .locked
        }
    }
    
    nonisolated func wallDetectionServiceDidUnlock(_ service: WallDetectionService) async {
        await MainActor.run {
            self.detectionMode = .free
        }
    }
    
    nonisolated func wallDetectionService(_ service: WallDetectionService, didFailWithError error: AppError) async {
        await MainActor.run {
            self.handleError(error)
        }
    }
}
