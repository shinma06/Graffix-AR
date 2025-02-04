//import ARKit
//import SceneKit
//
//// MARK: - Protocols
//
//protocol RenderingManagerDelegate: AnyObject {
//    func renderingManager(_ manager: RenderingManager, didFailWithError error: Error) async
//    func renderingManager(_ manager: RenderingManager, didUpdateWalls walls: [ARPlaneAnchor]) async
//}
//
//protocol RenderingManaging: AnyObject {
//    func handleNodeAddition(_ node: SCNNode, for anchor: ARAnchor) async
//    func handleNodeUpdate(_ node: SCNNode, for anchor: ARAnchor) async
//    func handleNodeRemoval(_ node: SCNNode, for anchor: ARAnchor) async
//    func setLockedWallID(_ identifier: UUID?) async
//    func clearRenderingState() async
//}
//
//// MARK: - RenderingManager Implementation
//
//actor RenderingManager: RenderingManaging {
//    private weak var delegate: RenderingManagerDelegate?
//    private let planeNodeCache: PlaneNodeCache
//    private let wallGroupManager: WallGroupManager
//    private var lockedWallID: UUID?
//    private var renderTasks: [UUID: Task<Void, Never>] = [:]
//    
//    init(planeNodeCache: PlaneNodeCache,
//         wallGroupManager: WallGroupManager,
//         delegate: RenderingManagerDelegate?) {
//        self.planeNodeCache = planeNodeCache
//        self.wallGroupManager = wallGroupManager
//        self.delegate = delegate
//    }
//    
//    func handleNodeAddition(_ node: SCNNode, for anchor: ARAnchor) async {
//        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
//        
//        let taskID = planeAnchor.identifier
//        renderTasks[taskID]?.cancel()
//        renderTasks[taskID] = Task { [weak self] in
//            guard let self = self else { return }
//            do {
//                if let lockedID = self.lockedWallID {
//                    try await self.handleLockedWallNodeAddition(node, planeAnchor: planeAnchor, lockedID: lockedID)
//                } else {
//                    try await self.handleFreeWallNodeAddition(node, planeAnchor: planeAnchor)
//                }
//            } catch {
//                if !Task.isCancelled {
//                    await self.delegate?.renderingManager(self, didFailWithError: error)
//                }
//            }
//        }
//    }
//    
//    func handleNodeUpdate(_ node: SCNNode, for anchor: ARAnchor) async {
//        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
//        
//        let taskID = planeAnchor.identifier
//        renderTasks[taskID]?.cancel()
//        renderTasks[taskID] = Task { [weak self] in
//            guard let self = self else { return }
//            do {
//                let planeNode = try await self.planeNodeCache.getNode(for: planeAnchor.identifier)
//                let groupID = try await self.wallGroupManager.addWall(planeAnchor)
//                let color = await self.wallGroupManager.getColor(for: groupID)
//                
//                await MainActor.run {
//                    PlaneNodeUpdater.updatePlaneNode(planeNode, with: planeAnchor)
//                    planeNode.geometry?.firstMaterial?.diffuse.contents = color
//                }
//                
//                await self.notifyWallsUpdate()
//            } catch {
//                if !Task.isCancelled {
//                    await self.delegate?.renderingManager(self, didFailWithError: error)
//                }
//            }
//        }
//    }
//    
//    func handleNodeRemoval(_ node: SCNNode, for anchor: ARAnchor) async {
//        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
//        
//        let taskID = planeAnchor.identifier
//        renderTasks[taskID]?.cancel()
//        renderTasks[taskID] = Task { [weak self] in
//            guard let self = self else { return }
//            do {
//                if let lockedID = self.lockedWallID, planeAnchor.identifier == lockedID {
//                    return
//                }
//                
//                try await self.planeNodeCache.remove(identifier: planeAnchor.identifier)
//                await self.wallGroupManager.removeWall(planeAnchor)
//                await self.notifyWallsUpdate()
//            } catch {
//                if !Task.isCancelled {
//                    await self.delegate?.renderingManager(self, didFailWithError: error)
//                }
//            }
//        }
//    }
//    
//    func setLockedWallID(_ identifier: UUID?) async {
//        self.lockedWallID = identifier
//    }
//    
//    func clearRenderingState() async {
//        for task in renderTasks.values {
//            task.cancel()
//        }
//        renderTasks.removeAll()
//    }
//    
//    // MARK: - Private Methods
//    
//    private func handleLockedWallNodeAddition(_ node: SCNNode, planeAnchor: ARPlaneAnchor, lockedID: UUID) async throws {
//        let isInSameGroup = await wallGroupManager.isInSameGroup(planeAnchor, as: planeAnchor)
//        if isInSameGroup {
//            let groupID = try await wallGroupManager.addWall(planeAnchor)
//            let color = await wallGroupManager.getColor(for: groupID)
//            let planeNode = PlaneNodeFactory.createPlaneNode(for: planeAnchor, color: color)
//            
//            await MainActor.run {
//                node.addChildNode(planeNode)
//            }
//            
//            try await planeNodeCache.store(identifier: planeAnchor.identifier, node: planeNode)
//        }
//    }
//    
//    private func handleFreeWallNodeAddition(_ node: SCNNode, planeAnchor: ARPlaneAnchor) async throws {
//        let groupID = try await wallGroupManager.addWall(planeAnchor)
//        let color = await wallGroupManager.getColor(for: groupID)
//        let planeNode = PlaneNodeFactory.createPlaneNode(for: planeAnchor, color: color)
//        
//        await MainActor.run {
//            node.addChildNode(planeNode)
//        }
//        
//        try await planeNodeCache.store(identifier: planeAnchor.identifier, node: planeNode)
//        await notifyWallsUpdate()
//    }
//    
//    private func notifyWallsUpdate() async {
//        let detectedWalls = await wallGroupManager.getAllWalls()
//        await delegate?.renderingManager(self, didUpdateWalls: detectedWalls)
//    }
//    
//    deinit {
//        renderTasks.values.forEach { $0.cancel() }
//    }
//}
