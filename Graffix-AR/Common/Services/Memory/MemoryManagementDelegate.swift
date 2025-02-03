import Foundation

protocol MemoryManagementDelegate: AnyObject {
    /// メモリ警告時の処理
    func handleMemoryWarning()
    
    /// メモリ圧迫時の処理（重要度に応じた解放）
    func handleMemoryPressure(_ pressure: MemoryPressureLevel)
    
    /// システムメモリの状態変更時の処理
    func handleSystemMemoryChange(_ status: SystemMemoryStatus)
}

enum MemoryPressureLevel {
    case low      // 通常状態
    case medium   // 中程度の圧迫
    case high     // 深刻な圧迫
    case critical // 極めて危機的
}

enum SystemMemoryStatus {
    case normal
    case warning
    case critical
}
