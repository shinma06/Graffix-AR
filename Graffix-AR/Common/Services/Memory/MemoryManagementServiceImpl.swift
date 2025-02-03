import Foundation
import UIKit

@MainActor
final class MemoryManagementServiceImpl: MemoryManagementService {
    private var delegates: NSHashTable<AnyObject> = .weakObjects()
    private var memoryWarningObserver: NSObjectProtocol?
    private var thermalStateObserver: NSObjectProtocol?
    
    private(set) var currentPressureLevel: MemoryPressureLevel = .low
    private(set) var systemMemoryStatus: SystemMemoryStatus = .normal
    
    init() {
        setupObservers()
    }
    
    func startMonitoring() {
        setupObservers()
    }
    
    func stopMonitoring() {
        cleanupObservers()
    }
    
    func addDelegate(_ delegate: MemoryManagementDelegate) {
        delegates.add(delegate)
    }
    
    func removeDelegate(_ delegate: MemoryManagementDelegate) {
        delegates.remove(delegate)
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // メモリ警告の監視
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleMemoryWarning()
            }
        }
        
        // サーマル状態の監視
        if #available(iOS 16.0, *) {
            thermalStateObserver = NotificationCenter.default.addObserver(
                forName: ProcessInfo.thermalStateDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.handleThermalStateChange()
                }
            }
        }
    }
    
    private func cleanupObservers() {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = thermalStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        memoryWarningObserver = nil
        thermalStateObserver = nil
    }
    
    private func handleMemoryWarning() async {
        systemMemoryStatus = .warning
        await notifyDelegates { delegate in
            delegate.handleMemoryWarning()
        }
    }
    
    @available(iOS 16.0, *)
    private func handleThermalStateChange() async {
        let state = ProcessInfo.processInfo.thermalState
        let pressureLevel: MemoryPressureLevel
        
        switch state {
        case .nominal:
            pressureLevel = .low
        case .fair:
            pressureLevel = .medium
        case .serious:
            pressureLevel = .high
        case .critical:
            pressureLevel = .critical
        @unknown default:
            pressureLevel = .low
        }
        
        currentPressureLevel = pressureLevel
        await notifyDelegates { delegate in
            delegate.handleMemoryPressure(pressureLevel)
        }
    }
    
    private func notifyDelegates(_ notification: (MemoryManagementDelegate) async -> Void) async {
        for case let delegate as MemoryManagementDelegate in delegates.allObjects {
            await notification(delegate)
        }
    }
    
    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = thermalStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        memoryWarningObserver = nil
        thermalStateObserver = nil
    }
}
