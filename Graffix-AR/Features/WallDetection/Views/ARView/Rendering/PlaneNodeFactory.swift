import SceneKit
import ARKit

class PlaneNodeFactory {
    static func createPlaneNode(for anchor: ARPlaneAnchor, color: UIColor) -> SCNNode {
        let planeGeometry = createPlaneGeometry(for: anchor)
        let material = createMaterial(with: color)
        planeGeometry.materials = [material]
        
        let planeNode = SCNNode(geometry: planeGeometry)
        planeNode.simdPosition = anchor.center
        planeNode.eulerAngles.x = -Float.pi / 2
        
        let borderNode = createBorderNode(for: planeGeometry, color: color.withAlphaComponent(0.8))
        planeNode.addChildNode(borderNode)
        
        return planeNode
    }
    
    private static func createPlaneGeometry(for anchor: ARPlaneAnchor) -> SCNPlane {
        if #available(iOS 16.0, *) {
            return SCNPlane(width: CGFloat(anchor.planeExtent.width),
                            height: CGFloat(anchor.planeExtent.height))
        } else {
            return SCNPlane(width: CGFloat(anchor.extent.x),
                            height: CGFloat(anchor.extent.z))
        }
    }
    
    private static func createMaterial(with color: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.isDoubleSided = true
        material.lightingModel = .constant
        material.writesToDepthBuffer = true
        material.readsFromDepthBuffer = true
        return material
    }
    
    private static func createBorderNode(for geometry: SCNPlane, color: UIColor) -> SCNNode {
        let borderGeometry = SCNPlane(width: geometry.width + 0.01,
                                      height: geometry.height + 0.01)
        
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.isDoubleSided = true
        material.lightingModel = .constant
        
        borderGeometry.materials = [material]
        
        let borderNode = SCNNode(geometry: borderGeometry)
        borderNode.position.z = 0.001
        
        return borderNode
    }
}
