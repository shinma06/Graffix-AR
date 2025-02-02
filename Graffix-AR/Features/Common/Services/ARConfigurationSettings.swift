import ARKit
import SceneKit

/// AR機能の設定を管理する構造体群
enum ARConfigurationSettings {
    // MARK: - Core Settings
    
    /// 基本セッション設定
    struct Core {
        /// 平面検出の設定
        static let planeDetection: ARWorldTrackingConfiguration.PlaneDetection = [.vertical]
        
        /// 環境テクスチャの設定
        static let environmentTexturing: ARWorldTrackingConfiguration.EnvironmentTexturing = .automatic
    }
    
    // MARK: - Session Management
    
    /// セッション管理設定
    struct Session {
        /// リセットオプション
        static let defaultResetOptions: ARSession.RunOptions = [.resetTracking, .removeExistingAnchors]
        static let fullResetOptions: ARSession.RunOptions = defaultResetOptions.union(.resetSceneReconstruction)
        
        /// フレームセマンティクス
        struct FrameSemantics {
            /// 高性能モード: シーンの深度データを処理
            static let high: ARWorldTrackingConfiguration.FrameSemantics = [.smoothedSceneDepth, .sceneDepth]
            /// 中性能モード: 平滑化された深度のみ
            static let medium: ARWorldTrackingConfiguration.FrameSemantics = [.smoothedSceneDepth]
            /// 低性能モード: 最小限の機能
            static let low: ARWorldTrackingConfiguration.FrameSemantics = []
        }
    }
    
    // MARK: - Performance Settings
    
    /// パフォーマンス関連設定
    struct Performance {
        /// フレームレート設定
        struct FrameRate {
            static let high = 60
            static let medium = 45
            static let low = 30
        }
        
        /// システムリソースのしきい値
        struct Thresholds {
            /// プロセッサ数のしきい値
            static let processor = (
                high: 6,    // 6コア以上で高性能モード
                medium: 4   // 4-5コアで中性能モード
            )
            
            /// メモリ容量のしきい値（GB単位）
            static let memory = (
                minimum: 2.0,   // 2GB未満は低性能モード
                standard: 4.0   // 4GB未満は中性能モード
            )
        }
        
        /// モニタリング設定
        struct Monitoring {
            /// アンカー数の警告しきい値
            static let maxAnchors = 30
            /// 更新間隔（秒）
            static let updateInterval: TimeInterval = 1.0
            /// 熱状態回復の待機時間（秒）
            static let thermalRecoveryDelay: TimeInterval = 5.0
        }
    }
    
    // MARK: - Rendering Settings
    
    /// レンダリング関連設定
    struct Rendering {
        /// アンチエイリアシング設定
        static let antialiasing = (
            none: SCNAntialiasingMode.none,
            high: SCNAntialiasingMode.multisampling4X
        )
        
#if DEBUG
        /// デバッグ表示オプション（デバッグビルドのみ）
        static let debugOptions: SCNDebugOptions = [.showFeaturePoints, .showWorldOrigin]
#endif
    }
    
    // MARK: - Device Specific Settings
    
    /// デバイス固有の設定
    struct Device {
        /// デバイスタイプに基づく設定を取得
        static func getSpecificSettings() -> (maxAnchors: Int, preferHighPerformance: Bool) {
            switch UIDevice.current.userInterfaceIdiom {
            case .pad:
                return (maxAnchors: 50, preferHighPerformance: true)
            default:
                return (maxAnchors: 30, preferHighPerformance: false)
            }
        }
    }
    
    // MARK: - Feature Availability
    
    /// 機能の利用可否判定
    struct Features {
        /// iOS 14以降の拡張機能が利用可能かどうか
        static var hasAdvancedFeatures: Bool {
            if #available(iOS 14.0, *) {
                return true
            }
            return false
        }
    }
}
