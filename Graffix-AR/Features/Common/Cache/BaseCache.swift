import Foundation

actor BaseCache<T> {
    let maxItems: Int
    let cleanupInterval: TimeInterval
    private(set) var isInitialized = false
    
    private var items: [UUID: (item: T, metadata: CacheMetadata)] = [:]
    private var lastCleanupTime: Date
    private var cleanupTask: Task<Void, Never>?
    
    init(maxItems: Int, cleanupInterval: TimeInterval) {
        self.maxItems = maxItems
        self.cleanupInterval = cleanupInterval
        self.lastCleanupTime = Date()
    }
    
    func initialize() throws {
        guard !isInitialized else { return }
        isInitialized = true
        startAutoCleanup()
    }
    
    func store(_ item: T, forKey key: UUID) async throws {
        try validateInitialization()
        
        if items.count >= maxItems {
            try await performEmergencyCleanup()
        }
        
        items[key] = (
            item: item,
            metadata: CacheMetadata(
                lastAccessed: Date(),
                createdAt: Date()
            )
        )
    }
    
    func get(forKey key: UUID) async throws -> T {
        try validateInitialization()
        
        guard let cached = items[key] else {
            throw CacheError.itemNotFound(key)
        }
        
        // アクセス時間を更新
        items[key] = (
            item: cached.item,
            metadata: CacheMetadata(
                lastAccessed: Date(),
                createdAt: cached.metadata.createdAt
            )
        )
        
        return cached.item
    }
    
    func remove(forKey key: UUID) async throws {
        try validateInitialization()
        items.removeValue(forKey: key)
    }
    
    func performCleanup() async throws {
        try validateInitialization()
        
        let now = Date()
        let oldItems = items.filter {
            now.timeIntervalSince($0.value.metadata.lastAccessed) > cleanupInterval
        }
        
        for key in oldItems.keys {
            try await remove(forKey: key)
        }
        
        lastCleanupTime = now
    }
    
    var count: Int {
        get async {
            items.count
        }
    }
    
    var keys: [UUID] {
        get async {
            Array(items.keys)
        }
    }
    
    func getMetadata(for key: UUID) async throws -> CacheMetadata {
        try validateInitialization()
        guard let item = items[key] else {
            throw CacheError.itemNotFound(key)
        }
        return item.metadata
    }
    
    // MARK: - Private Methods
    
    private func validateInitialization() throws {
        guard isInitialized else {
            throw CacheError.notInitialized
        }
    }
    
    private func startAutoCleanup() {
        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64(self?.cleanupInterval ?? 15 * 1_000_000_000))
                    try await self?.performCleanup()
                } catch {
                    if !Task.isCancelled {
                        print("Cache cleanup error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func performEmergencyCleanup() async throws {
        let itemsToRemove = Int(Double(items.count) * 0.2)
        let sortedItems = items.sorted { $0.value.metadata.lastAccessed < $1.value.metadata.lastAccessed }
        
        for i in 0..<min(itemsToRemove, sortedItems.count) {
            try await remove(forKey: sortedItems[i].key)
        }
    }
    
    deinit {
        cleanupTask?.cancel()
    }
}
