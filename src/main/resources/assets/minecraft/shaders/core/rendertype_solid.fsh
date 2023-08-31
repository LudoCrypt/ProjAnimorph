#version 150

#moj_import <fog.glsl>

uniform sampler2D Sampler0;
uniform sampler2D Sampler5;
uniform sampler2D Sampler6;
uniform sampler2D Sampler7;
uniform sampler2D Sampler8;
uniform sampler2D Sampler9;
uniform sampler2D Sampler10;

uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;
uniform vec4 FogColor;

uniform mat4 ProjMat;
uniform mat4 ModelViewMat;
uniform mat4 BobMat;
uniform mat4 BasicMat;

uniform vec2 ScreenSize;
uniform vec3 Origin;
uniform vec3 CameraPos;

uniform float FarFar;

in float vertexDistance;
in vec3 vertexPos;
in vec4 vertexColor;
in vec2 texCoord0;
in vec4 normal;
in vec4 glPos;
in mat4 BoblessMat;

out vec4 fragColor;

out float currFace;

struct Vertex {
	vec3 pos;
	vec4 color;
	vec2 uv;
};

Vertex vertice(vec3 pos, vec4 color, vec2 uv) {
	Vertex v;
	v.pos = pos;
	v.color = color;
	v.uv = uv;
	return v;
}

float cross2(vec2 a, vec2 b) {
	return a.x * b.y - a.y * b.x;
}

vec3 barycentric(vec4 v1, vec4 v2, vec4 v3) {
	vec4 ndcv1 = vec4(v1.xyz / v1.w, 1.0 / v1.w);
	vec2 sv1 = mix(vec2(0.0), ScreenSize, 0.5 * (ndcv1.xy + 1.0));

	vec4 ndcv2 = vec4(v2.xyz / v2.w, 1.0 / v2.w);
	vec2 sv2 = mix(vec2(0.0), ScreenSize, 0.5 * (ndcv2.xy + 1.0));

	vec4 ndcv3 = vec4(v3.xyz / v3.w, 1.0 / v3.w);
	vec2 sv3 = mix(vec2(0.0), ScreenSize, 0.5 * (ndcv3.xy + 1.0));

	float denom = cross2(sv2 - sv1, sv3 - sv1);

	if (v1.w < 0.0 && v2.w < 0.0 && v3.w < 0.0) {
		return vec3(-1.0);
	}

	vec3 bary = vec3(cross2(sv2 - gl_FragCoord.xy, sv3 - gl_FragCoord.xy), cross2(gl_FragCoord.xy - sv1, sv3 - sv1), cross2(sv2 - sv1, gl_FragCoord.xy - sv1)) / denom;

	vec3 persp = 1.0 / ((bary.x * ndcv1.w) + (bary.y * ndcv2.w) + (bary.z * ndcv3.w)) * bary * vec3(ndcv1.w, ndcv2.w, ndcv3.w);

	return persp;
}

vec4 toScreen(vec3 vertex) {
	return ProjMat * ModelViewMat * vec4(vertex - CameraPos, 1.0);
}

bool isInTriangle(vec3 bary) {
	return bary.x >= 0 && bary.y >= 0 && bary.z >= 0;
}

vec4 unbob(vec4 pos) {
	return BoblessMat * pos;
}

vec3 unbob(vec3 pos) {
	return unbob(vec4(pos, 1.0)).xyz / unbob(vec4(pos, 1.0)).w;
}

vec3 calculateTriangleNormal(vec3 v0, vec3 v1, vec3 v2) {
	vec3 edge1 = v1 - v0;
	vec3 edge2 = v2 - v0;
	vec3 normal = cross(edge1, edge2);
	return normalize(normal);
}

vec4 drawTriangle(vec4 base, Vertex v1, Vertex v2, Vertex v3) {
	vec3 bary = barycentric(toScreen(v1.pos), toScreen(v2.pos), toScreen(v3.pos));
	if (isInTriangle(bary) && dot(normalize(unbob(vertexPos)), calculateTriangleNormal(v1.pos, v2.pos, v3.pos)) <= 0.0) {
		vec4 quadColor = ((bary.x * v1.color) + (bary.y * v2.color) + (bary.z * v3.color));
		vec2 uv = ((bary.x * v1.uv) + (bary.y * v2.uv) + (bary.z * v3.uv));

		vec4 color = texture(Sampler5, uv);
		
		if (currFace == 0) {
			color = texture(Sampler5, uv);
		} else if (currFace == 1) {
			color = texture(Sampler6, uv);
		} else if (currFace == 2) {
			color = texture(Sampler7, uv);
		} else if (currFace == 3) {
			color = texture(Sampler8, uv);
		} else if (currFace == 4) {
			color = texture(Sampler9, uv);
		} else if (currFace == 5) {
			color = texture(Sampler10, uv);
		}

		return vec4(vec3(color.x), 1.0);
	}
	return base;
}

