import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { FALLBACK_VIDEO_CONTENT_BY_SORT_ORDER } from "../_shared/fallbackVideoContent.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const ADMIN_EMAILS = ["sls25trading@gmail.com", "emaildonovin@gmail.com"];

const logTelemetryFailure = (step: string, error: unknown) => {
  console.error(`get-video telemetry failed during ${step}:`, error);
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabaseAnon = Deno.env.get("SUPABASE_ANON_KEY")!;

    const userClient = createClient(supabaseUrl, supabaseAnon, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authError } = await userClient.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { videoId, fingerprint } = await req.json();
    if (!videoId) {
      return new Response(JSON.stringify({ error: "Missing videoId" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const adminClient = createClient(supabaseUrl, supabaseServiceKey);
    const email = user.email?.toLowerCase() ?? "";
    const isAdmin = ADMIN_EMAILS.includes(email);

    if (!isAdmin) {
      const { data: customer } = await adminClient
        .from("customers")
        .select("id, course_access")
        .eq("email", email)
        .maybeSingle();

      if (!customer?.course_access) {
        return new Response(JSON.stringify({ error: "No course access" }), {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    let customerId: string;
    if (isAdmin) {
      const { data: cust } = await adminClient
        .from("customers")
        .upsert({ email, course_access: true }, { onConflict: "email" })
        .select("id")
        .single();
      customerId = cust!.id;
    } else {
      const { data: cust } = await adminClient
        .from("customers")
        .select("id")
        .eq("email", email)
        .single();
      customerId = cust!.id;
    }

    // Fetch video including transcript and summary
    const { data: video, error: videoError } = await adminClient
      .from("videos")
      .select("id, title, description, youtube_id, transcript, summary, sort_order")
      .eq("id", videoId)
      .single();

    if (videoError || !video) {
      return new Response(JSON.stringify({ error: "Video not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
    const now = new Date();
    const expiresAt = new Date(now.getTime() + 90 * 60 * 1000);

    try {
      const { error: closeSessionsError } = await adminClient
        .from("video_sessions")
        .update({ used: true })
        .eq("customer_id", customerId)
        .eq("video_id", videoId)
        .eq("used", false);

      if (closeSessionsError) {
        logTelemetryFailure("closing prior sessions", closeSessionsError);
      }

      const { error: createSessionError } = await adminClient.from("video_sessions").insert({
        customer_id: customerId,
        video_id: videoId,
        session_token: crypto.randomUUID(),
        ip_address: ip,
        device_fingerprint: fingerprint ?? null,
        expires_at: expiresAt.toISOString(),
      });

      if (createSessionError) {
        logTelemetryFailure("creating session", createSessionError);
      }

      const { error: watchLogError } = await adminClient.from("activity_log").insert({
        customer_id: customerId,
        video_id: videoId,
        ip_address: ip,
        event_type: "watch",
      });

      if (watchLogError) {
        logTelemetryFailure("recording watch event", watchLogError);
      }

      if (fingerprint) {
        const { data: activeSessions, error: activeSessionsError } = await adminClient
          .from("video_sessions")
          .select("device_fingerprint")
          .eq("customer_id", customerId)
          .eq("used", false)
          .gt("expires_at", now.toISOString());

        if (activeSessionsError) {
          logTelemetryFailure("loading active sessions", activeSessionsError);
        } else {
          const distinctFingerprints = new Set(
            (activeSessions ?? []).map((s) => s.device_fingerprint).filter(Boolean)
          );

          if (distinctFingerprints.size >= 2) {
            const { error: sharingFlagError } = await adminClient.from("activity_log").insert({
              customer_id: customerId,
              video_id: videoId,
              ip_address: ip,
              event_type: "suspicious_sharing",
            });

            if (sharingFlagError) {
              logTelemetryFailure("recording suspicious sharing", sharingFlagError);
            }
          }
        }
      }

      const twentyFourHoursAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
      const { data: recentLogs, error: recentLogsError } = await adminClient
        .from("activity_log")
        .select("ip_address")
        .eq("customer_id", customerId)
        .eq("event_type", "watch")
        .gte("watched_at", twentyFourHoursAgo.toISOString());

      if (recentLogsError) {
        logTelemetryFailure("loading recent logs", recentLogsError);
      } else {
        const distinctIPs = new Set((recentLogs ?? []).map((l) => l.ip_address).filter(Boolean));
        if (distinctIPs.size >= 3) {
          const { error: ipFlagError } = await adminClient.from("activity_log").insert({
            customer_id: customerId,
            video_id: videoId,
            ip_address: ip,
            event_type: "ip_flag",
          });

          if (ipFlagError) {
            logTelemetryFailure("recording ip flag", ipFlagError);
          }
        }
      }
    } catch (telemetryError) {
      logTelemetryFailure("unexpected telemetry block", telemetryError);
    }

    const fallbackContent = FALLBACK_VIDEO_CONTENT_BY_SORT_ORDER[video.sort_order as keyof typeof FALLBACK_VIDEO_CONTENT_BY_SORT_ORDER];
    const transcript = video.transcript?.trim() || fallbackContent?.transcript || "";
    const summary = video.summary?.trim() || fallbackContent?.summary || "";
    const embedUrl = `https://www.youtube.com/embed/${video.youtube_id}?rel=0&modestbranding=1`;

    return new Response(
      JSON.stringify({
        embedUrl,
        title: video.title,
        description: video.description,
        transcript,
        summary,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    console.error(err);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
