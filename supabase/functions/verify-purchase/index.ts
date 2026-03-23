import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { sessionId } = await req.json();
    if (!sessionId) {
      return new Response(
        JSON.stringify({ success: false, error: "Missing session ID" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY");
    if (!stripeSecretKey) {
      console.error("STRIPE_SECRET_KEY not configured");
      return new Response(
        JSON.stringify({ success: false, error: "Payment verification is not configured yet. Please contact support." }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Verify with Stripe
    const stripeRes = await fetch(
      `https://api.stripe.com/v1/checkout/sessions/${sessionId}`,
      {
        headers: {
          Authorization: `Bearer ${stripeSecretKey}`,
        },
      }
    );

    if (!stripeRes.ok) {
      return new Response(
        JSON.stringify({ success: false, error: "Invalid session ID" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const session = await stripeRes.json();

    if (session.payment_status !== "paid") {
      return new Response(
        JSON.stringify({ success: false, error: "Payment not completed" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const customerEmail = session.customer_details?.email;
    if (!customerEmail) {
      return new Response(
        JSON.stringify({ success: false, error: "No email found in session" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Upsert customer
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    await adminClient.from("customers").upsert(
      {
        email: customerEmail.toLowerCase(),
        stripe_customer_id: session.customer ?? null,
        course_access: true,
        purchased_at: new Date().toISOString(),
      },
      { onConflict: "email" }
    );

    // Send magic link via Supabase Auth (uses built-in email)
    const baseUrl = Deno.env.get("BASE_URL") ?? req.headers.get("origin") ?? "";
    await adminClient.auth.admin.inviteUserByEmail(customerEmail.toLowerCase(), {
      redirectTo: `${baseUrl}/portal`,
    });

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error(err);
    return new Response(
      JSON.stringify({ success: false, error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
