import * as THREE from 'three';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/examples/jsm/postprocessing/OutputPass.js';
import { RectAreaLightUniformsLib } from 'three/examples/jsm/lights/RectAreaLightUniformsLib.js';
import { buildGlyph, type GlyphBuild } from './glyphs';
import { identityStates, type IdentityStateContract, type IdentityStateName } from './contracts';

export type OpticalTier = 'micro' | 'compact' | 'master';
export type SceneQuality = 'hero' | 'standard' | 'mini';

export interface IdentitySceneOptions {
  opticalTier?: OpticalTier;
  quality?: SceneQuality;
  initialState?: IdentityStateName;
  interactive?: boolean;
  transparent?: boolean;
  certificationTier?: 0 | 1 | 2 | 3 | 4;
  ariaPrefix?: string;
  showGlyph?: boolean;
  motionSpeed?: number;
}

interface MotionParts {
  outerRings: THREE.Group[];
  innerRings: THREE.Object3D[];
  nodes: THREE.Mesh[];
  nodeCores: THREE.Mesh[];
  pulseParts: THREE.Object3D[];
  beamParticles: THREE.Points | null;
  particlePositions: Float32Array | null;
  scan: THREE.Mesh | null;
}

// Structural materials (no emissive glow) simplify all the way to unlit MeshBasicMaterial
// under constrainedRuntime. Materials that glow (emissive) simplify only to
// MeshStandardMaterial, since MeshBasicMaterial has no emissive property.
type StructuralMaterial = THREE.MeshPhysicalMaterial | THREE.MeshBasicMaterial;
type EmissiveMaterial = THREE.MeshPhysicalMaterial | THREE.MeshStandardMaterial;

interface Materials {
  silver: StructuralMaterial;
  silverBright: StructuralMaterial;
  silverDark: StructuralMaterial;
  polished: StructuralMaterial;
  carbon: StructuralMaterial;
  dark: StructuralMaterial;
  glass: StructuralMaterial;
  accent: EmissiveMaterial;
  accentSoft: EmissiveMaterial;
  accentTransparent: THREE.MeshBasicMaterial;
  stateMetal: EmissiveMaterial;
}

function octagonVertices(radius: number, rotation = -Math.PI / 8): THREE.Vector2[] {
  return Array.from({ length: 8 }, (_, index) => {
    const angle = rotation + index * Math.PI / 4;
    return new THREE.Vector2(Math.cos(angle) * radius, Math.sin(angle) * radius);
  });
}

function octShape(radius: number): THREE.Shape {
  const points = octagonVertices(radius);
  const shape = new THREE.Shape();
  points.forEach((point, index) => index ? shape.lineTo(point.x, point.y) : shape.moveTo(point.x, point.y));
  shape.closePath();
  return shape;
}

function ringShape(outer: number, inner: number): THREE.Shape {
  const shape = octShape(outer);
  const innerPoints = octagonVertices(inner).reverse();
  const hole = new THREE.Path();
  innerPoints.forEach((point, index) => index ? hole.lineTo(point.x, point.y) : hole.moveTo(point.x, point.y));
  hole.closePath();
  shape.holes.push(hole);
  return shape;
}

function chamferedRect(length: number, width: number, chamfer: number): THREE.Shape {
  const halfX = length / 2;
  const halfY = width / 2;
  const cut = Math.min(chamfer, halfX * 0.25, halfY * 0.76);
  const shape = new THREE.Shape();
  shape.moveTo(-halfX + cut, -halfY);
  shape.lineTo(halfX - cut, -halfY);
  shape.lineTo(halfX, -halfY + cut);
  shape.lineTo(halfX, halfY - cut);
  shape.lineTo(halfX - cut, halfY);
  shape.lineTo(-halfX + cut, halfY);
  shape.lineTo(-halfX, halfY - cut);
  shape.lineTo(-halfX, -halfY + cut);
  shape.closePath();
  return shape;
}

function extrudedSegmentGeometry(length: number, width: number, depth: number, bevel: number): THREE.ExtrudeGeometry {
  const geometry = new THREE.ExtrudeGeometry(chamferedRect(length, width, width * 0.28), {
    depth,
    steps: 1,
    bevelEnabled: true,
    bevelThickness: bevel,
    bevelSize: bevel * 0.72,
    bevelSegments: 7,
  });
  geometry.center();
  geometry.computeVertexNormals();
  return geometry;
}

function addSegmentedOctagon(
  parent: THREE.Group,
  radius: number,
  width: number,
  depth: number,
  material: THREE.Material,
  gap = 0.055,
  z = 0,
  bevel = 0.025,
  rotation = -Math.PI / 8,
): THREE.Group {
  const group = new THREE.Group();
  const vertices = octagonVertices(radius, rotation);
  const edge = vertices[0].distanceTo(vertices[1]);
  const geometry = extrudedSegmentGeometry(edge * (1 - gap), width, depth, bevel);
  for (let index = 0; index < 8; index += 1) {
    const start = vertices[index];
    const end = vertices[(index + 1) % 8];
    const midpoint = start.clone().add(end).multiplyScalar(0.5);
    const mesh = new THREE.Mesh(geometry, material);
    mesh.position.set(midpoint.x, midpoint.y, z);
    mesh.rotation.z = Math.atan2(end.y - start.y, end.x - start.x);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    group.add(mesh);
  }
  parent.add(group);
  return group;
}

function addCornerSegmentedOctagon(
  parent: THREE.Group,
  outerRadius: number,
  innerRadius: number,
  depth: number,
  material: THREE.Material,
  jointGap = 0.08,
  z = 0,
  bevel = 0.024,
  rotation = -Math.PI / 8,
): THREE.Group {
  const group = new THREE.Group();
  const outer = octagonVertices(outerRadius, rotation);
  const inner = octagonVertices(innerRadius, rotation);
  for (let index = 0; index < 8; index += 1) {
    const previous = (index + 7) % 8;
    const next = (index + 1) % 8;
    const outerPreviousMid = outer[previous].clone().add(outer[index]).multiplyScalar(0.5).lerp(outer[index], jointGap);
    const outerNextMid = outer[index].clone().add(outer[next]).multiplyScalar(0.5).lerp(outer[index], jointGap);
    const innerPreviousMid = inner[previous].clone().add(inner[index]).multiplyScalar(0.5).lerp(inner[index], jointGap);
    const innerNextMid = inner[index].clone().add(inner[next]).multiplyScalar(0.5).lerp(inner[index], jointGap);
    const shape = new THREE.Shape();
    const points = [outerPreviousMid, outer[index], outerNextMid, innerNextMid, inner[index], innerPreviousMid];
    points.forEach((point, pointIndex) => pointIndex ? shape.lineTo(point.x, point.y) : shape.moveTo(point.x, point.y));
    shape.closePath();
    const geometry = new THREE.ExtrudeGeometry(shape, {
      depth, steps: 1, bevelEnabled: true, bevelThickness: bevel, bevelSize: bevel * 0.72, bevelSegments: 6,
    });
    geometry.computeVertexNormals();
    const mesh = new THREE.Mesh(geometry, material);
    mesh.position.z = z;
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    group.add(mesh);
  }
  parent.add(group);
  return group;
}

function addOctRing(
  parent: THREE.Group,
  outer: number,
  inner: number,
  depth: number,
  material: THREE.Material,
  z = 0,
  bevel = 0.018,
): THREE.Mesh {
  const geometry = new THREE.ExtrudeGeometry(ringShape(outer, inner), {
    depth,
    steps: 1,
    bevelEnabled: true,
    bevelThickness: bevel,
    bevelSize: bevel * 0.7,
    bevelSegments: 6,
  });
  geometry.center();
  geometry.computeVertexNormals();
  const mesh = new THREE.Mesh(geometry, material);
  mesh.position.z = z;
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  parent.add(mesh);
  return mesh;
}

