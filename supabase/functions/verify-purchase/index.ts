import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const BASE_URL = "https://slscourse.lovable.app";

async function sendResendEmail(
  to: string,
  subject: string,
  html: string,
): Promise<{ ok: boolean; error?: string }> {
  const apiKey = Deno.env.get("RESEND_API");
  const from = Deno.env.get("RESEND_FROM_EMAIL") ?? "noreply@mail.sheaslegacyscalping.com";

  if (!apiKey) {
    console.error("RESEND_API not configured — skipping email");
    return { ok: false, error: "RESEND_API not configured" };
  }

  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ from, to: [to], subject, html }),
    });

    if (!res.ok) {
      const errText = await res.text();
      console.error("Resend error:", res.status, errText);
      return { ok: false, error: `Resend ${res.status}: ${errText}` };
    }

    return { ok: true };
  } catch (err) {
    console.error("Resend fetch error:", err);
    return { ok: false, error: String(err) };
  }
}

function buyerConfirmationHtml(email: string, planType: string): string {
  const planLabel = planType === "early_bird" ? "Early Bird ($149)" : "Regular ($199)";
  return `
<!DOCTYPE html>
<html><head><meta charset="utf-8"></head>
<body style="font-family:Arial,sans-serif;background:#ffffff;color:#1a1a1a;max-width:560px;margin:0 auto;padding:40px 20px;">
  <h1 style="font-size:24px;margin-bottom:8px;">You're in! 🎉</h1>
  <p style="font-size:16px;line-height:1.6;color:#555;">
    Your purchase of the <strong>SLS Trading Course</strong> (${planLabel}) is confirmed.
    Your course access is now live.
  </p>
  <p style="font-size:16px;line-height:1.6;color:#555;">
    We've sent a separate magic login link to <strong>${email}</strong>.
    Click it to sign in and start learning — no password needed.
  </p>
  <a href="${BASE_URL}/login" style="display:inline-block;background:#c8a962;color:#fff;text-decoration:none;padding:14px 28px;border-radius:6px;font-weight:600;font-size:16px;margin:16px 0;">
    Go to Login
  </a>
  <p style="font-size:14px;color:#888;margin-top:24px;">
    If you don't see the login link email, check your spam folder or request a new one from the login page.
  </p>
  <p style="font-size:13px;color:#aaa;margin-top:32px;">
    Questions? Reply to this email or contact <a href="mailto:sls25trading@gmail.com" style="color:#c8a962;">sls25trading@gmail.com</a>
  </p>
</body></html>`;
}

