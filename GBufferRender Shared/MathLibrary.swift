//
//  MathLibrary.swift
//  GBufferRender
//
//  Created by gzonelee on 2022/03/15.
//

import Foundation
import simd

extension float4x4 {
    static func identity() -> float4x4 {
        matrix_identity_float4x4
    }
    
    init(translation: SIMD3<Float>) {
        let matrix = float4x4(
                [            1,             0,             0, 0],
                [            0,             1,             0, 0],
                [            0,             0,             1, 0],
                [translation.x, translation.y, translation.z, 1]
        )
        self = matrix
    }
    
    init(rotationY angle: Float) {
        let matrix = float4x4(
                [cos(angle), 0, -sin(angle), 0],
                [         0, 1,           0, 0],
                [sin(angle), 0,  cos(angle), 0],
                [         0, 0,           0, 1]
        )
        self = matrix
    }

    init(scaling: SIMD3<Float>) {
        let matrix = float4x4(
                [scaling.x,         0,         0, 0],
                [        0, scaling.y,         0, 0],
                [        0,         0, scaling.z, 0],
                [        0,         0,         0, 1]
        )
        self = matrix
    }
    
    var upperLeft: float3x3 {
        let x: SIMD3<Float> = [columns.0.x, columns.0.y, columns.0.z]
        let y: SIMD3<Float> = [columns.1.x, columns.1.y, columns.1.z]
        let z: SIMD3<Float> = [columns.2.x, columns.2.y, columns.2.z]
        return float3x3(columns: (x, y, z))
    }
}
