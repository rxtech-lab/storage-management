// @vitest-environment node
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
vi.hoisted(() => { process.env.IS_E2E = "true"; process.env.E2E_DATABASE_URL = `file:/tmp/storage-mcp-test-${crypto.randomUUID()}.db`; process.env.MCP_RESOURCE_URL = "http://localhost:3000/api/mcp"; });
vi.mock("@/auth", () => ({auth: vi.fn(async () => null)}));
vi.mock("next/cache", () => ({revalidatePath: vi.fn()}));
vi.mock("@/lib/auth-helper", () => ({getSession: vi.fn(async () => null),verifyBearerToken: vi.fn()}));
import { unlink } from "node:fs/promises";
import { createDatabaseClient } from "@/lib/db/client";
import { db, items, mcpOAuthClients, mcpOAuthGrants, mcpOAuthCodes } from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";
import { authenticateOAuthToken, exchangeCode, exchangeRefresh } from "../oauth-tokens";
import { challenge, digest, mcpResource } from "../oauth-config";
import { ownedItem, validateParent, createMcpServer } from "../server";
import { deleteItemAction, getItem, getItems } from "@/lib/actions/item-actions";
import { restoreItem, purgeItem } from "../recycle-bin";
import { eq } from "drizzle-orm";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";

beforeAll(async () => {
 await ensureSchemaInitialized();
 await db.insert(mcpOAuthClients).values({id:"test-client",name:"Test",redirectUris:["http://localhost/callback"]});
 await db.insert(items).values([{id:"owner-item",userId:"owner",title:"Owned"},{id:"other-item",userId:"other",title:"Other"},{id:"child-item",userId:"owner",title:"Child",parentId:"owner-item"}]);
});

afterAll(async () => { createDatabaseClient().close(); await unlink(process.env.E2E_DATABASE_URL!.slice(5)).catch(() => {}); });

async function authorize(id:string) {
 const verifier = "a".repeat(43);
 await db.insert(mcpOAuthGrants).values({id,ownerId:"owner",clientId:"test-client",resource:mcpResource(),scope:"storage:read storage:write",expiresAt:new Date(Date.now()+3600000)});
 await db.insert(mcpOAuthCodes).values({hash:digest(id),grantId:id,redirectUri:"http://localhost/callback",challenge:challenge(verifier),expiresAt:new Date(Date.now()+60000)});
 return {code:id,clientId:"test-client",resource:mcpResource(),redirectUri:"http://localhost/callback",verifier};
}

describe("MCP authorization", () => {
 it("enforces PKCE, resource and client binding", async () => {
  const args = await authorize("binding");
  await expect(exchangeCode(db,{...args,verifier:"b".repeat(43)})).rejects.toThrow();
  await expect(exchangeCode(db,{...args,resource:"https://other.example/api/mcp"})).rejects.toThrow();
  await expect(exchangeCode(db,{...args,clientId:"other-client"})).rejects.toThrow();
  const tokens = await exchangeCode(db,args);
  expect((await authenticateOAuthToken(db,tokens.access_token))?.sub).toBe("owner");
  await expect(exchangeCode(db,args)).rejects.toThrow();
  expect(await authenticateOAuthToken(db,tokens.access_token)).toBeNull();
 });
 it("rotates refresh tokens and revokes the family on replay", async () => {
  const args = await authorize("refresh");
  const first = await exchangeCode(db,args);
  const second = await exchangeRefresh(db,{token:first.refresh_token,clientId:args.clientId,resource:args.resource});
  expect(second.refresh_token).not.toBe(first.refresh_token);
  await expect(exchangeRefresh(db,{token:first.refresh_token,clientId:args.clientId,resource:args.resource})).rejects.toThrow();
  expect(await authenticateOAuthToken(db,second.access_token)).toBeNull();
 });
 it("immediately invalidates access when disconnected", async () => {
  const args = await authorize("revoke"); const tokens = await exchangeCode(db,args);
  await db.update(mcpOAuthGrants).set({revokedAt:new Date()}).where(eq(mcpOAuthGrants.id,"revoke"));
  expect(await authenticateOAuthToken(db,tokens.access_token)).toBeNull();
 });
});

