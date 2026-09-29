import http2 from "node:http2";
import { createPrivateKey, sign, type KeyObject } from "node:crypto";

/**
 * Minimal APNs client using token-based (.p8) authentication over HTTP/2.
 *
 * Required environment variables:
 * - APNS_KEY_ID: Key ID of the APNs auth key
 * - APNS_TEAM_ID: Apple developer team ID
 * - APNS_PRIVATE_KEY: Base64-encoded contents of the .p8 file (`base64 -i AuthKey_XXX.p8`)
 * - APNS_BUNDLE_ID: App bundle ID used as the push topic
 */

export type ApnsEnvironment = "sandbox" | "production";

export interface ApnsAlert {
  title: string;
  body: string;
  /** Groups related notifications in Notification Center */
  threadId?: string;
  /** Extra top-level keys delivered to the app alongside `aps` */
  data?: Record<string, unknown>;
}

export interface ApnsResult {
  token: string;
  status: number;
  reason?: string;
  /** `apns-id` response header, identifying the notification for Apple support */
  apnsId?: string;
  /** `apns-unique-id` response header (sandbox only), searchable in the Push Notifications Console */
  apnsUniqueId?: string;
}

/** Shortens a device token so logs identify it without exposing it. */
export function maskToken(token: string): string {
  return token.length > 12 ? `${token.slice(0, 6)}…${token.slice(-6)}` : token;
}

/** Logs every push outcome with its APNs IDs for debugging delivery. */
export function logApnsResults(context: string, environment: ApnsEnvironment, results: ApnsResult[]): void {
  for (const result of results) {
    const line =
      `[APNs] ${context} env=${environment} token=${maskToken(result.token)} status=${result.status}` +
      ` apns-id=${result.apnsId ?? "-"} apns-unique-id=${result.apnsUniqueId ?? "-"}` +
      (result.reason ? ` reason=${result.reason}` : "");
    if (result.status === 200) {
      console.log(line);
    } else {
      console.warn(line);
    }
  }
}

const HOSTS: Record<ApnsEnvironment, string> = {
  sandbox: "https://api.sandbox.push.apple.com",
  production: "https://api.push.apple.com",
};

// APNs rejects tokens older than an hour and throttles refreshes more often than every 20 minutes.
const JWT_LIFETIME_MS = 45 * 60 * 1000;

interface ApnsConfig {
  keyId: string;
  teamId: string;
  bundleId: string;
  privateKey: KeyObject;
}

let cachedConfig: ApnsConfig | null | undefined;
let cachedJwt: { value: string; issuedAt: number } | null = null;

function getConfig(): ApnsConfig | null {
  if (cachedConfig !== undefined) return cachedConfig;

  const { APNS_KEY_ID, APNS_TEAM_ID, APNS_PRIVATE_KEY, APNS_BUNDLE_ID } = process.env;
  if (!APNS_KEY_ID || !APNS_TEAM_ID || !APNS_PRIVATE_KEY || !APNS_BUNDLE_ID) {
    cachedConfig = null;
    return cachedConfig;
  }

  try {
    cachedConfig = {
      keyId: APNS_KEY_ID,
      teamId: APNS_TEAM_ID,
      bundleId: APNS_BUNDLE_ID,
      privateKey: createPrivateKey(Buffer.from(APNS_PRIVATE_KEY, "base64").toString("utf8")),
    };
  } catch (error) {
    console.warn("APNS_PRIVATE_KEY is not a base64-encoded .p8 key; push notifications are disabled:", error);
    cachedConfig = null;
  }
  return cachedConfig;
}

/** Whether the APNs environment variables are set. */
export function isApnsConfigured(): boolean {
  return getConfig() !== null;
}

function base64Url(input: Buffer | string): string {
  return Buffer.from(input).toString("base64url");
}

function getJwt(config: ApnsConfig): string {
  const now = Date.now();
  if (cachedJwt && now - cachedJwt.issuedAt < JWT_LIFETIME_MS) {
    return cachedJwt.value;
  }

  const header = base64Url(JSON.stringify({ alg: "ES256", kid: config.keyId }));
  const claims = base64Url(JSON.stringify({ iss: config.teamId, iat: Math.floor(now / 1000) }));
  const signature = sign("sha256", Buffer.from(`${header}.${claims}`), {
    key: config.privateKey,
    dsaEncoding: "ieee-p1363",
  });

  cachedJwt = { value: `${header}.${claims}.${base64Url(signature)}`, issuedAt: now };
  return cachedJwt.value;
}

