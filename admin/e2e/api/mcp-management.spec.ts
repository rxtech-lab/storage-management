import { test, expect } from "@playwright/test";

test("MCP advertises discovery and validates dynamic client metadata", async ({request}) => {
 const unauth = await request.post("/api/mcp",{data:{jsonrpc:"2.0",id:1,method:"initialize",params:{protocolVersion:"2025-03-26",capabilities:{},clientInfo:{name:"test",version:"1"}}}});
 expect(unauth.status()).toBe(401);
 expect(unauth.headers()["www-authenticate"]).toContain("resource_metadata=");
 const protectedResource = await request.get("/.well-known/oauth-protected-resource/api/mcp");
 expect(protectedResource.ok()).toBe(true);
 expect((await protectedResource.json()).resource).toMatch(/\/api\/mcp$/);
 const metadata = await request.get("/.well-known/oauth-authorization-server");
 expect((await metadata.json()).code_challenge_methods_supported).toEqual(["S256"]);
 const bad = await request.post("/api/mcp/oauth/register",{data:{redirect_uris:["https://example.com/callback#fragment"]}});
 expect(bad.status()).toBe(400);
 const registered = await request.post("/api/mcp/oauth/register",{data:{client_name:"MCP integration test",redirect_uris:["http://127.0.0.1:4545/callback"]}});
 expect(registered.status()).toBe(201);
 const client = await registered.json(); expect(client.client_id).toBeTruthy(); expect(client.token_endpoint_auth_method).toBe("none");
 const unauthorizedRedirect = await request.get(`/api/mcp/oauth/authorize?client_id=${client.client_id}&redirect_uri=https://attacker.example/callback`,{maxRedirects:0});
 expect(unauthorizedRedirect.status()).toBe(400); expect(unauthorizedRedirect.headers().location).toBeUndefined();
});

test("iOS recycle-bin endpoints isolate users and support restore, hard delete and clear all", async ({request}) => {
 const owner = {"X-Test-User-Id":`mcp-bin-${crypto.randomUUID()}`};
 const other = {"X-Test-User-Id":`other-${crypto.randomUUID()}`};
 async function create(title:string) {
  const response=await request.post("/api/v1/items",{headers:owner,data:{title,visibility:"privateAccess"}});
  expect(response.status()).toBe(201); return (await response.json()).id as string;
 }
 const id = await create("Recycle me");
 expect((await request.delete(`/api/v1/items/${id}`,{headers:owner})).status()).toBe(204);
 expect((await request.get(`/api/v1/items/${id}`,{headers:owner})).status()).toBe(404);
 const deleted = await request.get("/api/v1/recycle-bin",{headers:owner});
 expect((await deleted.json()).items).toEqual(expect.arrayContaining([expect.objectContaining({id})]));
 expect((await (await request.get("/api/v1/recycle-bin",{headers:other})).json()).items).toEqual([]);
 expect((await request.delete(`/api/v1/recycle-bin/${id}`,{headers:other})).ok()).toBe(false);
 expect((await request.post(`/api/v1/recycle-bin/${id}`,{headers:owner})).status()).toBe(204);
 expect((await request.get(`/api/v1/items/${id}`,{headers:owner})).status()).toBe(200);
 expect((await request.delete(`/api/v1/recycle-bin/${id}`,{headers:owner})).ok()).toBe(false);
 await request.delete(`/api/v1/items/${id}`,{headers:owner});
 expect((await request.delete(`/api/v1/recycle-bin/${id}`,{headers:owner})).status()).toBe(204);
 expect((await request.post(`/api/v1/recycle-bin/${id}`,{headers:owner})).ok()).toBe(false);
 const another = await create("Empty bin"); await request.delete(`/api/v1/items/${another}`,{headers:owner});
 expect((await request.delete("/api/v1/recycle-bin",{headers:owner})).status()).toBe(204);
 expect((await (await request.get("/api/v1/recycle-bin",{headers:owner})).json()).items).toEqual([]);
 const clients = await request.get("/api/v1/mcp/clients",{headers:owner});
 expect(clients.ok()).toBe(true); expect((await clients.json()).items).toEqual([]);
});
