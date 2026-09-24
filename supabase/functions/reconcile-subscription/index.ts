import { decodeProtectedHeader, importX509, jwtVerify } from "https://esm.sh/jose@5.9.6";

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
    subscription: Record<string, any>;
    subscriptionExpiresAt: string | null;
    lastReconciledAt: string;
  }
): Promise<void> {
  const emulatorHost = Deno.env.get("FIRESTORE_EMULATOR_HOST");
  const baseUrl = emulatorHost
    ? `http://${emulatorHost}/v1/projects/${project}/databases/(default)/documents`
    : `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;

  const mask = [
    "updateMask.fieldPaths=tier",
    "updateMask.fieldPaths=subscription",
    "updateMask.fieldPaths=subscriptionExpiresAt",
    "updateMask.fieldPaths=lastReconciledAt",
  ].join("&");

  const firestoreFields: Record<string, any> = {
    tier: pack(fields.tier),
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

  if (!res.ok && res.status !== 404) {
    console.error("Firestore patch error", res.status, await res.text());
  }
}

async function fetchRevenueCatSubscriber(uid: string): Promise<{
  active: boolean;
  expiresDate: string | null;
  store: string | null;
  productId: string | null;
  raw: any;
}> {
  const rcKey = Deno.env.get("REVENUECAT_SECRET_KEY") || Deno.env.get("REVENUECAT_API_KEY");
  if (!rcKey) {
    // In local sandbox without server key, return graceful fallback
    return {
      active: false,
      expiresDate: null,
      store: "none",
      productId: null,
      raw: null,
    };
  }

  const res = await fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}`, {
    headers: {
      Authorization: `Bearer ${rcKey}`,
      "Content-Type": "application/json",
    },
  });

  if (!res.ok) {
    if (res.status === 404) {
      return { active: false, expiresDate: null, store: null, productId: null, raw: null };
    }
    throw new Failure("RevenueCat subscriber status is temporarily unavailable.", 502);
  }

  const data = await res.json();
  const subscriber = data?.subscriber;
  const entitlement = subscriber?.entitlements?.stewardie_plus;

  if (!entitlement) {
    return { active: false, expiresDate: null, store: null, productId: null, raw: subscriber };
  }

  const expiresDate = entitlement.expires_date ?? null;
  const isExpired = expiresDate != null && new Date(expiresDate).getTime() <= Date.now();
  const active = !isExpired;

  return {
    active,
    expiresDate,
    store: entitlement.store ?? null,
    productId: entitlement.product_identifier ?? null,
    raw: subscriber,
  };
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  try {
    const url = new URL(req.url);
    const isWebhook = url.searchParams.get("webhook") === "true";

    if (isWebhook) {
      // Idempotent RevenueCat webhook verification
      const webhookSecret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
      const authHeader = req.headers.get("x-webhook-auth") || req.headers.get("authorization");
      if (webhookSecret && authHeader !== webhookSecret && authHeader !== `Bearer ${webhookSecret}`) {
        throw new Failure("Unauthorized webhook delivery.", 401);
      }

      const body = await req.json();
      const appUserId = body.event?.app_user_id;
      if (!appUserId || typeof appUserId !== "string") {
        return json({ error: "Missing app_user_id in webhook payload." }, 400);
      }

      // Deduplicate deliveries and refetch current state so delayed events cannot reinstate an expired grant
      const rcStatus = await fetchRevenueCatSubscriber(appUserId);
      const serverToken = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_TOKEN") || "";
      if (serverToken) {
        const account = await getAccountDoc(appUserId, serverToken);
        const isFounder = account.founderGrant === true || account.entitlementSource === "founder";
        const effectiveTier = isFounder || rcStatus.active ? "plus" : "basic";

        await updateAccountSubscription(appUserId, serverToken, {
          tier: effectiveTier,
          subscription: {
            active: rcStatus.active,
            entitlement: "stewardie_plus",
            expiresAt: rcStatus.expiresDate,
            store: rcStatus.store,
            productId: rcStatus.productId,
            environment: rcStatus.store === "test_store" ? "test" : "production",
            lastVerifiedAt: new Date().toISOString(),
          },
          subscriptionExpiresAt: rcStatus.expiresDate,
          lastReconciledAt: new Date().toISOString(),
        });
      }

      return json({ received: true, uid: appUserId, active: rcStatus.active });
    }

    // Direct user-authenticated reconciliation
    const auth = await identify(req);
    const account = await getAccountDoc(auth.uid, auth.token);

    const isFounder = account.founderGrant === true || account.entitlementSource === "founder";
    const rcStatus = await fetchRevenueCatSubscriber(auth.uid);

    // Founder Plus survives all test subscription cycles
    const effectiveTier = isFounder || rcStatus.active ? "plus" : "basic";

    const serverToken = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_TOKEN") || auth.token;
    await updateAccountSubscription(auth.uid, serverToken, {
      tier: effectiveTier,
      subscription: {
        active: rcStatus.active,
        entitlement: "stewardie_plus",
        expiresAt: rcStatus.expiresDate,
        store: rcStatus.store,
        productId: rcStatus.productId,
        environment: rcStatus.store === "test_store" ? "test" : "production",
        lastVerifiedAt: new Date().toISOString(),
      },
      subscriptionExpiresAt: rcStatus.expiresDate,
      lastReconciledAt: new Date().toISOString(),
    });

    return json({
      success: true,
      uid: auth.uid,
      tier: effectiveTier,
      isPlus: effectiveTier === "plus",
      isFounder,
      subscription: {
        active: rcStatus.active,
        entitlement: "stewardie_plus",
        expiresAt: rcStatus.expiresDate,
        store: rcStatus.store,
        productId: rcStatus.productId,
      },
    });
  } catch (e) {
    const status = e instanceof Failure ? e.status : 500;
    const message = e instanceof Error ? e.message : "Subscription reconciliation failed.";
    return json({ error: message }, status);
  }
});
