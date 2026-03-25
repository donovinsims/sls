import { useState, useEffect } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import SEOHead from "@/components/SEOHead";

type Status = "verifying" | "fulfilled" | "pending" | "error";

const Success = () => {
  const [searchParams] = useSearchParams();
  const sessionId = searchParams.get("session_id");
  const [status, setStatus] = useState<Status>(sessionId ? "verifying" : "pending");
  const [email, setEmail] = useState("");
  const [errorMsg, setErrorMsg] = useState("");
  const [retryCount, setRetryCount] = useState(0);

  useEffect(() => {
    if (!sessionId) return;

    const verify = async () => {
      try {
        const { data, error } = await supabase.functions.invoke("verify-purchase", {
          body: { sessionId },
        });

        if (error) {
          console.error("Verify error:", error);
          if (retryCount < 3) {
            setTimeout(() => setRetryCount((c) => c + 1), 3000);
            return;
          }
          setStatus("pending");
          return;
        }

        if (data?.success && (data?.status === "fulfilled" || data?.status === "verified_pending_db")) {
          setEmail(data.email || "");
          setStatus("fulfilled");
          return;
        }

        if (data?.status === "pending" || data?.status === "unpaid") {
          if (retryCount < 3) {
            setTimeout(() => setRetryCount((c) => c + 1), 3000);
            return;
          }
          setStatus("pending");
          return;
        }

        setErrorMsg(data?.error || "Verification failed.");
        setStatus("error");
      } catch {
        if (retryCount < 3) {
          setTimeout(() => setRetryCount((c) => c + 1), 3000);
        } else {
          setStatus("pending");
        }
      }
    };

    verify();
  }, [sessionId, retryCount]);

  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <SEOHead title="Purchase Confirmed | SLS Trading" description="Your SLS Trading course purchase is confirmed." path="/success" />
      <div className="w-full max-w-md text-center space-y-6">
        {status === "verifying" && (
          <div className="rounded-lg bg-card p-8 shadow-md border border-border">
            <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-primary/10">
              <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
            <h1 className="font-display text-3xl font-semibold text-foreground mb-2">
              Confirming Your Purchase
            </h1>
            <p className="text-muted-foreground">
              We're verifying your payment with Stripe. This usually takes a few seconds...
            </p>
          </div>
        )}

        {status === "fulfilled" && (
          <div className="rounded-lg bg-card p-8 shadow-md border border-border">
            <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-[hsl(var(--success))]/10">
              <svg className="h-8 w-8 text-[hsl(var(--success))]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <h1 className="font-display text-3xl font-semibold text-foreground mb-2">
              You're In!
            </h1>
            <p className="text-muted-foreground mb-2">
              Payment confirmed. Your course access is live.
            </p>
            {email && (
              <p className="text-muted-foreground mb-6">
                We sent a login link to <strong className="text-foreground">{email}</strong>. Check your inbox (and spam folder).
              </p>
            )}
            <div className="space-y-3">
              <Button variant="cta" size="lg" className="w-full" asChild>
                <Link to="/login">Go to Course Login</Link>
              </Button>
              <p className="text-xs text-muted-foreground">
                Didn't get the email? Use the login page to request a new magic link.
              </p>
            </div>
          </div>
        )}

        {status === "pending" && (
          <div className="rounded-lg bg-card p-8 shadow-md border border-border">
            <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-primary/10">
              <svg className="h-8 w-8 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <h1 className="font-display text-3xl font-semibold text-foreground mb-2">
              Payment Received!
            </h1>
            <p className="text-muted-foreground mb-6">
              We're processing your purchase. You'll receive a login link at the email you used during checkout within a few minutes. If you don't see it, check your spam folder or use the login page to request a new one.
            </p>
            <div className="space-y-3">
              <Button variant="cta" size="lg" className="w-full" asChild>
                <Link to="/login">Go to Login</Link>
              </Button>
              <p className="text-xs text-muted-foreground">
                Need help? Email <a href="mailto:sls25trading@gmail.com" className="text-primary hover:underline">sls25trading@gmail.com</a>
              </p>
            </div>
          </div>
        )}

        {status === "error" && (
          <div className="rounded-lg bg-card p-8 shadow-md border border-border">
            <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-destructive/10">
              <svg className="h-8 w-8 text-destructive" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.072 16.5c-.77.833.192 2.5 1.732 2.5z" />
              </svg>
            </div>
            <h1 className="font-display text-2xl font-semibold text-foreground mb-2">
              Something Went Wrong
            </h1>
            <p className="text-muted-foreground mb-6">
              {errorMsg || "We couldn't verify your payment. Don't worry — if you were charged, your purchase is safe."}
            </p>
            <div className="space-y-3">
              <Button variant="cta" size="lg" className="w-full" asChild>
                <a href="mailto:sls25trading@gmail.com">Contact Support</a>
              </Button>
              <Button variant="outline" size="lg" className="w-full" asChild>
                <Link to="/">Back to Home</Link>
              </Button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default Success;
