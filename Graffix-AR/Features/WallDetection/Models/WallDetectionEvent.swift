import ARKit

enum WallDetectionEvent {
    case wallsUpdated([ARPlaneAnchor])
    case wallLocked(ARPlaneAnchor)
    case wallUnlocked
    case trackingStateChanged(ARCamera.TrackingState)
    case sessionInterrupted
    case sessionResumes
    case error(AppError)
    
    var priority: EventPriority {
        switch self {
        case .error: return .high
        case .trackingStateChanged, .wallLocked, .wallUnlocked: return .medium
        case .wallsUpdated, .sessionInterrupted, .sessionResumes: return .low
        }
    }
}

enum EventPriority: Int, Comparable {
    case high = 0
    case medium = 1
    case low = 2
    
    static func < (lhs: EventPriority, rhs: EventPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct EventWrapper {
    let event: WallDetectionEvent
    let timestamp: Date
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 5.0
    }
}
