/* Offline type-audit shims used only when the locked npm dependency graph is unavailable.
 * They preserve project strictness for application-owned types while providing the public
 * surfaces consumed from React, Next.js, Three, D3, Vitest and Playwright.
 */

declare namespace React {
  type ReactNode = any;
  type FormEvent<T = any> = { currentTarget: T; target: EventTarget | null; preventDefault(): void } & Event;
  type ChangeEvent<T = any> = { currentTarget: T; target: T } & Event;
  type KeyboardEvent<T = any> = { currentTarget: T; target: T; key: string; preventDefault(): void } & Event;
  type MouseEvent<T = any> = { currentTarget: T; target: EventTarget | null; preventDefault(): void } & Event;
  type CSSProperties = Record<string, string | number | undefined>;
  type RefObject<T> = { current: T };
  type Dispatch<A> = (value: A) => void;
  type SetStateAction<S> = S | ((previous: S) => S);
  interface HTMLAttributes<T> { [key: string]: any }
  interface ImgHTMLAttributes<T> extends HTMLAttributes<T> {}
  interface AnchorHTMLAttributes<T> extends HTMLAttributes<T> {}
}

declare module 'react' {
  export type ReactNode = React.ReactNode;
  export type FormEvent<T = any> = React.FormEvent<T>;
  export type ChangeEvent<T = any> = React.ChangeEvent<T>;
  export type KeyboardEvent<T = any> = React.KeyboardEvent<T>;
  export type MouseEvent<T = any> = React.MouseEvent<T>;
  export type CSSProperties = React.CSSProperties;
  export type ImgHTMLAttributes<T> = React.ImgHTMLAttributes<T>;
  export type AnchorHTMLAttributes<T> = React.AnchorHTMLAttributes<T>;
  export function useState<S>(initial: S | (() => S)): [S, React.Dispatch<React.SetStateAction<S>>];
  export function useState<S = undefined>(): [S | undefined, React.Dispatch<React.SetStateAction<S | undefined>>];
  export function useEffect(effect: () => void | (() => void), deps?: readonly unknown[]): void;
  export function useMemo<T>(factory: () => T, deps: readonly unknown[]): T;
  export function useCallback<T extends (...args: any[]) => any>(callback: T, deps: readonly unknown[]): T;
  export function useRef<T>(initial: T): React.RefObject<T>;
  export function useRef<T>(initial: T | null): React.RefObject<T | null>;
  export function useSyncExternalStore<T>(subscribe: (callback: () => void) => () => void, getSnapshot: () => T, getServerSnapshot?: () => T): T;
  export const Suspense: any;
  const ReactDefault: any;
  export default ReactDefault;
}

declare module 'react/jsx-runtime' {
  export const jsx: any;
  export const jsxs: any;
  export const Fragment: any;
}
declare module 'react-dom/client' { export function createRoot(element: Element | DocumentFragment): { render(node: any): void; unmount(): void }; }

declare module 'next/link' { const Link: any; export default Link; }
declare module 'next/image' { const Image: any; export default Image; }
declare module 'next/navigation' {
  export function redirect(url: string): never;
  export function notFound(): never;
  export function useRouter(): { push(url: string): void; replace(url: string): void; refresh(): void; back(): void };
  export function usePathname(): string;
  export function useSearchParams(): URLSearchParams;
}
declare module 'next/server' {
  export class NextRequest extends Request {
    constructor(input: string | URL | Request, init?: RequestInit);
    readonly nextUrl: URL;
    readonly cookies: any;
    json(): Promise<any>;
    text(): Promise<string>;
  }
  export class NextResponse<T = any> extends Response {
    readonly cookies: any;
    static next(init?: any): NextResponse;
    static redirect(url: string | URL, init?: number | ResponseInit): NextResponse;
    static json<T = any>(body: T, init?: ResponseInit): NextResponse<T>;
    static rewrite(url: string | URL, init?: any): NextResponse;
  }
}
declare module 'next/headers' {
  export function cookies(): Promise<any>;
  export function headers(): Promise<Headers>;
}
declare module 'next' {
  export type Metadata = any;
  export type Viewport = any;
  export namespace MetadataRoute {
    type Robots = any;
    type Sitemap = any;
    type Manifest = any;
  }
}

declare module 'zustand' {
  export function create<T>(initializer: (set: any, get: any, api: any) => T): {
    (): T;
    <U>(selector: (state: T) => U): U;
    getState(): T;
    setState(partial: Partial<T> | ((state: T) => Partial<T>), replace?: boolean): void;
    subscribe(listener: (state: T, previous: T) => void): () => void;
  };
}
declare namespace z { type infer<T> = any; class ZodError extends Error { issues: any[] } }
declare module 'zod' { export const z: typeof z; export { z }; }
declare module 'qrcode' { const QRCode: { toDataURL(...args: any[]): Promise<string>; toString(...args: any[]): Promise<string> }; export default QRCode; }

