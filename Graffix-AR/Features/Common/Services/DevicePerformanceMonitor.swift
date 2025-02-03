import Foundation
import UIKit
import Combine

@MainActor
final class DevicePerformanceMonitor: ObservableObject {
    @Published private(set) var currentLevel: PerformanceLevel
    private let memoryManager: MemoryManagementService
    private let updateInterval: TimeInterval
    private var updateTimer: Timer?
    
    private init(memoryManager: MemoryManagementService) {
        self.memoryManager = memoryManager
        self.currentLevel = .medium
        self.updateInterval = ARConfigurationSettings.Performance.Monitoring.updateInterval
    }
    
    static func create() async -> DevicePerformanceMonitor {
        let memoryManager = MemoryManagementServiceImpl()
        let monitor = DevicePerformanceMonitor(memoryManager: memoryManager)
        memoryManager.addDelegate(monitor)
        monitor.startMonitoring()
        return monitor
    }
    
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
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func updatePerformanceMetrics() async {
        let baseLevel = evaluateHardwareCapabilities()
        let adjustedLevel = await adjustForSystemConditions(baseLevel)
        
        if currentLevel != adjustedLevel {
            currentLevel = adjustedLevel
        }
    }
    
    private func evaluateHardwareCapabilities() -> PerformanceLevel {
        let processorCount = ProcessInfo.processInfo.processorCount
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let processorThresholds = ARConfigurationSettings.Performance.Thresholds.processor
        let memoryThresholds = ARConfigurationSettings.Performance.Thresholds.memory
        
        let baseLevel: PerformanceLevel
        switch processorCount {
        case processorThresholds.high...: baseLevel = .high
        case processorThresholds.medium...: baseLevel = .medium
        default: baseLevel = .low
        }
        
        let memoryGB = Double(totalMemory) / 1_000_000_000
        if memoryGB < memoryThresholds.minimum && baseLevel != .low {
            return .low
        } else if memoryGB < memoryThresholds.standard && baseLevel == .high {
            return .medium
        }
        
        let deviceSettings = ARConfigurationSettings.Device.getSpecificSettings()
        return deviceSettings.preferHighPerformance ? baseLevel : min(baseLevel, .medium)
    }
    
    private func adjustForSystemConditions(_ baseLevel: PerformanceLevel) async -> PerformanceLevel {
        switch memoryManager.systemMemoryStatus {
        case .warning:
            return baseLevel == .high ? .medium : .low
        case .critical:
            return .low
        case .normal:
            return baseLevel
        }
    }
    
    deinit {
        updateTimer?.invalidate()
        updateTimer = nil
    }
}

extension DevicePerformanceMonitor: MemoryManagementDelegate {
    nonisolated func handleMemoryWarning() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let adjustedLevel = await self.adjustForSystemConditions(self.currentLevel)
            if self.currentLevel != adjustedLevel {
                self.currentLevel = adjustedLevel
            }
        }
    }
    
    nonisolated func handleMemoryPressure(_ pressure: MemoryPressureLevel) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let adjustedLevel = await self.adjustForSystemConditions(self.currentLevel)
            if self.currentLevel != adjustedLevel {
                self.currentLevel = adjustedLevel
            }
        }
    }
    
    nonisolated func handleSystemMemoryChange(_ status: SystemMemoryStatus) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let adjustedLevel = await self.adjustForSystemConditions(self.currentLevel)
            if self.currentLevel != adjustedLevel {
                self.currentLevel = adjustedLevel
            }
        }
    }
}

extension DevicePerformanceMonitor {
    enum PerformanceLevel: Int, Comparable {
        case low = 0
        case medium = 1
        case high = 2
        
        static func < (lhs: PerformanceLevel, rhs: PerformanceLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}
