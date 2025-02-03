import SceneKit

actor PlaneNodeCache {
    private let cache: BaseCache<SCNNode>
    private let unusedThreshold: TimeInterval
    private let emergencyThreshold: Int
    
    init(maxNodes: Int = 30, cleanupInterval: TimeInterval = 15, memoryManager: MemoryManagementService) {
        self.cache = BaseCache<SCNNode>(maxItems: maxNodes,
                                        cleanupInterval: cleanupInterval,
                                        memoryManager: memoryManager)
        self.unusedThreshold = 30
        self.emergencyThreshold = Int(Double(maxNodes) * 0.9)
    }
    
    func initialize() async throws {
        try await cache.initialize()
    }
    
    func store(identifier: UUID, node: SCNNode) async throws {
        if await cache.count >= emergencyThreshold {
            try await cache.performEmergencyCleanup()
        }
        try await cache.store(node, forKey: identifier)
    }
    
    func getNode(for identifier: UUID) async throws -> SCNNode {
        try await cache.get(forKey: identifier)
    }
    
    func remove(identifier: UUID) async throws {
        let node = try await cache.get(forKey: identifier)
        await MainActor.run {
            node.removeFromParentNode()
        }
        try await cache.remove(forKey: identifier)
    }
    
    func getUnusedNodes(threshold: TimeInterval = 30) async -> [UUID] {
        let now = Date()
        let keys = await cache.keys
        
        var unusedKeys: [UUID] = []
        for key in keys {
            if let metadata = try? await cache.getMetadata(for: key),
               now.timeIntervalSince(metadata.lastAccessed) > threshold {
                unusedKeys.append(key)
            }
        }
        return unusedKeys
    }
    
    deinit {
        // BaseCacheのdeinitが自動的に呼ばれる
    }
}
