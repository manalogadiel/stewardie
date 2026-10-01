import { decodeProtectedHeader, importPKCS8, importX509, jwtVerify, SignJWT } from "https://esm.sh/jose@5.9.6";
import { coreEnabled, coreLookup, service } from '../_shared/core_store.ts';

const project = Deno.env.get("FIREBASE_PROJECT_ID") || "stewardie";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, apikey, x-webhook-auth",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
};

class Failure extends Error {
  constructor(message: string, public status = 400) {
    super(message);
  }
}

let certs: Record<string, string> = {};
let certExpiry = 0;

async function identify(req: Request): Promise<{ uid: string; token: string }> {
  const token = req.headers.get("authorization")?.match(/^Bearer (.+)$/i)?.[1];
  if (!token || token.length > 8192) throw new Failure("Sign in again to verify subscription.", 401);

  let header;
  try {
    header = decodeProtectedHeader(token);
  } catch (_) {
    throw new Failure("Invalid sign-in.", 401);
  }

  const { kid, alg } = header;
  if (alg !== "RS256" || !kid) throw new Failure("Invalid sign-in.", 401);

  if (Date.now() > certExpiry) {
    const res = await fetch("https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com");
    if (!res.ok) throw new Failure("Authentication is temporarily unavailable.", 503);
    certs = await res.json();
    certExpiry = Date.now() + Math.min(3600, Number(res.headers.get("cache-control")?.match(/max-age=(\d+)/)?.[1] ?? 300)) * 1000;
  }

  if (!certs[kid]) throw new Failure("Sign in again.", 401);
  const key = await importX509(certs[kid], "RS256");

  let verified;
  try {
    verified = await jwtVerify(token, key, {
      issuer: `https://securetoken.google.com/${project}`,
      audience: project,
      algorithms: ["RS256"],
    });
  } catch (_) {
    throw new Failure("Sign in again.", 401);
  }

  const { payload } = verified;
  if (!payload.sub || payload.sub.length > 128) throw new Failure("Invalid account.", 403);
  return { uid: payload.sub, token };
}

let cachedServerToken: { token: string; expiresAt: number } | null = null;

async function getServerAuthToken(): Promise<string> {
  const explicit = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_TOKEN");
  if (explicit) return explicit;

  const clientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL");
  const privateKeyPem = Deno.env.get("FIREBASE_PRIVATE_KEY");
  if (!clientEmail || !privateKeyPem) {
    throw new Failure("Server database credentials are not configured.", 503);
  }

  if (cachedServerToken && Date.now() < cachedServerToken.expiresAt - 60000) {
    return cachedServerToken.token;
  }

  try {
    const formattedKey = privateKeyPem.replace(/\\n/g, "\n");
    const key = await importPKCS8(formattedKey, "RS256");
    const now = Math.floor(Date.now() / 1000);
    const jwt = await new SignJWT({
      iss: clientEmail,
      sub: clientEmail,
      aud: "https://oauth2.googleapis.com/token",
      scope: "https://www.googleapis.com/auth/datastore",
    })
      .setProtectedHeader({ alg: "RS256", typ: "JWT" })
      .setIssuedAt(now)
      .setExpirationTime(now + 3600)
      .sign(key);

    const res = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }),
    });

    if (!res.ok) {
      console.error("OAuth token exchange failed", res.status);
      throw new Failure("Server database authentication failed.", 502);
    }

    const data = await res.json();
    cachedServerToken = {
      token: data.access_token,
      expiresAt: Date.now() + (data.expires_in ?? 3600) * 1000,
    };
    return cachedServerToken.token;
  } catch (err) {
    if (err instanceof Failure) throw err;
    console.error("Failed to generate server token", err);
    throw new Failure("Server database authentication failed.", 502);
  }
}

