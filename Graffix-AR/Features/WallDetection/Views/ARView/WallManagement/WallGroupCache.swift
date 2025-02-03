import ARKit
import Foundation

actor WallGroupCache {
    private let cache: BaseCache<[ARPlaneAnchor]>
    private let cleanupThreshold: TimeInterval = 60
    
    init(maxGroups: Int = 20, cleanupInterval: TimeInterval = 30, memoryManager: MemoryManagementService) {
        self.cache = BaseCache<[ARPlaneAnchor]>(
            maxItems: maxGroups,
            cleanupInterval: cleanupInterval,
            memoryManager: memoryManager
        )
    }
    
    func initialize() async throws {
        try await cache.initialize()
    }
    
    func store(groupID: UUID, anchors: [ARPlaneAnchor]) async throws {
        try await cache.store(anchors, forKey: groupID)
    }
    
    func getAnchors(for groupID: UUID) async -> [ARPlaneAnchor]? {
        try? await cache.get(forKey: groupID)
    }
    
    func getAllGroups() async -> [(UUID, [ARPlaneAnchor])] {
        let keys = await cache.keys
        var groups: [(UUID, [ARPlaneAnchor])] = []
        
        for key in keys {
            if let anchors = await getAnchors(for: key) {
                groups.append((key, anchors))
            }
        }
        
        return groups
    }
    
    func remove(groupID: UUID) async {
        try? await cache.remove(forKey: groupID)
    }
}
