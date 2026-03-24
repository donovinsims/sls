import { useState } from "react";
import { Link } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

const Success = () => {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"form" | "submitting" | "done" | "error">("form");
  const [message, setMessage] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const trimmed = email.trim().toLowerCase();
    if (!trimmed) return;

    setStatus("submitting");

    try {
      const { error } = await supabase.from("customers").upsert(
        {
          email: trimmed,
          course_access: false,
          purchased_at: new Date().toISOString(),
        },
        { onConflict: "email" }
      );

      if (error) {
        console.error(error);
        setStatus("error");
        setMessage("Something went wrong. Please contact support with your payment confirmation.");
        return;
      }

      setStatus("done");
    } catch {
      setStatus("error");
      setMessage("An unexpected error occurred. Please contact support.");
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <div className="w-full max-w-md text-center space-y-6">
        {status === "form" || status === "submitting" ? (
          <div className="rounded-lg bg-card p-8 shadow-md border border-border">
            <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-primary/10">
              <svg className="h-8 w-8 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <h1 className="font-display text-3xl font-semibold text-foreground mb-2">
              Payment Received!
            </h1>
            <p className="text-muted-foreground mb-6">
              Enter the email you'd like to use for your course login. We'll send you a magic link within a few minutes.
            </p>
            <form onSubmit={handleSubmit} className="space-y-4">
              <Input
                type="email"
                placeholder="you@example.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                className="border-0 border-b-2 border-border rounded-none bg-transparent px-0 focus-visible:ring-0 focus-visible:border-primary text-foreground placeholder:text-muted-foreground"
              />
              <Button
                type="submit"
                variant="cta"
                size="lg"
                className="w-full"
                disabled={status === "submitting"}
              >
                {status === "submitting" ? "Submitting..." : "Get My Access"}
              </Button>
            </form>
          </div>
        ) : status === "done" ? (
          <div className="rounded-lg bg-card p-8 shadow-md border border-border">
            <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-[hsl(var(--success))]/10">
              <svg className="h-8 w-8 text-[hsl(var(--success))]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <h1 className="font-display text-3xl font-semibold text-foreground mb-2">
              You're All Set!
            </h1>
            <p className="text-muted-foreground mb-6">
              We'll send a login link to <strong className="text-foreground">{email.trim().toLowerCase()}</strong> within a few minutes. Check your inbox (and spam folder).
            </p>
            <Button variant="cta" size="lg" asChild>
              <Link to="/login">Go to Login</Link>
            </Button>
          </div>
        ) : (
          <div className="rounded-lg bg-card p-8 shadow-md border border-border">
            <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-destructive/10">
              <svg className="h-8 w-8 text-destructive" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </div>
            <h1 className="font-display text-2xl font-semibold text-foreground mb-2">
              Something Went Wrong
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