function unpack(v: any): any {
  if (v === undefined || v === null) return null;
  if ("stringValue" in v) return v.stringValue;
  if ("booleanValue" in v) return v.booleanValue;
  if ("timestampValue" in v) return v.timestampValue;
  if ("integerValue" in v) return Number(v.integerValue);
  if ("mapValue" in v) {
    const fields = v.mapValue.fields ?? {};
    return Object.fromEntries(Object.entries(fields).map(([k, val]) => [k, unpack(val)]));
  }
  if ("arrayValue" in v) return (v.arrayValue.values ?? []).map(unpack);
  return null;
}

function pack(v: any): any {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === "string") return { stringValue: v };
  if (typeof v === "boolean") return { booleanValue: v };
  if (typeof v === "number") return { integerValue: v.toString() };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(pack) } };
  if (typeof v === "object") {
    return { mapValue: { fields: Object.fromEntries(Object.entries(v).map(([k, val]) => [k, pack(val)])) } };
  }
  return { stringValue: String(v) };
}

async function getAccountDoc(uid: string, token: string): Promise<Record<string, any>> {
  if(coreEnabled())return await coreLookup(`accounts/${uid}`)??{};
  const emulatorHost = Deno.env.get("FIRESTORE_EMULATOR_HOST");
  const baseUrl = emulatorHost
    ? `http://${emulatorHost}/v1/projects/${project}/databases/(default)/documents`
    : `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;

  const res = await fetch(`${baseUrl}/accounts/${uid}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (res.status === 404) return {};
  if (!res.ok) throw new Failure("Could not verify account state.", 503);
  const body = await res.json();
  return Object.fromEntries(Object.entries(body.fields ?? {}).map(([k, v]) => [k, unpack(v)]));
}

async function updateAccountSubscription(
  uid: string,
  serverAuthToken: string,
  fields: {
    tier: string;
    entitlementSource: string;
    subscription: Record<string, any>;
    subscriptionExpiresAt: string | null;
    lastReconciledAt: string;
  }
): Promise<void> {
  if(coreEnabled()){await service('reconcile',`accounts/${uid}`,fields);return;}
  const emulatorHost = Deno.env.get("FIRESTORE_EMULATOR_HOST");
  const baseUrl = emulatorHost
    ? `http://${emulatorHost}/v1/projects/${project}/databases/(default)/documents`
    : `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;

  const mask = [
    "updateMask.fieldPaths=tier",
    "updateMask.fieldPaths=entitlementSource",
    "updateMask.fieldPaths=subscription",
    "updateMask.fieldPaths=subscriptionExpiresAt",
    "updateMask.fieldPaths=lastReconciledAt",
  ].join("&");

  const firestoreFields: Record<string, any> = {
    tier: pack(fields.tier),
    entitlementSource: pack(fields.entitlementSource),
    subscription: pack(fields.subscription),
    lastReconciledAt: pack(new Date(fields.lastReconciledAt)),
  };
  if (fields.subscriptionExpiresAt) {
    firestoreFields.subscriptionExpiresAt = pack(new Date(fields.subscriptionExpiresAt));
  } else {
    firestoreFields.subscriptionExpiresAt = { nullValue: null };
  }

  const res = await fetch(`${baseUrl}/accounts/${uid}?${mask}`, {
    method: "PATCH",
    headers: {
      Authorization: `Bearer ${serverAuthToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ fields: firestoreFields }),
  });

  if (!res.ok) {
    const errorText = await res.text().catch(() => "");
    console.error("Firestore patch error", res.status, errorText);
    throw new Failure("Failed to update subscription in database.", 502);
  }
}

