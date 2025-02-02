import ARKit
import SceneKit

@MainActor
final class ARConfigurationServiceImpl: ARConfigurationService {
    private let performanceMonitor: DevicePerformanceMonitor
    
    init(performanceMonitor: DevicePerformanceMonitor) {
        self.performanceMonitor = performanceMonitor
    }
    
    func createConfiguration() -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        let options = createOptionsForCurrentPerformance()
        
        // 基本設定
        configuration.planeDetection = ARConfigurationSettings.Core.planeDetection
        configuration.environmentTexturing = ARConfigurationSettings.Core.environmentTexturing
        configuration.frameSemantics = options.frameSemantics
        
        if ARConfigurationSettings.Features.hasAdvancedFeatures {
            configuration.isAutoFocusEnabled = true
        }
        
        if options.usePersonSegmentation {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        }
        
        return configuration
    }
    
    func getDefaultRunOptions() -> ARSession.RunOptions {
        performanceMonitor.currentLevel == .high
        ? ARConfigurationSettings.Session.fullResetOptions
        : ARConfigurationSettings.Session.defaultResetOptions
    }
    
    func configureView(_ view: ARSCNView) {
        let options = createOptionsForCurrentPerformance()
        
        view.preferredFramesPerSecond = options.preferredFPS
        configureRendering(view, options: options)
        view.automaticallyUpdatesLighting = true
    }
    
    func updateConfiguration(_ configuration: ARWorldTrackingConfiguration) {
        let options = createOptionsForCurrentPerformance()
        configuration.frameSemantics = options.frameSemantics
        
        if options.usePersonSegmentation {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        }
    }
    
#if DEBUG
    func monitorPerformance(_ session: ARSession) {
        guard let frame = session.currentFrame else { return }
        
        let metrics: [String: Any] = [
            "Frame Timestamp": frame.timestamp,
            "Tracking State": String(describing: frame.camera.trackingState),
            "Camera Transform": frame.camera.transform,
            "Anchor Count": frame.anchors.count
        ]
        
        print("AR Performance Metrics:", metrics)
        
        if frame.anchors.count > ARConfigurationSettings.Performance.Monitoring.maxAnchors {
            print("Warning: High anchor count (\(frame.anchors.count))")
        }
        
        if case .limited(let reason) = frame.camera.trackingState {
            print("Limited Tracking Reason: \(reason)")
        }
    }
#endif
    
    // MARK: - Private Methods
    
    private func createOptionsForCurrentPerformance() -> ARConfigurationOptions {
        let deviceSettings = ARConfigurationSettings.Device.getSpecificSettings()
        
        switch performanceMonitor.currentLevel {
        case .high:
            return ARConfigurationOptions(
                preferredFPS: ARConfigurationSettings.Performance.FrameRate.high,
                useAntialiasing: deviceSettings.preferHighPerformance,
                frameSemantics: ARConfigurationSettings.Session.FrameSemantics.high,
                showDebugOptions: false,
                usePersonSegmentation: true
            )
            
        case .medium:
            return ARConfigurationOptions(
                preferredFPS: ARConfigurationSettings.Performance.FrameRate.medium,
                useAntialiasing: false,
                frameSemantics: ARConfigurationSettings.Session.FrameSemantics.medium,
                showDebugOptions: false,
                usePersonSegmentation: true
            )
            
        case .low:
            return ARConfigurationOptions(
                preferredFPS: ARConfigurationSettings.Performance.FrameRate.low,
                useAntialiasing: false,
                frameSemantics: ARConfigurationSettings.Session.FrameSemantics.low,
                showDebugOptions: false,
                usePersonSegmentation: false
            )
        }
    }
    
    private func configureRendering(_ view: ARSCNView, options: ARConfigurationOptions) {
        guard MTLCreateSystemDefaultDevice() != nil else { return }
        
        view.antialiasingMode = options.useAntialiasing
        ? ARConfigurationSettings.Rendering.antialiasing.high
        : ARConfigurationSettings.Rendering.antialiasing.none
        
#if DEBUG
        configureDebug(view, showDebugOptions: options.showDebugOptions)
#endif
    }
    
#if DEBUG
    private func configureDebug(_ view: ARSCNView, showDebugOptions: Bool) {
        view.showsStatistics = showDebugOptions
        view.debugOptions = showDebugOptions ? ARConfigurationSettings.Rendering.debugOptions : []
    }
#endif
}
