export const stateNames = [
  'verify','prove','secure','approve','check','attest','policy','observe',
  'pending','failed','revoked','exception'
] as const;
export type IdentityStateName = typeof stateNames[number];

export type GlyphName =
  | 'verify' | 'prove' | 'secure' | 'approve' | 'check' | 'attest'
  | 'policy' | 'observe' | 'pending' | 'failed' | 'revoked' | 'exception';

export interface MotionContract {
  outerSpin: number;
  innerSpin: number;
  pulse: number;
  beam: number;
  nodeWave: number;
  scan: number;
  jitter: number;
}
export interface LightingContract {
  key: number;
  fill: number;
  rim: number;
  accent: number;
  exposure: number;
}
export interface StateMaterialContract {
  insertColor: number;
  glassColor: number;
  metalness: number;
  roughness: number;
  clearcoat: number;
  emissiveIntensity: number;
  glassOpacity: number;
  description: string;
}
export interface IdentityStateContract {
  key: IdentityStateName;
  label: string;
  uiContent: string;
  glyph: GlyphName;
  objectState: string;
  lightingState: LightingContract;
  motionState: MotionContract;
  statusColor: string;
  statusColorHex: number;
  materialState: StateMaterialContract;
  apiLabel: string;
  reducedMotionResult: string;
  accessibilityName: string;
  lifecycle: 'active' | 'pending' | 'failed' | 'revoked' | 'exception';
}