vec4 drawQuad(vec4 base, Vertex v1, Vertex v2, Vertex v3, Vertex v4) {
	vec4 color = drawTriangle(base, v1, v2, v4);
	color = drawTriangle(color, v1, v4, v3);
	return color;
}

vec2 sampleCube(vec3 v, out int faceIndex) {
	vec3 vAbs = abs(v);
	float ma;
	vec2 uv;
	if(vAbs.z >= vAbs.x && vAbs.z >= vAbs.y) {
		faceIndex = v.z < 0 ? 2 : 0;
		ma = 0.5 / vAbs.z;
		uv = vec2(v.z < 0.0 ? v.x : -v.x, v.y);
	} else if(vAbs.y >= vAbs.x) {
		faceIndex = v.y < 0 ? 5 : 4;
		ma = 0.5 / vAbs.y;
		uv = vec2(-v.x, v.y < 0.0 ? v.z : -v.z);
	} else {
		faceIndex = v.x < 0 ? 1 : 3;
		ma = 0.5 / vAbs.x;
		uv = vec2(v.x < 0.0 ? -v.z : v.z, v.y);
	}
	return uv * ma + 0.5;
}

mat4 yxRotationMatrix(float yDegrees, float xDegrees) {
    float yRadians = radians(yDegrees);
    float xRadians = radians(xDegrees);

    mat4 yRotation = mat4(
        cos(yRadians), 0.0, sin(yRadians), 0.0,
        0.0, 1.0, 0.0, 0.0,
        -sin(yRadians), 0.0, cos(yRadians), 0.0,
        0.0, 0.0, 0.0, 1.0
    );

    mat4 xRotation = mat4(
        1.0, 0.0, 0.0, 0.0,
        0.0, cos(xRadians), -sin(xRadians), 0.0,
        0.0, sin(xRadians), cos(xRadians), 0.0,
        0.0, 0.0, 0.0, 1.0
    );

    return yRotation * xRotation;
}

