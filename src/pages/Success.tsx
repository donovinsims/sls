import { useEffect, useState } from "react";
import { useSearchParams, Link } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";

const Success = () => {
  const [searchParams] = useSearchParams();
  const sessionId = searchParams.get("session_id");
  const [status, setStatus] = useState<"loading" | "success" | "error">("loading");
  const [message, setMessage] = useState("");

  useEffect(() => {
    if (!sessionId) {
      setStatus("error");
      setMessage("No session ID found. If you completed a purchase, please contact support.");
      return;
    }

    const verifyPurchase = async () => {
      try {
        const { data, error } = await supabase.functions.invoke("verify-purchase", {
          body: { sessionId },
        });

        if (error || !data?.success) {
          setStatus("error");
          setMessage(data?.error ?? "Could not verify your purchase. Please contact support.");
          return;
        }

        setStatus("success");
        setMessage("Purchase confirmed! Check your email for your login link.");
      } catch {
        setStatus("error");
        setMessage("An unexpected error occurred. Please contact support.");
      }
    };

    verifyPurchase();
  }, [sessionId]);

  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <div className="w-full max-w-md text-center space-y-6">
        {status === "loading" && (
          <>
            <div className="mx-auto h-12 w-12 rounded-full border-4 border-primary border-t-transparent animate-spin" />
            <h1 className="font-display text-2xl font-semibold text-foreground">
              Verifying your purchase...
            </h1>
          </>
        )}

        {status === "success" && (
          <div className="rounded-lg bg-card p-8 shadow-md border border-border">
            <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-[hsl(var(--success))]/10">
              <svg className="h-8 w-8 text-[hsl(var(--success))]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <h1 className="font-display text-3xl font-semibold text-foreground mb-2">
              You're In!
            </h1>
            <p className="text-muted-foreground mb-6">{message}</p>
            <Button variant="cta" size="lg" asChild>
              <Link to="/login">Go to Login</Link>
            </Button>
          </div>
        )}

        {status === "error" && (
          <div className="rounded-lg bg-card p-8 shadow-md border border-border">
            <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-destructive/10">
              <svg className="h-8 w-8 text-destructive" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </div>
            <h1 className="font-display text-2xl font-semibold text-foreground mb-2">
              Verification Failed
            </h1>
            <p className="text-muted-foreground mb-6">{message}</p>
            <Button variant="cta" size="lg" asChild>
              <a href="/">Back to Home</a>
            </Button>
          </div>
        )}
      </div>
    </div>
  );
};

export default Success;
