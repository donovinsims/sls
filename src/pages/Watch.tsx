import { useEffect, useState, useRef } from "react";
import { useParams, useNavigate, Link } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/contexts/AuthContext";
import { Button } from "@/components/ui/button";
import { toast } from "sonner";
import type { Database } from "@/integrations/supabase/types";

const ADMIN_EMAILS = ["sls25trading@gmail.com", "emaildonovin@gmail.com"];
const SUPPORT_EMAIL = "sls25trading@gmail.com";
const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL;
const SUPABASE_PUBLISHABLE_KEY = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;

type VideoProgressRow = Database["public"]["Tables"]["video_progress"]["Row"];
type GetVideoResponse = {
  embedUrl?: string;
  title?: string;
  description?: string;
  transcript?: string;
  summary?: string;
  error?: string;
};

const parseFunctionPayload = async (response?: Response): Promise<GetVideoResponse | null> => {
  const contentType = response?.headers.get("content-type") ?? "";
  if (!response || !contentType.includes("application/json")) return null;

  try {
    return (await response.clone().json()) as GetVideoResponse;
  } catch {
    return null;
  }
};

const getWatchErrorMessage = (payload: GetVideoResponse | null, status?: number) => {
  const backendError = payload?.error?.toLowerCase() ?? "";

  if (status === 401 || backendError.includes("unauthorized")) {
    return "Your session expired. Please sign in again.";
  }

  if (status === 403 || backendError.includes("no course access")) {
    return "No active purchase found.";
  }

  if (status === 404 || backendError.includes("video not found")) {
    return "This lesson could not be found.";
  }

  return "Playback is temporarily unavailable. Please try again.";
};

