export class NextRequest extends Request {
  readonly nextUrl: URL;
  readonly ip?: string;
  constructor(input: RequestInfo | URL, init?: RequestInit) {
    const normalized = typeof input === 'string' && input.startsWith('/')
      ? new URL(input, globalThis.location?.origin && globalThis.location.origin !== 'null' ? globalThis.location.origin : 'https://standalone.provenanceverified.org').toString()
      : input;
    super(normalized, init);
    this.nextUrl = new URL(this.url);
  }
}
export class NextResponse extends Response {
  static json(data: unknown, init?: ResponseInit): NextResponse {
    const headers = new Headers(init?.headers);
    if (!headers.has('content-type')) headers.set('content-type', 'application/json');
    return new NextResponse(JSON.stringify(data), { ...init, headers });
  }
}
