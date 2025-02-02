enum SensorType {
    case lidar
    case tof
    case ultrasonic
    
    var reliableRange: ClosedRange<Float> {
        switch self {
        case .lidar: return 0.5...5.0 // 50cm-5m
        case .tof: return 0.03...0.5  // 3cm-50cm
        case .ultrasonic: return 0.01...0.03 // 1cm-3cm
        }
    }
}
