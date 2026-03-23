import { useEffect, useState } from "react";
import { useParams, useNavigate, Link } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/contexts/AuthContext";
import { toast } from "sonner";

const ADMIN_EMAILS = ["sls25trading@gmail.com", "emaildonovin@gmail.com"];

const Watch = () => {
  const { videoId } = useParams<{ videoId: string }>();
  const { user, loading } = useAuth();
  const navigate = useNavigate();
  const [embedUrl, setEmbedUrl] = useState<string | null>(null);
  const [videoTitle, setVideoTitle] = useState("");
  const [videoDescription, setVideoDescription] = useState("");
  const [loadingVideo, setLoadingVideo] = useState(true);
  const [error, setError] = useState<string | null>(null);

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

        // Check access
        if (!isAdmin) {
          const { data: customer } = await supabase
            .from("customers")
            .select("course_access")
            .eq("email", email)
            .maybeSingle();

          if (!customer?.course_access) {
            setError("No active purchase found.");
            setLoadingVideo(false);
            return;
          }
        }

        // Generate device fingerprint
        const fp = `${navigator.userAgent}|${screen.width}x${screen.height}|${Intl.DateTimeFormat().resolvedOptions().timeZone}`;
        const encoder = new TextEncoder();
        const hashBuffer = await crypto.subtle.digest("SHA-256", encoder.encode(fp));
        const hashArray = Array.from(new Uint8Array(hashBuffer));
        const fingerprint = hashArray.map(b => b.toString(16).padStart(2, "0")).join("");

        // Call edge function to get embed URL
        const { data, error: fnError } = await supabase.functions.invoke("get-video", {
          body: { videoId, fingerprint },
        });

        if (fnError || !data?.embedUrl) {
          setError("Failed to load video. Please try again.");
          console.error(fnError || data);
          setLoadingVideo(false);
          return;
        }

        setEmbedUrl(data.embedUrl);
        setVideoTitle(data.title ?? "");
        setVideoDescription(data.description ?? "");
      } catch (err) {
        console.error(err);
        setError("An unexpected error occurred.");
      }
      setLoadingVideo(false);
    };

    loadVideo();
  }, [user, videoId]);

  if (loading || loadingVideo) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background">
        <p className="text-muted-foreground">Loading video...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background px-4">
        <div className="text-center max-w-md">
          <h1 className="font-display text-2xl font-semibold text-foreground mb-4">{error}</h1>
          <Link to="/portal" className="text-primary underline hover:text-primary/80">
            ← Back to Dashboard
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      <header className="border-b border-border bg-card/50 backdrop-blur-sm">
        <div className="mx-auto max-w-5xl px-4 py-4">
          <Link to="/portal" className="text-sm text-muted-foreground hover:text-foreground transition-colors">
            ← Back to Dashboard
          </Link>
        </div>
      </header>

      <main className="mx-auto max-w-5xl px-4 py-8 space-y-6">
        <div className="relative w-full aspect-video rounded-lg overflow-hidden shadow-lg bg-foreground/5">
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

        <div className="space-y-2">
          <h1 className="font-display text-3xl font-semibold text-foreground">
            {videoTitle}
          </h1>
          <p className="text-muted-foreground leading-relaxed">
            {videoDescription}
          </p>
        </div>
      </main>
    </div>
  );
};

export default Watch;
