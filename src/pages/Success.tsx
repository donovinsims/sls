import { useEffect, useState } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import SEOHead from "@/components/SEOHead";

type Status =
  | "verifying"
  | "fulfilled"
  | "already_processed"
  | "processing"
  | "manual_review"
  | "invalid_session"
  | "config_error";

const SUPPORT_EMAIL = "sls25trading@gmail.com";
const REDIRECT_DELAY_MS = 1800;

type VerifyPurchaseResponse = {
  status?: string;
  email?: string;
  referenceCode?: string;
  recoveryMessage?: string;
  error?: string;
  success?: boolean;
};

const parseFunctionPayload = async (response?: Response): Promise<VerifyPurchaseResponse | null> => {
  const contentType = response?.headers.get("content-type") ?? "";
  if (!response || !contentType.includes("application/json")) return null;

  try {
    return (await response.clone().json()) as VerifyPurchaseResponse;
  } catch {
    return null;
  }
};

const Success = () => {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const sessionId = searchParams.get("session_id");
  const [status, setStatus] = useState<Status>(sessionId ? "verifying" : "invalid_session");
  const [email, setEmail] = useState(searchParams.get("email") ?? "");
  const [message, setMessage] = useState("");
  const [referenceCode, setReferenceCode] = useState(sessionId ?? "");
  const [retryCount, setRetryCount] = useState(0);
  const [targetPath, setTargetPath] = useState<string | null>(null);

  useEffect(() => {
    setReferenceCode(sessionId ?? "");
  }, [sessionId]);

  useEffect(() => {
    if (!sessionId) return;

    let cancelled = false;

    const verify = async () => {
      try {
        const { data, error, response } = await supabase.functions.invoke<VerifyPurchaseResponse>("verify-purchase", {
          body: { sessionId },
        });
        const payload = data ?? await parseFunctionPayload(response);

        if (cancelled) return;

        if (error && !payload) {
          if (retryCount < 2) {
            window.setTimeout(() => setRetryCount((count) => count + 1), 2000);
            return;
          }
          setMessage("The verification service is unavailable right now.");
          setStatus("config_error");
          return;
        }

        const responseEmail = typeof payload?.email === "string" ? payload.email.toLowerCase() : "";
        if (responseEmail) setEmail(responseEmail);
        if (typeof payload?.referenceCode === "string") setReferenceCode(payload.referenceCode);

        switch (payload?.status) {
          case "fulfilled":
          case "already_processed":
            setStatus(payload.status);
            return;
          case "processing":
          case "pending":
          case "unpaid":
            setMessage(payload?.recoveryMessage ?? "Payment is confirmed. Your access is still being finalized.");
            setStatus("processing");
            return;
          case "manual_review":
          case "verified_pending_db":
            setMessage(payload?.recoveryMessage ?? "Your payment was verified, but account setup needs a manual pass.");
            setStatus("manual_review");
            return;
          case "invalid_session":
            setMessage(payload?.recoveryMessage ?? "We could not verify this payment session.");
            setStatus("invalid_session");
            return;
          case "config_error":
            setMessage(payload?.recoveryMessage ?? "Verification is temporarily unavailable.");
            setStatus("config_error");
            return;
          default:
            break;
        }

        if (payload?.success) {
          setStatus("already_processed");
          return;
        }

        setMessage(payload?.error || "We couldn't verify your payment right now.");
        setStatus("manual_review");
      } catch {
        if (retryCount < 2) {
          window.setTimeout(() => setRetryCount((count) => count + 1), 2000);
          return;
        }
        setMessage("The verification service timed out.");
        setStatus("config_error");
      }
    };

    verify();

    return () => {
      cancelled = true;
    };
  }, [retryCount, sessionId]);

  useEffect(() => {
    if (status !== "fulfilled" && status !== "already_processed") return;

    let cancelled = false;
    let timer: number | undefined;

    const routeNext = async () => {
      const { data } = await supabase.auth.getSession();
      if (cancelled) return;

      const path = data.session?.user
        ? "/portal"
        : email
          ? `/login?email=${encodeURIComponent(email)}`
          : "/login";

      setTargetPath(path);
      timer = window.setTimeout(() => navigate(path, { replace: true }), REDIRECT_DELAY_MS);
    };

    routeNext();

    return () => {
      cancelled = true;
      if (timer) window.clearTimeout(timer);
    };
  }, [email, navigate, status]);

  const supportHref = `mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent(`SLS checkout help ${referenceCode ? `- ${referenceCode}` : ""}`)}`;
  const primaryHref = targetPath ?? (email ? `/login?email=${encodeURIComponent(email)}` : "/login");
  const isFinalized = status === "fulfilled" || status === "already_processed";

  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4 py-8">
      <SEOHead title="Purchase Status | SLS Trading" description="Your SLS Trading course purchase is being verified." path="/success" />
      <div className="w-full max-w-md text-center space-y-6">
        {(status === "verifying" || status === "processing") && (
          <div className="rounded-2xl bg-card p-8 shadow-md border border-border">
            <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-primary/10">
              <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
            <h1 className="font-display text-3xl font-semibold text-foreground mb-2">
              {status === "verifying" ? "Confirming Your Purchase" : "Finalizing Access"}
            </h1>
            <p className="text-muted-foreground">
              {status === "verifying"
                ? "We are checking your Stripe session now. This only takes a moment."
                : message || "Your payment is confirmed. We are finishing your account setup."}
            </p>
            {referenceCode && (
              <p className="mt-4 text-xs text-muted-foreground">
                Reference: <span className="font-medium text-foreground">{referenceCode}</span>
              </p>
            )}
          </div>
        )}

        {isFinalized && (
          <div className="rounded-2xl bg-card p-8 shadow-md border border-border">
            <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-[hsl(var(--success))]/10">
              <svg className="h-8 w-8 text-[hsl(var(--success))]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <h1 className="font-display text-3xl font-semibold text-foreground mb-2">
              {status === "fulfilled" ? "Payment Confirmed" : "Already Processed"}
            </h1>
            <p className="text-muted-foreground mb-2">
              Your course access is ready.
            </p>
            {email && (
              <p className="text-muted-foreground mb-6">
                We sent next steps to <strong className="text-foreground">{email}</strong>.
              </p>
            )}
            <div className="space-y-3">
              <Button variant="cta" size="lg" className="w-full" asChild>
                <Link to={primaryHref}>{targetPath?.includes("/portal") ? "Open Course Portal" : "Continue to Login"}</Link>
              </Button>
              <p className="text-xs text-muted-foreground">
                {targetPath?.includes("/portal")
                  ? "If the portal does not open automatically, use the button above."
                  : "We are sending you to the login page with your email prefilled."}
              </p>
            </div>
            {referenceCode && (
              <p className="mt-4 text-xs text-muted-foreground">
                Reference: <span className="font-medium text-foreground">{referenceCode}</span>
              </p>
            )}
          </div>
        )}

        {status === "manual_review" && (
          <div className="rounded-2xl bg-card p-8 shadow-md border border-border">
            <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-amber-500/10">
              <svg className="h-8 w-8 text-amber-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.072 16.5c-.77.833.192 2.5 1.732 2.5z" />
              </svg>
            </div>
            <h1 className="font-display text-3xl font-semibold text-foreground mb-2">
              Access Is Almost Ready
            </h1>
            <p className="text-muted-foreground mb-4">
              {message || "Your payment went through, but we need one more step to finish setup."}
            </p>
            {referenceCode && (
              <p className="text-xs text-muted-foreground mb-6">
                Reference: <span className="font-medium text-foreground">{referenceCode}</span>
              </p>
            )}
            <div className="space-y-3">
              <Button variant="cta" size="lg" className="w-full" asChild>
                <a href={supportHref}>Contact Support</a>
              </Button>
              <Button variant="outline" size="lg" className="w-full" asChild>
                <Link to="/">Back to Home</Link>
              </Button>
            </div>
          </div>
        )}

        {status === "invalid_session" && (
          <div className="rounded-2xl bg-card p-8 shadow-md border border-border">
            <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-destructive/10">
              <svg className="h-8 w-8 text-destructive" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.072 16.5c-.77.833.192 2.5 1.732 2.5z" />
              </svg>
            </div>
            <h1 className="font-display text-3xl font-semibold text-foreground mb-2">
              We Could Not Verify This Session
            </h1>
            <p className="text-muted-foreground mb-6">
              {message || "If you were charged, your purchase is safe. We just need to match the checkout session correctly."}
            </p>
            <div className="space-y-3">
              <Button variant="cta" size="lg" className="w-full" asChild>
                <a href={supportHref}>Get Help</a>
              </Button>
              <Button variant="outline" size="lg" className="w-full" asChild>
                <Link to="/">Back to Home</Link>
              </Button>
            </div>
            {referenceCode && (
              <p className="mt-4 text-xs text-muted-foreground">
                Reference: <span className="font-medium text-foreground">{referenceCode}</span>
              </p>
            )}
          </div>
        )}

        {status === "config_error" && (
          <div className="rounded-2xl bg-card p-8 shadow-md border border-border">
            <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-primary/10">
              <svg className="h-8 w-8 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <h1 className="font-display text-3xl font-semibold text-foreground mb-2">
              We Are Finalizing Access
            </h1>
            <p className="text-muted-foreground mb-6">
              {message || "The checkout verification service is catching up. Your payment is safe."}
            </p>
            <div className="space-y-3">
              <Button variant="cta" size="lg" className="w-full" asChild>
                <Link to={primaryHref}>Continue to Login</Link>
              </Button>
              <Button variant="outline" size="lg" className="w-full" asChild>
                <a href={supportHref}>Contact Support</a>
              </Button>
            </div>
            {referenceCode && (
              <p className="mt-4 text-xs text-muted-foreground">
                Reference: <span className="font-medium text-foreground">{referenceCode}</span>
              </p>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default Success;
