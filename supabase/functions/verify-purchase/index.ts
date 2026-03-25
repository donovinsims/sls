import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

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
      .select("id, email, course_access, fulfillment_status")
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
      // Even if DB write fails, we verified payment — don't lose the customer
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

    // Send magic link so they can log in immediately
    const baseUrl = Deno.env.get("BASE_URL") ?? req.headers.get("origin") ?? "";
    try {
      await adminClient.auth.admin.inviteUserByEmail(customerEmail, {
        redirectTo: `${baseUrl}/portal`,
      });
    } catch (emailErr) {
      // Access is granted even if email fails — log it
      console.error("Magic link email failed:", emailErr);
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
