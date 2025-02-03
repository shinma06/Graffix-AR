import Foundation

enum CacheError: LocalizedError {
    case notInitialized
    case itemNotFound(UUID)
    case capacityExceeded
    case invalidState(String)
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "キャッシュが初期化されていません"
        case .itemNotFound(let id):
            return "アイテムが見つかりません: \(id)"
        case .capacityExceeded:
            return "キャッシュの容量を超えました"
        case .invalidState(let message):
            return "不正な状態: \(message)"
        }
    }
}
