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

    return out;
}

fragment float4 fragmentShader(ColorInOut in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                               constant float4 & color     [[ buffer(BufferIndexColor) ]],
                               constant int & lightCount [[ buffer(BufferIndexLightCount) ]],
                               constant Light* lights [[ buffer(BufferIndexLights) ]])
{
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);

    float3 n = normalize(in.worldNormal);
//    return float4(n, 1);
    float diffuseIntensity = 1;
    for (int i = 0 ; i < lightCount; i++) {
        if (lights[i].type == LightTypeSpotlight) {
            float3 dir = -normalize(lights[i].target - lights[i].position);
            diffuseIntensity = saturate(dot(dir, n));
            if (diffuseIntensity < 0.1) {
                diffuseIntensity = 0.1;
            }
        }
    }
//    return float4(n, 1);
    //    return float4(diffuseIntensity, diffuseIntensity, diffuseIntensity, 1);
//    return color;
    return color * diffuseIntensity;
}