function addOctPlate(parent: THREE.Group, radius: number, depth: number, material: THREE.Material, z = 0): THREE.Mesh {
  const geometry = new THREE.ExtrudeGeometry(octShape(radius), {
    depth,
    steps: 1,
    bevelEnabled: true,
    bevelThickness: 0.018,
    bevelSize: 0.012,
    bevelSegments: 5,
  });
  geometry.center();
  geometry.computeVertexNormals();
  const mesh = new THREE.Mesh(geometry, material);
  mesh.position.z = z;
  mesh.receiveShadow = true;
  parent.add(mesh);
  return mesh;
}

function cylinderFacingCamera(radius: number, depth: number, material: THREE.Material, segments = 128): THREE.Mesh {
  const mesh = new THREE.Mesh(new THREE.CylinderGeometry(radius, radius, depth, segments, 1, false), material);
  mesh.rotation.x = Math.PI / 2;
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  return mesh;
}

function tubeBetween(start: THREE.Vector3, end: THREE.Vector3, radius: number, material: THREE.Material, segments = 18): THREE.Mesh {
  const delta = end.clone().sub(start);
  const mesh = new THREE.Mesh(new THREE.CylinderGeometry(radius, radius, delta.length(), segments), material);
  mesh.position.copy(start).add(end).multiplyScalar(0.5);
  mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), delta.normalize());
  return mesh;
}

function deterministic(index: number): number {
  const value = Math.sin(index * 12.9898 + 78.233) * 43758.5453;
  return value - Math.floor(value);
}

function makeBrushedRoughnessTexture(): THREE.CanvasTexture {
  const canvas = document.createElement('canvas');
  canvas.width = 1024;
  canvas.height = 128;
  const context = canvas.getContext('2d')!;
  context.fillStyle = '#7f7f7f';
  context.fillRect(0, 0, canvas.width, canvas.height);
  for (let y = 0; y < canvas.height; y += 1) {
    const wave = Math.sin(y * 0.43) * 12 + Math.sin(y * 1.7) * 5;
    const value = Math.max(52, Math.min(205, Math.round(125 + wave)));
    context.strokeStyle = `rgb(${value},${value},${value})`;
    context.globalAlpha = 0.24;
    context.beginPath();
    context.moveTo(0, y + 0.5);
    context.lineTo(canvas.width, y + 0.5);
    context.stroke();
  }
  context.globalAlpha = 1;
  const texture = new THREE.CanvasTexture(canvas);
  texture.wrapS = THREE.RepeatWrapping;
  texture.wrapT = THREE.RepeatWrapping;
  texture.repeat.set(2.4, 1);
  texture.colorSpace = THREE.NoColorSpace;
  return texture;
}

