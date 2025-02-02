import Foundation
import ARKit

actor WallGroupCache {
    private let maxGroups: Int
    private let cleanupThreshold: Int
    private var lastCleanupTime: Date
    private let cleanupInterval: TimeInterval
    private var isInitialized = false
    private var cleanupTask: Task<Void, Never>?
    
    private var groups: [UUID: CachedWallGroup] = [:]
    
    struct CachedWallGroup {
        let anchors: [ARPlaneAnchor]
        let lastAccessed: Date
        let createdAt: Date
    }
    
    init(maxGroups: Int = 20, cleanupThreshold: Int = 15, cleanupInterval: TimeInterval = 30) {
        self.maxGroups = maxGroups
        self.cleanupThreshold = cleanupThreshold
        self.cleanupInterval = cleanupInterval
        self.lastCleanupTime = Date()
    }
    
    func initialize() {
        guard !isInitialized else { return }
        isInitialized = true
        startAutoCleanup()
    }
    
    private func startAutoCleanup() {
        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.performCleanup()
                try? await Task.sleep(nanoseconds: UInt64(30 * 1_000_000_000))
            }
        }
    }
    
    func store(groupID: UUID, anchors: [ARPlaneAnchor]) async {
        await performCleanupIfNeeded()
        
        groups[groupID] = CachedWallGroup(
            anchors: anchors,
            lastAccessed: Date(),
            createdAt: Date()
        )
        
        if groups.count > maxGroups {
            await removeOldestGroup()
        }
    }
    
    func getAnchors(for groupID: UUID) async -> [ARPlaneAnchor]? {
        guard let cached = groups[groupID] else { return nil }
        
        groups[groupID] = CachedWallGroup(
            anchors: cached.anchors,
            lastAccessed: Date(),
            createdAt: cached.createdAt
        )
        
        return cached.anchors
    }
    
    func getAllGroups() async -> [(UUID, [ARPlaneAnchor])] {
        return groups.map { ($0.key, $0.value.anchors) }
    }
    
    func remove(groupID: UUID) {
        groups.removeValue(forKey: groupID)
    }
    
    private func performCleanupIfNeeded() async {
        let now = Date()
        guard now.timeIntervalSince(lastCleanupTime) > cleanupInterval else { return }
        await performCleanup()
    }
    
    private func performCleanup() async {
        let now = Date()
        let unusedThreshold: TimeInterval = 60 // 1分以上アクセスのないグループを削除
        
        let oldGroups = groups.filter { now.timeIntervalSince($0.value.lastAccessed) > unusedThreshold }
        for groupID in oldGroups.keys {
            groups.removeValue(forKey: groupID)
        }
        
        lastCleanupTime = now
    }
    
    private func removeOldestGroup() async {
        guard let oldest = groups.min(by: { $0.value.lastAccessed < $1.value.lastAccessed }) else { return }
        groups.removeValue(forKey: oldest.key)
    }
    
    deinit {
        cleanupTask?.cancel()
    }
}
