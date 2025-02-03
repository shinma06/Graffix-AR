
import ARKit

actor WallGroupManager {
    private let cache: WallGroupCache
    private let colorManager: WallColorManager
    private var isInitialized = false
    
    init() {
        self.cache = WallGroupCache()
        self.colorManager = WallColorManager()
    }
    
    func initialize() async throws {
        if isInitialized { return }
        try await cache.initialize()
        isInitialized = true
    }
    
    func addWall(_ wall: ARPlaneAnchor) async throws -> UUID {
        if !isInitialized {
            try await initialize()
        }
        
        guard wall.alignment == .vertical else {
            throw AppError.ar(.wallGroupError("垂直な壁面のみ追加できます"))
        }
        
        // 既存グループとの互換性チェック
        let groups = await cache.getAllGroups()
        for (groupID, anchors) in groups {
            if await isWallCompatible(wall, with: anchors) {
                var updatedAnchors = anchors
                updatedAnchors.append(wall)
                try await cache.store(groupID: groupID, anchors: updatedAnchors)
                return groupID
            }
        }
        
        // 新しいグループの作成
        let newGroupID = UUID()
        try await cache.store(groupID: newGroupID, anchors: [wall])
        await colorManager.assignColor(for: newGroupID)
        return newGroupID
    }
    
    func removeWall(_ wall: ARPlaneAnchor) async {
        let groups = await cache.getAllGroups()
        for (groupID, anchors) in groups {
            if anchors.contains(where: { $0.identifier == wall.identifier }) {
                let updatedAnchors = anchors.filter { $0.identifier != wall.identifier }
                if updatedAnchors.isEmpty {
                    await cache.remove(groupID: groupID)
                    await colorManager.releaseColor(for: groupID)
                } else {
                    try? await cache.store(groupID: groupID, anchors: updatedAnchors)
                }
                return
            }
        }
    }
    
    func getColor(for groupID: UUID) async -> UIColor {
        await colorManager.getColor(for: groupID)
    }
    
    func isWallCompatible(_ wall: ARPlaneAnchor, with groupWalls: [ARPlaneAnchor]) async -> Bool {
        guard wall.alignment == .vertical else { return false }
        
        let wallData = wall.planeNormalAndPosition
        for groupWall in groupWalls {
            let groupWallData = groupWall.planeNormalAndPosition
            let normalDifference = wallData.normal.distance(to: groupWallData.normal)
            let positionDifference = wallData.position.distance(to: groupWallData.position)
            
            if normalDifference < 0.1 && positionDifference < 0.5 {
                return true
            }
        }
        return false
    }
    
    func isInSameGroup(_ wall1: ARPlaneAnchor, as wall2: ARPlaneAnchor) async -> Bool {
        let groups = await cache.getAllGroups()
        return groups.contains { _, anchors in
            anchors.contains { $0.identifier == wall1.identifier } &&
            anchors.contains { $0.identifier == wall2.identifier }
        }
    }
    
    func reset() async {
        let groups = await cache.getAllGroups()
        for (groupID, _) in groups {
            await cache.remove(groupID: groupID)
            await colorManager.releaseColor(for: groupID)
        }
    }
}
