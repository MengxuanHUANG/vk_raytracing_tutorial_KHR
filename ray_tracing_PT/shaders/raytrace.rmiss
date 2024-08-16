#version 460

#extension GL_GOOGLE_include_directive : require
#extension GL_EXT_shader_explicit_arithmetic_types_int64 : require
#extension GL_EXT_ray_tracing : require

#include "raycommon.glsl"
#include "wavefront.glsl"

layout(location = 0) rayPayloadInEXT hitPayload prd;

layout(push_constant) uniform _PushConstantRay
{
  PushConstantRay pcRay;
};

void main()
{
    //hitValue = vec3(0.0, 0.1, 0.3);
    prd.hitValue = pcRay.clearColor.xyz * 0.8;
}