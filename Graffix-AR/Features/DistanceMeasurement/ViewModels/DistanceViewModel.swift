import ARKit
import SwiftUI

final class DistanceViewModel: BaseViewModel {
    @Published private(set) var currentDistance: DistanceData?
    private let sensorManager: SensorManager
    private let arSession: ARSession
    
    init(sensorManager: SensorManager = SensorManager(),
         arSession: ARSession = ARSession(),
         errorHandler: ErrorHandling = AppErrorHandler.shared) {
        self.sensorManager = sensorManager
        self.arSession = arSession
        super.init(errorHandler: errorHandler)
        setupDelegates()
    }
    
    private func setupDelegates() {
        sensorManager.delegate = self
    }
    
    func startMeasurement() {
        sensorManager.startMeasuring()
        errorMessage = nil
    }
    
    func stopMeasurement() {
        sensorManager.stopMeasuring()
    }
    
    deinit {
        stopMeasurement()
    }
}

// MARK: - SensorManagerDelegate
extension DistanceViewModel: SensorManagerDelegate {
    nonisolated func sensorManager(_ manager: SensorManager, didUpdateDistance distance: Float, sensorType: SensorType) {
        let isReliable = sensorType.reliableRange.contains(distance)
        Task { @MainActor in
            self.currentDistance = DistanceData(
                distance: distance,
                isReliable: isReliable,
                sensorType: sensorType,
                timestamp: Date()
            )
        }
    }
    
    nonisolated func sensorManager(_ manager: SensorManager, didFailWithError error: Error) {
        Task { @MainActor in
            if let appError = error as? AppError {
                self.handleError(appError)
            } else {
                self.handleError(.system(.unexpectedState(error.localizedDescription)))
            }
        }
    }
}
