#version 150

#moj_import <fog.glsl>

uniform sampler2D Sampler0;
uniform sampler2D Sampler4;
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

uniform float renderingPanorama;

in float vertexDistance;
in vec3 vertexPos;
in vec4 vertexColor;
in vec2 texCoord0;
in vec4 normal;
in vec4 glPos;
in mat4 BoblessMat;

out vec4 fragColor;

const float PI = 3.14159265359;
const float HALF_PI = PI * 0.5;

vec4 unbob(vec4 pos) {
	return BoblessMat * pos;
}

vec3 unbob(vec3 pos) {
	return unbob(vec4(pos, 1.0)).xyz / unbob(vec4(pos, 1.0)).w;
}

int getCubeFace(vec3 v) {
	vec3 vAbs = abs(v);
	if(vAbs.z >= vAbs.x && vAbs.z >= vAbs.y) {
		return v.z < 0 ? 2 : 0;
	} else if(vAbs.y >= vAbs.x) {
		return v.y < 0 ? 5 : 4;
	} else {
		return v.x < 0 ? 1 : 3;
	}
}

vec2 getCubeUV(vec3 v) {
	vec3 vAbs = abs(v);
	float ma;
	vec2 uv;
	if(vAbs.z >= vAbs.x && vAbs.z >= vAbs.y) {
		ma = 0.5 / vAbs.z;
		uv = vec2(v.z < 0.0 ? v.x : -v.x, v.y);
	} else if(vAbs.y >= vAbs.x) {
		ma = 0.5 / vAbs.y;
		uv = vec2(-v.x, v.y < 0.0 ? v.z : -v.z);
	} else {
		ma = 0.5 / vAbs.x;
		uv = vec2(v.x < 0.0 ? -v.z : v.z, v.y);
	}
	return vec2(uv * ma + 0.5);
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

mat4 getRotMat(vec3 v) {
	int faceIndex = getCubeFace(v);
	mat4 faceRotationMat = mat4(
    	vec4(1.0, 0.0, 0.0, 0.0),
    	vec4(0.0, 1.0, 0.0, 0.0),
    	vec4(0.0, 0.0, 1.0, 0.0),
    	vec4(0.0, 0.0, 0.0, 1.0)
	);

	if (faceIndex == 0) {
		faceRotationMat = yxRotationMatrix(180.0, 0.0);
	} else if (faceIndex == 1) {
		faceRotationMat = yxRotationMatrix(-90.0, 0.0);
	} else if (faceIndex == 2) {
		faceRotationMat = yxRotationMatrix(0.0, 0.0);
	} else if (faceIndex == 3) {
		faceRotationMat = yxRotationMatrix(90.0, 0.0);
	} else if (faceIndex == 4) {
		faceRotationMat = yxRotationMatrix(0.0, -90.0);
	} else if (faceIndex == 5) {
		faceRotationMat = yxRotationMatrix(0.0, 90.0);
	}

	return faceRotationMat;
}

vec4 sampleCube(vec3 v) {
	int faceIndex = getCubeFace(v);

	vec2 tex = getCubeUV(v);
	vec4 color = texture(Sampler5, tex);

	if (faceIndex == 0) {
		color = texture(Sampler5, tex);
	} else if (faceIndex == 1) {
		color = texture(Sampler6, tex);
	} else if (faceIndex == 2) {
		color = texture(Sampler7, tex);
	} else if (faceIndex == 3) {
		color = texture(Sampler8, tex);
	} else if (faceIndex == 4) {
		color = texture(Sampler9, tex);
	} else if (faceIndex == 5) {
		color = texture(Sampler10, tex);
	}

	return color;
}

float normalizeDepth(float d) {
	float n = 0.05;
	float f = FarFar;
	return -(n * d) / (-f-(n * d) + (d * f));
}

float linearizeDepth(float d) {
	float n = 0.05;
	float f = FarFar;
    float z_n = 2.0 * d - 1.0;
    return 2.0 * n * f / (f + n - z_n * (f - n));
}

float distToCameraDistance(float depth, vec2 texCoord) {
    return length(vec3(1.0, (2.0 * texCoord - 1.0) * tan(radians(90.0) / 2.0)) * linearizeDepth(depth));
}

void main() {
	vec4 texturedColor = texture(Sampler0, texCoord0) * vertexColor * ColorModulator;
    if (texturedColor.a < 0.1) {
        discard;
    }
	vec3 relativePos = vertexPos + CameraPos - Origin;
	vec3 viewDir = normalize(unbob(vertexPos));

	float longitude = atan(relativePos.z, relativePos.x);
	float u = (longitude + PI) / (2.0 * PI);
	
	float latitude = asin(relativePos.y / length(relativePos));
	float v = -(latitude + HALF_PI) / PI;

    vec4 color = texture(Sampler4, vec2(u, v));

	float depthDistance = distToCameraDistance(sampleCube(normalize(relativePos)).x, getCubeUV(normalize(relativePos)));
	float fragmentDistance = distance(vertexPos + CameraPos, Origin);

	fragColor = texturedColor;

	if (fragmentDistance - (0.0003 * (fragmentDistance * fragmentDistance)) <= depthDistance) {
		fragColor = color;
	}

	if (renderingPanorama == 1.0) {
		fragColor = texturedColor;
	}
}
