import ARKit

extension SIMD4 {
    var xyz: SIMD3<Scalar> {
        SIMD3(x, y, z)
    }
}

extension SIMD3 where Scalar == Float {
    func distance(to other: SIMD3<Float>) -> Float {
        let difference = self - other
        return sqrt(difference.x * difference.x +
                    difference.y * difference.y +
                    difference.z * difference.z)
    }
}

extension ARPlaneAnchor {
    var normal: simd_float3 {
        // 垂直な壁面の場合、法線ベクトルを計算
        // transformのcolumns.2が平面の向きを示す
        transform.columns.2.xyz
    }
    
    var planeNormalAndPosition: (normal: simd_float3, position: simd_float3) {
        (normal: transform.columns.2.xyz,
         position: transform.columns.3.xyz)
    }
}