export const identityStates: Record<IdentityStateName, IdentityStateContract> = {
  verify: {
    key:'verify', label:'VERIFY', glyph:'verify',
    uiContent:'Confirm artifact, model, evidence, and dependency integrity before execution.',
    objectState:'Core locked; evidence beam validates the selected object; eight authority nodes confirm integrity.',
    lightingState:{key:5.2,fill:1.7,rim:5.8,accent:5.1,exposure:1.02},
    motionState:{outerSpin:.018,innerSpin:-.026,pulse:.08,beam:.82,nodeWave:.12,scan:.12,jitter:0},
    statusColor:'#18D8EE',statusColorHex:0x18d8ee,materialState:{insertColor:0x0d91a8,glassColor:0x061e26,metalness:.82,roughness:.20,clearcoat:.76,emissiveIntensity:.20,glassOpacity:.64,description:'cyan-anodized verification insert'},apiLabel:'state.verify',
    reducedMotionResult:'Static validated core with a steady evidence beam and illuminated verification glyph.',
    accessibilityName:'PROVENANCE VERIFIED™ Verify state — integrity confirmed.', lifecycle:'active'
  },
  prove: {
    key:'prove', label:'PROVE', glyph:'prove',
    uiContent:'Generate portable, machine-verifiable evidence from the validated trust state.',
    objectState:'Proof rings accelerate; the evidence channel releases a structured proof packet.',
    lightingState:{key:5.0,fill:1.6,rim:6.4,accent:6.2,exposure:1.06},
    motionState:{outerSpin:.034,innerSpin:-.065,pulse:.13,beam:1,nodeWave:.16,scan:.05,jitter:0},
    statusColor:'#00A7FF',statusColorHex:0x00a7ff,materialState:{insertColor:0x176bb0,glassColor:0x06182a,metalness:.78,roughness:.16,clearcoat:.82,emissiveIntensity:.24,glassOpacity:.68,description:'ice-cyan proof alloy'},apiLabel:'state.prove',
    reducedMotionResult:'Static proof glyph with a bright completed proof channel.',
    accessibilityName:'PROVENANCE VERIFIED™ Prove state — machine-verifiable evidence generated.', lifecycle:'active'
  },
  secure: {
    key:'secure', label:'SECURE', glyph:'secure',
    uiContent:'Enforce policy, access boundaries, and runtime controls around the trusted object.',
    objectState:'Perimeter closes into a protected boundary; beam narrows; security core remains stable.',
    lightingState:{key:4.7,fill:1.4,rim:5.2,accent:4.8,exposure:.98},
    motionState:{outerSpin:.008,innerSpin:-.015,pulse:.04,beam:.34,nodeWave:.06,scan:.45,jitter:0},
    statusColor:'#4B6FFF',statusColorHex:0x4b6fff,materialState:{insertColor:0x2f479f,glassColor:0x080d27,metalness:.88,roughness:.23,clearcoat:.68,emissiveIntensity:.16,glassOpacity:.60,description:'blue-steel security insert'},apiLabel:'state.secure',
    reducedMotionResult:'Static locked perimeter with shield glyph and restrained cyan boundary light.',
    accessibilityName:'PROVENANCE VERIFIED™ Secure state — policy boundary enforced.', lifecycle:'active'
  },
  approve: {
    key:'approve', label:'APPROVE', glyph:'approve',
    uiContent:'Issue a governed approval when policy, evidence, and accountability gates pass.',
    objectState:'Authority nodes resolve together and the core changes to approved green confirmation.',
    lightingState:{key:5.1,fill:1.5,rim:4.4,accent:5.4,exposure:1.02},
    motionState:{outerSpin:.012,innerSpin:-.02,pulse:.1,beam:.66,nodeWave:.2,scan:.08,jitter:0},
    statusColor:'#38E57A',statusColorHex:0x38e57a,materialState:{insertColor:0x22894b,glassColor:0x071d10,metalness:.74,roughness:.19,clearcoat:.80,emissiveIntensity:.18,glassOpacity:.62,description:'teal-green approval alloy'},apiLabel:'state.approve',
    reducedMotionResult:'Static approved core with green status ring and confirmation glyph.',
    accessibilityName:'PROVENANCE VERIFIED™ Approve state — governed approval issued.', lifecycle:'active'
  },
  check: {
    key:'check', label:'CHECK', glyph:'check',
    uiContent:'Continuously re-evaluate the trust state and detect material changes.',
    objectState:'A scanning aperture moves across the core while the evidence channel remains available.',
    lightingState:{key:4.8,fill:1.55,rim:5.0,accent:5.0,exposure:1},
    motionState:{outerSpin:.02,innerSpin:-.035,pulse:.06,beam:.48,nodeWave:.09,scan:.72,jitter:0},
    statusColor:'#00C6B5',statusColorHex:0x00c6b5,materialState:{insertColor:0x147f75,glassColor:0x051e1b,metalness:.76,roughness:.18,clearcoat:.78,emissiveIntensity:.19,glassOpacity:.66,description:'cyan inspection alloy'},apiLabel:'state.check',
    reducedMotionResult:'Static inspection aperture with a visible check status.',
    accessibilityName:'PROVENANCE VERIFIED™ Check state — continuous trust inspection active.', lifecycle:'active'
  },
  attest: {
    key:'attest', label:'ATTEST', glyph:'attest',
    uiContent:'Bind an accountable attestation to the selected evidence and identity record.',
    objectState:'Signature plane and witness node illuminate; proof channel carries the attestation.',
    lightingState:{key:4.9,fill:1.55,rim:5.4,accent:4.9,exposure:1.01},
    motionState:{outerSpin:.015,innerSpin:-.028,pulse:.07,beam:.58,nodeWave:.11,scan:.03,jitter:0},
    statusColor:'#00E0C4',statusColorHex:0x00e0c4,materialState:{insertColor:0x138f7e,glassColor:0x041f1b,metalness:.80,roughness:.18,clearcoat:.82,emissiveIntensity:.18,glassOpacity:.66,description:'teal witness alloy'},apiLabel:'state.attest',
    reducedMotionResult:'Static signed attestation glyph and steady witness node.',
    accessibilityName:'PROVENANCE VERIFIED™ Attest state — accountable attestation bound.', lifecycle:'active'
  },
  policy: {
    key:'policy', label:'POLICY', glyph:'policy',
    uiContent:'Resolve the governing rule set and expose the policy decision as evidence.',
    objectState:'Policy layers align; the core emits a violet rule-resolution signal.',
    lightingState:{key:4.6,fill:1.45,rim:4.7,accent:5.2,exposure:.99},
    motionState:{outerSpin:.01,innerSpin:-.018,pulse:.05,beam:.44,nodeWave:.07,scan:.26,jitter:0},
    statusColor:'#9B66FF',statusColorHex:0x9b66ff,materialState:{insertColor:0x6043a8,glassColor:0x160c2b,metalness:.68,roughness:.22,clearcoat:.74,emissiveIntensity:.22,glassOpacity:.67,description:'violet policy enamel'},apiLabel:'state.policy',
    reducedMotionResult:'Static policy document glyph with violet rule-resolution ring.',
    accessibilityName:'PROVENANCE VERIFIED™ Policy state — governing policy resolved.', lifecycle:'active'
  },
  observe: {
    key:'observe', label:'OBSERVE', glyph:'observe',
    uiContent:'Expose real-time trust telemetry without changing the governed state.',
    objectState:'Observation aperture opens; telemetry nodes sample the live object.',
    lightingState:{key:4.7,fill:1.5,rim:5.3,accent:4.8,exposure:1},
    motionState:{outerSpin:.023,innerSpin:-.03,pulse:.04,beam:.42,nodeWave:.1,scan:.48,jitter:0},
    statusColor:'#8DDCFF',statusColorHex:0x8ddcff,materialState:{insertColor:0x4a8ba6,glassColor:0x071724,metalness:.72,roughness:.18,clearcoat:.84,emissiveIntensity:.19,glassOpacity:.69,description:'blue telemetry glass-metal'},apiLabel:'state.observe',
    reducedMotionResult:'Static observation aperture with live telemetry indicator.',
    accessibilityName:'PROVENANCE VERIFIED™ Observe state — trust telemetry visible.', lifecycle:'active'
  },
  pending: {
    key:'pending', label:'PENDING', glyph:'pending',
    uiContent:'Evidence or authorization is incomplete; no certification or approval is represented.',
    objectState:'Core waits in amber; authority nodes remain unresolved; evidence channel is paused.',
    lightingState:{key:4.2,fill:1.25,rim:3.9,accent:4.8,exposure:.94},
    motionState:{outerSpin:.006,innerSpin:-.01,pulse:.08,beam:.08,nodeWave:.03,scan:.18,jitter:0},
    statusColor:'#F2B331',statusColorHex:0xf2b331,materialState:{insertColor:0xa56b10,glassColor:0x281803,metalness:.52,roughness:.28,clearcoat:.58,emissiveIntensity:.16,glassOpacity:.62,description:'amber ceramic waiting insert'},apiLabel:'state.pending',
    reducedMotionResult:'Static amber waiting state with no evidence release.',
    accessibilityName:'PROVENANCE VERIFIED™ Pending state — evidence or authorization incomplete.', lifecycle:'pending'
  },
  failed: {
    key:'failed', label:'FAILED', glyph:'failed',
    uiContent:'A validation or execution gate failed; proof and approval channels are blocked.',
    objectState:'Core turns red; perimeter separates slightly; evidence channel terminates.',
    lightingState:{key:3.9,fill:1.1,rim:4.2,accent:5.5,exposure:.92},
    motionState:{outerSpin:0,innerSpin:0,pulse:.16,beam:0,nodeWave:.02,scan:0,jitter:.012},
    statusColor:'#FF4B40',statusColorHex:0xff4b40,materialState:{insertColor:0xb32b24,glassColor:0x280604,metalness:.42,roughness:.25,clearcoat:.66,emissiveIntensity:.22,glassOpacity:.58,description:'red failure enamel'},apiLabel:'state.failed',
    reducedMotionResult:'Static red failure glyph with the evidence channel visibly disabled.',
    accessibilityName:'PROVENANCE VERIFIED™ Failed state — validation or execution gate failed.', lifecycle:'failed'
  },
  revoked: {
    key:'revoked', label:'REVOKED', glyph:'revoked',
    uiContent:'The former authority state is withdrawn; the historical record remains identifiable.',
    objectState:'Core is dark red; signature channel is cut; the outer frame remains as historical identity.',
    lightingState:{key:3.6,fill:1.0,rim:3.5,accent:4.3,exposure:.88},
    motionState:{outerSpin:0,innerSpin:0,pulse:.02,beam:0,nodeWave:0,scan:0,jitter:0},
    statusColor:'#D82B7B',statusColorHex:0xd82b7b,materialState:{insertColor:0x7f1f4b,glassColor:0x21050f,metalness:.48,roughness:.34,clearcoat:.42,emissiveIntensity:.10,glassOpacity:.52,description:'dark-red revoked oxide'},apiLabel:'state.revoked',
    reducedMotionResult:'Static revoked symbol with dark-red core and disconnected evidence exit.',
    accessibilityName:'PROVENANCE VERIFIED™ Revoked state — former authority withdrawn.', lifecycle:'revoked'
  },
  exception: {
    key:'exception', label:'EXCEPTION', glyph:'exception',
    uiContent:'A governed exception requires accountable human review before the system can proceed.',
    objectState:'Amber warning core; witness nodes isolate the unresolved exception.',
    lightingState:{key:4.1,fill:1.2,rim:4.0,accent:4.9,exposure:.93},
    motionState:{outerSpin:.004,innerSpin:-.006,pulse:.11,beam:.04,nodeWave:.04,scan:.08,jitter:.004},
    statusColor:'#FF7A24',statusColorHex:0xff7a24,materialState:{insertColor:0xa64d10,glassColor:0x2a0f03,metalness:.50,roughness:.27,clearcoat:.62,emissiveIntensity:.18,glassOpacity:.60,description:'amber exception ceramic'},apiLabel:'state.exception',
    reducedMotionResult:'Static amber exception glyph with the evidence channel held.',
    accessibilityName:'PROVENANCE VERIFIED™ Exception state — accountable human review required.', lifecycle:'exception'
  }
};

export function assertContractParity(): void {
  for (const name of stateNames) {
    const state = identityStates[name];
    const required: (keyof IdentityStateContract)[] = [
      'uiContent','glyph','objectState','lightingState','motionState','statusColor',
      'apiLabel','reducedMotionResult','accessibilityName','materialState'
    ];
    for (const field of required) {
      if (state[field] === undefined || state[field] === '') throw new Error(`Missing ${field} for ${name}`);
    }
  }
}
