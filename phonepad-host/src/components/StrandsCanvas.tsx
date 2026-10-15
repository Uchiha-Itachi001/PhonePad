import React, { useEffect, useRef } from "react";

export type ConnectionState = "connected" | "connecting" | "disconnected";

interface StrandsCanvasProps {
  status: ConnectionState;
  className?: string;
  style?: React.CSSProperties;
}

const MAX_STRANDS = 24;
const MAX_COLORS = 8;

const VERT = `#version 300 es
in vec2 position;
void main() {
  gl_Position = vec4(position, 0.0, 1.0);
}
`;

const FRAG = `#version 300 es
precision highp float;

uniform float uTime;
uniform vec2 uResolution;
uniform vec3 uColors[${MAX_COLORS}];
uniform int uColorCount;
uniform int uStrandCount;
uniform float uSpeed;
uniform float uAmplitude;
uniform float uWaviness;
uniform float uThickness;
uniform float uSpread;
uniform float uHueShift;
uniform float uIntensity;
uniform float uOpacity;
uniform float uSaturation;

out vec4 fragColor;

const float PI = 3.14159265359;

vec3 samplePalette(float t) {
  t = fract(t);
  float scaled = t * float(uColorCount);
  int idx = int(floor(scaled));
  float blend = fract(scaled);
  int nextIdx = idx + 1;
  if (nextIdx >= uColorCount) nextIdx = 0;
  return mix(uColors[idx], uColors[nextIdx], blend);
}

void main() {
  // s: Normalized progress 0.0 (Phone Center) -> 1.0 (Laptop Center)
  float s = gl_FragCoord.x / max(uResolution.x, 1.0);

  // v: Normalized Y centered vertically (-0.5 to +0.5)
  float v = (gl_FragCoord.y - 0.5 * uResolution.y) / max(uResolution.y, 1.0);

  // Baseline Y: dynamically locks exactly 20px above center across any card height
  float baselineY = 20.0 / max(uResolution.y, 1.0);

  // Sinusoidal envelope: 0.0 at Phone Center (s=0), peaks at Wi-Fi Beacon (s=0.5), 0.0 at Laptop Center (s=1)
  float arch = sin(clamp(s, 0.0, 1.0) * PI);
  float env = pow(arch, 0.65);

  // Soft edge fade right at the emitter tips
  float edgeFade = smoothstep(0.0, 0.035, s) * smoothstep(1.0, 0.965, s);

  vec3 col = vec3(0.0);
  float tt = uTime * uSpeed;

  for (int i = 0; i < ${MAX_STRANDS}; i++) {
    if (i >= uStrandCount) break;

    float fi = float(i);

    // High-entropy deterministic pseudo-random seeds per strand
    float s1 = fract(sin(fi * 12.9898 + 1.234) * 43758.5453);
    float s2 = fract(cos(fi * 27.6543 + 2.345) * 28461.1234);
    float s3 = fract(sin(fi * 49.3210 + 3.456) * 19374.8291);
    float s4 = fract(cos(fi * 63.8912 + 4.567) * 31415.9265);

    // Differentiated non-harmonic wave frequencies so strands never move at same cadence
    float freq1 = (1.4 + s1 * 3.2) * uWaviness;
    float freq2 = (2.2 + s2 * 3.8) * uWaviness;
    float freq3 = (0.7 + s3 * 2.0) * uWaviness;

    // Opposing velocities & alternating travel directions (even strands move right, odd move left)
    float dir = (mod(fi, 2.0) < 1.0) ? 1.0 : -1.0;
    float spd1 = (0.75 + s2 * 1.1) * dir;
    float spd2 = (0.85 + s3 * 1.3) * (-dir);
    float spd3 = (0.55 + s4 * 0.9) * dir;

    // Asymmetric independent phase offsets
    float ph1 = s1 * PI * 2.0;
    float ph2 = s2 * PI * 2.0;
    float ph3 = s3 * PI * 2.0;

    // Compound multi-harmonic non-parallel wave with spatial modulation
    float wave = sin((s - 0.5) * freq1 * PI * 2.0 + tt * spd1 + ph1) * 0.44
               + cos((s - 0.5) * freq2 * PI * 2.0 + tt * spd2 + ph2) * 0.36
               + sin(s * freq3 * PI * 3.5 - tt * spd3 + ph3) * 0.20;

    // Individual macroscopic curvature: some strands arch upward, some downward, some perform S-crossing
    float macroOffset = (s1 - 0.5) * 0.13 * env;
    float macroTilt = sin((s - 0.5) * PI * (1.0 + s4 * 1.4)) * (s2 - 0.5) * 0.12 * env;

    // Dynamic weaving oscillation that continuously swaps vertical ordering over time
    float dynamicWeave = sin(tt * spd1 * 0.6 + fi * 1.85 + s * (2.2 + s3 * 2.8)) * 0.042 * env;

    // Individual amplitude variation per strand
    float amp = (0.038 + s2 * 0.042) * uAmplitude * env;

    // Combined y position: zero offset at emitters, highly non-parallel dynamic braided path across the bridge
    float y = baselineY + wave * amp + macroOffset + macroTilt + dynamicWeave;

    float d = abs(v - y);
    // Delicate luminous ribbon filament with micro-thickness variance
    float thick = (0.0018 + 0.0038 * env) * (0.78 + s3 * 0.36) * uThickness;
    float g = thick / (d + thick * 0.55);
    g = g * g;

    // Color cycling along the wave with strand-specific shift
    float h = fi / float(uStrandCount) + s * 0.25 + uTime * 0.035 + uHueShift;
    vec3 strandCol = samplePalette(h);

    col += strandCol * g * env * edgeFade;
  }

  // Soft luminous aura glow directly behind the center Wi-Fi beacon
  float centerDist = length(vec2((s - 0.5) * 2.4, (v - baselineY) * 1.5));
  float centerAura = exp(-centerDist * 4.4) * 0.45 * env;
  vec3 auraCol = samplePalette(0.35 + uTime * 0.03);
  col += auraCol * centerAura * edgeFade;

  // Gentle brightness - crisp and rich, not overexposed
  col *= 0.88 * uIntensity;

  // Reinhard tonemapping ensures rich electric blue / cyan saturation NEVER blows out to blinding white
  col = col / (1.0 + col * 0.45);

  // Saturation tuning
  float gray = dot(col, vec3(0.2126, 0.7152, 0.0722));
  col = max(mix(vec3(gray), col, uSaturation), 0.0);

  // Alpha computation: luminous and visible while preserving dark card clarity
  float lum = max(max(col.r, col.g), col.b);
  float alpha = clamp(lum * 1.6, 0.0, 1.0) * uOpacity * env * edgeFade;

  fragColor = vec4(col, alpha);
}
`;