declare namespace THREE {
  type ACESFilmicToneMapping = any; const ACESFilmicToneMapping: any;
  type AdditiveBlending = any; const AdditiveBlending: any;
  type AmbientLight = any; const AmbientLight: any;
  type BoxGeometry = any; const BoxGeometry: any;
  type BufferAttribute = any; const BufferAttribute: any;
  type BufferGeometry = any; const BufferGeometry: any;
  type CanvasTexture = any; const CanvasTexture: any;
  type CatmullRomCurve3 = any; const CatmullRomCurve3: any;
  type CircleGeometry = any; const CircleGeometry: any;
  type Color = any; const Color: any;
  type CylinderGeometry = any; const CylinderGeometry: any;
  type DirectionalLight = any; const DirectionalLight: any;
  type DoubleSide = any; const DoubleSide: any;
  type ExtrudeGeometry = any; const ExtrudeGeometry: any;
  type Group = any; const Group: any;
  type HemisphereLight = any; const HemisphereLight: any;
  type Line = any; const Line: any;
  type LineBasicMaterial = any; const LineBasicMaterial: any;
  type Material = any; const Material: any;
  type Mesh = any; const Mesh: any;
  type MeshBasicMaterial = any; const MeshBasicMaterial: any;
  type MeshPhysicalMaterial = any; const MeshPhysicalMaterial: any;
  type NoColorSpace = any; const NoColorSpace: any;
  type Object3D = any; const Object3D: any;
  type PCFSoftShadowMap = any; const PCFSoftShadowMap: any;
  type PMREMGenerator = any; const PMREMGenerator: any;
  type Path = any; const Path: any;
  type PerspectiveCamera = any; const PerspectiveCamera: any;
  type PlaneGeometry = any; const PlaneGeometry: any;
  type PointLight = any; const PointLight: any;
  type Points = any; const Points: any;
  type PointsMaterial = any; const PointsMaterial: any;
  type RectAreaLight = any; const RectAreaLight: any;
  type RepeatWrapping = any; const RepeatWrapping: any;
  type SRGBColorSpace = any; const SRGBColorSpace: any;
  type Scene = any; const Scene: any;
  type Shape = any; const Shape: any;
  type SphereGeometry = any; const SphereGeometry: any;
  type Sprite = any; const Sprite: any;
  type SpriteMaterial = any; const SpriteMaterial: any;
  type TorusGeometry = any; const TorusGeometry: any;
  type TubeGeometry = any; const TubeGeometry: any;
  type Vector2 = any; const Vector2: any;
  type Vector3 = any; const Vector3: any;
  type WebGLRenderer = any; const WebGLRenderer: any;
  type Intersection<T = any> = any;
}
declare module 'three' { export = THREE; }
declare module 'three/examples/jsm/environments/RoomEnvironment.js' { export const RoomEnvironment: any; }
declare module 'three/examples/jsm/postprocessing/EffectComposer.js' { export class EffectComposer { constructor(...args: any[]); [key: string]: any } }
declare module 'three/examples/jsm/postprocessing/RenderPass.js' { export const RenderPass: any; }
declare module 'three/examples/jsm/postprocessing/UnrealBloomPass.js' { export class UnrealBloomPass { constructor(...args: any[]); [key: string]: any } }
declare module 'three/examples/jsm/postprocessing/OutputPass.js' { export const OutputPass: any; }
declare module 'three/examples/jsm/lights/RectAreaLightUniformsLib.js' { export const RectAreaLightUniformsLib: any; }

declare module 'd3' { export function hierarchy<T = any>(data: T, children?: (d: T) => Iterable<T> | null | undefined): any; export function tree<T = any>(): any; }

declare module '@testing-library/react' {
  export const render: any; export const screen: any; export const fireEvent: any; export const waitFor: any; export const act: any;
}
declare module '@testing-library/jest-dom' {}
declare module '@testing-library/jest-dom/vitest' {}

type TestFixture = { page: any; isMobile: boolean; request: any; browserName: string; context: any };
type TestInfo = any;
declare module 'vitest' {
  export const describe: any; export const it: any; export const test: any; export const expect: any;
  export const beforeEach: any; export const afterEach: any; export const beforeAll: any; export const afterAll: any; export const vi: { fn<T extends (...args: any[]) => any>(implementation?: T): any; mock<T = any>(path: string, factory?: (importOriginal: <U = any>() => Promise<U>) => T | Promise<T>): void; [key: string]: any };
}
declare module '@playwright/test' {
  export const test: ((name: string, fn: (fixtures: TestFixture, testInfo: TestInfo) => any) => void) & Record<string, any>;
  export const expect: any;
  export const chromium: any;
  export type Page = any;
}
declare module '@axe-core/playwright' { const AxeBuilder: any; export default AxeBuilder; }

declare module 'node:fs' { const value: any; export = value; }
declare module 'node:path' { const value: any; export = value; }
declare module 'node:crypto' { const value: any; export = value; export const createHash: any; export const randomUUID: any; export const randomBytes: any; export const webcrypto: any; export const createPrivateKey: any; export const createPublicKey: any; export const generateKeyPairSync: any; export const sign: any; export const verify: any; }
declare module 'node:assert' { const value: any; export = value; }
declare module 'node:assert/strict' { const value: any; export default value; export = value; }
declare module 'node:test' { const test: any; export default test; export { test }; export const describe: any; export const it: any; export const before: any; export const after: any; }
declare module 'node:url' { export const fileURLToPath: any; export const pathToFileURL: any; }
declare module 'node:fs/promises' { const value: any; export = value; export const readFile: any; export const writeFile: any; export const mkdir: any; }

declare namespace JSX {
  interface IntrinsicAttributes { key?: string | number }
  interface IntrinsicElements { [elemName: string]: any }
}
declare const process: any;
declare const Buffer: any;
declare const structuredClone: <T>(value: T) => T;

declare module 'node:net' { export const isIP: (input: string) => number; }
