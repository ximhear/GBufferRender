//
//  ShaderTypes.h
//  GBufferRender Shared
//
//  Created by gzonelee on 2022/03/15.
//

//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//
#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

typedef NS_ENUM(NSInteger, BufferIndex)
{
    BufferIndexMeshPositions = 0,
    BufferIndexMeshGenerics  = 1,
    BufferIndexMeshNormal  = 2,
    BufferIndexUniforms      = 3,
    BufferIndexColor      = 4,
    BufferIndexModelUniforms      = 5,
    BufferIndexLightCount      = 6,
    BufferIndexLights      = 7,
};

typedef NS_ENUM(NSInteger, VertexAttribute)
{
    VertexAttributePosition  = 0,
    VertexAttributeTexcoord  = 1,
    VertexAttributeNormal  = 2,
};

typedef NS_ENUM(NSInteger, TextureIndex)
{
    TextureIndexColor    = 0,
    TextureIndexDepth    = 1,
};

typedef NS_ENUM(NSInteger, LightType)
{
    LightTypeSunlight    = 0,
    LightTypeSpotlight    = 1,
    LightTypePointlight    = 2
};
typedef struct
{
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 shadowMatrix;
} Uniforms;

typedef struct
{
    matrix_float4x4 modelMatrix;
    matrix_float4x4 normalMatrix;
} InstanceUniforms;


typedef struct {
    LightType type;
    vector_float3 color;
    vector_float3 position;
    vector_float3 target;
    vector_float3 attenuation;
    float coneAngle;
    vector_float3 coneDirection;
    float coneAttenuation;
} Light;

#endif /* ShaderTypes_h */

