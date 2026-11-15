export class ApiError extends Error { constructor(public status: number, public code: string, message: string) { super(message); } }
export function noStoreJson(value: unknown, init: ResponseInit = {}) { const headers = new Headers(init.headers); headers.set("cache-control", "no-store"); return Response.json(value, {...init, headers}); }
