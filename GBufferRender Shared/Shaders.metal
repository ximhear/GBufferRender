//
//  Shaders.metal
//  GBufferRender Shared
//
//  Created by gzonelee on 2022/03/15.
//

// File for Metal kernel and shader functions

#include <metal_stdlib>
#include <simd/simd.h>

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "ShaderTypes.h"

using namespace metal;

typedef struct
{
    float3 position [[attribute(VertexAttributePosition)]];
    float2 texCoord [[attribute(VertexAttributeTexcoord)]];
    float3 normal [[attribute(VertexAttributeNormal)]];
} Vertex;

typedef struct
{
    float4 position [[position]];
    float2 texCoord;
    float3 worldNormal;
    float3 worldPosition;
    float4 shadowPosition;
} ColorInOut;

vertex ColorInOut vertexShader(Vertex in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                               constant InstanceUniforms & instanceUniforms [[ buffer(BufferIndexModelUniforms) ]])
{
    ColorInOut out;

    float4 position = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * instanceUniforms.modelMatrix * position;
    out.texCoord = in.texCoord;
    out.worldPosition = (instanceUniforms.modelMatrix * position).xyz;
    out.worldNormal = (instanceUniforms.normalMatrix * float4(in.normal, 1)).xyz;
    out.shadowPosition = uniforms.shadowMatrix * instanceUniforms.modelMatrix * position;
    return out;
}

fragment float4 fragmentShader(ColorInOut in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                               constant float4 & color     [[ buffer(BufferIndexColor) ]],
                               constant int & lightCount [[ buffer(BufferIndexLightCount) ]],
                               constant Light* lights [[ buffer(BufferIndexLights) ]],
                               depth2d<float> shadowTextue [[ texture(TextureIndexDepth) ]])
{
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);
    
    float2 xy = in.shadowPosition.xy;
    xy = xy * 0.5 + 0.5;
    xy.y = 1 - xy.y;

    float3 n = normalize(in.worldNormal);
//    return float4(n, 1);
    float diffuseIntensity = 1;
    for (int i = 0 ; i < lightCount; i++) {
        if (lights[i].type == LightTypeSunlight) {
            float3 dir = -normalize(lights[i].target - lights[i].position);
            diffuseIntensity = saturate(dot(dir, n));
            if (diffuseIntensity < 0.1) {
                diffuseIntensity = 0.1;
            }
        }
    }
    
    constexpr sampler s(coord::normalized, filter::linear, address::clamp_to_edge, compare_func::less);
    float shadow = shadowTextue.sample(s, xy);
    float current = in.shadowPosition.z / in.shadowPosition.w;
    float shadowFactor = 1;
    if (current > shadow) {
        shadowFactor = 0.5;
    }
//    return float4(n, 1);
    //    return float4(diffuseIntensity, diffuseIntensity, diffuseIntensity, 1);
//    return color;
//    return float4(shadowFactor, 0, 0, 1);
    return color * diffuseIntensity * shadowFactor;
}
