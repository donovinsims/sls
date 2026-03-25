import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SITE_URL = Deno.env.get("SITE_URL") ?? "https://www.sheaslegacyscalping.com";
const SUPPORT_EMAIL = Deno.env.get("RESEND_ADMIN_EMAIL") ?? "donovinsims@gmail.com";
const FROM_EMAIL = Deno.env.get("RESEND_FROM_EMAIL") ?? "noreply@mail.sheaslegacyscalping.com";
const COURSE_KEY = "sls-vault";
const EARLY_BIRD_PRICE_ID = Deno.env.get("STRIPE_EARLY_BIRD_PRICE_ID") ?? "price_1TEBYp4Fv76iWH7ToEEsVh21";
const REGULAR_PRICE_ID = Deno.env.get("STRIPE_REGULAR_PRICE_ID") ?? "price_1TEBZY4Fv76iWH7TxiNgWHAl";
const EARLY_BIRD_PRODUCT_ID = Deno.env.get("STRIPE_EARLY_BIRD_PRODUCT_ID") ?? "prod_UCakarBzW9NJ35";
const REGULAR_PRODUCT_ID = Deno.env.get("STRIPE_REGULAR_PRODUCT_ID") ?? "prod_UCalgGxrUYLR5B";

type PurchaseResultStatus =
  | "fulfilled"
  | "already_processed"
  | "processing"
  | "manual_review"
  | "invalid_session"
  | "config_error";

type PurchaseRow = {
  id: string;
  stripe_session_id: string;
  stripe_customer_id: string | null;
  customer_id: string | null;
  email: string;
  course_key: string;
  stripe_price_id: string | null;
  stripe_product_id: string | null;
  amount_paid: number | null;
  currency: string | null;
  payment_status: string;
  fulfillment_status: string;
  session_payload: Record<string, unknown>;
  processed_at: string | null;
  buyer_confirmation_sent_at: string | null;
  buyer_access_sent_at: string | null;
  admin_notified_at: string | null;
  manual_review_reason: string | null;
  last_error: string | null;
};

type CustomerRow = {
  id: string;
  email: string;
  course_access: boolean;
  fulfillment_status: string;
  purchased_at: string | null;
  stripe_customer_id: string | null;
  stripe_session_id: string | null;
  confirmation_email_sent_at: string | null;
  admin_notified_at: string | null;
  last_email_error: string | null;
};

type StripePriceLike = {
  id?: string | null;
  product?: string | { id?: string | null } | null;
} | null;

type StripeLineItem = {
  amount_total?: number | null;
  currency?: string | null;
  price?: string | StripePriceLike;
};

type StripeCheckoutSession = Record<string, unknown> & {
  amount_total?: number | null;
  currency?: string | null;
  payment_status?: string | null;
  customer_email?: string | null;
  customer_details?: {
    email?: string | null;
  } | null;
  customer?: string | { id?: string | null } | null;
  line_items?: {
    data?: StripeLineItem[] | null;
  } | null;
};

const PRICE_PRODUCT_MAP = new Map<string, string>([
  [EARLY_BIRD_PRICE_ID, EARLY_BIRD_PRODUCT_ID],
  [REGULAR_PRICE_ID, REGULAR_PRODUCT_ID],
]);

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function normalizeEmail(email: string | null | undefined) {
  return email?.trim().toLowerCase() ?? "";
}

function referenceCode(sessionId: string, purchaseId?: string | null) {
  return purchaseId ?? sessionId.slice(-8).toUpperCase();
}

function formatCurrency(amount: number | null, currency: string | null) {
  if (amount == null) return "";
  const value = (amount / 100).toFixed(2);
  return `${currency?.toUpperCase() ?? "USD"} ${value}`;
}