function makeCarbonTexture(): THREE.CanvasTexture {
  const canvas = document.createElement('canvas');
  canvas.width = 256;
  canvas.height = 256;
  const context = canvas.getContext('2d')!;
  context.fillStyle = '#111518';
  context.fillRect(0, 0, 256, 256);
  for (let index = -256; index < 512; index += 10) {
    context.strokeStyle = 'rgba(255,255,255,.035)';
    context.lineWidth = 3;
    context.beginPath();
    context.moveTo(index, 0);
    context.lineTo(index + 256, 256);
    context.stroke();
    context.strokeStyle = 'rgba(0,0,0,.32)';
    context.beginPath();
    context.moveTo(index + 5, 0);
    context.lineTo(index + 261, 256);
    context.stroke();
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.wrapS = THREE.RepeatWrapping;
  texture.wrapT = THREE.RepeatWrapping;
  texture.repeat.set(4, 4);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

function makeGlowTexture(): THREE.CanvasTexture {
  const canvas = document.createElement('canvas');
  canvas.width = 256;
  canvas.height = 256;
  const context = canvas.getContext('2d')!;
  const gradient = context.createRadialGradient(128, 128, 0, 128, 128, 128);
  gradient.addColorStop(0, 'rgba(255,255,255,1)');
  gradient.addColorStop(0.06, 'rgba(188,253,255,.98)');
  gradient.addColorStop(0.22, 'rgba(32,221,242,.48)');
  gradient.addColorStop(0.58, 'rgba(32,221,242,.08)');
  gradient.addColorStop(1, 'rgba(32,221,242,0)');
  context.fillStyle = gradient;
  context.fillRect(0, 0, 256, 256);
  return new THREE.CanvasTexture(canvas);
}

function makeShadowTexture(): THREE.CanvasTexture {
  const canvas = document.createElement('canvas');
  canvas.width = 512;
  canvas.height = 256;
  const context = canvas.getContext('2d')!;
  const gradient = context.createRadialGradient(256, 128, 6, 256, 128, 248);
  gradient.addColorStop(0, 'rgba(0,0,0,.78)');
  gradient.addColorStop(0.45, 'rgba(0,0,0,.35)');
  gradient.addColorStop(1, 'rgba(0,0,0,0)');
  context.fillStyle = gradient;
  context.fillRect(0, 0, 512, 256);
  return new THREE.CanvasTexture(canvas);
}

function addOctagonLine(parent: THREE.Group, radius: number, z: number, color: number, opacity: number): THREE.Line {
  const points = octagonVertices(radius).map(point => new THREE.Vector3(point.x, point.y, z));
  points.push(points[0].clone());
  const line = new THREE.Line(
    new THREE.BufferGeometry().setFromPoints(points),
    new THREE.LineBasicMaterial({ color, transparent: true, opacity, blending: THREE.AdditiveBlending, depthWrite: false }),
  );
  parent.add(line);
  return line;
}

export class ProvenanceIdentityScene {
  readonly canvas: HTMLCanvasElement;
  readonly renderer: THREE.WebGLRenderer;
  readonly scene = new THREE.Scene();
  readonly camera = new THREE.PerspectiveCamera(25, 1, 0.1, 80);
  readonly root = new THREE.Group();
  readonly objectGroup = new THREE.Group();
  readonly beamGroup = new THREE.Group();
  readonly glyphAnchor = new THREE.Group();

  private composer: EffectComposer | null = null;
  private bloom: UnrealBloomPass | null = null;
  private opticalTier: OpticalTier;
  private quality: SceneQuality;
  private interactive: boolean;
  private certificationTier: 0 | 1 | 2 | 3 | 4;
  private showGlyph: boolean;
  private motionSpeed: number;
  private state: IdentityStateContract;
  private reducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
  private animationFrame = 0;
  private renderedFrames = 0;
  private observer: ResizeObserver;
  private pointer = { x: 0, y: 0 };
  private disposed = false;
  private paused = false;
  private contextLost = false;
  private constrainedRuntime = false;
  private startTime = performance.now();
  private keyLight = new THREE.RectAreaLight(0xe7eef1, 4.2, 4.2, 3.0);
  private fillLight = new THREE.RectAreaLight(0x6b8490, 0.95, 4.0, 3.0);
  private rimLight = new THREE.PointLight(0x20ddf2, 1.25, 14, 2);
  private accentLight = new THREE.PointLight(0x20ddf2, 0.95, 8, 2);
  private materials: Materials;
  private motion: MotionParts = {
    outerRings: [], innerRings: [], nodes: [], nodeCores: [], pulseParts: [],
    beamParticles: null, particlePositions: null, scan: null,
  };
  private glyph: THREE.Group | null = null;
  private glyphCache = new Map<string, GlyphBuild>();
  private currentGlyphParts: THREE.Object3D[] = [];
  private core: THREE.Mesh | null = null;
  private coreHalo: THREE.Sprite | null = null;
  private coreLens: THREE.Mesh | null = null;
  private beamBody: THREE.Object3D[] = [];
  private lifecycleOverlay = new THREE.Group();

  constructor(readonly host: HTMLElement, options: IdentitySceneOptions = {}) {
    this.opticalTier = options.opticalTier ?? 'master';
    this.quality = options.quality ?? 'standard';
    this.interactive = options.interactive ?? false;
    this.certificationTier = options.certificationTier ?? 0;
    this.showGlyph = options.showGlyph ?? true;
    this.motionSpeed = options.motionSpeed ?? 1.68;
    this.state = identityStates[options.initialState ?? 'verify'];

    this.canvas = document.createElement('canvas');
    this.canvas.className = 'pcx-webgl-canvas';
    this.canvas.setAttribute('role', 'img');
    this.canvas.setAttribute('aria-label', `${options.ariaPrefix ?? ''}${this.state.accessibilityName}`.trim());
    host.replaceChildren(this.canvas);

    this.renderer = new THREE.WebGLRenderer({
      canvas: this.canvas,
      alpha: options.transparent ?? true,
      antialias: this.opticalTier !== 'micro',
      powerPreference: 'high-performance',
      preserveDrawingBuffer: false,
      stencil: false,
    });
    const gl = this.renderer.getContext();
    const rendererInfo = gl.getExtension('WEBGL_debug_renderer_info');
    const rendererName = String(rendererInfo ? gl.getParameter(rendererInfo.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER));
    this.constrainedRuntime = /swiftshader|software|llvmpipe|angle \(software\)/i.test(rendererName);
    this.host.dataset.rendererClass = this.constrainedRuntime ? 'software' : 'hardware';

    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 0.72;
    this.renderer.shadowMap.enabled = this.quality !== 'mini' && !this.constrainedRuntime;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    const pixelRatioCeiling = this.constrainedRuntime ? 1 : this.quality === 'hero' ? 1.8 : 1.5;
    this.renderer.setPixelRatio(Math.min(devicePixelRatio || 1, pixelRatioCeiling));

    RectAreaLightUniformsLib.init();
    if (!this.constrainedRuntime) {
      const pmrem = new THREE.PMREMGenerator(this.renderer);
      this.scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.036).texture;
      this.scene.environmentIntensity = 0.72;
      pmrem.dispose();
    } else {
      this.scene.environment = null;
      this.scene.environmentIntensity = 0;
    }

    const brushedRoughness = makeBrushedRoughnessTexture();
    const carbonMap = makeCarbonTexture();
    const tierMetal = this.certificationTier === 1 ? 0x39434a : this.certificationTier === 2 ? 0x8c5638 : this.certificationTier === 4 ? 0xa77d2c : 0x8a949a;
    const tierBright = this.certificationTier === 1 ? 0x77828a : this.certificationTier === 2 ? 0xc28b61 : this.certificationTier === 4 ? 0xd9b653 : 0xd6dde1;
    const tierDark = this.certificationTier === 1 ? 0x11161b : this.certificationTier === 2 ? 0x352117 : this.certificationTier === 4 ? 0x443511 : 0x182228;

    // On a software rasterizer (SwiftShader/llvmpipe — see constrainedRuntime above),
    // MeshPhysicalMaterial's clearcoat/anisotropy/roughness+bump-map shader permutations
    // take many seconds *each* to compile (CPU-emulated shader compilation, not just
    // slower per-pixel cost), which is the actual cause of the multi-second load stalls
    // this class is prone to on constrained hardware — measured directly via CPU
    // profiling, including after this already dropped clearcoat/anisotropy/maps: even
    // MeshStandardMaterial's real lighting computation (metalness/roughness against the
    // scene's lights) still compiles slowly enough to matter. A material with no
    // emissive requirement doesn't need to be lit at all here — constrainedRuntime
    // already drops shadows and the environment map, so an unlit MeshBasicMaterial (by
    // far the simplest fragment shader available) is a legitimate further step down the
    // same fidelity ladder, not a new one. Materials that glow (emissive) keep
    // MeshStandardMaterial, since MeshBasicMaterial has no such property. Full hardware
    // keeps every physical material feature regardless.
    const structuralMaterial = (options: THREE.MeshPhysicalMaterialParameters): StructuralMaterial => {
      if (!this.constrainedRuntime) return new THREE.MeshPhysicalMaterial(options);
      const basic: THREE.MeshBasicMaterialParameters = {};
      if (options.color !== undefined) basic.color = options.color;
      if (options.transparent !== undefined) basic.transparent = options.transparent;
      if (options.opacity !== undefined) basic.opacity = options.opacity;
      if (options.side !== undefined) basic.side = options.side;
      return new THREE.MeshBasicMaterial(basic);
    };

    const emissiveMaterial = (options: THREE.MeshPhysicalMaterialParameters & { emissive: THREE.ColorRepresentation }): EmissiveMaterial => {
      if (!this.constrainedRuntime) return new THREE.MeshPhysicalMaterial(options);
      const simple: THREE.MeshStandardMaterialParameters = { roughness: 0.5, emissive: options.emissive };
      if (options.color !== undefined) simple.color = options.color;
      if (options.metalness !== undefined) simple.metalness = options.metalness;
      if (typeof options.roughness === 'number') simple.roughness = options.roughness;
      if (options.emissiveIntensity !== undefined) simple.emissiveIntensity = options.emissiveIntensity;
      if (options.transparent !== undefined) simple.transparent = options.transparent;
      if (options.opacity !== undefined) simple.opacity = options.opacity;
      if (options.side !== undefined) simple.side = options.side;
      return new THREE.MeshStandardMaterial(simple);
    };

    this.materials = {
      silver: structuralMaterial({
        color: tierMetal, metalness: 1, roughness: 0.29, clearcoat: 0.24, clearcoatRoughness: 0.14, anisotropy: 0.78, anisotropyRotation: Math.PI / 2,
        roughnessMap: brushedRoughness, bumpMap: brushedRoughness, bumpScale: 0.006, envMapIntensity: 0.72,
      }),
      silverBright: structuralMaterial({
        color: tierBright, metalness: 1, roughness: 0.23, clearcoat: 0.34, clearcoatRoughness: 0.10, anisotropy: 0.72, anisotropyRotation: Math.PI / 2,
        roughnessMap: brushedRoughness, bumpMap: brushedRoughness, bumpScale: 0.004, envMapIntensity: 0.95,
      }),
      silverDark: structuralMaterial({
        color: tierDark, metalness: 0.92, roughness: 0.34, clearcoat: 0.20, clearcoatRoughness: 0.18, anisotropy: 0.58,
        roughnessMap: brushedRoughness, envMapIntensity: 0.42,
      }),
      polished: structuralMaterial({
        color: tierBright, metalness: 1, roughness: 0.13, clearcoat: 0.68, clearcoatRoughness: 0.04, envMapIntensity: 1.06,
      }),
      carbon: structuralMaterial({
        color: 0x010304, metalness: 0.16, roughness: 0.72, map: carbonMap, bumpMap: carbonMap, bumpScale: 0.012,
        clearcoat: 0.08, clearcoatRoughness: 0.58, envMapIntensity: 0.16,
      }),
      dark: structuralMaterial({
        color: 0x05090c, metalness: 0.62, roughness: 0.46, clearcoat: 0.28, clearcoatRoughness: 0.28, envMapIntensity: 0.28,
      }),
      glass: structuralMaterial({
        color: 0x021016, metalness: 0.02, roughness: 0.19, transmission: 0, transparent: true, opacity: 0.29,
        thickness: 0.32, ior: 1.46, clearcoat: 0.48, clearcoatRoughness: 0.10, envMapIntensity: 0.12, side: THREE.DoubleSide,
      }),
      // accent/accentSoft/stateMetal glow (emissive), so they simplify only as far as
      // MeshStandardMaterial, not the fully-unlit MeshBasicMaterial the 7 structural
      // materials above use. Their runtime .clearcoat mutation in setState() below is
      // guarded for constrainedRuntime, since MeshStandardMaterial has no such property.
      accent: emissiveMaterial({
        color: this.state.materialState.insertColor, metalness: this.state.materialState.metalness, roughness: this.state.materialState.roughness,
        emissive: this.state.statusColorHex, emissiveIntensity: this.state.materialState.emissiveIntensity,
        clearcoat: this.state.materialState.clearcoat, clearcoatRoughness: 0.06, envMapIntensity: 1.02,
        anisotropy: 0.34, anisotropyRotation: Math.PI / 2,
      }),
      accentSoft: emissiveMaterial({
        color: this.state.materialState.glassColor, metalness: Math.max(0.16, this.state.materialState.metalness * 0.38), roughness: Math.max(0.11, this.state.materialState.roughness * 0.72),
        emissive: this.state.statusColorHex, emissiveIntensity: this.state.materialState.emissiveIntensity * 0.58,
        transparent: true, opacity: this.state.materialState.glassOpacity, transmission: 0.06, thickness: 0.14,
        clearcoat: Math.min(1, this.state.materialState.clearcoat + 0.08), clearcoatRoughness: 0.08, envMapIntensity: 0.72,
      }),
      accentTransparent: new THREE.MeshBasicMaterial({
        color: this.state.statusColorHex, transparent: true, opacity: 0.34, blending: THREE.AdditiveBlending, depthWrite: false,
      }),
      stateMetal: emissiveMaterial({
        color: this.state.materialState.insertColor, metalness: 0.92, roughness: 0.19, clearcoat: 0.72, clearcoatRoughness: 0.05,
        emissive: this.state.statusColorHex, emissiveIntensity: 0.07, envMapIntensity: 1.05, anisotropy: 0.48, anisotropyRotation: Math.PI/2,
      }),
    };

    this.scene.add(this.root);
    this.root.add(this.objectGroup, this.beamGroup, this.glyphAnchor, this.lifecycleOverlay);
    this.setupScene();
    if (this.certificationTier === 0) {
      this.buildObject();
      this.buildBeam();
    } else {
      this.buildCertificationObject();
    }
    if (this.showGlyph) this.prebuildGlyphs();
    this.setState(this.state.key, false);

    this.observer = new ResizeObserver(() => this.resize());
    this.observer.observe(host);
    this.resize();

    this.canvas.addEventListener('webglcontextlost', event => {
      event.preventDefault();
      this.contextLost = true;
      host.dataset.context = 'lost';
    });
    this.canvas.addEventListener('webglcontextrestored', () => {
      this.contextLost = false;
      host.dataset.context = 'restored';
      this.renderOnce();
    });
    if (this.interactive) {
      host.addEventListener('pointermove', this.onPointerMove);
      host.addEventListener('pointerleave', this.onPointerLeave);
    }
    this.animate();
  }

  private setupScene(): void {
    this.scene.add(new THREE.HemisphereLight(0x667b84, 0x000102, this.certificationTier ? 0.34 : 0.18));

    this.keyLight.position.set(-5.4, 4.6, 6.6);
    this.keyLight.lookAt(0, 0, 0);
    this.scene.add(this.keyLight);

    this.fillLight.position.set(4.8, -2.6, 4.8);
    this.fillLight.lookAt(0, 0.1, 0);
    this.scene.add(this.fillLight);

    this.rimLight.position.set(4.4, 1.15, 4.6);
    this.scene.add(this.rimLight);
    this.accentLight.position.set(1.65, 0.1, 3.1);
    this.scene.add(this.accentLight);
    const leftWitness = new THREE.PointLight(0xb9d2dd, 0.32, 18, 2);
    leftWitness.position.set(-5.6, 3.8, 5.2);
    this.scene.add(leftWitness);
    const lowerWitness = new THREE.PointLight(0x6f8792, 0.18, 15, 2);
    lowerWitness.position.set(4.8, -4.0, 3.8);
    this.scene.add(lowerWitness);
    if (this.certificationTier) {
      const certificationKey = new THREE.DirectionalLight(0xf2fbff, this.constrainedRuntime ? 3.8 : 2.15);
      certificationKey.position.set(-3.8, 5.2, 8.4);
      this.scene.add(certificationKey);
      const certificationWarm = new THREE.DirectionalLight(this.certificationTier === 4 ? 0xffd77d : 0xc8e7ee, this.constrainedRuntime ? 2.35 : 1.2);
      certificationWarm.position.set(4.6, -1.8, 6.2);
      this.scene.add(certificationWarm);
      const certificationAmbient = new THREE.AmbientLight(0xbad9df, this.constrainedRuntime ? 0.72 : 0.3);
      this.scene.add(certificationAmbient);
    } else if (this.constrainedRuntime) {
      const softwareKey = new THREE.DirectionalLight(0xdff8fb, 2.65);
      softwareKey.position.set(-4.2, 4.8, 7.6);
      this.scene.add(softwareKey);
      const softwareFill = new THREE.DirectionalLight(0x56dce6, 1.15);
      softwareFill.position.set(4.2, -1.8, 5.4);
      this.scene.add(softwareFill);
      this.scene.add(new THREE.AmbientLight(0x89aeb5, 0.42));
    }

    this.camera.position.set(0, 0.08, 15.7);
    this.root.rotation.set(-0.055, -0.135, 0);

    if (this.quality === 'hero' && !this.constrainedRuntime) {
      this.composer = new EffectComposer(this.renderer);
      this.composer.addPass(new RenderPass(this.scene, this.camera));
      this.bloom = new UnrealBloomPass(
        new THREE.Vector2(512, 512),
        0.04,
        0.24,
        0.9,
      );
      this.composer.addPass(this.bloom);
      this.composer.addPass(new OutputPass());
    }

    if (this.opticalTier === 'master') {
      const shadow = new THREE.Mesh(
        new THREE.PlaneGeometry(7.6, 2.2),
        new THREE.MeshBasicMaterial({ map: makeShadowTexture(), transparent: true, opacity: 0.68, depthWrite: false }),
      );
      shadow.rotation.x = -Math.PI / 2;
      shadow.position.set(0, -3.05, -0.8);
      this.scene.add(shadow);

      const floor = new THREE.Mesh(
        new THREE.CircleGeometry(5.4, 128),
        new THREE.MeshPhysicalMaterial({ color: 0x020405, metalness: 0.18, roughness: 0.78, transparent: true, opacity: 0.32 }),
      );
      floor.rotation.x = -Math.PI / 2;
      floor.position.set(0, -3.22, -1.02);
      floor.receiveShadow = true;
      this.scene.add(floor);
    }
  }

  private buildObject(): void {
    // Preserve the full master object on hardware renderers. Software renderers use the
    // maintained compact optical tier so the live scene remains operational instead of
    // crashing into a static fallback. Authority state, layers, nodes, rings, and proof
    // transitions remain present in both paths.
    if (this.constrainedRuntime) this.buildCompactObject();
    else this.buildMasterObject();
  }

  private buildMasterObject(): void {
    const { silver, silverBright, silverDark, polished, carbon, dark, glass, accent, accentSoft, stateMetal } = this.materials;

    // Rear authority plate and restrained smoked-glass chamber.
    addOctPlate(this.objectGroup, 2.55, 0.20, carbon, -0.30);
    addOctPlate(this.objectGroup, 2.28, 0.10, glass, -0.10);

    // Precision outer frame: dark mechanical carrier, machined body, bright witness edge.
    this.motion.outerRings.push(addCornerSegmentedOctagon(this.objectGroup, 2.78, 2.46, 0.30, carbon, 0.07, -0.16, 0.034));
    this.motion.outerRings.push(addCornerSegmentedOctagon(this.objectGroup, 2.72, 2.47, 0.31, silver, 0.075, 0.00, 0.027));
    this.motion.outerRings.push(addCornerSegmentedOctagon(this.objectGroup, 2.68, 2.635, 0.052, silverBright, 0.082, 0.205, 0.008));
    this.motion.outerRings.push(addCornerSegmentedOctagon(this.objectGroup, 2.505, 2.47, 0.05, silverBright, 0.082, 0.205, 0.008));

    // Secondary mechanical frame and cyan witness line.
    this.motion.outerRings.push(addCornerSegmentedOctagon(this.objectGroup, 2.34, 2.20, 0.18, silverDark, 0.055, 0.14, 0.018));
    this.motion.innerRings.push(addCornerSegmentedOctagon(this.objectGroup, 2.08, 1.995, 0.12, silver, 0.05, 0.27, 0.014));
    this.motion.innerRings.push(addCornerSegmentedOctagon(this.objectGroup, 1.91, 1.888, 0.040, accentSoft, 0.05, 0.37, 0.005));

    // Inner carbon chamber and transparent octagonal edge.
    addOctRing(this.objectGroup, 1.79, 1.06, 0.12, dark, 0.17, 0.014);
    addOctRing(this.objectGroup, 1.72, 1.61, 0.06, glass, 0.29, 0.008);
    addOctagonLine(this.objectGroup, 2.5, 0.33, 0x87f7ff, 0.12);
    addOctagonLine(this.objectGroup, 2.17, 0.38, 0x20ddf2, 0.18);

    // State color is a physical insert system, not a flat color drawn over the corporate mark.
    const stateCarrier = addOctRing(this.objectGroup, 1.32, 1.18, 0.075, stateMetal, 0.45, 0.010);
    this.motion.innerRings.push(stateCarrier);
    const stateWitness = addOctRing(this.objectGroup, 1.10, 1.055, 0.052, accent, 0.54, 0.007);
    this.motion.innerRings.push(stateWitness);

    // Radial authority rails and engineered node mounts.
    const nodeMetal = polished.clone();
    nodeMetal.color.setHex(0xaab4b9);
    if (!this.constrainedRuntime) {
      (nodeMetal as THREE.MeshPhysicalMaterial).roughness = 0.11;
      (nodeMetal as THREE.MeshPhysicalMaterial).envMapIntensity = 1.18;
    }
    for (let index = 0; index < 8; index += 1) {
      const angle = -Math.PI / 2 + index * Math.PI / 4;
      const inner = new THREE.Vector3(Math.cos(angle) * 0.76, Math.sin(angle) * 0.76, 0.42);
      const outer = new THREE.Vector3(Math.cos(angle) * 1.49, Math.sin(angle) * 1.49, 0.42);
      const rail = tubeBetween(inner, outer, 0.026, silverDark, 20);
      this.objectGroup.add(rail);
      const conductor = tubeBetween(inner.clone().setZ(0.49), outer.clone().setZ(0.49), 0.012, stateMetal, 12);
      this.objectGroup.add(conductor);

      const socket = cylinderFacingCamera(0.145, 0.11, carbon, 64);
      socket.position.copy(outer);
      socket.position.z = 0.38;
      this.objectGroup.add(socket);

      const collar = new THREE.Mesh(new THREE.TorusGeometry(0.108, 0.019, 14, 64), stateMetal);
      collar.position.set(outer.x, outer.y, 0.52);
      this.objectGroup.add(collar);

      const node = new THREE.Mesh(new THREE.SphereGeometry(0.079, 56, 40), nodeMetal);
      node.position.set(outer.x, outer.y, 0.59);
      node.castShadow = true;
      this.objectGroup.add(node);
      this.motion.nodes.push(node);

      const nodeCore = new THREE.Mesh(new THREE.SphereGeometry(0.015, 24, 18), accent);
      nodeCore.position.set(outer.x + 0.035, outer.y + 0.035, 0.68);
      this.objectGroup.add(nodeCore);
      this.motion.nodeCores.push(nodeCore);
      this.motion.pulseParts.push(nodeCore);
    }

    // Layered authority core: smaller, deeper, and mechanically mounted.
    const coreBack = cylinderFacingCamera(0.76, 0.24, carbon, 160);
    coreBack.position.z = 0.23;
    this.objectGroup.add(coreBack);

    const coreOuterRing = new THREE.Mesh(new THREE.TorusGeometry(0.70, 0.064, 28, 192), silverDark);
    coreOuterRing.position.z = 0.43;
    coreOuterRing.castShadow = true;
    this.objectGroup.add(coreOuterRing);
    this.motion.innerRings.push(coreOuterRing);
    const coreWitnessRing = new THREE.Mesh(new THREE.TorusGeometry(0.735, 0.022, 18, 192), polished);
    coreWitnessRing.position.z = 0.49;
    this.objectGroup.add(coreWitnessRing);

    const coreSilverRing = new THREE.Mesh(new THREE.TorusGeometry(0.55, 0.048, 28, 192), polished);
    coreSilverRing.position.z = 0.5;
    coreSilverRing.castShadow = true;
    this.objectGroup.add(coreSilverRing);
    this.motion.innerRings.push(coreSilverRing);

    const coreDark = cylinderFacingCamera(0.44, 0.30, dark, 144);
    coreDark.position.z = 0.48;
    this.objectGroup.add(coreDark);

    const coreAccentRing = new THREE.Mesh(new THREE.TorusGeometry(0.31, 0.022, 20, 160), accentSoft);
    coreAccentRing.position.z = 0.66;
    this.objectGroup.add(coreAccentRing);
    this.motion.innerRings.push(coreAccentRing);

    this.coreLens = cylinderFacingCamera(0.205, 0.20, glass, 128);
    this.coreLens.position.z = 0.68;
    this.objectGroup.add(this.coreLens);

    this.core = new THREE.Mesh(new THREE.SphereGeometry(0.061, 64, 44), accent);
    this.core.position.z = 0.86;
    this.core.castShadow = true;
    this.objectGroup.add(this.core);
    this.motion.pulseParts.push(this.core);

    this.coreHalo = new THREE.Sprite(new THREE.SpriteMaterial({
      map: makeGlowTexture(), color: this.state.statusColorHex, transparent: true, opacity: 0.48,
      blending: THREE.AdditiveBlending, depthWrite: false,
    }));
    this.coreHalo.position.set(0, 0, 0.79);
    this.coreHalo.scale.set(0.54, 0.54, 1);
    this.objectGroup.add(this.coreHalo);

    // Fine cross-axis construction lines.
    const lineMaterial = new THREE.LineBasicMaterial({ color: 0x91f7ff, transparent: true, opacity: 0.16, blending: THREE.AdditiveBlending });
    for (const [start, end] of [
      [new THREE.Vector3(0, -2.58, 0.34), new THREE.Vector3(0, 2.58, 0.34)],
      [new THREE.Vector3(-2.58, 0, 0.34), new THREE.Vector3(2.58, 0, 0.34)],
    ] as [THREE.Vector3, THREE.Vector3][]) {
      this.objectGroup.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints([start, end]), lineMaterial));
    }

    const scanMaterial = new THREE.MeshBasicMaterial({
      color: this.state.statusColorHex, transparent: true, opacity: 0,
      blending: THREE.AdditiveBlending, depthWrite: false,
    });
    this.motion.scan = new THREE.Mesh(new THREE.PlaneGeometry(4.6, 0.018), scanMaterial);
    this.motion.scan.position.set(0, -2.2, 0.79);
    this.objectGroup.add(this.motion.scan);
  }

  private buildCompactObject(): void {
    const { silver, silverDark, polished, carbon, dark, glass, accent, accentSoft } = this.materials;
    addOctPlate(this.objectGroup, 1.92, 0.13, carbon, -0.14);
    addOctPlate(this.objectGroup, 1.68, 0.08, glass, -0.03);
    this.motion.outerRings.push(addCornerSegmentedOctagon(this.objectGroup, 2.02, 1.74, 0.24, carbon, 0.06, -0.08, 0.031));
    this.motion.outerRings.push(addCornerSegmentedOctagon(this.objectGroup, 1.97, 1.80, 0.25, silver, 0.065, 0.05, 0.026));
    this.motion.innerRings.push(addSegmentedOctagon(this.objectGroup, 1.52, 0.11, 0.15, silverDark, 0.06, 0.21, 0.02));
    this.motion.innerRings.push(addSegmentedOctagon(this.objectGroup, 1.31, 0.022, 0.045, accentSoft, 0.08, 0.32, 0.008));
    const compactCarrier = addOctRing(this.objectGroup, 1.02, 0.86, 0.12, silverDark, 0.22, 0.014);
    this.motion.innerRings.push(compactCarrier);
    for (let index = 0; index < 4; index += 1) {
      const angle = index * Math.PI / 2;
      const start = new THREE.Vector3(Math.cos(angle) * 0.52, Math.sin(angle) * 0.52, 0.35);
      const end = new THREE.Vector3(Math.cos(angle) * 0.92, Math.sin(angle) * 0.92, 0.35);
      this.objectGroup.add(tubeBetween(start, end, 0.018, silverDark, 12));
      const port = new THREE.Mesh(new THREE.SphereGeometry(0.076, 28, 20), polished);
      port.position.set(end.x, end.y, 0.43);
      this.objectGroup.add(port);
      this.motion.nodes.push(port);
      const signal = new THREE.Mesh(new THREE.SphereGeometry(0.018, 16, 12), accent);
      signal.position.set(end.x + 0.018, end.y + 0.018, 0.49);
      this.objectGroup.add(signal);
      this.motion.nodeCores.push(signal);
    }
    const coreBack = cylinderFacingCamera(0.62, 0.18, dark, 96); coreBack.position.z = 0.24; this.objectGroup.add(coreBack);
    const ring = new THREE.Mesh(new THREE.TorusGeometry(0.47, 0.065, 20, 128), polished); ring.position.z = 0.4; this.objectGroup.add(ring); this.motion.innerRings.push(ring);
    const accentRing = new THREE.Mesh(new THREE.TorusGeometry(0.31, 0.026, 16, 112), accentSoft); accentRing.position.z = 0.5; this.objectGroup.add(accentRing); this.motion.innerRings.push(accentRing);
    this.core = new THREE.Mesh(new THREE.SphereGeometry(0.09, 40, 30), accent); this.core.position.z = 0.63; this.objectGroup.add(this.core); this.motion.pulseParts.push(this.core);
    this.coreHalo = new THREE.Sprite(new THREE.SpriteMaterial({ map: makeGlowTexture(), color: this.state.statusColorHex, transparent: true, opacity: 0.26, blending: THREE.AdditiveBlending, depthWrite: false }));
    this.coreHalo.position.set(0, 0, 0.57); this.coreHalo.scale.set(0.64, 0.64, 1); this.objectGroup.add(this.coreHalo);
  }

  private buildMicroObject(): void {
    const { silverBright, carbon, dark, accent, accentSoft } = this.materials;
    addOctPlate(this.objectGroup, 1.45, 0.12, carbon, -0.1);
    const perimeter = addOctRing(this.objectGroup, 1.55, 1.22, 0.2, silverBright, 0.03, 0.028);
    this.motion.outerRings.push(perimeter as unknown as THREE.Group);
    const inner = addOctRing(this.objectGroup, 0.7, 0.5, 0.13, dark, 0.17, 0.018);
    this.motion.innerRings.push(inner);
    const accentRing = new THREE.Mesh(new THREE.TorusGeometry(0.36, 0.026, 14, 80), accentSoft);
    accentRing.position.z = 0.31;
    this.objectGroup.add(accentRing);
    this.motion.innerRings.push(accentRing);
    this.core = new THREE.Mesh(new THREE.SphereGeometry(0.105, 32, 24), accent);
    this.core.position.z = 0.45;
    this.objectGroup.add(this.core);
    this.motion.pulseParts.push(this.core);
  }

  private buildCertificationObject(): void {
    const { silver, silverBright, silverDark, polished, carbon, dark, glass, accentSoft } = this.materials;
    addOctPlate(this.objectGroup, 2.42, 0.2, carbon, -0.18);
    addOctPlate(this.objectGroup, 2.12, 0.1, glass, -0.03);
    this.motion.outerRings.push(addCornerSegmentedOctagon(this.objectGroup, 2.58, 2.24, 0.27, carbon, 0.065, -0.1, 0.036));
    this.motion.outerRings.push(addCornerSegmentedOctagon(this.objectGroup, 2.52, 2.31, 0.3, silver, 0.07, 0.05, 0.030));
    this.motion.outerRings.push(addCornerSegmentedOctagon(this.objectGroup, 2.48, 2.425, 0.068, silverBright, 0.075, 0.22, 0.012));
    const sealCarrier = addOctRing(this.objectGroup, 2.03, 1.86, 0.14, silverDark, 0.22, 0.018);
    this.motion.innerRings.push(sealCarrier);
    const radii = [1.66, 1.42, 1.18, 0.94];
    for (let index = 0; index < this.certificationTier; index += 1) {
      const outer = radii[index];
      const ring = addOctRing(this.objectGroup, outer, outer - 0.055, 0.07, silverBright, 0.38 + index * 0.012, 0.01);
      this.motion.innerRings.push(ring);
    }
    const centerBase = cylinderFacingCamera(0.72, 0.22, dark, 112);
    centerBase.position.z = 0.38;
    this.objectGroup.add(centerBase);
    const centerRing = new THREE.Mesh(new THREE.TorusGeometry(0.57, 0.07, 22, 144), polished);
    centerRing.position.z = 0.55;
    this.objectGroup.add(centerRing);
    this.motion.innerRings.push(centerRing);
    const signatureRing = new THREE.Mesh(new THREE.TorusGeometry(0.39, 0.025, 18, 112), accentSoft);
    signatureRing.position.z = 0.66;
    this.objectGroup.add(signatureRing);
    this.motion.innerRings.push(signatureRing);
    this.core = new THREE.Mesh(new THREE.SphereGeometry(0.075, 40, 28), this.materials.accent);
    this.core.position.z = 0.78;
    this.objectGroup.add(this.core);
    this.motion.pulseParts.push(this.core);
    this.beamGroup.visible = false;
  }

  private buildCertificationOverlay(): void {
    const ringColor = this.materials.silverBright;
    for (let index = 0; index < this.certificationTier; index += 1) {
      const radius = 1.33 - index * 0.14;
      const ring = new THREE.Mesh(new THREE.TorusGeometry(radius, 0.025, 14, 128), ringColor);
      ring.position.z = 0.77 + index * 0.008;
      this.objectGroup.add(ring);
      this.motion.innerRings.push(ring);
    }
    this.beamGroup.visible = false;
  }

  private addCircuitBranch(points: THREE.Vector3[]): void {
    const material = new THREE.LineBasicMaterial({
      color: this.state.statusColorHex, transparent: true, opacity: 0.26,
      blending: THREE.AdditiveBlending, depthWrite: false,
    });
    this.beamGroup.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints(points), material));
  }

  private buildBeam(): void {
    const { accentTransparent, dark, silverDark } = this.materials;
    const start = 0.18;
    const end = 4.55;
    const z = 0.72;

    const central = tubeBetween(new THREE.Vector3(start, 0, z), new THREE.Vector3(end, 0, z), 0.02, accentTransparent, 14);
    this.beamGroup.add(central);
    this.beamBody.push(central);

    if (this.opticalTier !== 'micro') {
      const emitter = new THREE.Mesh(new THREE.TorusGeometry(0.13, 0.025, 14, 64), silverDark);
      emitter.rotation.y = Math.PI / 2;
      emitter.position.set(2.08, 0, z);
      this.beamGroup.add(emitter);

      for (const offset of [-0.12, 0.12]) {
        const guide = tubeBetween(
          new THREE.Vector3(1.2, offset, z - 0.02),
          new THREE.Vector3(end * 0.93, offset * 1.6, z - 0.02),
          0.007,
          accentTransparent,
          10,
        );
        this.beamGroup.add(guide);
        this.beamBody.push(guide);
      }

      this.addCircuitBranch([
        new THREE.Vector3(2.05, 0.12, z), new THREE.Vector3(2.48, 0.34, z), new THREE.Vector3(3.12, 0.34, z), new THREE.Vector3(3.42, 0.52, z), new THREE.Vector3(4.08, 0.52, z),
      ]);
      this.addCircuitBranch([
        new THREE.Vector3(2.22, -0.12, z), new THREE.Vector3(2.68, -0.32, z), new THREE.Vector3(3.42, -0.32, z), new THREE.Vector3(3.72, -0.5, z), new THREE.Vector3(4.24, -0.5, z),
      ]);
    }

    if (true) {
      const count = 100;
      const positions = new Float32Array(count * 3);
      for (let index = 0; index < count; index += 1) {
        positions[index * 3] = 1.55 + deterministic(index) * 3.0;
        positions[index * 3 + 1] = (deterministic(index + 100) - 0.5) * 0.38;
        positions[index * 3 + 2] = z + (deterministic(index + 200) - 0.5) * 0.08;
      }
      const geometry = new THREE.BufferGeometry();
      geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
      const points = new THREE.Points(geometry, new THREE.PointsMaterial({
        color: this.state.statusColorHex, size: 0.026, transparent: true, opacity: 0.68,
        blending: THREE.AdditiveBlending, depthWrite: false, sizeAttenuation: true,
      }));
      this.beamGroup.add(points);
      this.motion.beamParticles = points;
      this.motion.particlePositions = positions;
    }

    const gate = cylinderFacingCamera(0.12, 0.08, dark, 48);
    gate.rotation.z = Math.PI / 2;
    gate.position.set(2.72, 0, z - 0.03);
    this.beamGroup.add(gate);
  }

  private createGlyph(kind: IdentityStateContract['glyph']): GlyphBuild {
    const built = buildGlyph(kind, this.materials.accent, this.materials.carbon);
    const scale = 0.58;
    built.group.scale.setScalar(scale);
    built.group.position.z = 0.73;
    built.group.visible = false;
    this.glyphAnchor.add(built.group);
    this.glyphCache.set(kind, built);
    return built;
  }

  private prebuildGlyphs(): void {
    const kinds = (this.quality === 'mini' || this.constrainedRuntime ? [this.state.glyph] : Object.values(identityStates).map(state => state.glyph)) as IdentityStateContract['glyph'][];
    for (const kind of [...new Set(kinds)]) if (!this.glyphCache.has(kind)) this.createGlyph(kind);
  }

  private activateGlyph(kind: IdentityStateContract['glyph']): void {
    if (this.glyph) this.glyph.visible = false;
    const built = this.glyphCache.get(kind) ?? this.createGlyph(kind);
    this.glyph = built.group;
    this.glyph.visible = true;
    this.currentGlyphParts = built.pulseParts;
  }

  private setMaterialOpacity(material: THREE.Material, opacity: number): void {
    const value = material as THREE.Material & { opacity?: number; transparent?: boolean };
    if (value.opacity !== undefined) value.opacity = opacity;
    if (opacity < 1) value.transparent = true;
  }

  private applyStateGeometry(contract: IdentityStateContract): void {
    const failedLike = contract.lifecycle === 'failed' || contract.lifecycle === 'revoked';
    const pendingLike = contract.lifecycle === 'pending' || contract.lifecycle === 'exception';

    this.motion.outerRings.forEach((ring, index) => {
      const target = failedLike ? 1.018 + index * 0.002 : contract.key === 'secure' ? 0.994 : 1;
      ring.scale.setScalar(target);
    });

    this.motion.nodes.forEach((node, index) => {
      node.visible = contract.lifecycle !== 'revoked';
      node.rotation.z = index * 0.05;
      const opacity = pendingLike ? 0.48 : failedLike ? 0.25 : 1;
      this.setMaterialOpacity(node.material as THREE.Material, opacity);
    });
    this.motion.nodeCores.forEach((core, index) => {
      core.visible = contract.lifecycle !== 'revoked';
      const opacity = pendingLike ? (index % 2 ? 0.16 : 0.5) : failedLike ? 0.12 : 0.82;
      this.setMaterialOpacity(core.material as THREE.Material, opacity);
    });

    this.lifecycleOverlay.clear();
    if (contract.lifecycle === 'failed' || contract.lifecycle === 'revoked') {
      const slash = tubeBetween(new THREE.Vector3(-1.65, -1.65, 0.86), new THREE.Vector3(1.65, 1.65, 0.86), 0.018, this.materials.accentTransparent, 12);
      this.lifecycleOverlay.add(slash);
    }
  }

  setState(name: IdentityStateName, announce = true): void {
    const contract = identityStates[name];
    this.state = contract;
    this.canvas.setAttribute('aria-label', contract.accessibilityName);
    this.host.dataset.state = name;
    this.host.style.setProperty('--state-color', contract.statusColor);

    const materialState = contract.materialState;
    // .clearcoat only exists on MeshPhysicalMaterial, not the MeshStandardMaterial
    // physicalOrSimple() substitutes under constrainedRuntime (see the constructor).
    this.materials.accent.color.setHex(materialState.insertColor);
    this.materials.accent.metalness = materialState.metalness;
    this.materials.accent.roughness = materialState.roughness;
    if (!this.constrainedRuntime) (this.materials.accent as THREE.MeshPhysicalMaterial).clearcoat = materialState.clearcoat;
    this.materials.accent.emissive.setHex(contract.statusColorHex);
    this.materials.accent.emissiveIntensity = materialState.emissiveIntensity;
    this.materials.accentSoft.color.setHex(materialState.glassColor);
    this.materials.accentSoft.metalness = Math.max(0.16, materialState.metalness * 0.38);
    this.materials.accentSoft.roughness = Math.max(0.11, materialState.roughness * 0.72);
    if (!this.constrainedRuntime) (this.materials.accentSoft as THREE.MeshPhysicalMaterial).clearcoat = Math.min(1, materialState.clearcoat + 0.08);
    this.materials.accentSoft.opacity = materialState.glassOpacity;
    this.materials.accentSoft.emissive.setHex(contract.statusColorHex);
    this.materials.accentSoft.emissiveIntensity = materialState.emissiveIntensity * 0.58;
    this.materials.accentTransparent.color.setHex(contract.statusColorHex);
    this.materials.stateMetal.color.setHex(materialState.insertColor);
    this.materials.stateMetal.metalness = Math.max(.62, materialState.metalness);
    this.materials.stateMetal.roughness = Math.max(.12, materialState.roughness * .82);
    if (!this.constrainedRuntime) (this.materials.stateMetal as THREE.MeshPhysicalMaterial).clearcoat = Math.min(1, materialState.clearcoat + .08);
    this.materials.stateMetal.emissive.setHex(contract.statusColorHex);
    this.materials.stateMetal.emissiveIntensity = materialState.emissiveIntensity * .34;
    this.rimLight.color.setHex(contract.statusColorHex);
    this.accentLight.color.setHex(contract.statusColorHex);

    const certificationLightBoost = this.certificationTier ? (this.constrainedRuntime ? 1.72 : 1.28) : 1;
    this.keyLight.intensity = contract.lightingState.key * 0.22 * certificationLightBoost;
    this.fillLight.intensity = contract.lightingState.fill * 0.12 * certificationLightBoost;
    this.rimLight.intensity = contract.lightingState.rim * 0.095 * certificationLightBoost;
    this.accentLight.intensity = contract.lightingState.accent * 0.06 * certificationLightBoost;
    this.renderer.toneMappingExposure = contract.lightingState.exposure * (this.certificationTier ? (this.constrainedRuntime ? 0.94 : 0.72) : 0.52);

    if (this.coreHalo) (this.coreHalo.material as THREE.SpriteMaterial).color.setHex(contract.statusColorHex);
    if (this.motion.scan) (this.motion.scan.material as THREE.MeshBasicMaterial).color.setHex(contract.statusColorHex);
    if (this.motion.beamParticles) (this.motion.beamParticles.material as THREE.PointsMaterial).color.setHex(contract.statusColorHex);
    this.beamGroup.traverse((node) => {
      const object = node as THREE.Object3D & { material?: THREE.Material & { color?: THREE.Color } };
      if (object.material?.color && object.material !== this.materials.dark && object.material !== this.materials.silverDark) {
        object.material.color.setHex(contract.statusColorHex);
      }
    });

    if (this.showGlyph) this.activateGlyph(contract.glyph);
    this.beamGroup.visible = contract.motionState.beam > 0.001;
    this.applyStateGeometry(contract);
    if (announce) this.host.dispatchEvent(new CustomEvent('pcx-statechange', { detail: contract, bubbles: true }));
    this.renderOnce();
  }

  setMotionSpeed(value: number): void {
    this.motionSpeed = Math.max(0.35, Math.min(3, value));
    this.host.dataset.motionSpeed = this.motionSpeed.toFixed(2);
  }

  setReducedMotion(value: boolean): void {
    this.reducedMotion = value;
    this.host.dataset.reducedMotion = value ? 'true' : 'false';
    this.renderOnce();
  }

  getState(): IdentityStateContract { return this.state; }

  getRendererInfo(): Record<string, unknown> {
    const gl = this.renderer.getContext();
    return {
      renderer: gl.getParameter(gl.RENDERER),
      vendor: gl.getParameter(gl.VENDOR),
      version: gl.getParameter(gl.VERSION),
      contextsLost: this.contextLost,
      triangles: this.renderer.info.render.triangles,
      calls: this.renderer.info.render.calls,
    };
  }

  forceContextLossRestore(delay = 180): boolean {
    const gl = this.renderer.getContext();
    const extension = gl.getExtension('WEBGL_lose_context');
    if (!extension) return false;
    setTimeout(() => {
      extension.loseContext();
      setTimeout(() => extension.restoreContext(), delay);
    }, 0);
    return true;
  }

  private onPointerMove = (event: PointerEvent): void => {
    const rect = this.host.getBoundingClientRect();
    this.pointer.x = ((event.clientX - rect.left) / rect.width - 0.5) * 0.22;
    this.pointer.y = ((event.clientY - rect.top) / rect.height - 0.5) * 0.14;
  };

  private onPointerLeave = (): void => {
    this.pointer.x = 0;
    this.pointer.y = 0;
  };

  private resize(): void {
    const width = Math.max(16, this.host.clientWidth);
    const height = Math.max(16, this.host.clientHeight);
    this.renderer.setSize(width, height, false);
    this.camera.aspect = width / height;
    const ratio = width / height;
    this.camera.position.z = ratio < 0.9 ? 16.8 : ratio > 1.25 ? 14.8 : 15.7;
    this.root.position.x = this.certificationTier ? 0 : ratio > 1.15 ? -0.28 : 0;
    this.camera.updateProjectionMatrix();
    this.composer?.setSize(width, height);
    if (this.bloom) this.bloom.resolution.set(width, height);
    this.renderOnce();
  }

  captureDataURL(): string {
    this.renderOnce();
    const gl = this.renderer.getContext();
    const width = this.canvas.width;
    const height = this.canvas.height;
    const pixels = new Uint8Array(width * height * 4);
    gl.readPixels(0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, pixels);
    const raw = document.createElement('canvas');
    raw.width = width;
    raw.height = height;
    const rawContext = raw.getContext('2d')!;
    rawContext.putImageData(new ImageData(new Uint8ClampedArray(pixels.buffer), width, height), 0, 0);
    const output = document.createElement('canvas');
    output.width = width;
    output.height = height;
    const context = output.getContext('2d')!;
    context.translate(0, height);
    context.scale(1, -1);
    context.drawImage(raw, 0, 0);
    return output.toDataURL('image/png');
  }

  freezeToImage(): string {
    const url = this.captureDataURL();
    const image = document.createElement('img');
    image.src = url;
    image.alt = this.canvas.getAttribute('aria-label') || 'PROVENANCE VERIFIED™ live identity render';
    image.className = 'pcx-frozen-render';
    this.dispose();
    this.host.replaceChildren(image);
    return url;
  }

  pause(): void {
    this.paused = true;
    cancelAnimationFrame(this.animationFrame);
    this.renderOnce();
  }

  resume(): void {
    if (!this.paused || this.disposed) return;
    this.paused = false;
    this.startTime = performance.now();
    this.animate();
  }

  private animate = (): void => {
    if (this.disposed || this.paused) return;
    this.animationFrame = requestAnimationFrame(this.animate);
    if (this.contextLost) return;

    const time = ((performance.now() - this.startTime) / 1000) * this.motionSpeed;
    const motion = this.state.motionState;
    const staticMode = this.reducedMotion;
    const targetY = this.interactive ? -0.135 + this.pointer.x : -0.135;
    const targetX = this.interactive ? -0.055 - this.pointer.y : -0.055;
    this.root.rotation.y += (targetY - this.root.rotation.y) * 0.065;
    this.root.rotation.x += (targetX - this.root.rotation.x) * 0.065;

    if (!staticMode) {
      this.motion.outerRings.forEach((ring, index) => {
        ring.rotation.z += (index % 2 ? motion.outerSpin * 0.32 : -motion.outerSpin * 0.22) * this.motionSpeed / 60;
      });
      this.motion.innerRings.forEach((ring, index) => {
        ring.rotation.z += (index % 2 ? motion.innerSpin * 0.38 : -motion.innerSpin * 0.24) * this.motionSpeed / 60;
      });
      this.motion.pulseParts.forEach((part, index) => {
        const pulse = 1 + Math.max(0, Math.sin(time * 1.8 - index * 0.34)) * motion.pulse * 0.42;
        part.scale.setScalar(pulse);
      });
      this.currentGlyphParts.forEach((part, index) => {
        const pulse = 1 + Math.max(0, Math.sin(time * 1.9 - index * 0.42)) * motion.pulse * 0.18;
        part.scale.setScalar(pulse);
      });
      this.motion.nodes.forEach((node, index) => {
        const scale = 1 + Math.max(0, Math.sin(time * 1.45 - index * 0.58)) * motion.nodeWave * 0.38;
        node.scale.setScalar(scale);
      });
      this.beamGroup.scale.x = 0.46 + motion.beam * 0.54 + Math.sin(time * 1.45) * 0.012 * motion.beam;
      this.beamGroup.visible = motion.beam > 0.001;
      if (this.motion.scan) {
        (this.motion.scan.material as THREE.MeshBasicMaterial).opacity = motion.scan * 0.22;
        this.motion.scan.position.y = ((time * 0.56) % 1) * 4.4 - 2.2;
      }
      if (this.motion.beamParticles && this.motion.particlePositions) {
        const positions = this.motion.particlePositions;
        for (let index = 0; index < positions.length; index += 3) {
          positions[index] += 0.012 + 0.035 * motion.beam;
          if (positions[index] > 4.55) positions[index] = 1.55;
        }
        this.motion.beamParticles.geometry.attributes.position.needsUpdate = true;
      }
      if (motion.jitter > 0) {
        this.root.position.x += Math.sin(time * 29) * motion.jitter * 0.14;
        this.root.position.y = Math.sin(time * 31) * motion.jitter * 0.18;
      } else {
        this.root.position.y = Math.sin(time * 0.46) * 0.014;
      }
    } else {
      this.beamGroup.scale.x = 0.46 + motion.beam * 0.54;
      this.motion.nodes.forEach(node => node.scale.setScalar(1));
      this.motion.pulseParts.forEach(part => part.scale.setScalar(1));
      this.currentGlyphParts.forEach(part => part.scale.setScalar(1));
      if (this.motion.scan) (this.motion.scan.material as THREE.MeshBasicMaterial).opacity = 0;
    }

    this.materials.accent.emissiveIntensity = this.state.materialState.emissiveIntensity + motion.beam * 0.10 + (staticMode ? 0 : Math.sin(time * 2.1) * 0.018);
    this.materials.accentSoft.emissiveIntensity = this.state.materialState.emissiveIntensity * 0.52 + motion.beam * 0.055;
    this.render();
  };

  private render(): void {
    if (this.composer) this.composer.render();
    else this.renderer.render(this.scene, this.camera);
    this.renderedFrames += 1;
    this.canvas.dataset.renderedFrames = String(this.renderedFrames);
    this.canvas.dataset.rendererActive = 'true';
  }

  renderOnce(): void {
    if (!this.contextLost) this.render();
  }

  private disposeObject(root: THREE.Object3D): void {
    root.traverse((node) => {
      const object = node as THREE.Object3D & { geometry?: THREE.BufferGeometry; material?: THREE.Material | THREE.Material[] };
      object.geometry?.dispose();
      if (object.material) {
        const materials = Array.isArray(object.material) ? object.material : [object.material];
        materials.forEach((material: THREE.Material) => material.dispose?.());
      }
    });
  }

  dispose(): void {
    this.disposed = true;
    cancelAnimationFrame(this.animationFrame);
    this.observer.disconnect();
    if (this.interactive) {
      this.host.removeEventListener('pointermove', this.onPointerMove);
      this.host.removeEventListener('pointerleave', this.onPointerLeave);
    }
    this.disposeObject(this.root);
    Object.values(this.materials).forEach(material => material.dispose());
    this.composer?.dispose();
    this.renderer.dispose();
    this.canvas.remove();
  }
}