function adminNotificationHtml(email: string, planType: string, amount: number): string {
  const planLabel = planType === "early_bird" ? "Early Bird" : "Regular";
  const dollars = (amount / 100).toFixed(2);
  return `
<!DOCTYPE html>
<html><head><meta charset="utf-8"></head>
<body style="font-family:Arial,sans-serif;background:#ffffff;color:#1a1a1a;max-width:560px;margin:0 auto;padding:40px 20px;">
  <h1 style="font-size:22px;margin-bottom:8px;">New Course Purchase 💰</h1>
  <table style="font-size:15px;line-height:1.8;color:#555;">
    <tr><td style="padding-right:16px;font-weight:600;">Customer</td><td>${email}</td></tr>
    <tr><td style="padding-right:16px;font-weight:600;">Plan</td><td>${planLabel}</td></tr>
    <tr><td style="padding-right:16px;font-weight:600;">Amount</td><td>$${dollars}</td></tr>
    <tr><td style="padding-right:16px;font-weight:600;">Time</td><td>${new Date().toISOString()}</td></tr>
  </table>
  <a href="${BASE_URL}/admin" style="display:inline-block;background:#c8a962;color:#fff;text-decoration:none;padding:12px 24px;border-radius:6px;font-weight:600;font-size:14px;margin:20px 0;">
    View Admin Dashboard
  </a>
</body></html>`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { sessionId } = await req.json();
    if (!sessionId || typeof sessionId !== "string") {
      return new Response(
        JSON.stringify({ success: false, error: "Missing session ID" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY");
    if (!stripeSecretKey) {
      console.error("STRIPE_SECRET_KEY not configured");
      return new Response(
        JSON.stringify({
          success: false,
          status: "pending",
          error: "Payment verification is being configured. Your purchase is safe — we'll confirm it shortly.",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    // Idempotency check — already fulfilled this session?
    const { data: existing } = await adminClient
      .from("customers")
      .select("id, email, course_access, fulfillment_status, confirmation_email_sent_at, admin_notified_at")
      .eq("stripe_session_id", sessionId)
      .maybeSingle();

    if (existing?.fulfillment_status === "fulfilled") {
      return new Response(
        JSON.stringify({
          success: true,
          status: "fulfilled",
          email: existing.email,
          alreadyFulfilled: true,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Verify with Stripe
    const stripeRes = await fetch(
      `https://api.stripe.com/v1/checkout/sessions/${sessionId}`,
      { headers: { Authorization: `Bearer ${stripeSecretKey}` } }
    );

    if (!stripeRes.ok) {
      const errBody = await stripeRes.text();
      console.error("Stripe API error:", stripeRes.status, errBody);
      return new Response(
        JSON.stringify({ success: false, status: "invalid", error: "Could not verify this payment session." }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const session = await stripeRes.json();

    if (session.payment_status !== "paid") {
      return new Response(
        JSON.stringify({
          success: false,
          status: "unpaid",
          error: "Payment has not been completed yet.",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const customerEmail = session.customer_details?.email?.toLowerCase();
    if (!customerEmail) {
      return new Response(
        JSON.stringify({
          success: false,
          status: "no_email",
          error: "No email found in the payment session. Please contact support.",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Determine plan type from amount
    const amountPaid = session.amount_total; // in cents
    let planType = "unknown";
    if (amountPaid === 14900) planType = "early_bird";
    else if (amountPaid === 19900) planType = "regular";
    else planType = `custom_${amountPaid}`;

    // Upsert customer with fulfillment
    const { error: upsertError } = await adminClient.from("customers").upsert(
      {
        email: customerEmail,
        stripe_customer_id: session.customer ?? null,
        stripe_session_id: sessionId,
        course_access: true,
        fulfillment_status: "fulfilled",
        purchased_at: new Date().toISOString(),
        amount_paid: amountPaid,
        plan_type: planType,
      },
      { onConflict: "email" }
    );

    if (upsertError) {
      console.error("Fulfillment upsert error:", upsertError);
      return new Response(
        JSON.stringify({
          success: true,
          status: "verified_pending_db",
          email: customerEmail,
          error: "Payment verified but account setup encountered an issue. Please contact support if you can't access the course.",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Send magic link so they can log in immediately (Supabase auth handles this email)
    try {
      await adminClient.auth.admin.inviteUserByEmail(customerEmail, {
        redirectTo: `${BASE_URL}/portal`,
      });
    } catch (emailErr) {
      console.error("Magic link email failed:", emailErr);
    }

    // --- Resend transactional emails (idempotent: only send if not already sent) ---
    // Re-fetch the customer to get current email tracking state
    const { data: customer } = await adminClient
      .from("customers")
      .select("id, confirmation_email_sent_at, admin_notified_at")
      .eq("email", customerEmail)
      .maybeSingle();

    // Buyer confirmation email
    if (customer && !customer.confirmation_email_sent_at) {
      const result = await sendResendEmail(
        customerEmail,
        "Your SLS Trading Course Access is Live! 🎉",
        buyerConfirmationHtml(customerEmail, planType),
      );
      if (result.ok) {
        await adminClient
          .from("customers")
          .update({ confirmation_email_sent_at: new Date().toISOString(), last_email_error: null })
          .eq("id", customer.id);
      } else {
        await adminClient
          .from("customers")
          .update({ last_email_error: result.error ?? "Unknown error" })
          .eq("id", customer.id);
      }
    }

    // Admin notification email
    const adminEmail = Deno.env.get("RESEND_ADMIN_EMAIL") ?? "donovinsims@gmail.com";
    if (customer && !customer.admin_notified_at) {
      const result = await sendResendEmail(
        adminEmail,
        `New Purchase: ${customerEmail} — SLS Trading`,
        adminNotificationHtml(customerEmail, planType, amountPaid),
      );
      if (result.ok) {
        await adminClient
          .from("customers")
          .update({ admin_notified_at: new Date().toISOString() })
          .eq("id", customer.id);
      } else {
        console.error("Admin notification failed:", result.error);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        status: "fulfilled",
        email: customerEmail,
        planType,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("verify-purchase error:", err);
    return new Response(
      JSON.stringify({ success: false, status: "error", error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
