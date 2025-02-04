//import ARKit
//import SceneKit
//
//// MARK: - Protocols
//
//protocol WallManaging: AnyObject {
//    func lockWall(with identifier: UUID) async
//    func unlockWall() async
//    func checkWallIntersection(at point: CGPoint, in view: ARSCNView) async
//    func handleWallUpdate(_ wall: ARPlaneAnchor) async
//    var currentLockedWallID: UUID? { get async }
//}
//
//protocol WallManagerDelegate: AnyObject {
//    func wallManager(_ manager: WallManaging, didDetectWall wall: ARPlaneAnchor, at distance: Float) async
//    func wallManager(_ manager: WallManaging, didLockWall wall: ARPlaneAnchor) async
//    func wallManagerDidUnlockWall(_ manager: WallManaging) async
//    func wallManager(_ manager: WallManaging, didFailWithError error: Error) async
//}
//
//// MARK: - WallManager Implementation
//
//actor WallManager: WallManaging {
//    private weak var delegate: WallManagerDelegate?
//    private let wallGroupManager: WallGroupManager
//    private let arSession: ARSession
//    private var lockedWallID: UUID?
//    
//    var currentLockedWallID: UUID? { lockedWallID }
//    
//    init(wallGroupManager: WallGroupManager,
//         arSession: ARSession,
//         delegate: WallManagerDelegate?) {
//        self.wallGroupManager = wallGroupManager
//        self.arSession = arSession
//        self.delegate = delegate
//    }
//    
//    func lockWall(with identifier: UUID) async {
//        guard lockedWallID == nil else { return }
//        
//        do {
//            let walls = await wallGroupManager.getAllWalls()
//            guard let targetWall = walls.first(where: { $0.identifier == identifier }) else { return }
//            
//            lockedWallID = identifier
//            
//            // 他の壁を削除
//            for wall in walls where wall.identifier != identifier {
//                await wallGroupManager.removeWall(wall)
//            }
//            
//            await delegate?.wallManager(self, didLockWall: targetWall)
//        } catch {
//            await delegate?.wallManager(self, didFailWithError: error)
//        }
//    }
//    
//    func unlockWall() async {
//        guard lockedWallID != nil else { return }
//        
//        do {
//            lockedWallID = nil
//            await wallGroupManager.reset()
//            await delegate?.wallManagerDidUnlockWall(self)
//        } catch {
//            await delegate?.wallManager(self, didFailWithError: error)
//        }
//    }
//    
//    func checkWallIntersection(at point: CGPoint, in view: ARSCNView) async {
//        guard let query = await MainActor.run(resultType: ARRaycastQuery?.self) {
//            view.raycastQuery(
//                from: point,
//                allowing: .existingPlaneGeometry,
//                alignment: .vertical
//            )
//        } else { return }
//        
//        let results = await MainActor.run {
//            view.session.raycast(query)
//        }
//        
//        guard let result = results.first,
//              let anchor = result.anchor as? ARPlaneAnchor else { return }
//        
//        let distance = simd_length(result.worldTransform.columns.3.xyz)
//        await delegate?.wallManager(self, didDetectWall: anchor, at: distance)
//    }
//    
//    func handleWallUpdate(_ wall: ARPlaneAnchor) async {
//        if let lockedID = lockedWallID {
//            // 固定モード時は同じグループの壁のみ更新
//            let isInSameGroup = await wallGroupManager.isInSameGroup(wall, as: wall)
//            if isInSameGroup {
//                try? await wallGroupManager.addWall(wall)
//            }
//        } else {
//            // フリーモード時は全ての壁を更新
//            try? await wallGroupManager.addWall(wall)
//        }
//    }
//}
