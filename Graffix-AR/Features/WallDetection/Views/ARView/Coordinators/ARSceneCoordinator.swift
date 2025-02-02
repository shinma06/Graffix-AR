import ARKit
import SceneKit
import SwiftUI

class ARSceneCoordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
    let arViewHolder = ARViewHolder()
    private let parent: ARViewContainer
    private let wallGroupManager: WallGroupManager
    private let planeNodeCache: PlaneNodeCache
    private var lockedWallID: UUID?
    private var renderTasks: [UUID: Task<Void, Never>] = [:]
    private var cleanupTask: Task<Void, Never>?
    private let wallTargetingVM: WallTargetingViewModel
    private var intersectionCheckTask: Task<Void, Never>?
    
    init(_ parent: ARViewContainer, wallTargetingVM: WallTargetingViewModel) {
        self.parent = parent
        self.wallGroupManager = WallGroupManager()
        self.planeNodeCache = PlaneNodeCache()
        self.wallTargetingVM = wallTargetingVM
        super.init()
        
        Task {
            do {
                try await planeNodeCache.initialize()
            } catch {
                await handleError(error)
            }
        }
        
        setupTasks()
        setupMemoryWarningObserver()
    }
    
    private func setupTasks() {
        setupCleanupTask()
        setupIntersectionCheck()
    }
    
    private func setupCleanupTask() {
        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                do {
                    try await Task.sleep(nanoseconds: UInt64(30 * 1_000_000_000))
                    await self.performCleanup()
                } catch {
                    if !Task.isCancelled {
                        await self.handleError(error)
                    }
                }
            }
        }
    }
    
    private func setupIntersectionCheck() {
        intersectionCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                await self.checkIntersection()
                try? await Task.sleep(nanoseconds: UInt64(1.0 / 30.0 * 1_000_000_000))
            }
        }
    }
    
    private func checkIntersection() async {
        guard let arView = arViewHolder.view else { return }
        
        let bounds = await arView.bounds
        let viewCenter = CGPoint(
            x: bounds.width / 2,
            y: bounds.height / 2
        )
        
        if let result = await performRaycast(from: viewCenter, in: arView),
           let anchor = result.anchor as? ARPlaneAnchor {
            let distance = simd_length(result.worldTransform.columns.3.xyz)
            await wallTargetingVM.updateTargetedWall(anchor, distance: distance)
        } else {
            await wallTargetingVM.clearTarget()
        }
    }
    
    private func performRaycast(from point: CGPoint, in view: ARSCNView) async -> ARRaycastResult? {
        await MainActor.run {
            guard let query = view.raycastQuery(
                from: point,
                allowing: .existingPlaneGeometry,
                alignment: .vertical
            ) else { return nil }
            
            return view.session.raycast(query).first
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        let taskID = planeAnchor.identifier
        renderTasks[taskID]?.cancel()
        renderTasks[taskID] = Task { [weak self] in
            guard let self = self else { return }
            do {
                if let lockedID = self.lockedWallID {
                    let detectedWalls = await MainActor.run { self.parent.viewModel.detectedWalls }
                    if let lockedWall = detectedWalls.first(where: { $0.identifier == lockedID }) {
                        let isInSameGroup = await self.wallGroupManager.isInSameGroup(planeAnchor, as: lockedWall)
                        if isInSameGroup {
                            let groupID = try await self.wallGroupManager.addWall(planeAnchor)
                            let color = await self.wallGroupManager.getColor(for: groupID)
                            let planeNode = PlaneNodeFactory.createPlaneNode(for: planeAnchor, color: color)
                            
                            await MainActor.run {
                                node.addChildNode(planeNode)
                            }
                            
                            try await self.planeNodeCache.store(identifier: planeAnchor.identifier, node: planeNode)
                        }
                    }
                } else {
                    let groupID = try await self.wallGroupManager.addWall(planeAnchor)
                    await updateDetectedWalls { walls in
                        walls.append(planeAnchor)
                    }
                    
                    let color = await self.wallGroupManager.getColor(for: groupID)
                    let planeNode = PlaneNodeFactory.createPlaneNode(for: planeAnchor, color: color)
                    
                    await MainActor.run {
                        node.addChildNode(planeNode)
                    }
                    
                    try await self.planeNodeCache.store(identifier: planeAnchor.identifier, node: planeNode)
                }
            } catch {
                if !Task.isCancelled {
                    await self.handleError(error)
                }
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        let taskID = planeAnchor.identifier
        renderTasks[taskID]?.cancel()
        renderTasks[taskID] = Task { [weak self] in
            guard let self = self else { return }
            do {
                if let lockedID = self.lockedWallID {
                    let detectedWalls = await MainActor.run { self.parent.viewModel.detectedWalls }
                    if let lockedWall = detectedWalls.first(where: { $0.identifier == lockedID }) {
                        let isInSameGroup = await self.wallGroupManager.isInSameGroup(planeAnchor, as: lockedWall)
                        if isInSameGroup {
                            let groupID = try await self.wallGroupManager.addWall(planeAnchor)
                            let color = await self.wallGroupManager.getColor(for: groupID)
                            
                            let planeNode = try await self.planeNodeCache.getNode(for: planeAnchor.identifier)
                            await MainActor.run {
                                PlaneNodeUpdater.updatePlaneNode(planeNode, with: planeAnchor)
                                planeNode.geometry?.firstMaterial?.diffuse.contents = color
                            }
                        }
                    }
                } else {
                    let groupID = try await self.wallGroupManager.addWall(planeAnchor)
                    let color = await self.wallGroupManager.getColor(for: groupID)
                    
                    let planeNode = try await self.planeNodeCache.getNode(for: planeAnchor.identifier)
                    await MainActor.run {
                        PlaneNodeUpdater.updatePlaneNode(planeNode, with: planeAnchor)
                        planeNode.geometry?.firstMaterial?.diffuse.contents = color
                    }
                    
                    await updateDetectedWalls { walls in
                        if let index = walls.firstIndex(where: { $0.identifier == planeAnchor.identifier }) {
                            walls[index] = planeAnchor
                        }
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await self.handleError(error)
                }
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        let taskID = planeAnchor.identifier
        renderTasks[taskID]?.cancel()
        renderTasks[taskID] = Task { [weak self] in
            guard let self = self else { return }
            do {
                if let lockedID = self.lockedWallID, planeAnchor.identifier == lockedID {
                    return
                }
                
                await updateDetectedWalls { walls in
                    walls.removeAll { $0.identifier == planeAnchor.identifier }
                }
                
                try await self.planeNodeCache.remove(identifier: planeAnchor.identifier)
                await self.wallGroupManager.removeWall(planeAnchor)
            } catch {
                if !Task.isCancelled {
                    await self.handleError(error)
                }
            }
        }
    }
    
    private func handleError(_ error: Error) async {
        await MainActor.run {
            if let appError = error as? AppError {
                parent.viewModel.handleError(appError)
            } else {
                parent.viewModel.handleError(.system(.unexpectedState(error.localizedDescription)))
            }
        }
    }
    
    private func updateDetectedWalls(_ update: (inout [ARPlaneAnchor]) -> Void) async {
        await MainActor.run {
            var walls = parent.viewModel.detectedWalls
            update(&walls)
            parent.viewModel.detectedWalls = walls
        }
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        if lockedWallID == nil {
            Task {
                await performCleanup()
            }
        }
    }
    
    private func performCleanup() async {
        guard lockedWallID == nil else { return }
        
        let unusedNodes = await planeNodeCache.getUnusedNodes()
        for identifier in unusedNodes {
            do {
                try await planeNodeCache.remove(identifier: identifier)
            } catch {
                await handleError(error)
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        renderTasks.values.forEach { $0.cancel() }
        renderTasks.removeAll()
        cleanupTask?.cancel()
        intersectionCheckTask?.cancel()
    }
    
    func lockWall(with identifier: UUID) async {
        let detectedWalls = await MainActor.run { parent.viewModel.detectedWalls }
        guard let targetWall = detectedWalls.first(where: { $0.identifier == identifier }) else { return }
        
        self.lockedWallID = identifier
        
        for wall in detectedWalls where wall.identifier != identifier {
            try? await planeNodeCache.remove(identifier: wall.identifier)
            await wallGroupManager.removeWall(wall)
        }
        
        await updateDetectedWalls { walls in
            walls = [targetWall]
        }
        
        guard let arView = arViewHolder.view else { return }
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.vertical]
        await arView.session.run(configuration, options: [])
    }
    
    func unlockWall() async {
        self.lockedWallID = nil
        
        let detectedWalls = await MainActor.run { parent.viewModel.detectedWalls }
        
        for wall in detectedWalls {
            try? await planeNodeCache.remove(identifier: wall.identifier)
            await wallGroupManager.removeWall(wall)
        }
        
        await updateDetectedWalls { walls in
            walls.removeAll()
        }
        
        guard let arView = arViewHolder.view else { return }
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.vertical]
        await arView.session.run(
            configuration,
            options: [.resetTracking, .removeExistingAnchors]
        )
    }
}
