import ARKit
import Foundation

protocol WallDetectionServiceDelegate: AnyObject {
    func wallDetectionService(_ service: WallDetectionService, didUpdateWalls walls: [ARPlaneAnchor]) async
    func wallDetectionService(_ service: WallDetectionService, didLockToWall wall: ARPlaneAnchor) async
    func wallDetectionServiceDidUnlock(_ service: WallDetectionService) async
    func wallDetectionService(_ service: WallDetectionService, didFailWithError error: AppError) async
}

@globalActor actor WallDetectionServiceActor {
    static let shared = WallDetectionServiceActor()
}

class WallDetectionService: NSObject, ARSessionDelegate {
    weak var delegate: WallDetectionServiceDelegate?
    private let arSession: ARSession
    private var currentWall: ARPlaneAnchor?
    private var isProcessingUpdate = false
    
    private var eventContinuation: AsyncStream<WallDetectionEvent>.Continuation?
    private var eventBuffer: [EventWrapper] = []
    private let maxBufferSize = 30
    private var eventProcessingTask: Task<Void, Never>?
    
    init(arSession: ARSession, delegate: WallDetectionServiceDelegate? = nil) {
        self.arSession = arSession
        self.delegate = delegate
        super.init()
        self.arSession.delegate = self
        setupEventProcessing()
    }
    
    func events() -> AsyncStream<WallDetectionEvent> {
        AsyncStream { continuation in
            self.eventContinuation = continuation
            continuation.onTermination = { [weak self] _ in
                self?.cleanupEventProcessing()
            }
        }
    }
    
    @WallDetectionServiceActor
    func detectWalls() async -> [ARPlaneAnchor] {
        guard let currentFrame = arSession.currentFrame else { return [] }
        
        let walls = currentFrame.anchors.compactMap { anchor -> ARPlaneAnchor? in
            guard let planeAnchor = anchor as? ARPlaneAnchor,
                  planeAnchor.alignment == .vertical else {
                return nil
            }
            return planeAnchor
        }
        
        queueEvent(.wallsUpdated(walls))
        return walls
    }
    
    @WallDetectionServiceActor
    func lockToWall(_ wall: ARPlaneAnchor) async {
        currentWall = wall
        queueEvent(.wallLocked(wall))
        await delegate?.wallDetectionService(self, didLockToWall: wall)
    }
    
    @WallDetectionServiceActor
    func unlockWall() async {
        currentWall = nil
        queueEvent(.wallUnlocked)
        await delegate?.wallDetectionServiceDidUnlock(self)
    }
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @WallDetectionServiceActor in
            await handleSessionError(error)
        }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        Task { @WallDetectionServiceActor in
            await handleTrackingStateChange(camera.trackingState)
        }
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { @WallDetectionServiceActor in
            await processFrame(frame)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupEventProcessing() {
        eventProcessingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(1.0 / 30.0 * 1_000_000_000))
                await self?.processEventBuffer()
            }
        }
    }
    
    @WallDetectionServiceActor
    private func processEventBuffer() async {
        eventBuffer.removeAll { $0.isExpired }
        
        if eventBuffer.count > maxBufferSize {
            eventBuffer.sort { $0.event.priority < $1.event.priority }
            eventBuffer = Array(eventBuffer.prefix(maxBufferSize))
        }
        
        for wrapper in eventBuffer {
            eventContinuation?.yield(wrapper.event)
        }
        eventBuffer.removeAll()
    }
    
    @WallDetectionServiceActor
    private func queueEvent(_ event: WallDetectionEvent) {
        let wrapper = EventWrapper(event: event, timestamp: Date())
        eventBuffer.append(wrapper)
    }
    
    private func cleanupEventProcessing() {
        eventProcessingTask?.cancel()
        eventProcessingTask = nil
        eventBuffer.removeAll()
    }
    
    @WallDetectionServiceActor
    private func handleSessionError(_ error: Error) async {
        let appError = AppError.ar(.sessionFailed(error))
        queueEvent(.error(appError))
        await delegate?.wallDetectionService(self, didFailWithError: appError)
    }
    
    @WallDetectionServiceActor
    private func handleTrackingStateChange(_ state: ARCamera.TrackingState) async {
        queueEvent(.trackingStateChanged(state))
        
        switch state {
        case .normal:
            break
        case .notAvailable:
            await delegate?.wallDetectionService(self, didFailWithError: .ar(.trackingStateChanged(state)))
        case .limited(let reason):
            await delegate?.wallDetectionService(self, didFailWithError: .ar(.trackingStateChanged(.limited(reason))))
        }
    }
    
    @WallDetectionServiceActor
    private func processFrame(_ frame: ARFrame) async {
        guard !isProcessingUpdate else { return }
        isProcessingUpdate = true
        defer { isProcessingUpdate = false }
        
        let walls = frame.anchors.compactMap { anchor -> ARPlaneAnchor? in
            guard let planeAnchor = anchor as? ARPlaneAnchor,
                  planeAnchor.alignment == .vertical else {
                return nil
            }
            return planeAnchor
        }
        
        queueEvent(.wallsUpdated(walls))
        await delegate?.wallDetectionService(self, didUpdateWalls: walls)
    }
    
    deinit {
        cleanupEventProcessing()
    }
}
