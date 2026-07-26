import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {getMessaging} from "firebase-admin/messaging";
import {DocumentProcessorServiceClient} from "@google-cloud/documentai";
import {GoogleAuth} from "google-auth-library";
import Stripe from "stripe";
import {defineSecret, defineString} from "firebase-functions/params";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import OpenAI from "openai";
import {createHash, createSign} from "node:crypto";

initializeApp();

const db = getFirestore();
const openAiApiKey = defineSecret("OPENAI_API_KEY");
const documentAiProcessor = defineString("DOCUMENT_AI_PROCESSOR");
const stripeSecretKey = defineSecret("STRIPE_SECRET_KEY");
const stripeWebhookSecret = defineSecret("STRIPE_WEBHOOK_SECRET");
const stripePremiumPriceId = defineString("STRIPE_PREMIUM_PRICE_ID");
const stripeProPriceId = defineString("STRIPE_PRO_PRICE_ID");
const webAppOrigin = defineString("WEB_APP_ORIGIN");
const androidPackageName = defineString("ANDROID_PACKAGE_NAME");
const appleBundleId = defineString("APPLE_BUNDLE_ID");
const appleIssuerId = defineString("APPLE_APP_STORE_ISSUER_ID");
const appleKeyId = defineString("APPLE_APP_STORE_KEY_ID");
const appleEnvironment = defineString("APPLE_APP_STORE_ENV");
const googlePlayServiceAccountJson = defineSecret("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON");
const appleAppStorePrivateKey = defineSecret("APPLE_APP_STORE_PRIVATE_KEY");
const storeProductIds = new Set(["briefai_premium_monthly", "briefai_pro_monthly"]);
const allowedCategories = [
  "Finanzamt", "Krankenkasse", "Jobcenter", "Banka", "Osiguranje",
  "Telekom", "Poslodavac", "Stanodavac", "Škola", "Vrtić", "Sud", "Ostalo",
] as const;

type Analysis = {
  title: string;
  plainExplanation: string;
  category: (typeof allowedCategories)[number];
  urgency: "LOW" | "MEDIUM" | "HIGH";
  deadline: string | null;
  amounts: string[];
  suggestedAction: string;
  disclaimer: string;
};

const analysisSchema = {
  type: "object",
  additionalProperties: false,
  required: ["title", "plainExplanation", "category", "urgency", "deadline", "amounts", "suggestedAction", "disclaimer"],
  properties: {
    title: {type: "string"},
    plainExplanation: {type: "string"},
    category: {type: "string", enum: allowedCategories},
    urgency: {type: "string", enum: ["LOW", "MEDIUM", "HIGH"]},
    deadline: {type: ["string", "null"], description: "ISO date YYYY-MM-DD if explicitly found"},
    amounts: {type: "array", items: {type: "string"}},
    suggestedAction: {type: "string"},
    disclaimer: {type: "string"},
  },
};

function requireUser(uid: string | undefined): string {
  if (!uid) throw new HttpsError("unauthenticated", "Prijava je obavezna.");
  return uid;
}

function requireString(value: unknown, name: string, maxLength: number): string {
  if (typeof value !== "string" || value.trim() === "" || value.length > maxLength) {
    throw new HttpsError("invalid-argument", `Neispravno polje: ${name}.`);
  }
  return value.trim();
}

function stripeClient(): Stripe {
  return new Stripe(stripeSecretKey.value());
}

function isAllowedReturnUrl(value: unknown): value is string {
  if (typeof value !== "string") return false;
  try {
    const url = new URL(value);
    const configuredOrigin = new URL(webAppOrigin.value());
    return url.origin === configuredOrigin.origin &&
      (url.protocol === "https:" || (process.env.FUNCTIONS_EMULATOR === "true" && url.protocol === "http:"));
  } catch {
    return false;
  }
}

function base64UrlJson(value: Record<string, unknown>): string {
  return Buffer.from(JSON.stringify(value)).toString("base64url");
}

