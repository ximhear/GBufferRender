//
//  Composition.metal
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
    float2 texCoords;
};

vertex VertexOut compositionVert(constant float2 *quardVertices [[ buffer(0) ]],
                                 constant float2 *qurdTexCoords [[ buffer(1) ]],
                                 uint id [[ vertex_id ]]) {
    VertexOut out;
    out.position = float4(quardVertices[id], 0, 1);
    out.texCoords = qurdTexCoords[id];
    return out;
}

float3 compositeLighting(float3 normal,
                       float3 position,
                         int lightCount,
                         constant Light *lights,
                       float3 baseColor) {
  float3 diffuseColor = 0;
  float3 normalDirection = normalize(normal);
  for (int i = 0; i < lightCount; i++) {
    Light light = lights[i];
    if (light.type == LightTypeSunlight) {
        float3 lightDirection = normalize(light.position - light.target);
        float diffuseIntensity = saturate(dot(lightDirection, normalDirection));
        if (diffuseIntensity < 0.1) {
            diffuseIntensity = 0.1;
        }
        diffuseColor += light.color * baseColor * diffuseIntensity;
    } else if (light.type == LightTypePointlight) {
        float d = distance(light.position, position);
        float3 lightDirection = normalize(light.position - position);
        float attenuation = 1.0 / (light.attenuation.x + light.attenuation.y * d + light.attenuation.z * d * d);
        float diffuseIntensity = saturate(dot(lightDirection, normalDirection));
        float3 color = light.color * baseColor * diffuseIntensity;
        color *= attenuation;
        diffuseColor += color;
    } else if (light.type == LightTypeSpotlight) {
        float d = distance(light.position, position);
        float3 lightDirection = normalize(light.position - position);
        float3 coneDirection = normalize(-light.coneDirection);
        float spotResult = (dot(lightDirection, coneDirection));
        if (spotResult > cos(light.coneAngle)) {
            float attenuation = 1.0 / (light.attenuation.x + light.attenuation.y * d + light.attenuation.z * d * d);
            attenuation *= pow(spotResult, light.coneAttenuation);
            float diffuseIntensity = saturate(dot(lightDirection, normalDirection));
            float3 color = light.color * baseColor * diffuseIntensity;
            color *= attenuation;
            diffuseColor += color;
        }
    }
  }
  return diffuseColor;
}

fragment float4 compositionFrag(VertexOut in [[ stage_in ]],
                               constant int & lightCount [[ buffer(0) ]],
                               constant Light* lights [[ buffer(1) ]],
                                texture2d<float> albedoTexture [[ texture(0) ]],
                                texture2d<float> normalTexture [[ texture(1) ]],
                                texture2d<float> positionTexture [[ texture(2) ]])
{
    constexpr sampler s(min_filter::linear, mag_filter::linear);
    float4 albedo = albedoTexture.sample(s, in.texCoords);
    float3 normal = normalTexture.sample(s, in.texCoords).xyz;
    float3 position = positionTexture.sample(s, in.texCoords).xyz;
   
    float4 color = float4(compositeLighting(normal, position, lightCount, lights, albedo.rgb), 1);
//    float3 n = normalize(normal);
//    float diffuseIntensity = 1;
//    for (int i = 0 ; i < lightCount; i++) {
//        if (lights[i].type == LightTypeSunlight) {
//            float3 dir = -normalize(lights[i].target - lights[i].position);
//            diffuseIntensity = saturate(dot(dir, n));
//            if (diffuseIntensity < 0.1) {
//                diffuseIntensity = 0.1;
//            }
//        }
//    }
    float shadow = 1;
    if (albedo.a > 0) {
        shadow = 0.5;
    }
//    return albedo * diffuseIntensity * shadow;
    
//    return float4(albedo.rgb, 1);
    return color * shadow;
}



