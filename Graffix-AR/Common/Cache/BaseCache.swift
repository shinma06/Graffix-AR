import Foundation

actor BaseCache<T> {
    let maxItems: Int
    let cleanupInterval: TimeInterval
    private(set) var isInitialized = false
    private let memoryManager: MemoryManagementService
    
    private var items: [UUID: (item: T, metadata: CacheMetadata)] = [:]
    private var lastCleanupTime: Date
    private var cleanupTask: Task<Void, Never>?
    private var isMemoryManagementInitialized = false
    
    init(maxItems: Int, cleanupInterval: TimeInterval, memoryManager: MemoryManagementService) {
        self.maxItems = maxItems
        self.cleanupInterval = cleanupInterval
        self.lastCleanupTime = Date()
        self.memoryManager = memoryManager
    }
    
    func initialize() throws {
        guard !isInitialized else { return }
        isInitialized = true
        startAutoCleanup()
        
        // メモリ管理の初期化は別メソッドに分離
        Task { @MainActor in
            await setupMemoryManagement()
        }
    }
    
    private func setupMemoryManagement() async {
        guard !isMemoryManagementInitialized else { return }
        await memoryManager.addDelegate(self)
        isMemoryManagementInitialized = true
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
        let itemsToRemove = Int(Double(items.count) * 0.4)  // メモリ圧迫時は40%削減
        let sortedItems = items.sorted { $0.value.metadata.lastAccessed < $1.value.metadata.lastAccessed }
        
        for i in 0..<min(itemsToRemove, sortedItems.count) {
            try await remove(forKey: sortedItems[i].key)
        }
    }
    
    deinit {
        cleanupTask?.cancel()
    }
}

// MARK: - MemoryManagementDelegate
extension BaseCache: MemoryManagementDelegate {
    nonisolated func handleMemoryWarning() {
        Task { [weak self] in
            try? await self?.performEmergencyCleanup()
        }
    }
    
    nonisolated func handleMemoryPressure(_ pressure: MemoryPressureLevel) {
        Task { [weak self] in
            switch pressure {
            case .low: break
            case .medium:
                try? await self?.performCleanup()
            case .high, .critical:
                try? await self?.performEmergencyCleanup()
            }
        }
    }
    
    nonisolated func handleSystemMemoryChange(_ status: SystemMemoryStatus) {
        Task { [weak self] in
            if status == .warning || status == .critical {
                try? await self?.performEmergencyCleanup()
            }
        }
    }
}
