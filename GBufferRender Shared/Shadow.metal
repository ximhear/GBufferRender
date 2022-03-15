//
//  Shadow.metal
//  GBufferRender
//
//  Created by gzonelee on 2022/03/16.
//

#include <metal_stdlib>
#include <simd/simd.h>
#import "ShaderTypes.h"
using namespace metal;

struct VertexIn {
    float4 position [[ attribute(0) ]];
};

vertex float4 vertex_depth(const VertexIn vertexIn [[ stage_in ]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                               constant InstanceUniforms & instanceUniforms [[ buffer(BufferIndexModelUniforms) ]])
{
    matrix_float4x4 mvp = uniforms.projectionMatrix * uniforms.viewMatrix * instanceUniforms.modelMatrix;
    float4 pos = mvp * vertexIn.position;
    return pos;
}