function hexToRgb(hex: string): [number, number, number] {
  const h = hex.replace("#", "");
  const v = h.length === 3 ? h.split("").map((c) => c + c).join("") : h;
  const num = parseInt(v.slice(0, 6), 16);
  return [((num >> 16) & 255) / 255, ((num >> 8) & 255) / 255, (num & 255) / 255];
}

const COLOR_SCHEMES: Record<
  ConnectionState,
  {
    colors: string[];
    count: number;
    speed: number;
    amplitude: number;
    thickness: number;
    intensity: number;
    saturation: number;
  }
> = {
  connected: {
    // Lush Emerald & Mint Green Luminous Strands (Strictly 8 Strands)
    colors: [
      "#059669",
      "#10B981",
      "#34D399",
      "#047857",
      "#10B981",
      "#6EE7B7",
      "#059669",
      "#A7F3D0",
    ],
    count: 8,
    speed: 0.75,
    amplitude: 0.95,
    thickness: 0.85,
    intensity: 1.15,
    saturation: 1.85,
  },
  connecting: {
    // Vibrant Amber & Neon Orange Discovery Strands (Strictly 8 Strands)
    colors: [
      "#D97706",
      "#F59E0B",
      "#F97316",
      "#FB923C",
      "#EA580C",
      "#FBBF24",
      "#F59E0B",
      "#FED7AA",
    ],
    count: 8,
    speed: 0.65,
    amplitude: 0.92,
    thickness: 0.85,
    intensity: 1.15,
    saturation: 1.85,
  },
  disconnected: {
    // Soft Severed Crimson Strands (4 Strands)
    colors: ["#DC2626", "#EF4444", "#F87171", "#7F1D1D"],
    count: 4,
    speed: 0.25,
    amplitude: 0.45,
    thickness: 0.65,
    intensity: 0.6,
    saturation: 1.5,
  },
};