function decodeJwsPayload(value: string): Record<string, unknown> {
  const payload = value.split(".")[1];
  if (!payload) throw new HttpsError("failed-precondition", "Apple nije vratio validan potpisani odgovor.");
  try {
    return JSON.parse(Buffer.from(payload, "base64url").toString("utf8")) as Record<string, unknown>;
  } catch {
    throw new HttpsError("failed-precondition", "Apple odgovor nije moguće pročitati.");
  }
}

function appleApiToken(): string {
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlJson({alg: "ES256", kid: appleKeyId.value(), typ: "JWT"});
  const payload = base64UrlJson({
    iss: appleIssuerId.value(),
    iat: now,
    exp: now + 300,
    aud: "appstoreconnect-v1",
    bid: appleBundleId.value(),
  });
  const signer = createSign("SHA256");
  signer.update(`${header}.${payload}`);
  signer.end();
  const signature = signer.sign({key: appleAppStorePrivateKey.value(), dsaEncoding: "ieee-p1363"});
  return `${header}.${payload}.${signature.toString("base64url")}`;
}

function storeTransactionRef(provider: string, value: string) {
  const digest = createHash("sha256").update(`${provider}:${value}`).digest("hex");
  return db.collection("storeTransactions").doc(digest);
}

async function verifyGooglePlaySubscription(purchaseToken: string, productId: string) {
  let credentials: Record<string, unknown>;
  try {
    credentials = JSON.parse(googlePlayServiceAccountJson.value()) as Record<string, unknown>;
  } catch {
    throw new HttpsError("failed-precondition", "Google Play servisni nalog nije konfigurisan.");
  }
  const auth = new GoogleAuth({
    credentials,
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  const client = await auth.getClient();
  const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(androidPackageName.value())}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
  try {
    const response = await client.request<Record<string, unknown>>({url});
    const data = response.data;
    const lineItems = Array.isArray(data.lineItems) ? data.lineItems : [];
    const productMatches = lineItems.some((item) =>
      typeof item === "object" && item !== null && (item as Record<string, unknown>).productId === productId,
    );
    const state = data.subscriptionState;
    const active = state === "SUBSCRIPTION_STATE_ACTIVE" ||
      state === "SUBSCRIPTION_STATE_IN_GRACE_PERIOD" ||
      state === "SUBSCRIPTION_STATE_CANCELED";
    const expiry = lineItems
      .map((item) => typeof item === "object" && item !== null ? (item as Record<string, unknown>).expiryTime : null)
      .find((value): value is string => typeof value === "string");
    return {active: productMatches && active, status: String(state ?? "unknown"), expiresAt: expiry ?? null};
  } catch {
    throw new HttpsError("failed-precondition", "Google Play nije potvrdio pretplatu.");
  }
}

async function verifyAppleSubscription(transactionId: string, productId: string) {
  const sandbox = appleEnvironment.value().toLowerCase() === "sandbox";
  const host = sandbox ? "https://api.storekit-sandbox.apple.com" : "https://api.storekit.apple.com";
  const response = await fetch(`${host}/inApps/v1/subscriptions/${encodeURIComponent(transactionId)}`, {
    headers: {Authorization: `Bearer ${appleApiToken()}`},
  });
  if (!response.ok) throw new HttpsError("failed-precondition", "App Store nije potvrdio pretplatu.");
  const data = await response.json() as {data?: Array<{lastTransactions?: Array<{status?: number; signedTransactionInfo?: string}>}>};
  const transactions = data.data?.flatMap((group) => group.lastTransactions ?? []) ?? [];
  for (const transaction of transactions) {
    if (!transaction.signedTransactionInfo) continue;
    const payload = decodeJwsPayload(transaction.signedTransactionInfo);
    const expiresDate = typeof payload.expiresDate === "number" ? payload.expiresDate : 0;
    const matchingProduct = payload.productId === productId && payload.bundleId === appleBundleId.value();
    const activeStatus = transaction.status === 1 || transaction.status === 4;
    if (matchingProduct && activeStatus && expiresDate > Date.now()) {
      return {active: true, status: transaction.status === 4 ? "grace_period" : "active", expiresAt: new Date(expiresDate).toISOString()};
    }
  }
  return {active: false, status: "inactive", expiresAt: null};
}

// Accepts only OCR text. Binary documents stay private in Storage and are not
// serialized into function input or application logs.
export const analyzeLetter = onCall(
  {region: "europe-west3", secrets: [openAiApiKey], enforceAppCheck: true, timeoutSeconds: 90},
  async (request) => {
    const uid = requireUser(request.auth?.uid);
    const letterId = requireString(request.data?.letterId, "letterId", 128);
    const ocrText = requireString(request.data?.ocrText, "ocrText", 30000);
    const preferredLanguage = requireString(request.data?.preferredLanguage ?? "sr", "preferredLanguage", 16);
    const storagePath = typeof request.data?.storagePath === "string" ? request.data.storagePath : null;
    const [usage, subscription] = await Promise.all([
      db.collection("users").doc(uid).collection("usage").doc("current").get(),
      db.collection("subscriptions").doc(uid).get(),
    ]);
    const isPremium = ["active", "trialing"].includes(subscription.data()?.status);
    const now = new Date();
    const monthKey = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, "0")}`;
    const analysesThisMonth = usage.data()?.monthKey === monthKey ? usage.data()?.analysesThisMonth ?? 0 : 0;
    if (!isPremium && analysesThisMonth >= 2) {
      throw new HttpsError("resource-exhausted", "Besplatni limit od 2 analize je iskorišćen.");
    }
    const client = new OpenAI({apiKey: openAiApiKey.value()});
    const response = await client.responses.create({
      model: process.env.OPENAI_MODEL ?? "gpt-4.1-mini",
      instructions: `You explain German official letters in ${preferredLanguage}. Do not give legal, tax, medical or financial advice. Extract only facts explicitly present in the letter. Return a concise structured explanation.`,
      input: ocrText,
      text: {format: {type: "json_schema", name: "letter_analysis", strict: true, schema: analysisSchema}},
    });
    const output = response.output_text;
    if (!output) throw new HttpsError("internal", "AI analiza nije vraćena.");
    let analysis: Analysis;
    try { analysis = JSON.parse(output) as Analysis; } catch { throw new HttpsError("internal", "AI odgovor nije validan JSON."); }
    const letterRef = db.collection("users").doc(uid).collection("letters").doc(letterId);
    await db.runTransaction(async (transaction) => {
      transaction.set(letterRef, {
        ...analysis,
        sourceText: ocrText,
        storagePath,
        status: "newLetter",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      transaction.set(usage.ref, {analysesThisMonth: analysesThisMonth + 1, monthKey, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
    });
    return {analysis};
  },
);

// OCR runs server-side for PDFs and as a platform fallback for images. The
// object path is checked against the caller UID before any bytes are read.
export const extractDocumentText = onCall(
  {region: "europe-west3", enforceAppCheck: true, timeoutSeconds: 180, memory: "1GiB"},
  async (request) => {
    const uid = requireUser(request.auth?.uid);
    const storagePath = requireString(request.data?.storagePath, "storagePath", 1024);
    const mimeType = requireString(request.data?.mimeType, "mimeType", 64);
    if (!storagePath.startsWith(`users/${uid}/letters/`)) {
      throw new HttpsError("permission-denied", "Nedozvoljena putanja dokumenta.");
    }
    if (!["application/pdf", "image/jpeg", "image/png"].includes(mimeType)) {
      throw new HttpsError("invalid-argument", "Nepodržan format dokumenta.");
    }
    const processorId = documentAiProcessor.value();
    const projectId = process.env.GCLOUD_PROJECT;
    if (!projectId) throw new HttpsError("failed-precondition", "Google Cloud projekat nije konfigurisan.");
    const [content] = await getStorage().bucket().file(storagePath).download();
    const client = new DocumentProcessorServiceClient({apiEndpoint: "eu-documentai.googleapis.com"});
    const [result] = await client.processDocument({
      name: `projects/${projectId}/locations/eu/processors/${processorId}`,
      rawDocument: {content, mimeType},
    });
    const text = result.document?.text?.trim() ?? "";
    if (!text) throw new HttpsError("failed-precondition", "Tekst nije prepoznat u dokumentu.");
    return {text};
  },
);

export const generateReply = onCall(
  {region: "europe-west3", secrets: [openAiApiKey], enforceAppCheck: true},
  async (request) => {
    const uid = requireUser(request.auth?.uid);
    const letterId = requireString(request.data?.letterId, "letterId", 128);
    const facts = requireString(request.data?.facts, "facts", 10000);
    const language = requireString(request.data?.preferredLanguage ?? "sr", "preferredLanguage", 16);
    const [letter, subscription] = await Promise.all([
      db.collection("users").doc(uid).collection("letters").doc(letterId).get(),
      db.collection("subscriptions").doc(uid).get(),
    ]);
    if (!letter.exists) throw new HttpsError("not-found", "Pismo ne postoji.");
    if (!["active", "trialing"].includes(subscription.data()?.status)) {
      throw new HttpsError("permission-denied", "AI odgovori su dostupni uz Premium pretplatu.");
    }
    const client = new OpenAI({apiKey: openAiApiKey.value()});
    const response = await client.responses.create({
      model: process.env.OPENAI_MODEL ?? "gpt-4.1-mini",
      instructions: `Draft a formal German reply based only on user supplied facts. Also supply a short ${language} explanation. Never invent claims, dates, documents, or legal conclusions.`,
      input: facts,
    });
    return {reply: response.output_text};
  },
);

export const createStripeCheckout = onCall(
  {region: "europe-west3", secrets: [stripeSecretKey], enforceAppCheck: true},
  async (request) => {
    const uid = requireUser(request.auth?.uid);
    const plan = requireString(request.data?.plan, "plan", 16);
    const successUrl = request.data?.successUrl;
    const cancelUrl = request.data?.cancelUrl;
    if (!isAllowedReturnUrl(successUrl) || !isAllowedReturnUrl(cancelUrl)) {
      throw new HttpsError("invalid-argument", "Povratni URL mora koristiti HTTPS.");
    }
    const priceId = plan === "premium" ? stripePremiumPriceId.value() : plan === "pro" ? stripeProPriceId.value() : null;
    if (!priceId) throw new HttpsError("invalid-argument", "Nepoznat plan pretplate.");
    const session = await stripeClient().checkout.sessions.create({
      mode: "subscription",
      line_items: [{price: priceId, quantity: 1}],
      success_url: successUrl,
      cancel_url: cancelUrl,
      client_reference_id: uid,
      metadata: {uid, plan},
      subscription_data: {metadata: {uid, plan}},
    });
    if (!session.url) throw new HttpsError("internal", "Stripe nije vratio Checkout URL.");
    return {url: session.url};
  },
);

// Native stores provide only a proof of purchase to the client. This callable
// verifies that proof with the store and is the sole path that writes the
// entitlement; the client can never grant itself Premium access.
export const verifyStorePurchase = onCall(
  {
    region: "europe-west3",
    enforceAppCheck: true,
    secrets: [googlePlayServiceAccountJson, appleAppStorePrivateKey],
  },
  async (request) => {
    const uid = requireUser(request.auth?.uid);
    const provider = requireString(request.data?.provider, "provider", 32);
    const productId = requireString(request.data?.productId, "productId", 128);
    const verificationData = requireString(request.data?.verificationData, "verificationData", 30000);
    const purchaseId = typeof request.data?.purchaseId === "string" ? request.data.purchaseId : verificationData;
    if (!storeProductIds.has(productId)) throw new HttpsError("invalid-argument", "Nepoznat store proizvod.");
    const verification = provider === "google_play"
      ? await verifyGooglePlaySubscription(verificationData, productId)
      : provider === "app_store"
      ? await verifyAppleSubscription(purchaseId, productId)
      : null;
    if (!verification) throw new HttpsError("invalid-argument", "Nepoznat store provajder.");
    const transactionRef = storeTransactionRef(provider, verificationData);
    await db.runTransaction(async (transaction) => {
      const prior = await transaction.get(transactionRef);
      if (prior.exists && prior.data()?.uid !== uid) {
        throw new HttpsError("permission-denied", "Ova store transakcija je već povezana sa drugim nalogom.");
      }
      transaction.set(transactionRef, {
        uid,
        provider,
        productId,
        status: verification.status,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      transaction.set(db.collection("subscriptions").doc(uid), {
        provider,
        plan: productId === "briefai_pro_monthly" ? "pro" : "premium",
        status: verification.active ? "active" : "inactive",
        expiresAt: verification.expiresAt,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    });
    return {isActive: verification.active};
  },
);

export const stripeWebhook = onRequest(
  {region: "europe-west3", secrets: [stripeSecretKey, stripeWebhookSecret]},
  async (request, response) => {
    const signature = request.header("stripe-signature");
    if (!signature) {
      response.status(400).send("Missing Stripe signature");
      return;
    }
    let event: Stripe.Event;
    try {
      event = stripeClient().webhooks.constructEvent(request.rawBody, signature, stripeWebhookSecret.value());
    } catch {
      response.status(400).send("Invalid Stripe signature");
      return;
    }
    if (event.type.startsWith("customer.subscription.")) {
      const subscription = event.data.object as Stripe.Subscription;
      const uid = subscription.metadata.uid;
      if (uid) {
        await db.collection("subscriptions").doc(uid).set({
          provider: "stripe",
          status: subscription.status,
          plan: subscription.metadata.plan ?? "premium",
          stripeCustomerId: subscription.customer,
          stripeSubscriptionId: subscription.id,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
    }
    response.status(200).send("ok");
  },
);

export const deleteAccount = onCall({region: "europe-west3", enforceAppCheck: true}, async (request) => {
  const uid = requireUser(request.auth?.uid);
  await getStorage().bucket().deleteFiles({prefix: `users/${uid}/`});
  await db.recursiveDelete(db.collection("users").doc(uid));
  await db.collection("subscriptions").doc(uid).delete();
  await getAuth().deleteUser(uid);
  return {deleted: true};
});

export const adminOverview = onCall({region: "europe-west3", enforceAppCheck: true}, async (request) => {
  const uid = requireUser(request.auth?.uid);
  const account = await getAuth().getUser(uid);
  if (account.customClaims?.admin !== true) throw new HttpsError("permission-denied", "Administratorski pristup je obavezan.");
  const activeSince = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  const [users, activeUsers, analyses, premiumUsers, revenue] = await Promise.all([
    db.collection("users").count().get(),
    db.collection("users").where("lastActiveAt", ">=", activeSince).count().get(),
    db.collectionGroup("letters").count().get(),
    db.collection("subscriptions").where("status", "in", ["active", "trialing"]).count().get(),
    db.collection("adminMetrics").doc("current").get(),
  ]);
  return {
    users: users.data().count,
    activeUsers: activeUsers.data().count,
    analyses: analyses.data().count,
    premiumUsers: premiumUsers.data().count,
    revenueCents: revenue.data()?.revenueCents ?? 0,
  };
});

export const sendAdminNotification = onCall({region: "europe-west3", enforceAppCheck: true}, async (request) => {
  const uid = requireUser(request.auth?.uid);
  const account = await getAuth().getUser(uid);
  if (account.customClaims?.admin !== true) throw new HttpsError("permission-denied", "Administratorski pristup je obavezan.");
  const title = requireString(request.data?.title, "title", 80);
  const body = requireString(request.data?.body, "body", 240);
  const tokensSnapshot = await db.collection("deviceTokens").get();
  const tokens = tokensSnapshot.docs.map((doc) => doc.get("token")).filter((token): token is string => typeof token === "string");
  let delivered = 0;
  for (let index = 0; index < tokens.length; index += 500) {
    const result = await getMessaging().sendEachForMulticast({tokens: tokens.slice(index, index + 500), notification: {title, body}});
    delivered += result.successCount;
  }
  await db.collection("adminMetrics").doc("notifications").set({lastSentAt: FieldValue.serverTimestamp(), lastTitle: title, delivered}, {merge: true});
  return {delivered};
});
