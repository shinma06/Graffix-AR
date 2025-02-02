import SceneKit
import ARKit

class PlaneNodeUpdater {
    static func updatePlaneNode(_ node: SCNNode, with anchor: ARPlaneAnchor) {
        node.simdPosition = anchor.center
        
        if let geometry = node.geometry as? SCNPlane {
            let newWidth: CGFloat
            let newHeight: CGFloat
            
            if #available(iOS 16.0, *) {
                newWidth = CGFloat(anchor.planeExtent.width)
                newHeight = CGFloat(anchor.planeExtent.height)
            } else {
                newWidth = CGFloat(anchor.extent.x)
                newHeight = CGFloat(anchor.extent.z)
            }
            
            geometry.width = newWidth
            geometry.height = newHeight
            
            if let borderNode = node.childNodes.first,
               let borderGeometry = borderNode.geometry as? SCNPlane {
                borderGeometry.width = newWidth + 0.01
                borderGeometry.height = newHeight + 0.01
            }
        }
    }
}
