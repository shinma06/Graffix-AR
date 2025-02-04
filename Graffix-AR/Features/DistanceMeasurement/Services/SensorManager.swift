import Foundation
import ARKit

protocol SensorManagerDelegate: AnyObject {
    func sensorManager(_ manager: SensorManager, didUpdateDistance distance: Float, sensorType: SensorType)
    func sensorManager(_ manager: SensorManager, didFailWithError error: Error)
}

class SensorManager: MemoryManagementDelegate {
    weak var delegate: SensorManagerDelegate?
    private var measurementTask: Task<Void, Never>?
    private var streamContinuation: AsyncStream<DistanceData>.Continuation?
    private var isRunning: Bool = false
    private let memoryManager: MemoryManagementService
    
    private let updateInterval: TimeInterval = 1.0 / 30.0
    private let batchSize = 5
    private var measurementBuffer: [DistanceData] = []
    private let bufferCapacity = 30
    
    private var dynamicUpdateInterval: TimeInterval
    private let minUpdateInterval: TimeInterval = 1.0 / 60.0
    private let maxUpdateInterval: TimeInterval = 1.0 / 15.0
    private var systemLoadLevel: Int = 0
    private let maxSystemLoadLevel = 5
    
    private var consecutiveErrorCount: Int = 0
    private let maxConsecutiveErrors = 3
    private var lastSuccessfulMeasurement: Date?
    private var isCalibrating = false
    
    private init(memoryManager: MemoryManagementService) {
        self.memoryManager = memoryManager
        self.dynamicUpdateInterval = updateInterval
    }
    
    static func create(memoryManager: MemoryManagementService) async -> SensorManager {
        let manager = SensorManager(memoryManager: memoryManager)
        await memoryManager.addDelegate(manager)
        return manager
    }
    
    func distanceStream() -> AsyncStream<DistanceData> {
        AsyncStream<DistanceData> { continuation in
            self.streamContinuation = continuation
            continuation.onTermination = { [weak self] _ in
                self?.stopMeasuring()
            }
        }
    }
    
    func startMeasuring() {
        guard !isRunning else { return }
        guard canStartMeasurement() else {
            handleError(AppError.sensor(.resourceUnavailable))
            return
        }
        
        isRunning = true
        consecutiveErrorCount = 0
        measurementBuffer.reserveCapacity(bufferCapacity)
        
        measurementTask = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                try await self.initializeSensor()
                
                while !Task.isCancelled && self.isRunning {
                    if await self.shouldPerformCalibration() && !self.isCalibrating {
                        self.isCalibrating = true
                        try await self.performCalibration()
                        self.isCalibrating = false
                    }
                    
                    try await self.processMeasurements()
                    try await self.adjustedSleep()
                }
            } catch {
                if let appError = error as? AppError {
                    self.handleError(appError)
                } else {
                    self.handleError(AppError.sensor(.measurementError(error.localizedDescription)))
                }
            }
            
            self.streamContinuation?.finish()
        }
    }
    
    func stopMeasuring() {
        isRunning = false
        measurementTask?.cancel()
        measurementTask = nil
        streamContinuation?.finish()
        streamContinuation = nil
        measurementBuffer.removeAll(keepingCapacity: true)
    }
    
    private func processMeasurements() async throws {
        for _ in 0..<batchSize {
            if Task.isCancelled || !isRunning { break }
            
            let measurement = try await performSingleMeasurement()
            measurementBuffer.append(measurement)
            
            if measurementBuffer.count >= bufferCapacity {
                await flushMeasurements()
            }
        }
        
        if !measurementBuffer.isEmpty {
            await flushMeasurements()
        }
    }
    
    private func performSingleMeasurement() async throws -> DistanceData {
        if systemLoadLevel >= maxSystemLoadLevel {
            throw AppError.sensor(.systemOverload)
        }
        
        let dummyDistance = Float.random(in: 0.5...5.0)
        
        let distanceData = DistanceData(
            distance: dummyDistance,
            isReliable: true,
            sensorType: .lidar,
            timestamp: Date()
        )
        
        lastSuccessfulMeasurement = Date()
        consecutiveErrorCount = 0
        return distanceData
    }
    
    private func flushMeasurements() async {
        guard !measurementBuffer.isEmpty else { return }
        
        let latestMeasurement = measurementBuffer.last!
        delegate?.sensorManager(self,
                                didUpdateDistance: latestMeasurement.distance,
                                sensorType: latestMeasurement.sensorType)
        
        for measurement in measurementBuffer {
            streamContinuation?.yield(measurement)
        }
        
        measurementBuffer.removeAll(keepingCapacity: true)
    }
    
    private func adjustedSleep() async throws {
        let interval = min(max(dynamicUpdateInterval * Double(systemLoadLevel + 1),
                               minUpdateInterval),
                           maxUpdateInterval)
        try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
    }
    
    private func initializeSensor() async throws {
        if arc4random_uniform(100) < 5 {
            throw AppError.sensor(.initializationFailed)
        }
    }
    
    private func shouldPerformCalibration() async -> Bool {
        guard let lastMeasurement = lastSuccessfulMeasurement else { return true }
        return Date().timeIntervalSince(lastMeasurement) > 300
    }
    
    private func performCalibration() async throws {
        if arc4random_uniform(100) < 10 {
            throw AppError.sensor(.calibrationRequired)
        }
    }
    
    private func canStartMeasurement() -> Bool {
        return true
    }
    
    private func handleError(_ error: AppError) {
        delegate?.sensorManager(self, didFailWithError: error)
        
        switch error {
        case .sensor(let sensorError):
            switch sensorError {
            case .initializationFailed, .resourceUnavailable, .consecutiveErrors:
                stopMeasuring()
            case .systemOverload:
                if consecutiveErrorCount >= maxConsecutiveErrors {
                    stopMeasuring()
                }
            case .calibrationRequired, .measurementError, .dataInvalid:
                consecutiveErrorCount += 1
                if consecutiveErrorCount >= maxConsecutiveErrors {
                    stopMeasuring()
                }
            }
        default:
            break
        }
    }
    
    // MARK: - MemoryManagementDelegate
    
    nonisolated func handleMemoryWarning() {
        Task { @MainActor [weak self] in
            self?.systemLoadLevel = self?.maxSystemLoadLevel ?? 0
            self?.measurementBuffer.removeAll(keepingCapacity: true)
        }
    }
    
    nonisolated func handleMemoryPressure(_ pressure: MemoryPressureLevel) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            switch pressure {
            case .low:
                self.systemLoadLevel = 0
            case .medium:
                self.systemLoadLevel = self.maxSystemLoadLevel / 2
            case .high, .critical:
                self.systemLoadLevel = self.maxSystemLoadLevel
                self.measurementBuffer.removeAll(keepingCapacity: true)
            }
        }
    }
    
    nonisolated func handleSystemMemoryChange(_ status: SystemMemoryStatus) {
        Task { @MainActor [weak self] in
            if status != .normal {
                self?.measurementBuffer.removeAll(keepingCapacity: true)
            }
        }
    }
    
    deinit {
        stopMeasuring()
    }
}