describe("MCP inventory boundaries", () => {
 it("rejects foreign items and parent cycles", async () => {
  await expect(ownedItem("other-item","owner")).rejects.toThrow();
  await expect(validateParent("owner-item","other-item","owner")).rejects.toThrow();
  await expect(validateParent("owner-item","child-item","owner")).rejects.toThrow();
  await expect(validateParent("owner-item","owner-item","owner")).rejects.toThrow();
 });
 it("soft deletes, hides, restores and permanently purges only owned deleted items", async () => {
  expect((await deleteItemAction("owner-item","other")).success).toBe(false);
  expect((await deleteItemAction("owner-item","owner")).success).toBe(true);
  expect(await getItem("owner-item")).toBeFalsy();
  expect((await getItems("owner")).some(x=>x.id==="owner-item")).toBe(false);
  await expect(restoreItem("owner-item","other")).rejects.toThrow();
  await restoreItem("owner-item","owner"); expect(await getItem("owner-item")).not.toBeNull();
  await expect(purgeItem("owner-item","owner")).rejects.toThrow();
  await deleteItemAction("owner-item","owner"); await purgeItem("owner-item","owner");
  expect((await db.select().from(items).where(eq(items.id,"owner-item")))).toHaveLength(0);
  expect((await ownedItem("child-item","owner")).parentId).toBeNull();
 });
 it("exposes all tools and denies write tools to read-only grants", async () => {
  const server = createMcpServer({sub:"owner",clientId:"test-client",scopes:["storage:read"]});
  const client = new Client({name:"test",version:"1"});
  const [a,b] = InMemoryTransport.createLinkedPair();
  await Promise.all([server.connect(a),client.connect(b)]);
  try {
   const listed = await client.listTools();
   expect(listed.tools.map(t=>t.name)).toEqual(expect.arrayContaining(["find_items","read_item","update_item","delete_item","list_contents","set_parent","get_image_upload_url"]));
   const result = await client.callTool({name:"delete_item",arguments:{id:"child-item"}});
   expect(result.isError).toBe(true);
   expect(await ownedItem("child-item","owner")).toBeTruthy();
   const foreign = await client.callTool({name:"read_item",arguments:{id:"other-item"}}); expect(foreign.isError).toBe(true);
  } finally { await client.close(); await server.close(); }
 });
});

describe("Consent browser binding", () => {
 it("requires the flow cookie, matching origin and CSRF before issuing a code", async () => {
  const {mcpOAuthRequests} = await import("@/lib/db");
  const {consentPage,approveConsent} = await import("../oauth");
  await db.insert(mcpOAuthRequests).values({id:"consent-flow",stateHash:digest("login-state"),clientId:"test-client",redirectUri:"http://localhost/callback",clientState:"agent-state",challenge:challenge("v".repeat(43)),scope:"storage:read storage:write",upstreamVerifier:"",ownerId:"owner",consentHash:digest("cookie-secret"),expiresAt:new Date(Date.now()+60000)});
  const url = "http://localhost:3000/api/mcp/oauth/consent";
  await expect(consentPage(new Request(`${url}?request=consent-flow`))).rejects.toThrow();
  const cookie = "storage_mcp_consent-flow=cookie-secret";
  const page = await consentPage(new Request(`${url}?request=consent-flow`,{headers:{cookie}}));
  const html = await page.text(); expect(html).toContain("Manage inventory"); expect(html).toContain("recycle bin"); expect(html).toContain('name="decision" value="allow"');
  const body = new URLSearchParams({request:"consent-flow",csrf:"cookie-secret",decision:"allow"});
  await expect(approveConsent(new Request(url,{method:"POST",headers:{cookie,origin:"https://attacker.example","content-type":"application/x-www-form-urlencoded"},body}))).rejects.toThrow();
  await expect(approveConsent(new Request(url,{method:"POST",headers:{cookie,origin:"http://localhost:3000","content-type":"application/x-www-form-urlencoded"},body:new URLSearchParams({...Object.fromEntries(body),csrf:"wrong"})}))).rejects.toThrow();
  const response = await approveConsent(new Request(url,{method:"POST",headers:{cookie,origin:"http://localhost:3000","content-type":"application/x-www-form-urlencoded"},body}));
  const destination = new URL(response.headers.get("location")!);
  expect(destination.origin).toBe("http://localhost"); expect(destination.searchParams.get("state")).toBe("agent-state"); expect(destination.searchParams.get("code")).toBeTruthy();
  await expect(approveConsent(new Request(url,{method:"POST",headers:{cookie,origin:"http://localhost:3000","content-type":"application/x-www-form-urlencoded"},body}))).rejects.toThrow();
 });
});

