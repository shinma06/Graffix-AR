import Foundation

@MainActor
protocol MemoryManagementService: AnyObject {
    /// メモリ管理の開始
    func startMonitoring()
    
    /// メモリ管理の停止
    func stopMonitoring()
    
    /// デリゲートの追加
    func addDelegate(_ delegate: MemoryManagementDelegate)
    
    /// デリゲートの削除
    func removeDelegate(_ delegate: MemoryManagementDelegate)
    
    /// 現在のメモリ圧迫レベルの取得
    var currentPressureLevel: MemoryPressureLevel { get }
    
    /// システムメモリの状態取得
    var systemMemoryStatus: SystemMemoryStatus { get }
}