interface PushOptions {
  pushType: "alert" | "liveactivity";
  priority: 5 | 10;
}

function sendOne(
  session: http2.ClientHttp2Session,
  config: ApnsConfig,
  token: string,
  payload: string,
  options: PushOptions
): Promise<ApnsResult> {
  return new Promise((resolve) => {
    const request = session.request({
      ":method": "POST",
      ":path": `/3/device/${token}`,
      authorization: `bearer ${getJwt(config)}`,
      // Live Activity pushes use a dedicated topic derived from the app's bundle ID
      "apns-topic":
        options.pushType === "liveactivity"
          ? `${config.bundleId}.push-type.liveactivity`
          : config.bundleId,
      "apns-push-type": options.pushType,
      "apns-priority": String(options.priority),
      "content-type": "application/json",
    });

    let status = 0;
    let apnsId: string | undefined;
    let apnsUniqueId: string | undefined;
    let body = "";
    request.setEncoding("utf8");
    request.on("response", (headers) => {
      status = Number(headers[":status"]);
      apnsId = headers["apns-id"] as string | undefined;
      apnsUniqueId = headers["apns-unique-id"] as string | undefined;
    });
    request.on("data", (chunk: string) => {
      body += chunk;
    });
    request.on("end", () => {
      let reason: string | undefined;
      if (body) {
        try {
          reason = (JSON.parse(body) as { reason?: string }).reason;
        } catch {
          reason = body;
        }
      }
      resolve({ token, status, reason, apnsId, apnsUniqueId });
    });
    request.on("error", (error) => {
      resolve({ token, status: 0, reason: error.message });
    });

    request.end(payload);
  });
}

/**
 * Sends an alert to every token in one APNs environment. Never throws; each
 * token's outcome is returned so callers can prune invalid tokens.
 */
export async function sendApnsAlert(
  environment: ApnsEnvironment,
  tokens: string[],
  alert: ApnsAlert
): Promise<ApnsResult[]> {
  const payload = {
    aps: {
      alert: { title: alert.title, body: alert.body },
      sound: "default",
      ...(alert.threadId ? { "thread-id": alert.threadId } : {}),
    },
    ...alert.data,
  };
  return send(environment, tokens, payload, { pushType: "alert", priority: 10 });
}

/**
 * Sends a Live Activity push (start, update or end) to every token in one
 * APNs environment. `aps` is the full `aps` dictionary, including `event`,
 * `timestamp` and `content-state`. Never throws.
 */
export async function sendApnsLiveActivity(
  environment: ApnsEnvironment,
  tokens: string[],
  aps: Record<string, unknown>,
  priority: 5 | 10
): Promise<ApnsResult[]> {
  return send(environment, tokens, { aps }, { pushType: "liveactivity", priority });
}

async function send(
  environment: ApnsEnvironment,
  tokens: string[],
  body: Record<string, unknown>,
  options: PushOptions
): Promise<ApnsResult[]> {
  const config = getConfig();
  if (!config || tokens.length === 0) return [];

  const payload = JSON.stringify(body);
  const session = http2.connect(HOSTS[environment]);
  const sessionError = new Promise<ApnsResult[]>((resolve) => {
    session.on("error", (error) =>
      resolve(tokens.map((token) => ({ token, status: 0, reason: error.message })))
    );
  });

  try {
    return await Promise.race([
      Promise.all(tokens.map((token) => sendOne(session, config, token, payload, options))),
      sessionError,
    ]);
  } finally {
    session.close();
  }
}

/** Whether APNs says the token will never be deliverable again. */
export function isInvalidTokenResult(result: ApnsResult): boolean {
  return (
    result.status === 410 ||
    (result.status === 400 &&
      (result.reason === "BadDeviceToken" || result.reason === "DeviceTokenNotForTopic"))
  );
}
