import Foundation

protocol Cacheable: Actor {
    associatedtype T
    
    /// キャッシュの最大容量
    var maxItems: Int { get }
    /// クリーンアップ間隔
    var cleanupInterval: TimeInterval { get }
    
    /// アイテムの保存
    func store(_ item: T, forKey key: UUID) async throws
    
    /// アイテムの取得
    func get(forKey key: UUID) async throws -> T
    
    /// アイテムの削除
    func remove(forKey key: UUID) async throws
    
    /// キャッシュのクリーンアップを実行
    func performCleanup() async throws
}

/// キャッシュされたアイテムのメタデータ
struct CacheMetadata {
    let lastAccessed: Date
    let createdAt: Date
}