void main() {
	currFace = 0;
	vec4 texturedColor = texture(Sampler0, texCoord0) * vertexColor * ColorModulator;
	vec3 worldPos = vertexPos + CameraPos;
	float near = 0.05;
	float far = (ProjMat[2][2]-1.)/(ProjMat[2][2]+1.) * near;
	int faceIndex = 0;
	vec4 texPos = vec4(sampleCube(normalize((inverse(ProjMat * ModelViewMat) * vec4(glPos.xy / glPos.w * (far - near), far + near, far - near)).xyz), faceIndex), 1.0, 1.0);
	texPos = vec4(texPos.x, texPos.y, texPos.z, texPos.w);

	vec4 skyboxColor = textureProj(Sampler5, texPos);
	float d = textureProj(Sampler5, texPos).x;
	
	mat4 faceRotationMat = mat4(
    	vec4(1.0, 0.0, 0.0, 0.0),
    	vec4(0.0, 1.0, 0.0, 0.0),
    	vec4(0.0, 0.0, 1.0, 0.0),
    	vec4(0.0, 0.0, 0.0, 1.0)
	);

	if (faceIndex == 0) {
		d = textureProj(Sampler5, texPos).x;
		faceRotationMat = yxRotationMatrix(180.0, 0.0);
	} else if (faceIndex == 1) {
		d = textureProj(Sampler6, texPos).x;
		faceRotationMat = yxRotationMatrix(-90.0, 0.0);
	} else if (faceIndex == 2) {
		d = textureProj(Sampler7, texPos).x;
		faceRotationMat = yxRotationMatrix(0.0, 0.0);
	} else if (faceIndex == 3) {
		d = textureProj(Sampler8, texPos).x;
		faceRotationMat = yxRotationMatrix(90.0, 0.0);
	} else if (faceIndex == 4) {
		d = textureProj(Sampler9, texPos).x;
		faceRotationMat = yxRotationMatrix(0.0, -90.0);
	} else if (faceIndex == 5) {
		d = textureProj(Sampler10, texPos).x;
		faceRotationMat = yxRotationMatrix(0.0, 90.0);
	}

	float n = near;
	float f = FarFar;
	float depth = -(n * f) / (-f - (n * d) + (d * f));
	float normalizedDepth = (depth - n) / (f - n);

	vec4 clipPos = ProjMat * (inverse(faceRotationMat) * vec4(vertexPos + Origin, 1.0));
	float fragmentD = (clipPos.z / clipPos.w) / 2.0 + 0.5;
	float fragmentDepth = -(n * f) / (-f - (n * fragmentD) + (fragmentD * f));
	float normalizedfragmentDepth = (fragmentDepth - n) / (f - n);

	vec4 color = texturedColor;

	vec4 cachedDepthColor = vec4(0.0, 0.0, 0.0, 1.0);
	// Draw East Face
	currFace = 3;
	Vertex v1 = vertice(f * vec3(1.0, 1.0, 1.0) + Origin, vertexColor, vec2(1.0, 1.0));
	Vertex v2 = vertice(f * vec3(1.0, 1.0, -1.0) + Origin, vertexColor, vec2(0.0, 1.0));
	Vertex v3 = vertice(f * vec3(1.0, -1.0, 1.0) + Origin, vertexColor, vec2(1.0, 0.0));
	Vertex v4 = vertice(f * vec3(1.0, -1.0, -1.0) + Origin, vertexColor, vec2(0.0, 0.0));

	cachedDepthColor = drawQuad(cachedDepthColor, v1, v2, v3, v4);

	// Draw North Face
	currFace = 2;
	v1 = vertice(f * vec3(-1.0, 1.0, -1.0) + Origin, vertexColor, vec2(0.0, 1.0));
	v2 = vertice(f * vec3(-1.0, -1.0, -1.0) + Origin, vertexColor, vec2(0.0, 0.0));
	v3 = vertice(f * vec3(1.0, 1.0, -1.0) + Origin, vertexColor, vec2(1.0, 1.0));
	v4 = vertice(f * vec3(1.0, -1.0, -1.0) + Origin, vertexColor, vec2(1.0, 0.0));

	cachedDepthColor = drawQuad(cachedDepthColor, v1, v2, v3, v4);

	// Draw South Face
	currFace = 0;
	v1 = vertice(f * vec3(-1.0, -1.0, 1.0) + Origin, vertexColor, vec2(1.0, 0.0));
	v2 = vertice(f * vec3(-1.0, 1.0, 1.0) + Origin, vertexColor, vec2(1.0, 1.0));
	v3 = vertice(f * vec3(1.0, -1.0, 1.0) + Origin, vertexColor, vec2(0.0, 0.0));
	v4 = vertice(f * vec3(1.0, 1.0, 1.0) + Origin, vertexColor, vec2(0.0, 1.0));

	cachedDepthColor = drawQuad(cachedDepthColor, v1, v2, v3, v4);
	
	// Draw West Face
	currFace = 1;
	v1 = vertice(f * vec3(-1.0, 1.0, 1.0) + Origin, vertexColor, vec2(0.0, 1.0));
	v2 = vertice(f * vec3(-1.0, -1.0, 1.0) + Origin, vertexColor, vec2(0.0, 0.0));
	v3 = vertice(f * vec3(-1.0, 1.0, -1.0) + Origin, vertexColor, vec2(1.0, 1.0));
	v4 = vertice(f * vec3(-1.0, -1.0, -1.0) + Origin, vertexColor, vec2(1.0, 0.0));

	cachedDepthColor = drawQuad(cachedDepthColor, v1, v2, v3, v4);

	// Draw Bottom Face
	currFace = 5;
	v1 = vertice(f * vec3(1.0, -1.0, 1.0) + Origin, vertexColor, vec2(0.0, 1.0));
	v2 = vertice(f * vec3(1.0, -1.0, -1.0) + Origin, vertexColor, vec2(0.0, 0.0));
	v3 = vertice(f * vec3(-1.0, -1.0, 1.0) + Origin, vertexColor, vec2(1.0, 1.0));
	v4 = vertice(f * vec3(-1.0, -1.0, -1.0) + Origin, vertexColor, vec2(1.0, 0.0));

	cachedDepthColor = drawQuad(cachedDepthColor, v1, v2, v3, v4);

	// Draw Top Face
	currFace = 4;
	v1 = vertice(f * vec3(1.0, 1.0, 1.0) + Origin, vertexColor, vec2(0.0, 0.0));
	v2 = vertice(f * vec3(-1.0, 1.0, 1.0) + Origin, vertexColor, vec2(1.0, 0.0));
	v3 = vertice(f * vec3(1.0, 1.0, -1.0) + Origin, vertexColor, vec2(0.0, 1.0));
	v4 = vertice(f * vec3(-1.0, 1.0, -1.0) + Origin, vertexColor, vec2(1.0, 1.0));

	cachedDepthColor = drawQuad(cachedDepthColor, v1, v2, v3, v4);

	vec4 currentDepthColor = vec4(0.0, 0.0, 0.0, 1.0);
	// Current Depth

	// Draw East Face
	currFace = 3;
	v1 = vertice(f * vec3(1.0, 1.0, 1.0) + Origin, vertexColor, vec2(1.0, 1.0));
	v2 = vertice(f * vec3(1.0, 1.0, -1.0) + Origin, vertexColor, vec2(0.0, 1.0));
	v3 = vertice(f * vec3(1.0, -1.0, 1.0) + Origin, vertexColor, vec2(1.0, 0.0));
	v4 = vertice(f * vec3(1.0, -1.0, -1.0) + Origin, vertexColor, vec2(0.0, 0.0));

	currentDepthColor = drawQuad(currentDepthColor, v1, v2, v3, v4);

	// Draw North Face
	currFace = 2;
	v1 = vertice(f * vec3(-1.0, 1.0, -1.0) + Origin, vertexColor, vec2(0.0, 1.0));
	v2 = vertice(f * vec3(-1.0, -1.0, -1.0) + Origin, vertexColor, vec2(0.0, 0.0));
	v3 = vertice(f * vec3(1.0, 1.0, -1.0) + Origin, vertexColor, vec2(1.0, 1.0));
	v4 = vertice(f * vec3(1.0, -1.0, -1.0) + Origin, vertexColor, vec2(1.0, 0.0));

	currentDepthColor = drawQuad(currentDepthColor, v1, v2, v3, v4);

	// Draw South Face
	currFace = 0;
	v1 = vertice(f * vec3(-1.0, -1.0, 1.0) + Origin, vertexColor, vec2(1.0, 0.0));
	v2 = vertice(f * vec3(-1.0, 1.0, 1.0) + Origin, vertexColor, vec2(1.0, 1.0));
	v3 = vertice(f * vec3(1.0, -1.0, 1.0) + Origin, vertexColor, vec2(0.0, 0.0));
	v4 = vertice(f * vec3(1.0, 1.0, 1.0) + Origin, vertexColor, vec2(0.0, 1.0));

	currentDepthColor = drawQuad(currentDepthColor, v1, v2, v3, v4);
	
	// Draw West Face
	currFace = 1;
	v1 = vertice(f * vec3(-1.0, 1.0, 1.0) + Origin, vertexColor, vec2(0.0, 1.0));
	v2 = vertice(f * vec3(-1.0, -1.0, 1.0) + Origin, vertexColor, vec2(0.0, 0.0));
	v3 = vertice(f * vec3(-1.0, 1.0, -1.0) + Origin, vertexColor, vec2(1.0, 1.0));
	v4 = vertice(f * vec3(-1.0, -1.0, -1.0) + Origin, vertexColor, vec2(1.0, 0.0));

	currentDepthColor = drawQuad(currentDepthColor, v1, v2, v3, v4);

	// Draw Bottom Face
	currFace = 5;
	v1 = vertice(f * vec3(1.0, -1.0, 1.0) + Origin, vertexColor, vec2(0.0, 1.0));
	v2 = vertice(f * vec3(1.0, -1.0, -1.0) + Origin, vertexColor, vec2(0.0, 0.0));
	v3 = vertice(f * vec3(-1.0, -1.0, 1.0) + Origin, vertexColor, vec2(1.0, 1.0));
	v4 = vertice(f * vec3(-1.0, -1.0, -1.0) + Origin, vertexColor, vec2(1.0, 0.0));

	currentDepthColor = drawQuad(currentDepthColor, v1, v2, v3, v4);

	// Draw Top Face
	currFace = 4;
	v1 = vertice(f * vec3(1.0, 1.0, 1.0) + Origin, vertexColor, vec2(0.0, 0.0));
	v2 = vertice(f * vec3(-1.0, 1.0, 1.0) + Origin, vertexColor, vec2(1.0, 0.0));
	v3 = vertice(f * vec3(1.0, 1.0, -1.0) + Origin, vertexColor, vec2(0.0, 1.0));
	v4 = vertice(f * vec3(-1.0, 1.0, -1.0) + Origin, vertexColor, vec2(1.0, 1.0));

	currentDepthColor = drawQuad(currentDepthColor, v1, v2, v3, v4);

	if ((isInTriangle(barycentric(toScreen(v1.pos), toScreen(v2.pos), toScreen(v4.pos))) && dot(normalize(unbob(vertexPos)), calculateTriangleNormal(v1.pos, v2.pos, v4.pos)) <= 0.0) || (isInTriangle(barycentric(toScreen(v1.pos), toScreen(v4.pos), toScreen(v3.pos))) && dot(normalize(unbob(vertexPos)), calculateTriangleNormal(v1.pos, v4.pos, v3.pos)) <= 0.0)) {
		
	}

	d = cachedDepthColor.x;
	depth = -(n * f) / (-f - (n * d) + (d * f));
	normalizedDepth = (depth - n) / (f - n);

	color = vec4(vec3(normalizedfragmentDepth), 1.0);

    fragColor = linear_fog(color, vertexDistance, FogStart, FogEnd, FogColor);
}
