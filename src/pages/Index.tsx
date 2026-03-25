import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Link } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import SEOHead from "@/components/SEOHead";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { getCheckoutUrl, getCtaText, getPriceNote, getActivePrice, getStrikethroughPrice, isEarlyBird } from "@/lib/pricing";

interface VideoMeta {
  id: string;
  title: string;
  description: string;
  sort_order: number;
  module: string;
  summary: string;
}

const Index = () => {
  const [modules, setModules] = useState<Record<string, VideoMeta[]>>({});
  const [loadingCurriculum, setLoadingCurriculum] = useState(true);

  useEffect(() => {
    const load = async () => {
      const { data, error } = await supabase.rpc("get_course_videos");
      if (!error && data) {
        const grouped: Record<string, VideoMeta[]> = {};
        (data as VideoMeta[]).forEach((v) => {
          if (!grouped[v.module]) grouped[v.module] = [];
          grouped[v.module].push(v);
        });
        setModules(grouped);
      }
      setLoadingCurriculum(false);
    };
    load();
  }, []);

  const moduleNames = Object.keys(modules);
  const totalVideos = Object.values(modules).reduce((sum, vids) => sum + vids.length, 0);

  return (
    <div className="min-h-screen bg-background">
      <SEOHead
        title="SLS Trading Course | Learn Day Trading With a Real Plan"
        description="Learn day trading with a step-by-step course built for beginners. 25 video lessons, plain-language summaries, searchable transcripts, risk management training. $149 one-time payment."
        path="/"
      />

      {/* Nav */}
      <nav className="mx-auto max-w-6xl px-4 py-6 flex items-center justify-between">
        <Link to="/" className="font-display text-xl font-semibold text-foreground">SLS Trading</Link>
        <div className="flex items-center gap-4">
          <Link to="/about" className="text-sm text-muted-foreground hover:text-foreground transition-colors">
            About
          </Link>
          <Link to="/login" className="text-sm text-muted-foreground hover:text-foreground transition-colors">
            Sign In
          </Link>
        </div>
      </nav>

      {/* Hero */}
      <section className="mx-auto max-w-4xl px-4 py-16 md:py-24 text-center space-y-6">
        <p className="font-script text-primary text-2xl">Stop guessing. Start trading with a plan.</p>
        <h1 className="font-display text-4xl md:text-5xl lg:text-6xl font-bold text-foreground leading-tight">
          The Day Trading Course That Skips the Fluff
        </h1>
        <p className="text-lg md:text-xl text-muted-foreground max-w-2xl mx-auto leading-relaxed">
          {totalVideos} video lessons. Real strategies that work in live markets. Built for people who are tired of watching random YouTube videos and still losing money.
        </p>
        <div className="pt-4 space-y-3">
          <Button variant="cta" size="lg" className="text-lg px-10 py-6" asChild>
            <a href={getCheckoutUrl()}>
              {getCtaText()}
            </a>
          </Button>
          <p className="text-sm text-muted-foreground">
            {isEarlyBird() ? (
              <><span className="text-destructive font-medium">${getActivePrice()} until April 1</span> — then it's $199. One payment, yours forever.</>
            ) : (
              <>One payment of ${getActivePrice()}. Yours forever.</>
            )}
          </p>
        </div>
      </section>

      {/* Problem Section */}
      <section className="mx-auto max-w-4xl px-4 py-16">
        <div className="text-center mb-10">
          <h2 className="font-display text-3xl md:text-4xl font-semibold text-foreground mb-4">
            Sound familiar?
          </h2>
        </div>
        <div className="grid gap-4 sm:grid-cols-2 max-w-3xl mx-auto">
          {[
            "You've watched 200+ hours of free trading content and still don't have a system",
            "You know what a candlestick is but can't explain why you entered your last trade",
            "You've blown an account (or two) because nobody taught you risk management first",
            "You're stuck paper trading because you don't trust your own analysis yet",
          ].map((pain, i) => (
            <div key={i} className="flex items-start gap-3 rounded-lg bg-card border border-border p-5">
              <span className="text-destructive text-lg mt-0.5">✕</span>
              <p className="text-muted-foreground text-sm leading-relaxed">{pain}</p>
            </div>
          ))}
        </div>
        <p className="text-center text-muted-foreground mt-8 text-lg max-w-xl mx-auto">
          The problem isn't effort. It's structure. You need someone to lay it out in order — from the basics to the psychology — so each concept builds on the last.
        </p>
      </section>

      {/* What You Get */}
      <section className="mx-auto max-w-5xl px-4 py-16">
        <div className="text-center mb-12">
          <p className="font-script text-primary text-xl mb-2">Here's what's inside</p>
          <h2 className="font-display text-3xl md:text-4xl font-semibold text-foreground">
            {totalVideos} Lessons Across {moduleNames.length} Modules
          </h2>
          <p className="text-muted-foreground mt-3 max-w-2xl mx-auto">
            Each lesson comes with a written summary in plain language and a full transcript you can search. No filler. Every minute counts.
          </p>
        </div>
        {loadingCurriculum ? (
          <p className="text-center text-muted-foreground">Loading curriculum...</p>
        ) : (
          <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {moduleNames.map((mod) => (
              <div
                key={mod}
                className="rounded-lg bg-card border border-border p-6 shadow-sm"
              >
                <h3 className="font-display text-xl font-semibold text-foreground mb-3">
                  {mod}
                </h3>
                <ul className="space-y-2">
                  {modules[mod].map((video) => (
                    <li key={video.id} className="flex items-start gap-2 text-sm text-muted-foreground">
                      <span className="text-primary mt-0.5">•</span>
                      {video.title}
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
        )}
      </section>

      {/* Who This Is For / Not For */}
      <section className="mx-auto max-w-4xl px-4 py-16">
        <div className="text-center mb-10">
          <h2 className="font-display text-3xl md:text-4xl font-semibold text-foreground">
            Is this right for you?
          </h2>
          <p className="text-muted-foreground mt-3">Honestly? It's not for everyone. And that's the point.</p>
        </div>
        <div className="grid gap-6 sm:grid-cols-2">
          <div className="rounded-lg bg-card border border-border p-6">
            <h3 className="font-display text-lg font-semibold text-foreground mb-4 flex items-center gap-2">
              <span className="text-success">✓</span> This is for you if:
            </h3>
            <ul className="space-y-3">
              {[
                "You're serious about learning to trade — not looking for a magic indicator",
                "You're willing to study the material, replay the lessons, and practice",
                "You want a clear path from \"I know nothing\" to \"I have a repeatable process\"",
                "You understand that consistency beats home runs",
                "You're ready to treat trading like a skill, not a slot machine",
              ].map((item, i) => (
                <li key={i} className="flex items-start gap-2 text-sm text-muted-foreground">
                  <span className="text-success mt-0.5 flex-shrink-0">✓</span>
                  {item}
                </li>
              ))}
            </ul>
          </div>
          <div className="rounded-lg bg-card border border-border p-6">
            <h3 className="font-display text-lg font-semibold text-foreground mb-4 flex items-center gap-2">
              <span className="text-destructive">✕</span> Not for you if:
            </h3>
            <ul className="space-y-3">
              {[
                "You think buying a course = becoming profitable overnight",
                "You want someone to tell you exactly when to buy and sell (this isn't a signal group)",
                "You're not willing to put in screen time practicing what you learn",
                "You're looking for a get-rich-quick shortcut",
                "You'd rather blame the market than improve your process",
              ].map((item, i) => (
                <li key={i} className="flex items-start gap-2 text-sm text-muted-foreground">
                  <span className="text-destructive mt-0.5 flex-shrink-0">✕</span>
                  {item}
                </li>
              ))}
            </ul>
          </div>
        </div>
      </section>

      {/* Pricing */}
      <section className="mx-auto max-w-3xl px-4 py-16 text-center">
        <div className="rounded-lg bg-card border-2 border-primary p-8 md:p-12 shadow-md relative">
          {/* Money-back guarantee badge */}
          <div className="absolute -top-4 left-1/2 -translate-x-1/2">
            <span className="inline-flex items-center gap-1.5 bg-success text-card px-4 py-1.5 rounded-full text-sm font-medium shadow-sm">
              <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
              </svg>
              30-Day Money-Back Guarantee
            </span>
          </div>

          <p className="font-script text-primary text-xl mb-2 mt-2">One-time payment</p>
          <h2 className="font-display text-3xl md:text-4xl font-semibold text-foreground mb-4">
            Full Course Access
          </h2>
          <div className="flex items-baseline justify-center gap-3 mb-2">
            <span className="text-4xl md:text-5xl font-display font-bold text-foreground">${getActivePrice()}</span>
            {getStrikethroughPrice() && (
              <span className="text-xl text-muted-foreground line-through">${getStrikethroughPrice()}</span>
            )}
          </div>
          {isEarlyBird() && (
            <p className="text-sm text-destructive font-medium mb-6">
              Price goes to $199 on April 1. No exceptions.
            </p>
          )}
          {!isEarlyBird() && <div className="mb-6" />}
          <ul className="text-left max-w-sm mx-auto space-y-3 mb-8">
            {[
              `${totalVideos} video lessons — watch at your own pace`,
              "Plain-language summaries for every single lesson",
              "Full searchable transcripts included",
              `${moduleNames.length} modules from market basics to trading psychology`,
              "Lifetime access — rewatch whenever you want",
              "30-day money-back guarantee, no questions asked",
            ].map((item) => (
              <li key={item} className="flex items-start gap-2 text-muted-foreground">
                <svg className="h-5 w-5 text-primary mt-0.5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                </svg>
                {item}
              </li>
            ))}
          </ul>
          <Button variant="cta" size="lg" className="text-lg px-10 py-6" asChild>
            <a href={STRIPE_CHECKOUT_URL} target="_blank" rel="noopener noreferrer">
              Start Learning — $149
            </a>
          </Button>
          <p className="text-xs text-muted-foreground mt-4">
            One payment. No subscriptions. No upsells.
          </p>
        </div>
      </section>

      {/* FAQ */}
      <section className="mx-auto max-w-3xl px-4 py-16">
        <div className="text-center mb-10">
          <p className="font-script text-primary text-xl mb-2">Questions?</p>
          <h2 className="font-display text-3xl md:text-4xl font-semibold text-foreground">
            Frequently Asked Questions
          </h2>
        </div>
        <Accordion type="single" collapsible className="w-full">
          <AccordionItem value="results">
            <AccordionTrigger className="font-display text-lg text-foreground text-left">
              Will this course make me profitable?
            </AccordionTrigger>
            <AccordionContent className="text-muted-foreground leading-relaxed">
              Here's the honest answer: no course can guarantee profits. Anyone who promises that is selling you something worse than a course. What this will give you is a repeatable process — the same frameworks and setups that work in live markets every day. Whether you put in the screen time to master them is up to you. Most traders fail because they skip the fundamentals. This course doesn't let you skip anything.
            </AccordionContent>
          </AccordionItem>
          <AccordionItem value="beginner">
            <AccordionTrigger className="font-display text-lg text-foreground text-left">
              I'm a complete beginner. Will I be able to follow along?
            </AccordionTrigger>
            <AccordionContent className="text-muted-foreground leading-relaxed">
              Yes. The course starts from zero — what a candlestick is, how markets move, what support and resistance actually mean. Every lesson builds on the last. And every video includes a plain-language summary written for people who have never placed a trade. You won't feel lost.
            </AccordionContent>
          </AccordionItem>
          <AccordionItem value="time">
            <AccordionTrigger className="font-display text-lg text-foreground text-left">
              How much time does this take?
            </AccordionTrigger>
            <AccordionContent className="text-muted-foreground leading-relaxed">
              The full course is {totalVideos} video lessons. You could binge it in a weekend, but I'd recommend going through 2-3 lessons per day and practicing what you learn before moving on. Most students finish in 2-3 weeks at that pace. You have lifetime access, so there's no rush.
            </AccordionContent>
          </AccordionItem>
          <AccordionItem value="refund">
            <AccordionTrigger className="font-display text-lg text-foreground text-left">
              What's your refund policy?
            </AccordionTrigger>
            <AccordionContent className="text-muted-foreground leading-relaxed">
              Simple: if you go through the first 10 lessons and honestly feel like it's not worth $149, email us within 30 days and we'll refund every penny. No hoops to jump through. No "exit survey" required. We'd rather give your money back than have an unhappy student.
            </AccordionContent>
          </AccordionItem>
          <AccordionItem value="different">
            <AccordionTrigger className="font-display text-lg text-foreground text-left">
              How is this different from free YouTube content?
            </AccordionTrigger>
            <AccordionContent className="text-muted-foreground leading-relaxed">
              Free content is scattered. You watch a video on RSI, then one on price action from a different person with a different strategy, then something about options that contradicts what you learned yesterday. This course is one coherent system, taught in order, where each lesson connects to the next. It's the difference between having a textbook and having 500 random pages from different textbooks.
            </AccordionContent>
          </AccordionItem>
          <AccordionItem value="access">
            <AccordionTrigger className="font-display text-lg text-foreground text-left">
              How do I access the course after purchase?
            </AccordionTrigger>
            <AccordionContent className="text-muted-foreground leading-relaxed">
              After payment, you'll enter your email on the confirmation page. We'll send you a magic login link — click it and you're in. No password to remember. Your portal shows every lesson organized by module, tracks your progress, and lets you pick up right where you left off.
            </AccordionContent>
          </AccordionItem>
          <AccordionItem value="subscription">
            <AccordionTrigger className="font-display text-lg text-foreground text-left">
              Is this a subscription? Are there hidden costs?
            </AccordionTrigger>
            <AccordionContent className="text-muted-foreground leading-relaxed">
              No. It's one payment of $149 (or $199 after April 1). You get lifetime access to everything. No monthly fees. No "premium tier" upsell. No locked modules. Everything is included from day one.
            </AccordionContent>
          </AccordionItem>
          <AccordionItem value="crypto">
            <AccordionTrigger className="font-display text-lg text-foreground text-left">
              Does this work for crypto / forex / options?
            </AccordionTrigger>
            <AccordionContent className="text-muted-foreground leading-relaxed">
              The strategies are taught using stock examples, but the core principles — market structure, price action, risk management, psychology — apply to any market. If you can read a chart, you can trade any instrument. Several students use these same frameworks for crypto and futures.
            </AccordionContent>
          </AccordionItem>
        </Accordion>
      </section>

      {/* Final CTA */}
      <section className="mx-auto max-w-4xl px-4 py-16 text-center space-y-6">
        <h2 className="font-display text-3xl md:text-4xl font-semibold text-foreground">
          You've read this far for a reason.
        </h2>
        <p className="text-muted-foreground text-lg max-w-xl mx-auto">
          You already know you need structure. You already know random YouTube isn't cutting it. The only question is whether you'll start today or keep doing what isn't working.
        </p>
        <div className="space-y-3">
          <Button variant="cta" size="lg" className="text-lg px-10 py-6" asChild>
            <a href={STRIPE_CHECKOUT_URL} target="_blank" rel="noopener noreferrer">
              Start Learning — $149
            </a>
          </Button>
          <p className="text-xs text-muted-foreground">
            30-day money-back guarantee · One payment · Lifetime access
          </p>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-border py-8 text-center text-sm text-muted-foreground space-y-2">
        <p>© {new Date().getFullYear()} SLS Trading. All rights reserved.</p>
        <nav className="flex items-center justify-center gap-4">
          <Link to="/about" className="hover:text-foreground transition-colors">About</Link>
          <span>·</span>
          <Link to="/terms" className="hover:text-foreground transition-colors">Terms of Service</Link>
          <span>·</span>
          <Link to="/privacy" className="hover:text-foreground transition-colors">Privacy Policy</Link>
          <span>·</span>
          <a href="mailto:sls25trading@gmail.com" className="hover:text-foreground transition-colors">Contact</a>
        </nav>
      </footer>

      {/* JSON-LD: WebSite */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify({
            "@context": "https://schema.org",
            "@type": "WebSite",
            name: "SLS Trading",
            url: "https://id-preview--73ba5023-6123-45a4-bf22-4e15fce90d6e.lovable.app",
          }),
        }}
      />

      {/* JSON-LD: Course */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify({
            "@context": "https://schema.org",
            "@type": "Course",
            name: "SLS Trading Day Trading Course",
            description: "A structured, step-by-step day trading course with 25 video lessons covering market structure, entries, risk management, and trading psychology. Built for beginners.",
            provider: {
              "@type": "Organization",
              name: "SLS Trading",
              url: "https://id-preview--73ba5023-6123-45a4-bf22-4e15fce90d6e.lovable.app",
            },
            url: "https://id-preview--73ba5023-6123-45a4-bf22-4e15fce90d6e.lovable.app",
            courseMode: "online",
            offers: {
              "@type": "Offer",
              price: "149",
              priceCurrency: "USD",
              availability: "https://schema.org/InStock",
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
                acceptedAnswer: { "@type": "Answer", text: "No course can guarantee profits. What this will give you is a repeatable process — the same frameworks and setups that work in live markets every day. Whether you put in the screen time to master them is up to you." },
              },
              {
                "@type": "Question",
                name: "I'm a complete beginner. Will I be able to follow along?",
                acceptedAnswer: { "@type": "Answer", text: "Yes. The course starts from zero — what a candlestick is, how markets move, what support and resistance actually mean. Every lesson builds on the last. And every video includes a plain-language summary written for people who have never placed a trade." },
              },
              {
                "@type": "Question",
                name: "How much time does this take?",
                acceptedAnswer: { "@type": "Answer", text: `The full course is ${totalVideos} video lessons. Most students finish in 2-3 weeks at a pace of 2-3 lessons per day. You have lifetime access, so there's no rush.` },
              },
              {
                "@type": "Question",
                name: "What's your refund policy?",
                acceptedAnswer: { "@type": "Answer", text: "If you go through the first 10 lessons and feel it's not worth $149, email within 30 days for a full refund. No hoops, no exit survey." },
              },
              {
                "@type": "Question",
                name: "How is this different from free YouTube content?",
                acceptedAnswer: { "@type": "Answer", text: "Free content is scattered. This course is one coherent system, taught in order, where each lesson connects to the next." },
              },
              {
                "@type": "Question",
                name: "Is this a subscription? Are there hidden costs?",
                acceptedAnswer: { "@type": "Answer", text: `No. One payment of $149. Lifetime access. No monthly fees. No upsells.` },
              },
              {
                "@type": "Question",
                name: "Does this work for crypto / forex / options?",
                acceptedAnswer: { "@type": "Answer", text: "The strategies are taught using stock examples, but the core principles — market structure, price action, risk management, psychology — apply to any market." },
              },
            ],
          }),
        }}
      />

      {/* JSON-LD: BreadcrumbList */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify({
            "@context": "https://schema.org",
            "@type": "BreadcrumbList",
            itemListElement: [
              { "@type": "ListItem", position: 1, name: "Home", item: "https://id-preview--73ba5023-6123-45a4-bf22-4e15fce90d6e.lovable.app/" },
            ],
          }),
        }}
      />
    </div>
  );
};

export default Index;
