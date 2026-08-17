// Sends a push notification for one event, so an alert arrives even when the
// app is closed.
//
// This lives outside the app on purpose. Sending through FCM requires a
// Firebase service-account key, and a key shipped inside an APK can be
// extracted by anyone who downloads it — they could then push anything to
// every user of the platform. Cloud Functions is the usual home for this, but
// it needs the paid Blaze plan, so it runs here on Supabase's free tier
// instead.
//
// The caller sends only an id. The text is read from the notification document
// in Firestore, so nobody can dictate the contents of an alert by calling this
// endpoint. Deploy and configure it as described in docs/notifications.md.

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

/// Events older than this are refused. The app calls this immediately after
/// writing, so anything older is a replay rather than a real event.
const MAX_EVENT_AGE_MS = 5 * 60 * 1000;

const TEXT: Record<string, Record<string, string>> = {
  ar: {
    notification_proposal_title: "مقترح جديد",
    notification_proposal_body: 'قام {name} بإرسال "{title}"',
    notification_income_title: "تم تسجيل إيراد",
    notification_expense_title: "تم تسجيل مصروف",
    notification_transaction_body: "أضاف {name} مبلغ {amount}$",
  },
  en: {
    notification_proposal_title: "New proposal",
    notification_proposal_body: '{name} submitted "{title}"',
    notification_income_title: "Income recorded",
    notification_expense_title: "Expense recorded",
    notification_transaction_body: "{name} added {amount}$",
  },
  nl: {
    notification_proposal_title: "Nieuw voorstel",
    notification_proposal_body: '{name} heeft "{title}" ingediend',
    notification_income_title: "Inkomsten geboekt",
    notification_expense_title: "Uitgave geboekt",
    notification_transaction_body: "{name} heeft {amount}$ toegevoegd",
  },
};

function translate(
  locale: string,
  key: string,
  params: Record<string, string>,
): string {
  const table = TEXT[locale] ?? TEXT.ar;
  let value = table[key] ?? TEXT.ar[key] ?? key;
  for (const [name, replacement] of Object.entries(params)) {
    value = value.replaceAll(`{${name}}`, replacement);
  }
  return value;
}

// --- Google auth -----------------------------------------------------------

function base64Url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function pemToPkcs8(pem: string): ArrayBuffer {
  // Keys pasted into a shell env var often arrive with literal "\n".
  const body = pem
    .replace(/\\n/g, "\n")
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const raw = atob(body);
  const buffer = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) buffer[i] = raw.charCodeAt(i);
  return buffer.buffer;
}

/// Exchanges the service-account key for a short-lived access token.
async function accessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: account.client_email,
    scope: [
      "https://www.googleapis.com/auth/firebase.messaging",
      "https://www.googleapis.com/auth/datastore",
    ].join(" "),
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const encoder = new TextEncoder();
  const unsigned = `${base64Url(encoder.encode(JSON.stringify(header)))}.` +
    `${base64Url(encoder.encode(JSON.stringify(claims)))}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    encoder.encode(unsigned),
  );

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${unsigned}.${base64Url(new Uint8Array(signature))}`,
    }),
  });

  if (!response.ok) {
    throw new Error(`token exchange failed: ${await response.text()}`);
  }
  return (await response.json()).access_token;
}

// --- Firestore REST --------------------------------------------------------

// Firestore's REST API wraps every value in its type, so a document reads as
// {"name": {"stringValue": "Samer"}} rather than {"name": "Samer"}.
// deno-lint-ignore no-explicit-any
function plain(value: any): any {
  if (value === null || value === undefined) return null;
  if ("stringValue" in value) return value.stringValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return value.doubleValue;
  if ("booleanValue" in value) return value.booleanValue;
  if ("timestampValue" in value) return value.timestampValue;
  if ("arrayValue" in value) return (value.arrayValue.values ?? []).map(plain);
  if ("mapValue" in value) return fields(value.mapValue.fields ?? {});
  return null;
}

// deno-lint-ignore no-explicit-any
function fields(raw: Record<string, any>): Record<string, any> {
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(raw)) out[key] = plain(value);
  return out;
}

async function firestoreGet(
  token: string,
  projectId: string,
  path: string,
  // deno-lint-ignore no-explicit-any
): Promise<any> {
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}` +
      `/databases/(default)/documents/${path}`,
    { headers: { Authorization: `Bearer ${token}` } },
  );
  if (!response.ok) {
    throw new Error(`firestore ${path} failed: ${await response.text()}`);
  }
  return await response.json();
}

// --- Handler ---------------------------------------------------------------

Deno.serve(async (request) => {
  try {
    const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!raw) {
      return json({ error: "FIREBASE_SERVICE_ACCOUNT is not set" }, 500);
    }
    const account: ServiceAccount = JSON.parse(raw);
    const projectId = account.project_id;

    const { notificationId } = await request.json();
    if (typeof notificationId !== "string" || notificationId.length === 0) {
      return json({ error: "notificationId is required" }, 400);
    }

    const token = await accessToken(account);

    const document = await firestoreGet(
      token,
      projectId,
      `notifications/${encodeURIComponent(notificationId)}`,
    );
    const event = fields(document.fields ?? {});

    const createdAt = Date.parse(event.createdAt ?? "");
    if (!Number.isFinite(createdAt)) {
      return json({ error: "notification has no usable createdAt" }, 400);
    }
    if (Date.now() - createdAt > MAX_EVENT_AGE_MS) {
      // Refusing an old event is what stops this endpoint being used to
      // replay notifications at the team.
      return json({ skipped: "event is too old to deliver" }, 202);
    }

    const listing = await firestoreGet(token, projectId, "users?pageSize=300");
    const recipients: { token: string; locale: string }[] = [];

    for (const userDocument of listing.documents ?? []) {
      const user = fields(userDocument.fields ?? {});

      // Nobody is told about their own action.
      if (user.uid === event.actorUid) continue;

      const isReviewer = user.role === "manager" || user.role === "admin";
      const inAudience = event.audience === "all" ||
        (event.audience === "reviewers" && isReviewer);
      if (!inAudience) continue;

      for (const deviceToken of user.fcmTokens ?? []) {
        if (typeof deviceToken === "string") {
          recipients.push({ token: deviceToken, locale: user.locale ?? "ar" });
        }
      }
    }

    const params: Record<string, string> = event.params ?? {};
    let delivered = 0;

    for (const recipient of recipients) {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token: recipient.token,
              notification: {
                title: translate(recipient.locale, event.titleKey, params),
                body: translate(recipient.locale, event.bodyKey, params),
              },
              data: { route: event.route ?? "", notificationId },
              android: { priority: "HIGH" },
            },
          }),
        },
      );
      // One dead token — an uninstalled app, say — must not stop the rest.
      if (response.ok) delivered++;
    }

    return json({ recipients: recipients.length, delivered }, 200);
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
