#version 460
#extension GL_EXT_ray_tracing : require
#extension GL_EXT_nonuniform_qualifier : enable
#extension GL_EXT_scalar_block_layout : enable
#extension GL_GOOGLE_include_directive : enable

#extension GL_EXT_shader_explicit_arithmetic_types_int64 : require
#extension GL_EXT_buffer_reference2 : require


#include "raycommon.glsl"
#include "wavefront.glsl"

hitAttributeEXT vec2 attribs;

layout(location = 0) rayPayloadInEXT hitPayload prd;

layout(buffer_reference, scalar) buffer Vertices { Vertex v[]; }; // Positions of an object
layout(buffer_reference, scalar) buffer Indices { ivec3 i[]; }; // Triangle Indices
layout(buffer_reference, scalar) buffer Materials { WaveFrontMaterial m[]; }; // Array of all materials on an object
layout(buffer_reference, scalar) buffer MatIndices { int i []; }; // Material ID for each triangles
layout(set = 1, binding = eObjDescs, scalar) buffer ObjDesc_ { ObjDesc i[]; } objDesc;

layout(push_constant) uniform _PushConstantRay
{
  PushConstantRay pcRay;
};

vec3 barycentricInterpolation(in vec3 v[3], in vec3 bary)
{
	return v[0] * bary.x + v[1] * bary.y + v[2] * bary.z;
}

void main()
{
	// Object data
	ObjDesc objResource		= objDesc.i[gl_InstanceCustomIndexEXT];
	MatIndices matIndices	= MatIndices(objResource.materialIndexAddress);
	Materials materials		= Materials(objResource.materialAddress);
	Indices indices			= Indices(objResource.indexAddress);
	Vertices vertices		= Vertices(objResource.vertexAddress);

	// Indices of the triangle
	ivec3 ind = indices.i[gl_PrimitiveID];

	// Vertex of the triangle
	Vertex v0 = vertices.v[ind.x];
	Vertex v1 = vertices.v[ind.y];
	Vertex v2 = vertices.v[ind.z];

	// compute the barycentric coordinates
	const vec3 barycentricsCoord = vec3(1.0 - attribs.x - attribs.y, attribs.x, attribs.y);
	vec3 normals[3] = {v0.nrm, v1.nrm, v2.nrm};
	vec3 nor = barycentricInterpolation(normals, barycentricsCoord);
	nor = normalize(vec3(nor * gl_WorldToObjectEXT));
	prd.hitValue = nor * 0.5f + 0.5f;
}
