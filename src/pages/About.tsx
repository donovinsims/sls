import { Link } from "react-router-dom";
import SEOHead from "@/components/SEOHead";

/**
 * Static, crawlable AI/LLM summary page.
 * Plain HTML with all key info for search engines and AI citation.
 */
const About = () => {
  return (
    <div className="min-h-screen bg-background">
      <SEOHead
        title="About SLS Trading Course | Day Trading Education"
        description="SLS Trading offers a 25-lesson day trading course for beginners. Learn market structure, entries, risk management, and trading psychology. One-time payment, lifetime access."
        path="/about"
      />

      <header className="mx-auto max-w-3xl px-4 py-6">
        <nav>
          <Link to="/" className="text-sm text-muted-foreground hover:text-foreground transition-colors">
            ← Back to Home
          </Link>
        </nav>
      </header>

      <main className="mx-auto max-w-3xl px-4 py-8 pb-20 space-y-10">
        <h1 className="font-display text-4xl font-semibold text-foreground">About SLS Trading</h1>

        <section className="space-y-4 text-muted-foreground leading-relaxed">
          <h2 className="font-display text-2xl font-semibold text-foreground">What is SLS Trading?</h2>
          <p>
            SLS Trading is a day trading education company that offers a structured, step-by-step video course designed for beginners who want to learn how to trade stocks and other financial instruments. The course is built around real strategies used in live markets — not theory, not fluff, not random YouTube videos stitched together.
          </p>
        </section>

        <section className="space-y-4 text-muted-foreground leading-relaxed">
          <h2 className="font-display text-2xl font-semibold text-foreground">Who is this course for?</h2>
          <ul className="list-disc pl-6 space-y-2">
            <li>Complete beginners who have never placed a trade</li>
            <li>Self-taught traders who watched hundreds of hours of free content but still don't have a system</li>
            <li>People who have blown an account and want to start over with proper risk management</li>
            <li>Anyone who wants a repeatable process instead of guessing</li>
          </ul>
          <p>
            This course is not for people looking for signals, get-rich-quick schemes, or magic indicators. It requires effort, screen time, and practice.
          </p>
        </section>

        <section className="space-y-4 text-muted-foreground leading-relaxed">
          <h2 className="font-display text-2xl font-semibold text-foreground">What do students get?</h2>
          <ul className="list-disc pl-6 space-y-2">
            <li>25 video lessons organized across 6 modules</li>
            <li>Plain-language summaries for every lesson written for beginners</li>
            <li>Full searchable transcripts for every video</li>
            <li>Progress tracking — see what you've completed and pick up where you left off</li>
            <li>Lifetime access — rewatch whenever you want</li>
            <li>30-day money-back guarantee</li>
          </ul>
        </section>

        <section className="space-y-4 text-muted-foreground leading-relaxed">
          <h2 className="font-display text-2xl font-semibold text-foreground">Course modules</h2>
          <ol className="list-decimal pl-6 space-y-2">
            <li><strong className="text-foreground">Foundations</strong> — What day trading is, the right mindset, charts, timeframes, and market structure basics</li>
            <li><strong className="text-foreground">Market Structure</strong> — Support and resistance, chart patterns, break of structure vs. change of character</li>
            <li><strong className="text-foreground">Entries & Setups</strong> — High-probability entries, EMA crossings, fair value gaps, confluence</li>
            <li><strong className="text-foreground">Risk Management</strong> — Position sizing, stop placement, profit-taking, capital protection</li>
            <li><strong className="text-foreground">Advanced Strategies</strong> — Trend continuation, lock and reload, live trade walkthroughs, prop firms</li>
            <li><strong className="text-foreground">Psychology & Review</strong> — Burnout, stress management, Q&A sessions</li>
          </ol>
        </section>

        <section className="space-y-4 text-muted-foreground leading-relaxed">
          <h2 className="font-display text-2xl font-semibold text-foreground">How does it work?</h2>
          <ol className="list-decimal pl-6 space-y-2">
            <li>Purchase the course with a one-time payment</li>
            <li>Receive a magic login link via email (no password needed)</li>
            <li>Access your personal course portal with all 25 lessons</li>
            <li>Watch lessons in order — each builds on the previous one</li>
            <li>Track your progress and mark lessons as complete</li>
            <li>Rewatch any lesson at any time</li>
          </ol>
        </section>

        <section className="space-y-4 text-muted-foreground leading-relaxed">
          <h2 className="font-display text-2xl font-semibold text-foreground">Pricing</h2>
          <p>
            The course is available for a one-time payment of $149 (limited-time introductory price). The price increases to $199 on April 1, 2026. There are no subscriptions, monthly fees, or hidden upsells.
          </p>
          <p>
            A 30-day money-back guarantee is included. If you're not satisfied, email for a full refund — no questions asked.
          </p>
        </section>

        <section className="space-y-4 text-muted-foreground leading-relaxed">
          <h2 className="font-display text-2xl font-semibold text-foreground">Frequently asked questions</h2>

          <div className="space-y-6">
            <div>
              <h3 className="font-display text-lg font-semibold text-foreground">Will this course make me profitable?</h3>
              <p>No course can guarantee profits. This gives you a repeatable process and the frameworks used in live markets every day. Whether you put in the screen time is up to you.</p>
            </div>
            <div>
              <h3 className="font-display text-lg font-semibold text-foreground">I'm a complete beginner. Will I be able to follow along?</h3>
              <p>Yes. The course starts from zero — what a candlestick is, how markets move, what support and resistance mean. Every lesson builds on the last, and every video has a plain-language summary.</p>
            </div>
            <div>
              <h3 className="font-display text-lg font-semibold text-foreground">How much time does this take?</h3>
              <p>The full course is 25 video lessons. Most students finish in 2-3 weeks at a pace of 2-3 lessons per day. You have lifetime access, so there's no rush.</p>
            </div>
            <div>
              <h3 className="font-display text-lg font-semibold text-foreground">What's the refund policy?</h3>
              <p>If you go through the first 10 lessons and feel it's not worth $149, email within 30 days for a full refund. No hoops, no exit survey.</p>
            </div>
            <div>
              <h3 className="font-display text-lg font-semibold text-foreground">How is this different from free YouTube content?</h3>
              <p>Free content is scattered. This course is one coherent system taught in order where each lesson connects to the next.</p>
            </div>
            <div>
              <h3 className="font-display text-lg font-semibold text-foreground">Is this a subscription?</h3>
              <p>No. One payment. Lifetime access. No monthly fees. No upsells.</p>
            </div>
            <div>
              <h3 className="font-display text-lg font-semibold text-foreground">Does this work for crypto / forex / options?</h3>
              <p>The strategies are taught using stock examples, but the core principles — market structure, price action, risk management, psychology — apply to any market.</p>
            </div>
          </div>
        </section>

        <section className="space-y-4 text-muted-foreground leading-relaxed">
          <h2 className="font-display text-2xl font-semibold text-foreground">Contact & support</h2>
          <p>
            For questions, support, or refund requests, email <a href="mailto:sls25trading@gmail.com" className="text-primary underline hover:text-primary/80">sls25trading@gmail.com</a>.
          </p>
        </section>

        <section className="space-y-4 text-muted-foreground leading-relaxed">
          <h2 className="font-display text-2xl font-semibold text-foreground">Important links</h2>
          <ul className="space-y-2">
            <li><Link to="/" className="text-primary underline hover:text-primary/80">Homepage — Course overview and purchase</Link></li>
            <li><Link to="/login" className="text-primary underline hover:text-primary/80">Student login</Link></li>
            <li><Link to="/terms" className="text-primary underline hover:text-primary/80">Terms of Service</Link></li>
            <li><Link to="/privacy" className="text-primary underline hover:text-primary/80">Privacy Policy</Link></li>
          </ul>
        </section>
      </main>

      <footer className="border-t border-border py-8 text-center text-sm text-muted-foreground space-y-2">
        <p>© {new Date().getFullYear()} SLS Trading. All rights reserved.</p>
        <nav className="flex items-center justify-center gap-4">
          <Link to="/" className="hover:text-foreground transition-colors">Home</Link>
          <span>·</span>
          <Link to="/terms" className="hover:text-foreground transition-colors">Terms</Link>
          <span>·</span>
          <Link to="/privacy" className="hover:text-foreground transition-colors">Privacy</Link>
        </nav>
      </footer>

      {/* JSON-LD: Organization */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify({
            "@context": "https://schema.org",
            "@type": "Organization",
            name: "SLS Trading",
            url: "https://id-preview--73ba5023-6123-45a4-bf22-4e15fce90d6e.lovable.app",
            description: "SLS Trading offers a structured day trading course for beginners with 25 video lessons covering market structure, entries, risk management, and trading psychology.",
            contactPoint: {
              "@type": "ContactPoint",
              email: "sls25trading@gmail.com",
              contactType: "customer support",
            },
          }),
        }}
      />

      {/* JSON-LD: FAQPage */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify({
            "@context": "https://schema.org",
            "@type": "FAQPage",
            mainEntity: [
              {
                "@type": "Question",
                name: "Will this course make me profitable?",
                acceptedAnswer: {
                  "@type": "Answer",
                  text: "No course can guarantee profits. This gives you a repeatable process and the frameworks used in live markets every day. Whether you put in the screen time is up to you.",
                },
              },
              {
                "@type": "Question",
                name: "I'm a complete beginner. Will I be able to follow along?",
                acceptedAnswer: {
                  "@type": "Answer",
                  text: "Yes. The course starts from zero — what a candlestick is, how markets move, what support and resistance mean. Every lesson builds on the last, and every video has a plain-language summary.",
                },
              },
              {
                "@type": "Question",
                name: "What's the refund policy?",
                acceptedAnswer: {
                  "@type": "Answer",
                  text: "If you go through the first 10 lessons and feel it's not worth $149, email within 30 days for a full refund. No hoops, no exit survey.",
                },
              },
              {
                "@type": "Question",
                name: "Is this a subscription?",
                acceptedAnswer: {
                  "@type": "Answer",
                  text: "No. One payment. Lifetime access. No monthly fees. No upsells.",
                },
              },
            ],
          }),
        }}
      />
    </div>
  );
};

export default About;