async function claimWebhookEvent(
  eventId: string,
  serverToken: string
): Promise<{ status: "new" | "pending_retry" | "completed" }> {
  if(coreEnabled()) {
    const path=`revenuecat_events/${eventId}`;
    const previous=await coreLookup(path);
    if(previous)return {status:previous.status==='completed'?'completed':'pending_retry'};
    const created=await service('create',path,{status:'pending',claimedAt:new Date().toISOString()});
    return {status:created.ok?'new':'pending_retry'};
  }
  const emulatorHost = Deno.env.get("FIRESTORE_EMULATOR_HOST");
  const baseUrl = emulatorHost
    ? `http://${emulatorHost}/v1/projects/${project}/databases/(default)/documents`
    : `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;

  const checkRes = await fetch(`${baseUrl}/revenuecat_events/${encodeURIComponent(eventId)}`, {
    headers: { Authorization: `Bearer ${serverToken}` },
  });

  if (checkRes.ok) {
    const data = await checkRes.json().catch(() => ({}));
    const fields = data.fields ? Object.fromEntries(Object.entries(data.fields).map(([k, v]) => [k, unpack(v)])) : {};
    if (fields.status === "completed") {
      return { status: "completed" };
    }
    // Existing event in pending or unfinalized state: allow retry
    return { status: "pending_retry" };
  } else if (checkRes.status !== 404) {
    throw new Failure("Could not verify webhook event status.", 502);
  }

  // Atomically claim the event in pending state
  const createRes = await fetch(`${baseUrl}/revenuecat_events?documentId=${encodeURIComponent(eventId)}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${serverToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      fields: {
        status: pack("pending"),
        eventId: pack(eventId),
        claimedAt: pack(new Date()),
      },
    }),
  });

  if (!createRes.ok) {
    if (createRes.status === 409) {
      // Document was created concurrently, re-check completion status
      const retryCheck = await fetch(`${baseUrl}/revenuecat_events/${encodeURIComponent(eventId)}`, {
        headers: { Authorization: `Bearer ${serverToken}` },
      });
      if (retryCheck.ok) {
        const data = await retryCheck.json().catch(() => ({}));
        const fields = data.fields ? Object.fromEntries(Object.entries(data.fields).map(([k, v]) => [k, unpack(v)])) : {};
        if (fields.status === "completed") {
          return { status: "completed" };
        }
        return { status: "pending_retry" };
      }
    }
    throw new Failure("Failed to record webhook event claim.", 502);
  }

  return { status: "new" };
}

async function markWebhookEventCompleted(
  eventId: string,
  serverToken: string,
  metadata?: { tier?: string; uid?: string }
): Promise<void> {
  if(coreEnabled()){await service('merge',`revenuecat_events/${eventId}`,{status:'completed',processedAt:new Date().toISOString(),...metadata});return;}
  const emulatorHost = Deno.env.get("FIRESTORE_EMULATOR_HOST");
  const baseUrl = emulatorHost
    ? `http://${emulatorHost}/v1/projects/${project}/databases/(default)/documents`
    : `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;

  const mask = [
    "updateMask.fieldPaths=status",
    "updateMask.fieldPaths=processedAt",
  ];
  const fields: Record<string, any> = {
    status: pack("completed"),
    processedAt: pack(new Date()),
  };
  if (metadata?.tier) {
    mask.push("updateMask.fieldPaths=reconciledTier");
    fields.reconciledTier = pack(metadata.tier);
  }

  const patchRes = await fetch(`${baseUrl}/revenuecat_events/${encodeURIComponent(eventId)}?${mask.join("&")}`, {
    method: "PATCH",
    headers: {
      Authorization: `Bearer ${serverToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ fields }),
  });

  if (!patchRes.ok) {
    console.error("Failed to mark webhook event completed", patchRes.status);
    throw new Failure("Failed to finalize webhook event.", 502);
  }
}

