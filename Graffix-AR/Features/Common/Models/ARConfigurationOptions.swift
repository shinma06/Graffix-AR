import ARKit

struct ARConfigurationOptions {
    let preferredFPS: Int
    let useAntialiasing: Bool
    let frameSemantics: ARWorldTrackingConfiguration.FrameSemantics
    let showDebugOptions: Bool
    let usePersonSegmentation: Bool
    
    static func defaultOptions() -> ARConfigurationOptions {
        ARConfigurationOptions(
            preferredFPS: 60,
            useAntialiasing: true,
            frameSemantics: [.smoothedSceneDepth, .sceneDepth],
            showDebugOptions: false,
            usePersonSegmentation: true
        )
    }
    
    static func lowPerformanceOptions() -> ARConfigurationOptions {
        ARConfigurationOptions(
            preferredFPS: 30,
            useAntialiasing: false,
            frameSemantics: [],
            showDebugOptions: false,
            usePersonSegmentation: false
        )
    }
}
