import SwiftUI
import ARKit
import Combine

@MainActor
class WallTargetingViewModel: ObservableObject {
    enum TargetingState {
        case searching
        case targeting
        case locked
    }
    
    @Published private(set) var targetingState: TargetingState = .searching
    @Published private(set) var currentDistance: Float?
    @Published var errorMessage: String?
    
    private var targetedWall: ARPlaneAnchor?
    private weak var arSceneCoordinator: ARSceneCoordinator?
    
    // 非固定時は距離を表示しない
    func updateTargetedWall(_ wall: ARPlaneAnchor, distance: Float) {
        if targetingState == .locked {
            // 固定モード時は距離を更新
            if let lockedWall = targetedWall,
               wall.identifier == lockedWall.identifier {
                currentDistance = distance
            }
        } else {
            targetedWall = wall
            targetingState = .targeting
            // 非固定時は距離を表示しない
            currentDistance = nil
        }
    }
    
    // 壁面固定処理
    func lockWall() async {
        guard let wall = targetedWall else { return }
        guard let coordinator = arSceneCoordinator else { return }
        
        // 固定状態に移行
        targetingState = .locked
        // ARSceneCoordinatorに固定を通知
        await coordinator.lockWall(with: wall.identifier)
        // 固定後の距離測定開始
        startDistanceMeasurement()
    }
    
    // 固定解除処理
    func unlockWall() {
        guard let coordinator = arSceneCoordinator else { return }
        
        targetingState = .searching
        targetedWall = nil
        currentDistance = nil
        
        Task {
            await coordinator.unlockWall()
        }
    }
    
    // 固定時の距離測定
    private func startDistanceMeasurement() {
        // 距離測定ロジックは今後実装
        // 現状は仮の実装として、updateTargetedWallで更新される距離を表示
        if targetingState == .locked {
            // currentDistanceの更新を許可
        }
    }
    
    func setCoordinator(_ coordinator: ARSceneCoordinator) {
        arSceneCoordinator = coordinator
    }
    
    func clearTarget() {
        if targetingState != .locked {
            targetedWall = nil
            currentDistance = nil
            targetingState = .searching
        }
    }
}
