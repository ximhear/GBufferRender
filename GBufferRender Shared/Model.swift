//
//  Model.swift
//  GBufferRender
//
//  Created by gzonelee on 2022/03/16.
//

import Foundation
import MetalKit

class Model {
    var uniforms: InstanceUniforms = InstanceUniforms(modelMatrix: .identity(), normalMatrix: float4x4.identity())
    var color: SIMD4<Float> = [1, 0, 0, 1]
    var scale: SIMD3<Float> = [1, 1, 1]
    var position: SIMD3<Float> = [0, 0, 0] {
        didSet {
            uniforms.modelMatrix = calcModelMatrix()
            uniforms.normalMatrix = uniforms.modelMatrix.inverse.transpose
        }
    }
    var rotationY: Float = 0 {
        didSet {
            uniforms.modelMatrix = calcModelMatrix()
            uniforms.normalMatrix = uniforms.modelMatrix.inverse.transpose
        }
    }
    var mesh: MTKMesh
    
    init(mesh: MTKMesh) {
        self.mesh = mesh
    }
    
    func calcModelMatrix() -> float4x4 {
        float4x4(translation: position) * float4x4(rotationY: rotationY) * float4x4(scaling: scale)
    }
    
    func render(renderEncoder: MTLRenderCommandEncoder, prepare: (Model) -> Void) {
        prepare(self)
        for (index, element) in mesh.vertexDescriptor.layouts.enumerated() {
            guard let layout = element as? MDLVertexBufferLayout else {
                return
            }
            
            if layout.stride != 0 {
                let buffer = mesh.vertexBuffers[index]
                renderEncoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
            }
        }
        
        renderEncoder.setVertexBytes(&uniforms, length:MemoryLayout<InstanceUniforms>.stride, index: BufferIndex.modelUniforms.rawValue)
        
        renderEncoder.setFragmentBytes(&color, length: MemoryLayout<SIMD4<Float>>.stride, index: BufferIndex.color.rawValue)
        
        for submesh in mesh.submeshes {
            renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer.buffer,
                                                indexBufferOffset: submesh.indexBuffer.offset)
            
            
        }
        
    }
}