function buyerConfirmationHtml(email: string, priceId: string | null, amount: number | null) {
  const planLabel = priceId === EARLY_BIRD_PRICE_ID ? "Early Bird" : "Regular";
  return `
<!DOCTYPE html>
<html><head><meta charset="utf-8"></head>
<body style="font-family:Arial,sans-serif;background:#ffffff;color:#1a1a1a;max-width:560px;margin:0 auto;padding:40px 20px;">
  <h1 style="font-size:24px;margin-bottom:8px;">Purchase confirmed</h1>
  <p style="font-size:16px;line-height:1.6;color:#555;">
    Your <strong>SLS Vault</strong> purchase is confirmed.
    ${planLabel}${amount != null ? ` · ${formatCurrency(amount, "usd")}` : ""}
  </p>
  <p style="font-size:16px;line-height:1.6;color:#555;">
    We are setting up your access now. Your next email will contain the login link for <strong>${email}</strong>.
  </p>
  <a href="${SITE_URL}/login" style="display:inline-block;background:#c8a962;color:#fff;text-decoration:none;padding:14px 28px;border-radius:6px;font-weight:600;font-size:16px;margin:16px 0;">
    Go to Login
  </a>
  <p style="font-size:14px;color:#888;margin-top:24px;">
    If you do not see the follow-up email, check spam or use the login page again.
  </p>
  <p style="font-size:13px;color:#aaa;margin-top:32px;">
    Questions? Contact <a href="mailto:${SUPPORT_EMAIL}" style="color:#c8a962;">${SUPPORT_EMAIL}</a>
  </p>
</body></html>`;
}

function buyerAccessHtml(email: string, accessLink: string) {
  return `
<!DOCTYPE html>
<html><head><meta charset="utf-8"></head>
<body style="font-family:Arial,sans-serif;background:#ffffff;color:#1a1a1a;max-width:560px;margin:0 auto;padding:40px 20px;">
  <h1 style="font-size:24px;margin-bottom:8px;">Your access is ready</h1>
  <p style="font-size:16px;line-height:1.6;color:#555;">
    Click the button below to open your course portal for <strong>${email}</strong>.
  </p>
  <a href="${accessLink}" style="display:inline-block;background:#c8a962;color:#fff;text-decoration:none;padding:14px 28px;border-radius:6px;font-weight:600;font-size:16px;margin:16px 0;">
    Open Course Access
  </a>
  <p style="font-size:14px;color:#888;margin-top:24px;">
    If the button does not work, use the login page at <a href="${SITE_URL}/login" style="color:#c8a962;">${SITE_URL}/login</a>.
  </p>
</body></html>`;
}

function adminSuccessHtml(email: string, amount: number | null, priceId: string | null, sessionId: string) {
  return `
<!DOCTYPE html>
<html><head><meta charset="utf-8"></head>
<body style="font-family:Arial,sans-serif;background:#ffffff;color:#1a1a1a;max-width:560px;margin:0 auto;padding:40px 20px;">
  <h1 style="font-size:22px;margin-bottom:8px;">New course purchase</h1>
  <table style="font-size:15px;line-height:1.8;color:#555;">
    <tr><td style="padding-right:16px;font-weight:600;">Customer</td><td>${email}</td></tr>
    <tr><td style="padding-right:16px;font-weight:600;">Amount</td><td>${amount != null ? formatCurrency(amount, "usd") : "Unknown"}</td></tr>
    <tr><td style="padding-right:16px;font-weight:600;">Price</td><td>${priceId ?? "Unknown"}</td></tr>
    <tr><td style="padding-right:16px;font-weight:600;">Session</td><td>${sessionId}</td></tr>
    <tr><td style="padding-right:16px;font-weight:600;">Time</td><td>${new Date().toISOString()}</td></tr>
  </table>
  <a href="${SITE_URL}/admin" style="display:inline-block;background:#c8a962;color:#fff;text-decoration:none;padding:12px 24px;border-radius:6px;font-weight:600;font-size:14px;margin:20px 0;">
    Open Admin
  </a>
</body></html>`;
}

