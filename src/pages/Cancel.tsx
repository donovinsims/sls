import { Link } from "react-router-dom";
import { Button } from "@/components/ui/button";
import SEOHead from "@/components/SEOHead";
import { getCtaText, getCheckoutUrl } from "@/lib/pricing";

const Cancel = () => {
  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <SEOHead title="Checkout Cancelled | SLS Trading" description="Your checkout was cancelled. You can try again anytime." path="/cancel" />
      <div className="w-full max-w-md text-center space-y-6">
        <div className="rounded-lg bg-card p-8 shadow-md border border-border">
          <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-primary/10">
            <svg className="h-8 w-8 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 10h10a8 8 0 018 8v2M3 10l6 6m-6-6l6-6" />
            </svg>
          </div>
          <h1 className="font-display text-3xl font-semibold text-foreground mb-2">
            No Worries
          </h1>
          <p className="text-muted-foreground mb-6">
            Your checkout was cancelled and you haven't been charged. When you're ready, the course will be here.
          </p>
          <div className="space-y-3">
            <Button variant="cta" size="lg" className="w-full" asChild>
              <a href={getCheckoutUrl()}>
                {getCtaText()}
              </a>
            </Button>
            <Button variant="outline" size="lg" className="w-full" asChild>
              <Link to="/">Back to Home</Link>
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Cancel;
