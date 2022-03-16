//
//  GBuffer.metal
//  GBufferRender
//
//  Created by gzonelee on 2022/03/17.
//

#include <metal_stdlib>
#include <simd/simd.h>
#import "ShaderTypes.h"
using namespace metal;

struct VertexOut {
    float4 position [[ position ]];
    float3 worldPosition;
    float3 worldNormal;
    float4 shadowPosition;
};


struct GBufferOut {
    float4 albedo [[ color(0) ]];
    float4 normal [[ color(1) ]];
    float4 position [[ color(2) ]];
};

fragment GBufferOut gBufferFragment(VertexOut in [[ stage_in ]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                               constant float4 & color     [[ buffer(BufferIndexColor) ]],
                               constant int & lightCount [[ buffer(BufferIndexLightCount) ]],
                               constant Light* lights [[ buffer(BufferIndexLights) ]],
                               depth2d<float> shadowTextue [[ texture(TextureIndexDepth) ]])
{
    GBufferOut out;
    out.albedo = color;
    out.albedo.a = 0;
    out.normal = float4(in.worldNormal, 1);
    out.position = float4(in.worldPosition, 1);
    
    float2 xy = in.shadowPosition.xy;
    xy = xy * 0.5 + 0.5;
    xy.y = 1 - xy.y;

    constexpr sampler s(coord::normalized, filter::linear, address::clamp_to_edge, compare_func::less);
    float shadow = shadowTextue.sample(s, xy);
    float current = in.shadowPosition.z / in.shadowPosition.w;
    if (current > shadow) {
        out.albedo.a = 1;
    }
    return out;
}
