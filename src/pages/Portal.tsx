import { useEffect, useState } from "react";
import { useNavigate, Link } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/contexts/AuthContext";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { toast } from "sonner";
import type { Database } from "@/integrations/supabase/types";

const ADMIN_EMAILS = ["sls25trading@gmail.com", "emaildonovin@gmail.com"];
const SUPPORT_EMAIL = "sls25trading@gmail.com";

type VideoProgressRow = Database["public"]["Tables"]["video_progress"]["Row"];

interface Video {
  id: string;
  title: string;
  description: string;
  sort_order: number;
  module: string;
  summary: string;
}

const Portal = () => {
  const { user, loading, signOut } = useAuth();
  const navigate = useNavigate();
  const [videos, setVideos] = useState<Video[]>([]);
  const [hasAccess, setHasAccess] = useState<boolean | null>(null);
  const [loadingData, setLoadingData] = useState(true);
  const [completedIds, setCompletedIds] = useState<Set<string>>(new Set());
  const [lastWatchedId, setLastWatchedId] = useState<string | null>(null);

  useEffect(() => {
    if (!loading && !user) {
      navigate("/login");
    }
  }, [user, loading, navigate]);

  useEffect(() => {
    if (!user) return;

    const checkAccessAndLoadVideos = async () => {
      const email = user.email?.toLowerCase() ?? "";
      const isAdmin = ADMIN_EMAILS.includes(email);

      if (!isAdmin) {
        const { data: customer } = await supabase
          .from("customers")
          .select("course_access")
          .eq("email", email)
          .maybeSingle();

        if (!customer?.course_access) {
          setHasAccess(false);
          setLoadingData(false);
          return;
        }
      }

      if (isAdmin) {
        await supabase.from("customers").upsert(
          { email, course_access: true },
          { onConflict: "email" }
        );
      }

      setHasAccess(true);

      const { data, error } = await supabase.rpc("get_course_videos");
      if (error) {
        toast.error("Failed to load videos");
        console.error(error);
      } else {
        setVideos(data ?? []);
      }

      // Load progress
      const { data: customer } = await supabase
        .from("customers")
        .select("id")
        .eq("email", email)
        .maybeSingle();

      if (customer) {
        const { data: progress } = await supabase
          .from("video_progress")
          .select("video_id, completed, last_watched_at")
          .eq("customer_id", customer.id);

        if (progress) {
          const completed = new Set<string>();
          let latestTime = "";
          let latestId: string | null = null;

          for (const p of progress as VideoProgressRow[]) {
            if (p.completed) {
              completed.add(p.video_id);
            }
            if (p.last_watched_at > latestTime) {
              latestTime = p.last_watched_at;
              latestId = p.video_id;
            }
          }

          setCompletedIds(completed);
          setLastWatchedId(latestId);
        }
      }

      setLoadingData(false);
    };

    checkAccessAndLoadVideos();
  }, [user]);

  if (loading || loadingData) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background">
        <p className="text-muted-foreground">Loading your course...</p>
      </div>
    );
  }

  if (hasAccess === false) {
    const recoveryEmail = user?.email ? `/login?email=${encodeURIComponent(user.email)}` : "/login";
    return (
      <div className="flex min-h-screen items-center justify-center bg-background px-4">
        <div className="text-center max-w-md space-y-5">
          <h1 className="font-display text-3xl font-semibold text-foreground">
            No Active Purchase Found
          </h1>
          <p className="text-muted-foreground mb-6">
            Your current login does not show an active purchase. If you used a different email at checkout, sign in again with that email or contact support.
          </p>
          <div className="space-y-3">
            <Button variant="cta" size="lg" className="w-full" asChild>
              <Link to={recoveryEmail}>Use a Different Email</Link>
            </Button>
            <Button variant="outline" size="lg" className="w-full" asChild>
              <a href={`mailto:${SUPPORT_EMAIL}`}>Contact Support</a>
            </Button>
          </div>
        </div>
      </div>
    );
  }

  // Group videos by module
  const modules = videos.reduce<Record<string, Video[]>>((acc, video) => {
    if (!acc[video.module]) acc[video.module] = [];
    acc[video.module].push(video);
    return acc;
  }, {});

  const totalVideos = videos.length;
  const completedCount = completedIds.size;
  const progressPercent = totalVideos > 0 ? Math.round((completedCount / totalVideos) * 100) : 0;

  // Find the "continue" video — the last watched that isn't completed, or just last watched
  const continueVideo = lastWatchedId
    ? videos.find((v) => v.id === lastWatchedId)
    : videos[0];

  const isAdmin = user?.email && ADMIN_EMAILS.includes(user.email.toLowerCase());

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b border-border bg-card/50 backdrop-blur-sm sticky top-0 z-10">
        <div className="mx-auto max-w-6xl px-4 py-4 flex items-center justify-between">
          <h1 className="font-display text-2xl font-semibold text-foreground">
            Course Dashboard
          </h1>
          <div className="flex items-center gap-4">
            {isAdmin && (
              <Link to="/admin" className="text-sm text-primary hover:text-primary/80 transition-colors">
                Admin
              </Link>
            )}
            <span className="text-sm text-muted-foreground hidden sm:inline">
              {user?.email}
            </span>
            <Button variant="outline" size="sm" onClick={signOut}>
              Sign Out
            </Button>
          </div>
        </div>
      </header>

      {/* Content */}
      <main className="mx-auto max-w-6xl px-4 py-8 space-y-8">
        {/* Progress bar */}
        <div className="rounded-lg bg-card border border-border p-6 space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="font-script text-primary text-lg">Your progress</p>
              <h2 className="font-display text-2xl font-semibold text-foreground">
                {completedCount} of {totalVideos} lessons completed
              </h2>
            </div>
            <span className="text-3xl font-display font-bold text-primary">{progressPercent}%</span>
          </div>
          <Progress value={progressPercent} className="h-3" />

          {continueVideo && (
            <Link
              to={`/watch/${continueVideo.id}`}
              className="inline-flex items-center gap-2 text-sm font-medium text-primary hover:text-primary/80 transition-colors"
            >
              {completedCount === 0 ? "Start with" : "Continue with"}: {continueVideo.title} →
            </Link>
          )}
        </div>

        {/* Module grid */}
        {Object.entries(modules).map(([moduleName, moduleVideos]) => (
          <section key={moduleName} className="space-y-4">
            <div className="flex items-center justify-between border-b border-border pb-2">
              <h3 className="font-display text-xl font-semibold text-foreground">
                {moduleName}
              </h3>
              <span className="text-sm text-muted-foreground">
                {moduleVideos.filter((v) => completedIds.has(v.id)).length}/{moduleVideos.length} done
              </span>
            </div>
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {moduleVideos.map((video) => {
                const isCompleted = completedIds.has(video.id);
                return (
                  <Link
                    key={video.id}
                    to={`/watch/${video.id}`}
                    className={`group block rounded-lg border p-5 shadow-sm hover:shadow-md transition-all duration-200 ${
                      isCompleted
                        ? "bg-success/5 border-success/30 hover:border-success/50"
                        : "bg-card border-border hover:border-primary/40"
                    }`}
                  >
                    <div className="flex items-start justify-between mb-3">
                      <Badge className="bg-accent text-accent-foreground border-0 rounded-full text-xs">
                        {video.module}
                      </Badge>
                      {isCompleted && (
                        <span className="flex items-center gap-1 text-xs font-medium text-success">
                          <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                          </svg>
                          Done
                        </span>
                      )}
                    </div>
                    <h4 className="font-display text-lg font-semibold text-foreground group-hover:text-primary transition-colors mb-2">
                      {video.sort_order}. {video.title}
                    </h4>
                    <p className="text-sm text-muted-foreground line-clamp-2 mb-4">
                      {video.description}
                    </p>
                    <span className="inline-flex items-center gap-1 text-sm font-medium text-primary">
                      {isCompleted ? "Rewatch" : "Watch"} →
                    </span>
                  </Link>
                );
              })}
            </div>
          </section>
        ))}
      </main>
    </div>
  );
};

export default Portal;
