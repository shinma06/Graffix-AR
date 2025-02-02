import SceneKit

actor PlaneNodeCache {
    private let maxNodes: Int
    private let cleanupInterval: TimeInterval
    private let unusedThreshold: TimeInterval = 30
    private let emergencyThreshold: Int
    
    private var nodes: [UUID: CachedNode] = [:]
    private var lastCleanupTime: Date
    private var cleanupTask: Task<Void, Never>?
    private var isInitialized = false
    
    struct CachedNode {
        let node: SCNNode
        let lastAccessed: Date
        let createdAt: Date
    }
    
    init(maxNodes: Int = 30, cleanupInterval: TimeInterval = 15) {
        self.maxNodes = maxNodes
        self.cleanupInterval = cleanupInterval
        self.emergencyThreshold = Int(Double(maxNodes) * 0.9)
        self.lastCleanupTime = Date()
    }
    
    func initialize() throws {
        guard !isInitialized else { return }
        isInitialized = true
        startAutoCleanup()
    }
    
    func store(identifier: UUID, node: SCNNode) async throws {
        guard isInitialized else {
            throw AppError.system(.unexpectedState("キャッシュが初期化されていません"))
        }
        
        if nodes.count >= emergencyThreshold {
            try await performEmergencyCleanup()
        }
        
        nodes[identifier] = CachedNode(
            node: node,
            lastAccessed: Date(),
            createdAt: Date()
        )
    }
    
    func getNode(for identifier: UUID) async throws -> SCNNode {
        guard isInitialized else {
            throw AppError.system(.unexpectedState("キャッシュが初期化されていません"))
        }
        
        guard let cached = nodes[identifier] else {
            throw AppError.system(.resourceLimit("ノードが見つかりません: \(identifier)"))
        }
        
        nodes[identifier] = CachedNode(
            node: cached.node,
            lastAccessed: Date(),
            createdAt: cached.createdAt
        )
        
        return cached.node
    }
    
    func remove(identifier: UUID) async throws {
        guard let node = nodes[identifier]?.node else {
            throw AppError.system(.resourceLimit("削除対象のノードが見つかりません: \(identifier)"))
        }
        
        await MainActor.run {
            node.removeFromParentNode()
        }
        
        nodes.removeValue(forKey: identifier)
    }
    
    func getUnusedNodes(threshold: TimeInterval = 30) async -> [UUID] {
        let now = Date()
        return nodes.filter { now.timeIntervalSince($0.value.lastAccessed) > threshold }
            .map { $0.key }
    }
    
    private func startAutoCleanup() {
        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await self?.performCleanup()
                    guard let interval = self?.cleanupInterval else { break }
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                } catch {
                    print("⚠️ Cleanup error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func performCleanup() async throws {
        let now = Date()
        let oldNodes = nodes.filter { now.timeIntervalSince($0.value.lastAccessed) > unusedThreshold }
        
        for identifier in oldNodes.keys {
            try await remove(identifier: identifier)
        }
        
        lastCleanupTime = now
    }
    
    private func performEmergencyCleanup() async throws {
        let nodesToRemove = Int(Double(nodes.count) * 0.2)
        let sortedNodes = nodes.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
        
        for i in 0..<min(nodesToRemove, sortedNodes.count) {
            try await remove(identifier: sortedNodes[i].key)
        }
    }
    
    deinit {
        cleanupTask?.cancel()
    }
}
