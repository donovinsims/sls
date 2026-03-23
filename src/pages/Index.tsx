import { Button } from "@/components/ui/button";
import { Link } from "react-router-dom";

const STRIPE_CHECKOUT_URL = "https://buy.stripe.com/8x2dR28179hqbAQbv56J200";

const modules = [
  { name: "Foundations", lessons: ["Welcome & Course Overview", "The Day Trader's Mindset", "Charts, Timeframes & Tools", "Understanding Market Structure"] },
  { name: "Market Structure", lessons: ["Support & Resistance Mastery", "S&R In Practice", "M's & W's / Chart Patterns", "BOS vs CHOC"] },
  { name: "Entries & Setups", lessons: ["High-Probability Entries", "EMA Crossings & Signals", "Fair Value Gaps", "Confluence vs Strategy"] },
  { name: "Risk Management", lessons: ["Managing Risk & Securing Profits", "Taking Profit Options", "Liquidity & Stop Placement", "Payout & Capital Protection"] },
  { name: "Advanced Strategies", lessons: ["Trading Continuation & Trend", "Lock and Reload", "Live Trade Walkthrough", "Prop Firms: Pros & Cons"] },
  { name: "Psychology & Review", lessons: ["Eliminate Burnout", "Eliminating Stress & Anxiety", "Q&A Session 1", "Q&A Session 2"] },
];

const Index = () => {
  return (
    <div className="min-h-screen bg-background">
      {/* Nav */}
      <header className="mx-auto max-w-6xl px-4 py-6 flex items-center justify-between">
        <span className="font-display text-xl font-semibold text-foreground">SLS Trading</span>
        <Link to="/login" className="text-sm text-muted-foreground hover:text-foreground transition-colors">
          Sign In
        </Link>
      </header>

      {/* Hero */}
      <section className="mx-auto max-w-4xl px-4 py-16 md:py-24 text-center space-y-6">
        <p className="font-script text-primary text-2xl">Transform your trading</p>
        <h1 className="font-display text-4xl md:text-5xl lg:text-6xl font-bold text-foreground leading-tight">
          Master Day Trading
        </h1>
        <p className="text-lg md:text-xl text-muted-foreground max-w-2xl mx-auto leading-relaxed">
          24 comprehensive video lessons covering everything from market structure fundamentals to advanced strategies and trading psychology.
        </p>
        <div className="pt-4">
          <Button variant="cta" size="lg" className="text-lg px-10 py-6" asChild>
            <a href={STRIPE_CHECKOUT_URL} target="_blank" rel="noopener noreferrer">
              Get Instant Access
            </a>
          </Button>
        </div>
      </section>

      {/* What You'll Learn */}
      <section className="mx-auto max-w-5xl px-4 py-16">
        <div className="text-center mb-12">
          <p className="font-script text-primary text-xl mb-2">Curriculum</p>
          <h2 className="font-display text-3xl md:text-4xl font-semibold text-foreground">
            What You'll Learn
          </h2>
        </div>
        <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {modules.map((mod) => (
            <div
              key={mod.name}
              className="rounded-lg bg-card border border-border p-6 shadow-sm"
            >
              <h3 className="font-display text-xl font-semibold text-foreground mb-3">
                {mod.name}
              </h3>
              <ul className="space-y-2">
                {mod.lessons.map((lesson) => (
                  <li key={lesson} className="flex items-start gap-2 text-sm text-muted-foreground">
                    <span className="text-primary mt-0.5">•</span>
                    {lesson}
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </section>

      {/* Final CTA */}
      <section className="mx-auto max-w-4xl px-4 py-16 text-center space-y-6">
        <h2 className="font-display text-3xl md:text-4xl font-semibold text-foreground">
          Ready to Start?
        </h2>
        <p className="text-muted-foreground text-lg max-w-xl mx-auto">
          Join hundreds of traders who have transformed their approach to the markets.
        </p>
        <Button variant="cta" size="lg" className="text-lg px-10 py-6" asChild>
          <a href={STRIPE_CHECKOUT_URL} target="_blank" rel="noopener noreferrer">
            Get Instant Access
          </a>
        </Button>
      </section>

      {/* Footer */}
      <footer className="border-t border-border py-8 text-center text-sm text-muted-foreground">
        <p>© {new Date().getFullYear()} SLS Trading. All rights reserved.</p>
      </footer>
    </div>
  );
};

export default Index;