function manualReviewHtml(email: string, reason: string, sessionId: string, purchaseId: string) {
  return `
<!DOCTYPE html>
<html><head><meta charset="utf-8"></head>
<body style="font-family:Arial,sans-serif;background:#ffffff;color:#1a1a1a;max-width:560px;margin:0 auto;padding:40px 20px;">
  <h1 style="font-size:22px;margin-bottom:8px;">Manual review needed</h1>
  <p style="font-size:15px;line-height:1.7;color:#555;">
    A purchase verified in Stripe but fulfillment could not complete automatically.
  </p>
  <table style="font-size:15px;line-height:1.8;color:#555;">
    <tr><td style="padding-right:16px;font-weight:600;">Customer</td><td>${email}</td></tr>
    <tr><td style="padding-right:16px;font-weight:600;">Reason</td><td>${reason}</td></tr>
    <tr><td style="padding-right:16px;font-weight:600;">Session</td><td>${sessionId}</td></tr>
    <tr><td style="padding-right:16px;font-weight:600;">Purchase</td><td>${purchaseId}</td></tr>
  </table>
  <a href="${SITE_URL}/admin" style="display:inline-block;background:#c8a962;color:#fff;text-decoration:none;padding:12px 24px;border-radius:6px;font-weight:600;font-size:14px;margin:20px 0;">
    Review in Admin
  </a>
</body></html>`;
}

async function sendResendEmail(to: string, subject: string, html: string) {
  const apiKey = Deno.env.get("RESEND_API");
  if (!apiKey) {
    return { ok: false, error: "RESEND_API not configured" };
  }

  try {
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ from: FROM_EMAIL, to: [to], subject, html }),
    });

    if (!response.ok) {
      return { ok: false, error: await response.text() };
    }

    return { ok: true };
  } catch (error) {
    return { ok: false, error: String(error) };
  }
}

async function fetchStripeSession(stripeSecretKey: string, sessionId: string) {
  const url = new URL(`https://api.stripe.com/v1/checkout/sessions/${sessionId}`);
  url.searchParams.append("expand[]", "line_items.data.price.product");
  url.searchParams.append("expand[]", "customer");
  url.searchParams.append("expand[]", "line_items");

  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${stripeSecretKey}` },
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Stripe ${response.status}: ${errorText}`);
  }

  return (await response.json()) as StripeCheckoutSession;
}

function extractPriceInfo(session: StripeCheckoutSession) {
  const lineItems = session?.line_items?.data ?? [];
  if (lineItems.length !== 1) {
    return { error: "Expected exactly one checkout line item." };
  }

  const lineItem = lineItems[0];
  const price = lineItem?.price;
  const priceId = typeof price === "string" ? price : price?.id ?? null;
  const product = typeof price === "string" ? null : price?.product ?? null;
  const productId = typeof product === "string" ? product : product?.id ?? null;

  if (!priceId || !productId) {
    return { error: "Stripe line item missing price or product." };
  }

  if (PRICE_PRODUCT_MAP.get(priceId) !== productId) {
    return { error: "Stripe price and product do not match the configured course." };
  }

  return {
    priceId,
    productId,
    amountPaid: session?.amount_total ?? lineItem?.amount_total ?? null,
    currency: session?.currency ?? lineItem?.currency ?? null,
  };
}

async function resolveStripeCustomerEmail(stripeSecretKey: string, session: StripeCheckoutSession) {
  const directEmail = normalizeEmail(session?.customer_details?.email ?? session?.customer_email);
  if (directEmail) return directEmail;

  const customerId = typeof session?.customer === "string" ? session.customer : session?.customer?.id;
  if (!customerId) return "";

  const response = await fetch(`https://api.stripe.com/v1/customers/${customerId}`, {
    headers: { Authorization: `Bearer ${stripeSecretKey}` },
  });

  if (!response.ok) return "";

  const customer = await response.json();
  return normalizeEmail(customer?.email);
}

