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
layout(set = 1, binding = eTextures) uniform sampler2D textureSamplers[];

layout(push_constant) uniform _PushConstantRay
{
  PushConstantRay pcRay;
};

vec3 barycentricInterpolation(in vec3 v[3], in vec3 bary)
{
	return v[0] * bary.x + v[1] * bary.y + v[2] * bary.z;
}

vec2 barycentricInterpolationV2(in vec2 v[3], in vec3 bary)
{
	return v[0] * bary.x + v[1] * bary.y + v[2] * bary.z;
}

vec4 computeLight(in vec3 worldPos, in vec3 normal, in PushConstantRay ray_const)
{
	vec3  L = vec3(0.f); // light dir (normalize)
	float intensity = 1.f; // intensity;
	if(ray_const.lightType == 0) // pointLight
	{
		vec3 lightDir = ray_const.lightPosition - worldPos;
		float lightDist  = length(lightDir);
		intensity = ray_const.lightIntensity / (lightDist * lightDist);
		L = normalize(lightDir);
	}
	else // direction light
	{
		L = normalize(pcRay.lightPosition);
		intensity = ray_const.lightIntensity;
	}

	return vec4(L, intensity);
}

void main()
{
	// Object data
	ObjDesc objResource		= objDesc.i[gl_InstanceCustomIndexEXT];
	MatIndices matIndices	= MatIndices(objResource.materialIndexAddress);
	Materials materials		= Materials(objResource.materialAddress);
	Indices indices			= Indices(objResource.indexAddress);
	Vertices vertices		= Vertices(objResource.vertexAddress);

	// Material of the object
	int               matIdx = matIndices.i[gl_PrimitiveID];
	WaveFrontMaterial mat    = materials.m[matIdx];

	// Indices of the triangle
	ivec3 ind = indices.i[gl_PrimitiveID];

	// Vertex of the triangle
	Vertex v0 = vertices.v[ind.x];
	Vertex v1 = vertices.v[ind.y];
	Vertex v2 = vertices.v[ind.z];

	// get world position
	vec3 worldPos = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;

	// compute the barycentric coordinates
	const vec3 barycentricsCoord = vec3(1.0 - attribs.x - attribs.y, attribs.x, attribs.y);
	vec3 normals[3] = {v0.nrm, v1.nrm, v2.nrm};
	vec3 nor = barycentricInterpolation(normals, barycentricsCoord);
	nor = normalize(vec3(nor * gl_WorldToObjectEXT));

	vec4 light_result = computeLight(worldPos, nor, pcRay);

	float dotNL = max(dot(nor, light_result.xyz), 0.2);
	
	vec3 diffuse = computeDiffuse(mat, light_result.xyz, nor);
	if(mat.textureId >= 0)
	{
	  uint textureId = mat.textureId + objDesc.i[gl_InstanceCustomIndexEXT].txtOffset; // get textureId
	  vec2 uvs[3] = {v0.texCoord, v1.texCoord, v2.texCoord};
	  vec2 texCoord = barycentricInterpolationV2(uvs, barycentricsCoord);
	  diffuse *= texture(textureSamplers[nonuniformEXT(textureId)], texCoord).xyz;
	}

	// Specular
	vec3 specular = computeSpecular(mat, gl_WorldRayDirectionEXT, light_result.xyz, nor);

	prd.hitValue = vec3(light_result.w * (diffuse + specular));;
}
