import ARKit
import Foundation

enum AppError: LocalizedError {
    case ar(ARError)
    case sensor(SensorError)
    case system(SystemError)
    
    // MARK: - Nested Error Types
    
    enum ARError {
        case trackingStateChanged(ARCamera.TrackingState)
        case sessionFailed(Error)
        case notAvailable
        case initialization
        case relocalizing
        case insufficientFeatures
        case excessiveMotion
        case cacheError(String)
        case wallGroupError(String)
    }
    
    enum SensorError {
        case initializationFailed
        case calibrationRequired
        case systemOverload
        case consecutiveErrors
        case resourceUnavailable
        case measurementError(String)
        case dataInvalid
    }
    
    enum SystemError {
        case memoryWarning
        case taskCancelled
        case resourceLimit(String)
        case unexpectedState(String)
    }
}

// MARK: - Error Descriptions
extension AppError {
    var errorDescription: String? {
        switch self {
        case .ar(let error):
            return error.localizedDescription
        case .sensor(let error):
            return error.localizedDescription
        case .system(let error):
            return error.localizedDescription
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .ar(let error):
            return error.recoverySuggestion
        case .sensor(let error):
            return error.recoverySuggestion
        case .system(let error):
            return error.recoverySuggestion
        }
    }
}

// MARK: - AR Error Descriptions
extension AppError.ARError {
    var localizedDescription: String {
        switch self {
        case .trackingStateChanged(let state):
            switch state {
            case .normal:
                return String(localized: "ar.tracking.normal")
            case .limited(let reason):
                switch reason {
                case .excessiveMotion:
                    return String(localized: "ar.tracking.excessive_motion")
                case .insufficientFeatures:
                    return String(localized: "ar.tracking.insufficient_features")
                case .initializing:
                    return String(localized: "ar.tracking.initializing")
                case .relocalizing:
                    return String(localized: "ar.tracking.relocalizing")
                @unknown default:
                    return String(localized: "ar.tracking.limited")
                }
            case .notAvailable:
                return String(localized: "ar.tracking.not_available")
            }
        case .sessionFailed(let error):
            return String(localized: "ar.session.failed") + ": \(error.localizedDescription)"
        case .notAvailable:
            return String(localized: "ar.not_available")
        case .initialization:
            return String(localized: "ar.initialization")
        case .relocalizing:
            return String(localized: "ar.relocalizing")
        case .insufficientFeatures:
            return String(localized: "ar.insufficient_features")
        case .excessiveMotion:
            return String(localized: "ar.excessive_motion")
        case .cacheError(let message):
            return String(format: String(localized: "ar.cache.error"), message)
        case .wallGroupError(let message):
            return String(format: String(localized: "ar.wall.error"), message)
        }
    }
    
    var recoverySuggestion: String {
        switch self {
        case .trackingStateChanged(let state):
            switch state {
            case .limited(let reason):
                switch reason {
                case .excessiveMotion:
                    return String(localized: "ar.recovery.slow_down")
                case .insufficientFeatures:
                    return String(localized: "ar.recovery.more_features")
                case .initializing, .relocalizing:
                    return String(localized: "ar.recovery.wait")
                @unknown default:
                    return String(localized: "ar.recovery.general")
                }
            case .notAvailable:
                return String(localized: "ar.recovery.restart")
            case .normal:
                return ""
            }
        case .sessionFailed:
            return String(localized: "ar.recovery.restart_session")
        case .notAvailable:
            return String(localized: "ar.recovery.check_device")
        case .initialization:
            return String(localized: "ar.recovery.wait")
        case .relocalizing:
            return String(localized: "ar.recovery.scan_area")
        case .insufficientFeatures:
            return String(localized: "ar.recovery.more_light")
        case .excessiveMotion:
            return String(localized: "ar.recovery.slow_down")
        case .cacheError:
            return String(localized: "ar.recovery.restart_app")
        case .wallGroupError:
            return String(localized: "ar.recovery.rescan_wall")
        }
    }
}

// MARK: - Sensor Error Descriptions
extension AppError.SensorError {
    var localizedDescription: String {
        switch self {
        case .initializationFailed:
            return String(localized: "sensor.init.failed")
        case .calibrationRequired:
            return String(localized: "sensor.calibration.required")
        case .systemOverload:
            return String(localized: "sensor.system.overload")
        case .consecutiveErrors:
            return String(localized: "sensor.consecutive.errors")
        case .resourceUnavailable:
            return String(localized: "sensor.resource.unavailable")
        case .measurementError(let message):
            return String(format: String(localized: "sensor.measurement.error"), message)
        case .dataInvalid:
            return String(localized: "sensor.data.invalid")
        }
    }
    
    var recoverySuggestion: String {
        switch self {
        case .initializationFailed:
            return String(localized: "sensor.recovery.restart")
        case .calibrationRequired:
            return String(localized: "sensor.recovery.calibrate")
        case .systemOverload:
            return String(localized: "sensor.recovery.close_apps")
        case .consecutiveErrors:
            return String(localized: "sensor.recovery.reset")
        case .resourceUnavailable:
            return String(localized: "sensor.recovery.check_usage")
        case .measurementError:
            return String(localized: "sensor.recovery.retry")
        case .dataInvalid:
            return String(localized: "sensor.recovery.retry")
        }
    }
}

// MARK: - System Error Descriptions
extension AppError.SystemError {
    var localizedDescription: String {
        switch self {
        case .memoryWarning:
            return String(localized: "system.memory.warning")
        case .taskCancelled:
            return String(localized: "system.task.cancelled")
        case .resourceLimit(let message):
            return String(format: String(localized: "system.resource.limit"), message)
        case .unexpectedState(let message):
            return String(format: String(localized: "system.unexpected.state"), message)
        }
    }
    
    var recoverySuggestion: String {
        switch self {
        case .memoryWarning:
            return String(localized: "system.recovery.free_memory")
        case .taskCancelled:
            return String(localized: "system.recovery.retry")
        case .resourceLimit:
            return String(localized: "system.recovery.free_resources")
        case .unexpectedState:
            return String(localized: "system.recovery.restart")
        }
    }
}