async function buildAccessLink(adminClient: ReturnType<typeof createClient>, email: string) {
  const { data, error } = await adminClient.auth.admin.generateLink({
    type: "magiclink",
    email,
    options: { redirectTo: `${SITE_URL}/portal` },
  });

  if (error) {
    return { link: `${SITE_URL}/login?email=${encodeURIComponent(email)}`, error: error.message };
  }

  const link =
    data?.properties?.action_link ??
    data?.action_link ??
    `${SITE_URL}/login?email=${encodeURIComponent(email)}`;

  return { link, error: null };
}

async function fetchPurchase(adminClient: ReturnType<typeof createClient>, sessionId: string) {
  const { data } = await adminClient
    .from("purchases")
    .select(
      "id, stripe_session_id, stripe_customer_id, customer_id, email, course_key, stripe_price_id, stripe_product_id, amount_paid, currency, payment_status, fulfillment_status, session_payload, processed_at, buyer_confirmation_sent_at, buyer_access_sent_at, admin_notified_at, manual_review_reason, last_error",
    )
    .eq("stripe_session_id", sessionId)
    .maybeSingle();

  return data as PurchaseRow | null;
}

async function fetchCustomer(adminClient: ReturnType<typeof createClient>, email: string) {
  const { data } = await adminClient
    .from("customers")
    .select(
      "id, email, course_access, fulfillment_status, purchased_at, stripe_customer_id, stripe_session_id, confirmation_email_sent_at, admin_notified_at, last_email_error",
    )
    .eq("email", email)
    .maybeSingle();

  return data as CustomerRow | null;
}

async function persistPurchase(
  adminClient: ReturnType<typeof createClient>,
  payload: Record<string, unknown>,
) {
  const { data, error } = await adminClient
    .from("purchases")
    .upsert({ ...payload, updated_at: new Date().toISOString() }, { onConflict: "stripe_session_id" })
    .select(
      "id, stripe_session_id, stripe_customer_id, customer_id, email, course_key, stripe_price_id, stripe_product_id, amount_paid, currency, payment_status, fulfillment_status, session_payload, processed_at, buyer_confirmation_sent_at, buyer_access_sent_at, admin_notified_at, manual_review_reason, last_error",
    )
    .maybeSingle();

  if (error) {
    throw error;
  }

  return data as PurchaseRow;
}

async function persistCustomer(
  adminClient: ReturnType<typeof createClient>,
  payload: Record<string, unknown>,
) {
  const { data, error } = await adminClient
    .from("customers")
    .upsert(payload, { onConflict: "email" })
    .select(
      "id, email, course_access, fulfillment_status, purchased_at, stripe_customer_id, stripe_session_id, confirmation_email_sent_at, admin_notified_at, last_email_error",
    )
    .maybeSingle();

  if (error) {
    throw error;
  }

  return data as CustomerRow;
}

async function persistGrant(
  adminClient: ReturnType<typeof createClient>,
  customerId: string,
  purchaseId: string | null,
) {
  const { error } = await adminClient.from("course_access_grants").upsert(
    {
      customer_id: customerId,
      course_key: COURSE_KEY,
      source_purchase_id: purchaseId,
      revoked_at: null,
      updated_at: new Date().toISOString(),
    },
    { onConflict: "customer_id,course_key" },
  );

  if (error) {
    throw error;
  }
}

async function updatePurchase(
  adminClient: ReturnType<typeof createClient>,
  purchaseId: string,
  values: Record<string, unknown>,
) {
  const { error } = await adminClient
    .from("purchases")
    .update({ ...values, updated_at: new Date().toISOString() })
    .eq("id", purchaseId);
  if (error) throw error;
}

async function updateCustomer(
  adminClient: ReturnType<typeof createClient>,
  customerId: string,
  values: Record<string, unknown>,
) {
  const { error } = await adminClient.from("customers").update(values).eq("id", customerId);
  if (error) throw error;
}