describe("Writable MCP tools", () => {
 it("updates an owned item, moves its parent, lists contents and issues a direct S3 upload URL", async () => {
  await db.insert(items).values({id:"new-parent",userId:"owner",title:"New parent"});
  const server = createMcpServer({sub:"owner",clientId:"test-client",scopes:["storage:read","storage:write"]});
  const client = new Client({name:"writer",version:"1"});
  const [a,b] = InMemoryTransport.createLinkedPair(); await Promise.all([server.connect(a),client.connect(b)]);
  try {
   expect((await client.callTool({name:"set_parent",arguments:{id:"child-item",parentId:"new-parent"}})).isError).not.toBe(true);
   expect((await ownedItem("child-item","owner")).parentId).toBe("new-parent");
   expect((await client.callTool({name:"update_item",arguments:{id:"child-item",title:"Renamed by MCP"}})).isError).not.toBe(true);
   expect((await ownedItem("child-item","owner")).title).toBe("Renamed by MCP");
   expect((await client.callTool({name:"list_contents",arguments:{id:"child-item"}})).isError).not.toBe(true);
   const uploaded = await client.callTool({name:"get_image_upload_url",arguments:{filename:"photo.png",contentType:"image/png",size:1024}});
   expect(uploaded.isError).not.toBe(true);
   const content = uploaded.content as {type:string;text:string}[];
   const upload = JSON.parse(content[0].text);
   expect(upload.method).toBe("PUT"); expect(upload.uploadUrl).toMatch(/^https:\/\/mock-s3/); expect(upload.fileId).toBeTruthy();
   expect((await client.callTool({name:"update_item",arguments:{id:"child-item",images:[`file:${upload.fileId}`]}})).isError).not.toBe(true);
   expect((await ownedItem("child-item","owner")).images).toEqual([`file:${upload.fileId}`]);
  } finally { await client.close(); await server.close(); }
 });
});

describe("MCP reuses existing web sign-in", () => {
 it("works without dedicated credentials and checks browser identity before consent", async () => {
  vi.stubEnv("MCP_RXAUTH_CLIENT_ID", ""); vi.stubEnv("MCP_RXAUTH_CLIENT_SECRET", "");
  const {auth} = await import("@/auth");
  const {authorize, callback} = await import("../oauth");
  const {mcpOAuthRequests} = await import("@/lib/db");
  const params = new URLSearchParams({client_id:"test-client",redirect_uri:"http://localhost/callback",response_type:"code",code_challenge_method:"S256",code_challenge:challenge("w".repeat(43)),resource:mcpResource(),scope:"storage:read storage:write",state:"client-state"});
  const start = await authorize(new Request(`http://localhost:3000/api/mcp/oauth/authorize?${params}`));
  expect(start.status).toBe(302);
  const resume = start.headers.get("location")!;
  expect(new URL(resume).pathname).toBe("/api/mcp/oauth/callback");
  const cookie = start.headers.get("set-cookie")!.split(";",1)[0];
  await expect(callback(new Request(resume))).rejects.toThrow("another browser");
  const login = await callback(new Request(resume,{headers:{cookie}}));
  const loginUrl = new URL(login.headers.get("location")!);
  expect(loginUrl.pathname).toBe("/login"); expect(loginUrl.searchParams.get("callbackUrl")).toBe(resume);
  vi.mocked(auth).mockResolvedValueOnce({user:{id:"web-owner"},expires:new Date(Date.now()+60000).toISOString()} as never);
  const consent = await callback(new Request(resume,{headers:{cookie}}));
  const consentUrl = new URL(consent.headers.get("location")!);
  expect(consentUrl.pathname).toBe("/api/mcp/oauth/consent");
  const [flow] = await db.select().from(mcpOAuthRequests).where(eq(mcpOAuthRequests.id,consentUrl.searchParams.get("request")!));
  expect(flow.ownerId).toBe("web-owner"); expect(flow.consentHash).toBeTruthy();
  expect(await db.select().from(mcpOAuthGrants).where(eq(mcpOAuthGrants.ownerId,"web-owner"))).toHaveLength(0);
  await expect(callback(new Request(resume,{headers:{cookie}}))).rejects.toThrow();
  vi.unstubAllEnvs();
 });
 it("rejects incomplete dedicated configuration", async () => {
  vi.stubEnv("MCP_RXAUTH_CLIENT_ID", "dedicated-client"); vi.stubEnv("MCP_RXAUTH_CLIENT_SECRET", "");
  const {authorize,oauthResponse} = await import("../oauth");
  const params = new URLSearchParams({client_id:"test-client",redirect_uri:"http://localhost/callback",response_type:"code",code_challenge_method:"S256",code_challenge:challenge("w".repeat(43)),resource:mcpResource()});
  const response = await oauthResponse(()=>authorize(new Request(`http://localhost:3000/api/mcp/oauth/authorize?${params}`)));
  expect(response.status).toBe(503); expect((await response.json()).error_description).toContain("Set both");
  vi.unstubAllEnvs();
 });
});