const Watch = () => {
  const { videoId } = useParams<{ videoId: string }>();
  const { user, session, loading } = useAuth();
  const navigate = useNavigate();
  const [embedUrl, setEmbedUrl] = useState<string | null>(null);
  const [videoTitle, setVideoTitle] = useState("");
  const [videoDescription, setVideoDescription] = useState("");
  const [transcript, setTranscript] = useState("");
  const [summary, setSummary] = useState("");
  const [loadingVideo, setLoadingVideo] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showTranscript, setShowTranscript] = useState(false);
  const [isCompleted, setIsCompleted] = useState(false);
  const [customerId, setCustomerId] = useState<string | null>(null);
  const transcriptRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!loading && !user) {
      navigate("/login");
    }
  }, [user, loading, navigate]);

  useEffect(() => {
    if (!user || !videoId) return;

    const loadVideo = async () => {
      try {
        const email = user.email?.toLowerCase() ?? "";
        const isAdmin = ADMIN_EMAILS.includes(email);
        let resolvedCustomerId: string | null = null;

        if (!isAdmin) {
          const { data: customer } = await supabase
            .from("customers")
            .select("id, course_access")
            .eq("email", email)
            .maybeSingle();

          if (!customer?.course_access) {
            setError("No active purchase found.");
            setLoadingVideo(false);
            return;
          }
          resolvedCustomerId = customer.id;
          setCustomerId(customer.id);
        } else {
          const { data: customer } = await supabase
            .from("customers")
            .select("id")
            .eq("email", email)
            .maybeSingle();
          if (customer) {
            resolvedCustomerId = customer.id;
            setCustomerId(customer.id);
          }
        }

        const fp = `${navigator.userAgent}|${screen.width}x${screen.height}|${Intl.DateTimeFormat().resolvedOptions().timeZone}`;
        const encoder = new TextEncoder();
        const hashBuffer = await crypto.subtle.digest("SHA-256", encoder.encode(fp));
        const hashArray = Array.from(new Uint8Array(hashBuffer));
        const fingerprint = hashArray.map(b => b.toString(16).padStart(2, "0")).join("");

        if (!session?.access_token) {
          setError("Your session expired. Please sign in again.");
          setLoadingVideo(false);
          return;
        }

        const response = await fetch(`${SUPABASE_URL}/functions/v1/get-video`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            apikey: SUPABASE_PUBLISHABLE_KEY,
          },
          body: JSON.stringify({
            videoId,
            fingerprint,
            accessToken: session.access_token,
          }),
        });
        const payload = await parseFunctionPayload(response);

        if (!response.ok || !payload?.embedUrl) {
          setError(getWatchErrorMessage(payload, response.status));
          console.error(payload ?? { status: response.status });
          setLoadingVideo(false);
          return;
        }

        setEmbedUrl(payload.embedUrl);
        setVideoTitle(payload.title ?? "");
        setVideoDescription(payload.description ?? "");
        setTranscript(payload.transcript ?? "");
        setSummary(payload.summary ?? "");

        // Check if already completed & record progress
        if (resolvedCustomerId) {
          const { data: progress } = await supabase
            .from("video_progress")
            .select("completed")
            .eq("customer_id", resolvedCustomerId)
            .eq("video_id", videoId)
            .maybeSingle();

          if (progress) {
            setIsCompleted(progress.completed ?? false);
          }

          await supabase.from("video_progress").upsert(
            {
              customer_id: resolvedCustomerId,
              video_id: videoId,
              last_watched_at: new Date().toISOString(),
            },
            { onConflict: "customer_id,video_id" }
          );
        }
      } catch (err) {
        console.error(err);
        setError("An unexpected error occurred.");
      }
      setLoadingVideo(false);
    };

    loadVideo();
  }, [session, user, videoId]);

  // Also check progress once customerId resolves (it may resolve after loadVideo in admin case)
  useEffect(() => {
    if (!customerId || !videoId) return;
    const check = async () => {
      const { data: progress } = await supabase
        .from("video_progress")
        .select("completed")
        .eq("customer_id", customerId)
        .eq("video_id", videoId)
        .maybeSingle();
      if (progress) {
        setIsCompleted(progress.completed ?? false);
      }
    };
    check();
  }, [customerId, videoId]);

  const handleMarkComplete = async () => {
    if (!customerId || !videoId) return;
    const newState = !isCompleted;
    const { error } = await supabase.from("video_progress").upsert(
      {
        customer_id: customerId,
        video_id: videoId,
        completed: newState,
        last_watched_at: new Date().toISOString(),
      },
      { onConflict: "customer_id,video_id" }
    );
    if (error) {
      toast.error("Failed to update progress");
      console.error(error);
    } else {
      setIsCompleted(newState);
      toast.success(newState ? "Lesson marked as complete!" : "Marked as incomplete");
    }
  };

  const formatTranscript = (text: string) => {
    if (!text) return [];
    const lines = text.split(/\n{2,}/);
    if (lines.length > 1) return lines.filter(l => l.trim());
    const sentences = text.split(/(?<=[.!?])\s+/);
    const paragraphs: string[] = [];
    for (let i = 0; i < sentences.length; i += 4) {
      paragraphs.push(sentences.slice(i, i + 4).join(" "));
    }
    return paragraphs;
  };

  if (loading || loadingVideo) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background">
        <div className="flex flex-col items-center gap-3">
          <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
          <p className="text-muted-foreground">Loading video...</p>
        </div>
      </div>
    );
  }

  if (error) {
    const recoveryEmail = user?.email ? `/login?email=${encodeURIComponent(user.email)}` : "/login";
    return (
      <div className="flex min-h-screen items-center justify-center bg-background px-4">
        <div className="max-w-md text-center space-y-5 rounded-2xl border border-border bg-card p-8 shadow-md">
          <h1 className="font-display text-2xl font-semibold text-foreground">{error}</h1>
          <p className="text-sm text-muted-foreground">
            If you already purchased, this is usually an email mismatch. Try the email you used at checkout or reach out and we will restore access.
          </p>
          <div className="space-y-3">
            <Button variant="cta" size="lg" className="w-full" asChild>
              <Link to={recoveryEmail}>Try Another Email</Link>
            </Button>
            <Button variant="outline" size="lg" className="w-full" asChild>
              <a href={`mailto:${SUPPORT_EMAIL}`}>Contact Support</a>
            </Button>
            <Link to="/portal" className="inline-block text-sm text-primary underline hover:text-primary/80">
              ← Back to Dashboard
            </Link>
          </div>
        </div>
      </div>
    );
  }

  const transcriptParagraphs = formatTranscript(transcript);

  return (
    <div className="min-h-screen bg-background">
      <header className="border-b border-border bg-card/50 backdrop-blur-sm">
        <div className="mx-auto max-w-5xl px-4 py-4 flex items-center justify-between">
          <Link to="/portal" className="text-sm text-muted-foreground hover:text-foreground transition-colors">
            ← Back to Dashboard
          </Link>
          {customerId && (
            <Button
              variant={isCompleted ? "outline" : "cta"}
              size="sm"
              onClick={handleMarkComplete}
              className="gap-2"
            >
              {isCompleted ? (
                <>
                  <svg className="h-4 w-4 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                  Completed
                </>
              ) : (
                "Mark as Complete"
              )}
            </Button>
          )}
        </div>
      </header>

      <main className="mx-auto max-w-5xl px-4 py-8 space-y-8">
        {/* Video Player */}
        <div className="relative w-full aspect-video overflow-hidden rounded-[28px] border border-border/70 bg-foreground/5 shadow-[0_24px_70px_rgba(15,10,5,0.10)]">
          {embedUrl && (
            <iframe
              src={embedUrl}
              title={videoTitle}
              className="absolute inset-0 w-full h-full"
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
              allowFullScreen
            />
          )}
        </div>

        {/* Title & Summary */}
        <div className="space-y-5">
          <div className="space-y-3">
            <h1 className="font-display text-2xl sm:text-3xl font-semibold text-foreground">
              {videoTitle}
            </h1>
            {videoDescription && (
              <p className="max-w-3xl text-sm leading-7 text-muted-foreground sm:text-base">
                {videoDescription}
              </p>
            )}
          </div>

          {summary && (
            <section className="rounded-[22px] border border-primary/15 bg-card px-5 py-5 shadow-sm sm:px-6 sm:py-6">
              <p className="mb-3 text-[11px] font-semibold uppercase tracking-[0.24em] text-primary/75">
                Quick Summary
              </p>
              <p className="text-sm leading-8 text-foreground/85 sm:text-base">
                {summary}
              </p>
            </section>
          )}
        </div>

        {/* Transcript Section */}
        {transcript && (
          <section className="space-y-4">
            <button
              onClick={() => setShowTranscript(!showTranscript)}
              className="inline-flex items-center gap-2 text-sm font-semibold uppercase tracking-[0.16em] text-muted-foreground transition-colors hover:text-foreground"
            >
              <span
                aria-hidden="true"
                className={`text-xs transition-transform duration-200 ${showTranscript ? "rotate-90" : ""}`}
              >
                ▶
              </span>
              <span>{showTranscript ? "Hide Transcript" : "Show Transcript"}</span>
            </button>

            {showTranscript && (
              <div
                ref={transcriptRef}
                className="max-h-[560px] overflow-y-auto rounded-[22px] border border-border bg-card px-5 py-5 shadow-sm scroll-smooth sm:px-6 sm:py-6"
              >
                <div className="space-y-4">
                  {transcriptParagraphs.map((paragraph, i) => (
                    <p
                      key={i}
                      className="text-sm leading-8 text-muted-foreground sm:text-[15px]"
                    >
                      {paragraph}
                    </p>
                  ))}
                </div>
              </div>
            )}
          </section>
        )}
      </main>
    </div>
  );
};

export default Watch;