async function sendMissingEmails(
  adminClient: ReturnType<typeof createClient>,
  purchase: PurchaseRow,
  customer: CustomerRow,
  accessLink: string,
  manualReview = false,
  reason = "",
) {
  let latestPurchase = purchase;
  const latestCustomer = customer;
  const now = new Date().toISOString();

  if (!manualReview && !latestPurchase.buyer_confirmation_sent_at) {
    const confirmation = await sendResendEmail(
      latestPurchase.email,
      "Your SLS Vault purchase is confirmed",
      buyerConfirmationHtml(latestPurchase.email, latestPurchase.stripe_price_id, latestPurchase.amount_paid),
    );

    if (confirmation.ok) {
      await updatePurchase(adminClient, latestPurchase.id, { buyer_confirmation_sent_at: now, last_error: null });
      await updateCustomer(adminClient, latestCustomer.id, {
        confirmation_email_sent_at: now,
        last_email_error: null,
      });
      latestPurchase = { ...latestPurchase, buyer_confirmation_sent_at: now, last_error: null };
    } else {
      const error = confirmation.error ?? "Unknown error";
      await updatePurchase(adminClient, latestPurchase.id, { last_error: error });
      await updateCustomer(adminClient, latestCustomer.id, { last_email_error: error });
    }
  }

  if (!manualReview && !latestPurchase.buyer_access_sent_at) {
    const access = await sendResendEmail(
      latestPurchase.email,
      "Your SLS Vault access is ready",
      buyerAccessHtml(latestPurchase.email, accessLink),
    );

    if (access.ok) {
      await updatePurchase(adminClient, latestPurchase.id, { buyer_access_sent_at: now, last_error: null });
      await updateCustomer(adminClient, latestCustomer.id, { last_email_error: null });
      latestPurchase = { ...latestPurchase, buyer_access_sent_at: now, last_error: null };
    } else {
      const error = access.error ?? "Unknown error";
      await updatePurchase(adminClient, latestPurchase.id, { last_error: error });
      await updateCustomer(adminClient, latestCustomer.id, { last_email_error: error });
    }
  }

  if (!latestPurchase.admin_notified_at) {
    const subject = manualReview
      ? `Manual review needed: ${latestPurchase.email}`
      : `New SLS Vault purchase: ${latestPurchase.email}`;
    const html = manualReview
      ? manualReviewHtml(latestPurchase.email, reason, latestPurchase.stripe_session_id, latestPurchase.id)
      : adminSuccessHtml(latestPurchase.email, latestPurchase.amount_paid, latestPurchase.stripe_price_id, latestPurchase.stripe_session_id);

    const adminNotification = await sendResendEmail(SUPPORT_EMAIL, subject, html);
    if (adminNotification.ok) {
      await updatePurchase(adminClient, latestPurchase.id, { admin_notified_at: now });
      await updateCustomer(adminClient, latestCustomer.id, { admin_notified_at: now });
      latestPurchase = { ...latestPurchase, admin_notified_at: now };
    }
  }

  return { purchase: latestPurchase, customer: latestCustomer };
}

