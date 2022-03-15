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
    
    init(orthoLeft left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) {
        let X = SIMD4<Float>(2 / (right - left), 0, 0, 0)
        let Y = SIMD4<Float>(0, 2 / (top - bottom), 0, 0)
        let Z = SIMD4<Float>(0, 0, 1 / (far - near), 0)
        let W = SIMD4<Float>((left + right) / (left - right),
                       (top + bottom) / (bottom - top),
                       near / (near - far),
                       1)
        self.init()
        columns = (X, Y, Z, W)
    }
    // left-handed LookAt
    init(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) {
        let z = normalize(center-eye)
        let x = normalize(cross(up, z))
        let y = cross(z, x)
        
        let X = SIMD4<Float>(x.x, y.x, z.x, 0)
        let Y = SIMD4<Float>(x.y, y.y, z.y, 0)
        let Z = SIMD4<Float>(x.z, y.z, z.z, 0)
        let W = SIMD4<Float>(-dot(x, eye), -dot(y, eye), -dot(z, eye), 1)
        
        self.init()
        columns = (X, Y, Z, W)
    }
  
    
    var upperLeft: float3x3 {
        let x: SIMD3<Float> = [columns.0.x, columns.0.y, columns.0.z]
        let y: SIMD3<Float> = [columns.1.x, columns.1.y, columns.1.z]
        let z: SIMD3<Float> = [columns.2.x, columns.2.y, columns.2.z]
        return float3x3(columns: (x, y, z))
    }
}

// Generic matrix math utility functions
func matrix4x4_rotation(radians: Float, axis: SIMD3<Float>) -> matrix_float4x4 {
    let unitAxis = normalize(axis)
    let ct = cosf(radians)
    let st = sinf(radians)
    let ci = 1 - ct
    let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
    return matrix_float4x4.init(columns:(vector_float4(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
                                         vector_float4(x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0),
                                         vector_float4(x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0),
                                         vector_float4(                  0,                   0,                   0, 1)))
}

func matrix4x4_translation(_ translationX: Float, _ translationY: Float, _ translationZ: Float) -> matrix_float4x4 {
    return matrix_float4x4.init(columns:(vector_float4(1, 0, 0, 0),
                                         vector_float4(0, 1, 0, 0),
                                         vector_float4(0, 0, 1, 0),
                                         vector_float4(translationX, translationY, translationZ, 1)))
}

func matrix_perspective_left_hand(fovyRadians fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let ys = 1 / tanf(fovy * 0.5)
    let xs = ys / aspectRatio
    let zs = farZ / (nearZ - farZ)
    return matrix_float4x4.init(columns:(vector_float4(xs,  0, 0,   0),
                                         vector_float4( 0, ys, 0,   0),
                                         vector_float4( 0,  0, -zs, 1),
                                         vector_float4( 0,  0, zs * nearZ, 0)))
}

func matrix_perspective_right_hand(fovyRadians fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let ys = 1 / tanf(fovy * 0.5)
    let xs = ys / aspectRatio
    let zs = farZ / (nearZ - farZ)
    return matrix_float4x4.init(columns:(vector_float4(xs,  0, 0,   0),
                                         vector_float4( 0, ys, 0,   0),
                                         vector_float4( 0,  0, zs, -1),
                                         vector_float4( 0,  0, zs * nearZ, 0)))
}

func radians_from_degrees(_ degrees: Float) -> Float {
    return (degrees / 180) * .pi
}
