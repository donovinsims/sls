import { Link } from "react-router-dom";
import SEOHead from "@/components/SEOHead";

const Privacy = () => {
  return (
    <div className="min-h-screen bg-background">
      <SEOHead title="Privacy Policy | SLS Trading" description="Privacy Policy for SLS Trading. Learn how we collect, use, and protect your personal information when you use the SLS Trading course." path="/privacy" />
      <header className="mx-auto max-w-3xl px-4 py-6">
        <Link to="/" className="text-sm text-muted-foreground hover:text-foreground transition-colors">
          ← Back to Home
        </Link>
      </header>

      <main className="mx-auto max-w-3xl px-4 py-8 pb-20 space-y-8">
        <h1 className="font-display text-4xl font-semibold text-foreground">Privacy Policy</h1>
        <p className="text-sm text-muted-foreground">Last updated: March 24, 2026</p>

        <div className="space-y-6 text-muted-foreground leading-relaxed">
          <section className="space-y-3">
            <h2 className="font-display text-xl font-semibold text-foreground">1. Information We Collect</h2>
            <p>
              When you purchase or use the SLS Trading course, we collect the following information:
            </p>
            <ul className="list-disc pl-6 space-y-1">
              <li><strong className="text-foreground">Email address</strong> — used for account creation, login, and communication about your purchase</li>
              <li><strong className="text-foreground">Payment information</strong> — processed securely by Stripe; we do not store your credit card details</li>
              <li><strong className="text-foreground">Usage data</strong> — which videos you watch, when you watch them, and your course progress</li>
              <li><strong className="text-foreground">Device and network information</strong> — IP addresses, browser type, and device identifiers for security and anti-piracy purposes</li>
            </ul>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-semibold text-foreground">2. How We Use Your Information</h2>
            <ul className="list-disc pl-6 space-y-1">
              <li>To provide and maintain your course access</li>
              <li>To send you login links and important account communications</li>
              <li>To track your course progress so you can pick up where you left off</li>
              <li>To detect and prevent unauthorized access, account sharing, and piracy</li>
              <li>To improve the Course content and user experience</li>
            </ul>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-semibold text-foreground">3. Data Security</h2>
            <p>
              We use industry-standard security measures to protect your personal information, including encrypted connections (HTTPS/TLS), secure authentication via magic links (no passwords stored), and role-based access controls on our database. However, no method of transmission over the internet is 100% secure, and we cannot guarantee absolute security.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-semibold text-foreground">4. Third-Party Services</h2>
            <p>We use the following third-party services to operate the Course:</p>
            <ul className="list-disc pl-6 space-y-1">
              <li><strong className="text-foreground">Stripe</strong> — payment processing (<a href="https://stripe.com/privacy" className="text-primary underline hover:text-primary/80" target="_blank" rel="noopener noreferrer">Stripe Privacy Policy</a>)</li>
              <li><strong className="text-foreground">Google (YouTube)</strong> — video hosting via embedded player</li>
              <li><strong className="text-foreground">Google OAuth</strong> — optional sign-in method</li>
            </ul>
            <p>
              These services may collect information as described in their own privacy policies. We do not sell your personal information to any third party.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-semibold text-foreground">5. Cookies and Tracking</h2>
            <p>
              We use essential cookies and local storage to maintain your login session and track your course progress. We do not use advertising cookies or third-party tracking pixels. The YouTube embedded player may set its own cookies as governed by Google's privacy policy.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-semibold text-foreground">6. Data Retention</h2>
            <p>
              We retain your account information and course progress for as long as your account is active. If you request account deletion, we will remove your personal data within 30 days, except where we are required to retain it for legal or security purposes (such as fraud prevention logs).
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-semibold text-foreground">7. Your Rights</h2>
            <p>You have the right to:</p>
            <ul className="list-disc pl-6 space-y-1">
              <li>Access the personal data we hold about you</li>
              <li>Request correction of inaccurate data</li>
              <li>Request deletion of your account and personal data</li>
              <li>Withdraw consent for non-essential data processing</li>
            </ul>
            <p>
              To exercise any of these rights, contact us at the email below.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-semibold text-foreground">8. Children's Privacy</h2>
            <p>
              The Course is not intended for individuals under 18 years of age. We do not knowingly collect personal information from children. If we become aware that we have collected data from a person under 18, we will delete that information promptly.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-semibold text-foreground">9. Changes to This Policy</h2>
            <p>
              We may update this Privacy Policy from time to time. We will notify you of material changes by posting the updated policy on this page with a new "Last updated" date. Your continued use of the Course constitutes acceptance of the updated policy.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-semibold text-foreground">10. Contact</h2>
            <p>
              For privacy-related questions or requests, contact us at <a href="mailto:sls25trading@gmail.com" className="text-primary hover:text-primary/80 transition-colors underline">sls25trading@gmail.com</a>.
            </p>
          </section>
        </div>
      </main>

      <footer className="border-t border-border py-8 text-center text-sm text-muted-foreground">
        <p>© {new Date().getFullYear()} SLS Trading. All rights reserved.</p>
      </footer>
    </div>
  );
};

export default Privacy;