export const StrandsCanvas: React.FC<StrandsCanvasProps> = ({
  status,
  className,
  style,
}) => {
  const mountRef = useRef<HTMLDivElement | null>(null);
  const statusRef = useRef<ConnectionState>(status);

  useEffect(() => {
    statusRef.current = status;
  }, [status]);

  useEffect(() => {
    const mount = mountRef.current;
    if (!mount) return;

    // Clean up any stale canvas from prior HMR runs
    while (mount.firstChild) {
      mount.removeChild(mount.firstChild);
    }

    const canvas = document.createElement("canvas");
    canvas.style.display = "block";
    canvas.style.width = "100%";
    canvas.style.height = "100%";
    canvas.style.pointerEvents = "none";
    mount.appendChild(canvas);

    const gl = canvas.getContext("webgl2", {
      alpha: true,
      antialias: true,
      powerPreference: "high-performance",
    });

    if (!gl) {
      console.warn("WebGL 2 not supported for Strands; fallback will be used");
      return;
    }

    const createShader = (type: number, source: string) => {
      const shader = gl.createShader(type);
      if (!shader) return null;
      gl.shaderSource(shader, source);
      gl.compileShader(shader);
      if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
        console.error("Shader compile error:", gl.getShaderInfoLog(shader));
        gl.deleteShader(shader);
        return null;
      }
      return shader;
    };

    const vertShader = createShader(gl.VERTEX_SHADER, VERT);
    const fragShader = createShader(gl.FRAGMENT_SHADER, FRAG);
    if (!vertShader || !fragShader) return;

    const program = gl.createProgram();
    if (!program) return;
    gl.attachShader(program, vertShader);
    gl.attachShader(program, fragShader);
    gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
      console.error("Program link error:", gl.getProgramInfoLog(program));
      return;
    }
    gl.useProgram(program);

    const positionBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
    gl.bufferData(
      gl.ARRAY_BUFFER,
      new Float32Array([-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1]),
      gl.STATIC_DRAW
    );

    const posLoc = gl.getAttribLocation(program, "position");
    gl.enableVertexAttribArray(posLoc);
    gl.vertexAttribPointer(posLoc, 2, gl.FLOAT, false, 0, 0);

    const uTimeLoc = gl.getUniformLocation(program, "uTime");
    const uResLoc = gl.getUniformLocation(program, "uResolution");
    const uColorsLoc = gl.getUniformLocation(program, "uColors");
    const uColorCountLoc = gl.getUniformLocation(program, "uColorCount");
    const uStrandCountLoc = gl.getUniformLocation(program, "uStrandCount");
    const uSpeedLoc = gl.getUniformLocation(program, "uSpeed");
    const uAmpLoc = gl.getUniformLocation(program, "uAmplitude");
    const uWavinessLoc = gl.getUniformLocation(program, "uWaviness");
    const uThickLoc = gl.getUniformLocation(program, "uThickness");
    const uSpreadLoc = gl.getUniformLocation(program, "uSpread");
    const uHueShiftLoc = gl.getUniformLocation(program, "uHueShift");
    const uIntensityLoc = gl.getUniformLocation(program, "uIntensity");
    const uOpacityLoc = gl.getUniformLocation(program, "uOpacity");
    const uSatLoc = gl.getUniformLocation(program, "uSaturation");

    let animationFrameId: number;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);

    const resize = () => {
      if (!mount || !canvas) return;
      const w = mount.clientWidth;
      const h = mount.clientHeight;
      if (w === 0 || h === 0) return;
      canvas.width = Math.round(w * dpr);
      canvas.height = Math.round(h * dpr);
      canvas.style.width = `${w}px`;
      canvas.style.height = `${h}px`;
      gl.viewport(0, 0, canvas.width, canvas.height);
      gl.uniform2f(uResLoc, canvas.width, canvas.height);
    };

    resize();
    const resizeObserver = new ResizeObserver(resize);
    resizeObserver.observe(mount);

    const startTime = performance.now();

    const render = (now: number) => {
      const cfg = COLOR_SCHEMES[statusRef.current] || COLOR_SCHEMES.disconnected;

      const flatColors = new Float32Array(MAX_COLORS * 3);
      for (let i = 0; i < MAX_COLORS; i++) {
        const hex = cfg.colors[i] || cfg.colors[cfg.colors.length - 1] || "#3B82F6";
        const [r, g, b] = hexToRgb(hex);
        flatColors[i * 3] = r;
        flatColors[i * 3 + 1] = g;
        flatColors[i * 3 + 2] = b;
      }

      gl.uniform3fv(uColorsLoc, flatColors);
      gl.uniform1i(uColorCountLoc, cfg.colors.length);
      gl.uniform1i(uStrandCountLoc, cfg.count);
      gl.uniform1f(uSpeedLoc, cfg.speed);
      gl.uniform1f(uAmpLoc, cfg.amplitude);
      gl.uniform1f(uWavinessLoc, 1.0);
      gl.uniform1f(uThickLoc, cfg.thickness);
      gl.uniform1f(uSpreadLoc, 1.0);
      gl.uniform1f(uHueShiftLoc, 0.0);
      gl.uniform1f(uIntensityLoc, cfg.intensity);
      gl.uniform1f(uOpacityLoc, 1.0);
      gl.uniform1f(uSatLoc, cfg.saturation);

      const t = (now - startTime) / 1000;
      gl.uniform1f(uTimeLoc, t);
      gl.clearColor(0, 0, 0, 0);
      gl.clear(gl.COLOR_BUFFER_BIT);
      gl.drawArrays(gl.TRIANGLES, 0, 6);

      animationFrameId = requestAnimationFrame(render);
    };

    animationFrameId = requestAnimationFrame(render);

    return () => {
      cancelAnimationFrame(animationFrameId);
      resizeObserver.disconnect();
      if (mount && canvas && mount.contains(canvas)) {
        mount.removeChild(canvas);
      }
      if (gl) {
        gl.deleteProgram(program);
        gl.deleteShader(vertShader);
        gl.deleteShader(fragShader);
        gl.deleteBuffer(positionBuffer);
      }
    };
  }, []);

  return (
    <div
      ref={mountRef}
      className={`strands-mount ${className || ""}`}
      style={{
        position: "absolute",
        left: 0,
        right: 0,
        top: 0,
        bottom: 0,
        overflow: "hidden",
        pointerEvents: "none",
        ...style,
      }}
    />
  );
};
