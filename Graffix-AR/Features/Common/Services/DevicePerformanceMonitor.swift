import Foundation
import UIKit
import Combine

@MainActor
final class DevicePerformanceMonitor: ObservableObject {
    // MARK: - Public Properties
    @Published private(set) var currentLevel: PerformanceLevel
    @Published private(set) var systemLoadLevel: SystemLoad
    
    // MARK: - Private Properties
    private var memoryWarningSubscription: AnyCancellable?
    private var thermalStateSubscription: AnyCancellable?
    private var updateTimer: Timer?
    private var recoveryTask: Task<Void, Never>?
    private let updateInterval: TimeInterval
    
    // MARK: - Initialization
    init() {
        self.currentLevel = .medium
        self.systemLoadLevel = .normal
        self.updateInterval = ARConfigurationSettings.Performance.Monitoring.updateInterval
        
        setupObservers()
        startMonitoring()
    }
    
    // MARK: - Public Methods
    func startMonitoring() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(
            withTimeInterval: updateInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.updatePerformanceMetrics()
            }
        }
    }
    
    func stopMonitoring() {
        cleanup()
    }
    
    // MARK: - Private Methods
    private func cleanup() {
        updateTimer?.invalidate()
        updateTimer = nil
        recoveryTask?.cancel()
        recoveryTask = nil
        memoryWarningSubscription?.cancel()
        thermalStateSubscription?.cancel()
        memoryWarningSubscription = nil
        thermalStateSubscription = nil
    }
    
    private func setupObservers() {
        memoryWarningSubscription = NotificationCenter.default.publisher(
            for: UIApplication.didReceiveMemoryWarningNotification
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleMemoryWarning()
            }
        }
        
        if #available(iOS 16.0, *) {
            let processInfo = ProcessInfo.processInfo
            thermalStateSubscription = NotificationCenter.default.publisher(
                for: ProcessInfo.thermalStateDidChangeNotification
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleThermalStateChange(processInfo.thermalState)
                }
            }
        }
    }
    
    private func updatePerformanceMetrics() async {
        let baseLevel = evaluateHardwareCapabilities()
        let adjustedLevel = adjustForSystemConditions(baseLevel)
        
        if currentLevel != adjustedLevel {
            currentLevel = adjustedLevel
        }
    }
    
    private func evaluateHardwareCapabilities() -> PerformanceLevel {
        let processorCount = ProcessInfo.processInfo.processorCount
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let processorThresholds = ARConfigurationSettings.Performance.Thresholds.processor
        let memoryThresholds = ARConfigurationSettings.Performance.Thresholds.memory
        
        // プロセッサ数による基本評価
        let baseLevel: PerformanceLevel
        switch processorCount {
        case processorThresholds.high...: baseLevel = .high
        case processorThresholds.medium...: baseLevel = .medium
        default: baseLevel = .low
        }
        
        // メモリ容量による調整
        let memoryGB = Double(totalMemory) / 1_000_000_000
        if memoryGB < memoryThresholds.minimum && baseLevel != .low {
            return .low
        } else if memoryGB < memoryThresholds.standard && baseLevel == .high {
            return .medium
        }
        
        // デバイス特性による調整
        let deviceSettings = ARConfigurationSettings.Device.getSpecificSettings()
        return deviceSettings.preferHighPerformance ? baseLevel : min(baseLevel, .medium)
    }
    
    private func adjustForSystemConditions(_ baseLevel: PerformanceLevel) -> PerformanceLevel {
        switch systemLoadLevel {
        case .high:
            return baseLevel == .high ? .medium : .low
        case .critical:
            return .low
        case .normal:
            return baseLevel
        }
    }
    
    private func handleMemoryWarning() async {
        systemLoadLevel = .high
        
        recoveryTask?.cancel()
        recoveryTask = Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(ARConfigurationSettings.Performance.Monitoring.thermalRecoveryDelay * 1_000_000_000)
            )
            guard let self = self, !Task.isCancelled else { return }
            self.resetSystemLoad()
        }
    }
    
    private func resetSystemLoad() {
        if systemLoadLevel == .high {
            systemLoadLevel = .normal
        }
    }
    
    @available(iOS 16.0, *)
    private func handleThermalStateChange(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal:
            systemLoadLevel = .normal
        case .fair, .serious:
            systemLoadLevel = .high
        case .critical:
            systemLoadLevel = .critical
        @unknown default:
            systemLoadLevel = .normal
        }
    }
}

// MARK: - Supporting Types
extension DevicePerformanceMonitor {
    enum PerformanceLevel: Int, Comparable {
        case low = 0
        case medium = 1
        case high = 2
        
        static func < (lhs: PerformanceLevel, rhs: PerformanceLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    enum SystemLoad {
        case normal
        case high
        case critical
    }
}