async function fetchRevenueCatSubscriber(uid: string): Promise<{
  active: boolean;
  expiresDate: string | null;
  store: string | null;
  productId: string | null;
  environment: string;
  raw: any;
}> {
  const rcKey = Deno.env.get("REVENUECAT_SECRET_KEY") || Deno.env.get("REVENUECAT_API_KEY");
  if (!rcKey) {
    throw new Failure("RevenueCat credentials are not configured.", 503);
  }

  const res = await fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}`, {
    headers: {
      Authorization: `Bearer ${rcKey}`,
      "Content-Type": "application/json",
    },
  });

  if (!res.ok) {
    if (res.status === 404) {
      return { active: false, expiresDate: null, store: null, productId: null, environment: "production", raw: null };
    }
    throw new Failure("RevenueCat subscriber status is temporarily unavailable.", 502);
  }

  const data = await res.json();
  const subscriber = data?.subscriber;
  const entitlement = subscriber?.entitlements?.stewardie_plus;

  if (!entitlement) {
    return { active: false, expiresDate: null, store: null, productId: null, environment: "production", raw: subscriber };
  }

  const expiresDate = entitlement.expires_date ?? null;
  const isExpired = expiresDate != null && new Date(expiresDate).getTime() <= Date.now();
  const active = !isExpired;

  const productId = entitlement.product_identifier ?? null;
  // In RevenueCat REST v1, store and is_sandbox belong to subscriber.subscriptions[productId]
  // or subscriber.non_subscriptions[productId], not the entitlement.
  const sub = productId ? subscriber?.subscriptions?.[productId] : null;
  const nonSubList = productId ? subscriber?.non_subscriptions?.[productId] : null;
  const nonSub = Array.isArray(nonSubList) && nonSubList.length > 0 ? nonSubList[nonSubList.length - 1] : null;
  const tx = sub ?? nonSub;

  const store = tx?.store ?? entitlement?.store ?? null;
  const isSandbox = tx?.is_sandbox === true || entitlement?.is_sandbox === true;

  const validProductionStores = [
    "app_store",
    "mac_app_store",
    "play_store",
    "stripe",
    "amazon",
    "promotional",
  ];

  let environment = "test";
  if (!isSandbox && store && validProductionStores.includes(store)) {
    environment = "production";
  } else {
    // Fail closed: test_store, sandbox, missing store, or unknown metadata -> environment = test
    environment = "test";
  }

  return {
    active,
    expiresDate,
    store,
    productId,
    environment,
    raw: subscriber,
  };
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function isAuthorizedTester(uid: string, account: Record<string, any>): boolean {
  if (account.founderGrant === true || account.entitlementSource === "founder") return true;
  const founderUid = Deno.env.get("FOUNDER_UID");
  if (founderUid && uid === founderUid) return true;
  const allowedTesters = (Deno.env.get("ALLOWED_TEST_UIDS") || "").split(",").map((s) => s.trim()).filter(Boolean);
  if (allowedTesters.includes(uid)) return true;
  return false;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  try {
    const url = new URL(req.url);
    const isWebhook = url.searchParams.get("webhook") === "true";

    if (isWebhook) {
      // Require webhook secret and valid authentication; fail-closed
      const webhookSecret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
      if (!webhookSecret) {
        throw new Failure("Webhook handling is not configured.", 503);
      }
      const authHeader = req.headers.get("x-webhook-auth") || req.headers.get("authorization");
      if (!authHeader || (authHeader !== webhookSecret && authHeader !== `Bearer ${webhookSecret}`)) {
        throw new Failure("Unauthorized webhook delivery.", 401);
      }

      const body = await req.json();
      const appUserId = body.event?.app_user_id;
      if (!appUserId || typeof appUserId !== "string") {
        return json({ error: "Missing app_user_id in webhook payload." }, 400);
      }

      const serverToken = coreEnabled() ? '' : await getServerAuthToken();
      const eventId = body.event?.id;
      if (eventId && typeof eventId === "string") {
        const claim = await claimWebhookEvent(eventId, serverToken);
        if (claim.status === "completed") {
          return json({ received: true, duplicate: true, uid: appUserId });
        }
      }

      const rcStatus = await fetchRevenueCatSubscriber(appUserId);
      if (body.event?.environment === "SANDBOX" || String(body.event?.store || "").toLowerCase() === "test_store") {
        rcStatus.environment = "test";
        if (!rcStatus.store) rcStatus.store = "test_store";
      }

      const account = await getAccountDoc(appUserId, serverToken);
      const isFounder = account.founderGrant === true || account.entitlementSource === "founder";
      const isTestStore = rcStatus.store === "test_store" || rcStatus.environment === "test";
      const isTester = isAuthorizedTester(appUserId, account);

      // Prevent stale out-of-order events from overwriting newer state
      const eventTimestampMs = typeof body.event?.event_timestamp_ms === "number"
        ? body.event.event_timestamp_ms
        : Date.now();
      const existingEventMs = account.subscription?.eventTimestampMs;
      if (typeof existingEventMs === "number" && eventTimestampMs < existingEventMs) {
        if (eventId && typeof eventId === "string") {
          await markWebhookEventCompleted(eventId, serverToken, { uid: appUserId });
        }
        return json({ received: true, ignored: "stale_event", uid: appUserId });
      }

      // Only authorized testers/founders may receive Plus from test store / sandbox
      const effectiveStorePlus = rcStatus.active && (!isTestStore || isTester);
      const effectiveTier = isFounder || effectiveStorePlus ? "plus" : "basic";
      const entitlementSource = isFounder ? "founder" : (effectiveStorePlus ? "store" : "none");

      await updateAccountSubscription(appUserId, serverToken, {
        tier: effectiveTier,
        entitlementSource,
        subscription: {
          active: rcStatus.active,
          entitlement: "stewardie_plus",
          expiresAt: rcStatus.expiresDate,
          store: rcStatus.store,
          productId: rcStatus.productId,
          environment: rcStatus.environment,
          eventTimestampMs,
          lastVerifiedAt: new Date().toISOString(),
        },
        subscriptionExpiresAt: isFounder ? null : rcStatus.expiresDate,
        lastReconciledAt: new Date().toISOString(),
      });

      if (eventId && typeof eventId === "string") {
        await markWebhookEventCompleted(eventId, serverToken, {
          tier: effectiveTier,
          uid: appUserId,
        });
      }

      return json({ received: true, uid: appUserId, active: effectiveTier === "plus" });
    }

    // Direct user-authenticated reconciliation
    const auth = await identify(req);
    const serverToken = coreEnabled() ? '' : await getServerAuthToken();
    const account = await getAccountDoc(auth.uid, serverToken);

    const isFounder = account.founderGrant === true || account.entitlementSource === "founder";
    const rcStatus = await fetchRevenueCatSubscriber(auth.uid);
    const isTestStore = rcStatus.store === "test_store" || rcStatus.environment === "test";
    const isTester = isAuthorizedTester(auth.uid, account);

    // Test subscriptions are only honored for authorized testers/founders
    const effectiveStorePlus = rcStatus.active && (!isTestStore || isTester);
    const effectiveTier = isFounder || effectiveStorePlus ? "plus" : "basic";
    const entitlementSource = isFounder ? "founder" : (effectiveStorePlus ? "store" : "none");

    await updateAccountSubscription(auth.uid, serverToken, {
      tier: effectiveTier,
      entitlementSource,
      subscription: {
        active: rcStatus.active,
        entitlement: "stewardie_plus",
        expiresAt: rcStatus.expiresDate,
        store: rcStatus.store,
        productId: rcStatus.productId,
        environment: rcStatus.environment,
        eventTimestampMs: Date.now(),
        lastVerifiedAt: new Date().toISOString(),
      },
      subscriptionExpiresAt: isFounder ? null : rcStatus.expiresDate,
      lastReconciledAt: new Date().toISOString(),
    });

    return json({
      success: true,
      uid: auth.uid,
      tier: effectiveTier,
      isPlus: effectiveTier === "plus",
      isFounder,
      isSubscriptionActive: effectiveStorePlus,
      entitlementSource,
      subscription: {
        active: rcStatus.active,
        entitlement: "stewardie_plus",
        expiresAt: rcStatus.expiresDate,
        store: rcStatus.store,
        productId: rcStatus.productId,
        environment: rcStatus.environment,
      },
    });
  } catch (e) {
    const status = e instanceof Failure ? e.status : 500;
    const message = e instanceof Error ? e.message : "Subscription reconciliation failed.";
    return json({ error: message }, status);
  }
});