async function processPurchaseSession(
  adminClient: ReturnType<typeof createClient>,
  stripeSecretKey: string,
  sessionId: string,
  force = false,
) {
  const existingPurchase = await fetchPurchase(adminClient, sessionId);
  if (existingPurchase?.fulfillment_status === "fulfilled" && !force) {
    const existingCustomer = await fetchCustomer(adminClient, existingPurchase.email);
    if (existingCustomer) {
      const access = await buildAccessLink(adminClient, existingPurchase.email);
      await sendMissingEmails(adminClient, existingPurchase, existingCustomer, access.link, false);
    }

    return {
      success: true,
      status: "already_processed" as PurchaseResultStatus,
      email: existingPurchase.email,
      courseKey: existingPurchase.course_key,
      alreadyProcessed: true,
      referenceCode: referenceCode(sessionId, existingPurchase.id),
    };
  }

  const session = await fetchStripeSession(stripeSecretKey, sessionId);
  const paymentStatus = session?.payment_status ?? "unpaid";
  if (paymentStatus !== "paid") {
    const status = paymentStatus === "unpaid" ? "invalid_session" : "processing";
    return {
      success: false,
      status: status as PurchaseResultStatus,
      error: "Payment has not been completed yet.",
      referenceCode: referenceCode(sessionId, existingPurchase?.id ?? null),
    };
  }

  const checkoutEmail = await resolveStripeCustomerEmail(stripeSecretKey, session);
  if (!checkoutEmail) {
    return {
      success: true,
      status: "manual_review" as PurchaseResultStatus,
      error: "No customer email was found on the Stripe session.",
      referenceCode: referenceCode(sessionId, existingPurchase?.id ?? null),
      recoveryMessage: "Payment was confirmed, but the Stripe session did not include a usable email address.",
    };
  }

  const priceInfo = extractPriceInfo(session);
  if ("error" in priceInfo) {
    const reason = priceInfo.error;
    const purchaseId = existingPurchase?.id ?? null;
    const customerRecord = await persistCustomer(adminClient, {
      email: checkoutEmail,
      stripe_customer_id: typeof session?.customer === "string" ? session.customer : session?.customer?.id ?? null,
      stripe_session_id: sessionId,
      course_access: false,
      fulfillment_status: "manual_review",
      purchased_at: new Date().toISOString(),
      amount_paid: session?.amount_total ?? null,
      plan_type: null,
    });

    const purchase = await persistPurchase(adminClient, {
      stripe_session_id: sessionId,
      stripe_customer_id: typeof session?.customer === "string" ? session.customer : session?.customer?.id ?? null,
      customer_id: customerRecord.id,
      email: checkoutEmail,
      course_key: COURSE_KEY,
      stripe_price_id: null,
      stripe_product_id: null,
      amount_paid: session?.amount_total ?? null,
      currency: session?.currency ?? null,
      payment_status: paymentStatus,
      fulfillment_status: "manual_review",
      session_payload: session,
      processed_at: null,
      manual_review_reason: reason,
      last_error: reason,
      buyer_confirmation_sent_at: null,
      buyer_access_sent_at: null,
      admin_notified_at: null,
    });

    await sendMissingEmails(adminClient, purchase, customerRecord, `${SITE_URL}/login?email=${encodeURIComponent(checkoutEmail)}`, true, reason);

    return {
      success: true,
      status: "manual_review" as PurchaseResultStatus,
      email: checkoutEmail,
      courseKey: COURSE_KEY,
      referenceCode: referenceCode(sessionId, purchaseId ?? purchase.id),
      recoveryMessage: reason,
    };
  }

  const courseKey = COURSE_KEY;
  const now = new Date().toISOString();
  const stripeCustomerId = typeof session?.customer === "string" ? session.customer : session?.customer?.id ?? null;

  const customerRecord = await persistCustomer(adminClient, {
    email: checkoutEmail,
    stripe_customer_id: stripeCustomerId,
    stripe_session_id: sessionId,
    course_access: true,
    fulfillment_status: "processing",
    purchased_at: now,
    amount_paid: session?.amount_total ?? null,
    plan_type: priceInfo.priceId === EARLY_BIRD_PRICE_ID ? "early_bird" : "regular",
  });

  const purchase = await persistPurchase(adminClient, {
    stripe_session_id: sessionId,
    stripe_customer_id: stripeCustomerId,
    customer_id: customerRecord.id,
    email: checkoutEmail,
    course_key: courseKey,
    stripe_price_id: priceInfo.priceId,
    stripe_product_id: priceInfo.productId,
    amount_paid: priceInfo.amountPaid ?? session?.amount_total ?? null,
    currency: priceInfo.currency ?? session?.currency ?? null,
    payment_status: paymentStatus,
    fulfillment_status: "processing",
    session_payload: session,
    processed_at: null,
    manual_review_reason: null,
    last_error: null,
    buyer_confirmation_sent_at: existingPurchase?.buyer_confirmation_sent_at ?? null,
    buyer_access_sent_at: existingPurchase?.buyer_access_sent_at ?? null,
    admin_notified_at: existingPurchase?.admin_notified_at ?? null,
  });

  try {
    await persistGrant(adminClient, customerRecord.id, purchase.id);

    const access = await buildAccessLink(adminClient, checkoutEmail);
    const accessLink = access.link;

    await updatePurchase(adminClient, purchase.id, {
      fulfillment_status: "fulfilled",
      processed_at: now,
      last_error: access.error,
    });

    await updateCustomer(adminClient, customerRecord.id, {
      course_access: true,
      fulfillment_status: "fulfilled",
      purchased_at: now,
      stripe_customer_id: stripeCustomerId,
      stripe_session_id: sessionId,
      last_email_error: access.error,
    });

    const hydratedPurchase = {
      ...purchase,
      fulfillment_status: "fulfilled",
      processed_at: now,
      last_error: access.error,
    };

    const hydratedCustomer = {
      ...customerRecord,
      course_access: true,
      fulfillment_status: "fulfilled",
      purchased_at: now,
      stripe_customer_id: stripeCustomerId,
      stripe_session_id: sessionId,
      last_email_error: access.error,
    };

    const emailed = await sendMissingEmails(
      adminClient,
      hydratedPurchase,
      hydratedCustomer,
      accessLink,
      false,
    );

    return {
      success: true,
      status: "fulfilled" as PurchaseResultStatus,
      email: checkoutEmail,
      courseKey,
      referenceCode: referenceCode(sessionId, purchase.id),
      purchaseId: emailed.purchase.id,
    };
  } catch (error) {
    const reason = error instanceof Error ? error.message : String(error);

    await updatePurchase(adminClient, purchase.id, {
      fulfillment_status: "manual_review",
      manual_review_reason: reason,
      last_error: reason,
    }).catch(() => {});

    await updateCustomer(adminClient, customerRecord.id, {
      course_access: true,
      fulfillment_status: "manual_review",
      last_email_error: reason,
    }).catch(() => {});

    const manualReviewPurchase = {
      ...purchase,
      fulfillment_status: "manual_review",
      manual_review_reason: reason,
      last_error: reason,
    };

    await sendMissingEmails(
      adminClient,
      manualReviewPurchase,
      {
        ...customerRecord,
        course_access: true,
        fulfillment_status: "manual_review",
        last_email_error: reason,
      },
      `${SITE_URL}/login?email=${encodeURIComponent(checkoutEmail)}`,
      true,
      reason,
    );

    return {
      success: true,
      status: "manual_review" as PurchaseResultStatus,
      email: checkoutEmail,
      courseKey,
      referenceCode: referenceCode(sessionId, purchase.id),
      recoveryMessage: reason,
    };
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const sessionId = typeof body?.sessionId === "string" ? body.sessionId.trim() : "";
    const force = Boolean(body?.force);
    const invalidSessionPlaceholder =
      sessionId === "{CHECKOUT_SESSION_ID}" ||
      sessionId === "%7BCHECKOUT_SESSION_ID%7D" ||
      sessionId === "CHECKOUT_SESSION_ID";

    if (!sessionId || invalidSessionPlaceholder || !sessionId.startsWith("cs_")) {
      return jsonResponse({ success: false, status: "invalid_session", error: "Missing session ID" }, 400);
    }

    const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY");
    if (!stripeSecretKey) {
      return jsonResponse({
        success: false,
        status: "config_error",
        error: "Payment verification is not configured yet.",
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !supabaseServiceKey) {
      return jsonResponse({
        success: false,
        status: "config_error",
        error: "Supabase service credentials are missing.",
      });
    }

    const adminClient = createClient(supabaseUrl, supabaseServiceKey);
    const result = await processPurchaseSession(adminClient, stripeSecretKey, sessionId, force);
    return jsonResponse(result);
  } catch (error) {
    console.error("verify-purchase error:", error);
    return jsonResponse(
      {
        success: false,
        status: "manual_review",
        error: "Internal server error",
      },
      500,
    );
  }
});
