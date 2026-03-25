import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SITE_URL = Deno.env.get("SITE_URL") ?? "https://www.sheaslegacyscalping.com";
const SUPPORT_EMAIL = Deno.env.get("RESEND_ADMIN_EMAIL") ?? "donovinsims@gmail.com";
const FROM_EMAIL = Deno.env.get("RESEND_FROM_EMAIL") ?? "noreply@mail.sheaslegacyscalping.com";
const COURSE_KEY = "sls-vault";
const ADMIN_EMAILS = ["sls25trading@gmail.com", "emaildonovin@gmail.com"];
const SUPABASE_PUBLISHABLE_KEY =
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
  "sb_publishable_iCEc7SfJu9uWX6p9n6Gmbg_cuQ2V-BI";

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function normalizeEmail(email: string | null | undefined) {
  return email?.trim().toLowerCase() ?? "";
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

async function buildAccessLink(adminClient: ReturnType<typeof createClient>, email: string) {
  const { data, error } = await adminClient.auth.admin.generateLink({
    type: "magiclink",
    email,
    options: { redirectTo: `${SITE_URL}/portal` },
  });

  if (error) {
    return { link: `${SITE_URL}/login?email=${encodeURIComponent(email)}`, error: error.message };
  }

  return {
    link:
      data?.properties?.action_link ??
      data?.action_link ??
      `${SITE_URL}/login?email=${encodeURIComponent(email)}`,
    error: null,
  };
}

function accessEmailHtml(email: string, link: string, label: string) {
  return `
<!DOCTYPE html>
<html><head><meta charset="utf-8"></head>
<body style="font-family:Arial,sans-serif;background:#ffffff;color:#1a1a1a;max-width:560px;margin:0 auto;padding:40px 20px;">
  <h1 style="font-size:24px;margin-bottom:8px;">${label}</h1>
  <p style="font-size:16px;line-height:1.6;color:#555;">
    Open your course access for <strong>${email}</strong> with the button below.
  </p>
  <a href="${link}" style="display:inline-block;background:#c8a962;color:#fff;text-decoration:none;padding:14px 28px;border-radius:6px;font-weight:600;font-size:16px;margin:16px 0;">
    Open Course Access
  </a>
  <p style="font-size:14px;color:#888;margin-top:24px;">
    If the button does not work, use the login page at <a href="${SITE_URL}/login" style="color:#c8a962;">${SITE_URL}/login</a>.
  </p>
  <p style="font-size:13px;color:#aaa;margin-top:32px;">
    Support: <a href="mailto:${SUPPORT_EMAIL}" style="color:#c8a962;">${SUPPORT_EMAIL}</a>
  </p>
</body></html>`;
}

async function authGuard(req: Request, supabaseUrl: string, supabasePublishableKey: string) {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return { user: null, error: "Unauthorized" };
  }

  const authResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      Authorization: authHeader,
      apikey: supabasePublishableKey,
    },
  });
  const authPayload = authResponse.ok ? await authResponse.json() : null;
  const user = authPayload && typeof authPayload === "object" && "email" in authPayload ? authPayload : null;

  if (!authResponse.ok || !user?.email || !ADMIN_EMAILS.includes(user.email.toLowerCase())) {
    return { user: null, error: "Forbidden" };
  }

  return { user, error: null };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !supabaseServiceKey) {
      return jsonResponse({ error: "Supabase credentials are missing" }, 500);
    }

    const adminClient = createClient(supabaseUrl, supabaseServiceKey);
    const body = await req.json().catch(() => ({}));
    const action = body?.action;

    if (action === "register") {
      const email = normalizeEmail(body?.email);
      if (!email) {
        return jsonResponse({ error: "Missing email" }, 400);
      }

      const { error } = await adminClient.from("customers").upsert(
        {
          email,
          course_access: false,
          fulfillment_status: "processing",
          purchased_at: new Date().toISOString(),
        },
        { onConflict: "email" },
      );

      if (error) {
        return jsonResponse({ error: "Failed to register" }, 500);
      }

      return jsonResponse({ success: true });
    }

    const auth = await authGuard(req, supabaseUrl, SUPABASE_PUBLISHABLE_KEY);
    if (auth.error) {
      return jsonResponse({ error: auth.error }, auth.error === "Unauthorized" ? 401 : 403);
    }

    if (action === "list") {
      const [{ data: customers, error: customerError }, { data: purchases, error: purchaseError }] =
        await Promise.all([
          adminClient
            .from("customers")
            .select("id, email, course_access, fulfillment_status, purchased_at, stripe_session_id, confirmation_email_sent_at, admin_notified_at")
            .order("purchased_at", { ascending: false, nullsFirst: false }),
          adminClient
            .from("purchases")
            .select("id, stripe_session_id, stripe_customer_id, customer_id, email, course_key, stripe_price_id, stripe_product_id, amount_paid, currency, payment_status, fulfillment_status, processed_at, buyer_confirmation_sent_at, buyer_access_sent_at, admin_notified_at, manual_review_reason, last_error, created_at")
            .order("created_at", { ascending: false }),
        ]);

      if (customerError) throw customerError;
      if (purchaseError) throw purchaseError;

      const exceptions = (purchases ?? []).filter((purchase) => purchase.fulfillment_status !== "fulfilled");
      return jsonResponse({ customers: customers ?? [], purchases: purchases ?? [], exceptions });
    }

    if (action === "grant") {
      const email = normalizeEmail(body?.email);
      const customerId = body?.customerId as string | undefined;
      if (!email || !customerId) {
        return jsonResponse({ error: "Missing customerId or email" }, 400);
      }

      const { error: customerError } = await adminClient
        .from("customers")
        .update({
          course_access: true,
          fulfillment_status: "fulfilled",
          purchased_at: new Date().toISOString(),
        })
        .eq("id", customerId);

      if (customerError) throw customerError;

      const { error: grantError } = await adminClient.from("course_access_grants").upsert(
        {
          customer_id: customerId,
          course_key: COURSE_KEY,
          source_purchase_id: null,
          revoked_at: null,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "customer_id,course_key" },
      );

      if (grantError) throw grantError;

      const access = await buildAccessLink(adminClient, email);
      const emailResult = await sendResendEmail(
        email,
        "Your SLS Vault access is ready",
        accessEmailHtml(email, access.link, "Your access is ready"),
      );

      return jsonResponse({
        success: true,
        accessLink: access.link,
        emailSent: emailResult.ok,
        emailError: emailResult.ok ? null : emailResult.error,
      });
    }

    if (action === "rerun") {
      const purchaseId = typeof body?.purchaseId === "string" ? body.purchaseId : "";
      const bodySessionId = typeof body?.sessionId === "string" ? body.sessionId : "";
      let sessionId = bodySessionId;

      if (!sessionId && purchaseId) {
        const { data } = await adminClient
          .from("purchases")
          .select("stripe_session_id")
          .eq("id", purchaseId)
          .maybeSingle();
        sessionId = data?.stripe_session_id ?? "";
      }

      if (!sessionId) {
        return jsonResponse({ error: "Missing purchaseId or sessionId" }, 400);
      }

      const response = await fetch(`${supabaseUrl}/functions/v1/verify-purchase`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${supabaseServiceKey}`,
          apikey: supabaseServiceKey,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ sessionId, force: true }),
      });

      const result = await response.json().catch(() => ({}));
      if (!response.ok) {
        return jsonResponse({ error: result?.error ?? "Rerun failed" }, response.status);
      }

      return jsonResponse({ success: true, result });
    }

    if (action === "reseed") {
      const videos = body?.videos;
      if (!Array.isArray(videos) || videos.length === 0) {
        return jsonResponse({ error: "Missing videos array" }, 400);
      }

      const { error: cleanupError } = await adminClient
        .from("videos")
        .delete()
        .eq("sort_order", 0);

      if (cleanupError) {
        throw cleanupError;
      }

      for (const video of videos) {
        const { error } = await adminClient.from("videos").upsert(
          {
            title: video.title,
            module: video.module,
            youtube_id: video.youtube_id,
            sort_order: video.sort_order,
          },
          { onConflict: "sort_order" },
        );

        if (error) {
          console.error("Reseed upsert error:", error);
        }
      }

      return jsonResponse({ success: true, count: videos.length });
    }

    return jsonResponse({ error: "Unknown action" }, 400);
  } catch (error) {
    console.error(error);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});
