#version 460 core

#include <flutter/runtime_effect.glsl>

// Holographic foil: diagonal iridescent bands whose phase follows the card
// tilt, plus a procedural sparkle layer. Output is premultiplied alpha and is
// meant to be composited over the card content with a blend mode.

uniform vec2 uSize;
uniform vec2 uTilt;       // normalized tilt, each axis in [-1, 1]
uniform float uTime;      // seconds, already scaled by the shimmer speed
uniform float uIntensity; // 0..1
uniform float uDensity;   // bands across the card diagonal
uniform float uSparkle;   // 0..1
uniform float uColorCount; // 2..6
uniform vec3 uColor0;
uniform vec3 uColor1;
uniform vec3 uColor2;
uniform vec3 uColor3;
uniform vec3 uColor4;
uniform vec3 uColor5;

out vec4 fragColor;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

vec3 palette(float t) {
  vec3 cols[6];
  cols[0] = uColor0;
  cols[1] = uColor1;
  cols[2] = uColor2;
  cols[3] = uColor3;
  cols[4] = uColor4;
  cols[5] = uColor5;

  float x = fract(t) * uColorCount;
  float i0 = floor(x);
  float f = smoothstep(0.0, 1.0, x - i0);
  float i1 = mod(i0 + 1.0, uColorCount);

  vec3 a = uColor0;
  vec3 b = uColor0;
  for (int i = 0; i < 6; i++) {
    float fi = float(i);
    if (abs(fi - i0) < 0.5) a = cols[i];
    if (abs(fi - i1) < 0.5) b = cols[i];
  }
  return mix(a, b, f);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uSize;
  vec2 p = uv - 0.5;
  float aspect = uSize.x / max(uSize.y, 1.0);
  p.x *= aspect;

  // Diagonal coordinate; the tilt slides the bands across the surface.
  vec2 dir = normalize(vec2(1.0, 0.65));
  float d = dot(p, dir);
  float phase = d * uDensity
      + uTilt.x * 0.85
      + uTilt.y * 0.55
      + uTime * 0.15;
  // Slight curvature so the bands feel like a lit surface, not a stripe.
  phase += 0.12 * sin(p.y * 6.0 + uTilt.x * 2.0 + uTime * 0.4);

  vec3 col = palette(phase);

  // Brightness ripple along the bands.
  float ripple = 0.65 + 0.35 * sin(phase * 6.2831853);

  // Foil is brightest near the point the light hits.
  vec2 lightPos = uTilt * 0.5;
  lightPos.x *= aspect;
  float spot = 1.0 - smoothstep(0.0, 1.1, length(p - lightPos));
  float mask = 0.35 + 0.65 * spot;

  // Sparkle: twinkling cells whose phase depends on tilt.
  float cells = 46.0;
  vec2 g = uv * vec2(cells * aspect, cells);
  vec2 id = floor(g);
  vec2 gv = fract(g) - 0.5;
  float rnd = hash21(id);
  float twinkle = sin(rnd * 40.0 + uTime * 3.0 + (uTilt.x + uTilt.y) * 6.0);
  float star = smoothstep(0.32, 0.0, length(gv)) * step(0.82, rnd);
  float sparkle = star * max(twinkle, 0.0) * uSparkle;

  float alpha = clamp(uIntensity * ripple * mask + sparkle * uIntensity, 0.0, 1.0);
  vec3 rgb = mix(col, vec3(1.0), clamp(sparkle, 0.0, 1.0));
  fragColor = vec4(rgb * alpha, alpha);
}
