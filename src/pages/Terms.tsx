import { Link } from "react-router-dom";

const Terms = () => {
  return (
    <div className="min-h-screen bg-background">
      <header className="mx-auto max-w-3xl px-4 py-6">
        <Link to="/" className="text-sm text-muted-foreground hover:text-foreground transition-colors">
          ← Back to Home
        </Link>
      </header>

      <main className="mx-auto max-w-3xl px-4 py-8 pb-20 space-y-8">
        <h1 className="font-display text-4xl font-semibold text-foreground">Terms of Service</h1>
        <p className="text-sm text-muted-foreground">Last updated: March 24, 2026</p>

        <div className="space-y-6 text-muted-foreground leading-relaxed">
          <section className="space-y-3">
            <h2 className="font-display text-xl font-semibold text-foreground">1. Agreement to Terms</h2>
            <p>
              By purchasing or accessing the SLS Trading day trading course ("the Course"), you agree to be bound by these Terms of Service. If you do not agree with any part of these terms, do not purchase or use the Course.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-semibold text-foreground">2. Course Access</h2>
            <p>
              Upon completing your purchase, you will receive a login link to access the Course portal. Your access is personal and non-transferable. You may not share your login credentials, magic links, or course content with any third party.
            </p>
            <p>
              You are granted a single-user, non-exclusive, non-transferable license to access and view the Course content for personal educational purposes only. This license does not include the right to reproduce, distribute, modify, publicly display, or create derivative works from any Course content.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-semibold text-foreground">3. Payment and Pricing</h2>
            <p>
              The Course is offered as a one-time payment. Prices are listed in USD and are subject to change without notice. Any promotional pricing (including limited-time offers) is valid only during the stated promotional period.
            </p>
            <p>
              All payments are processed securely through Stripe. SLS Trading does not store your credit card information.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-semibold text-foreground">4. Refund Policy</h2>
            <p>
              We offer a 30-day money-back guarantee. If you are unsatisfied with the Course for any reason, contact us within 30 days of your purchase date for a full refund. Refunds will be processed to the original payment method within 5-10 business days.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-semibold text-foreground">5. Intellectual Property</h2>
            <p>
              All Course content — including but not limited to videos, text, graphics, transcripts, summaries, and any other materials — is the intellectual property of SLS Trading and is protected by copyright and other intellectual property laws. Unauthorized reproduction, distribution, screen recording, downloading, or sharing of any Course content is strictly prohibited and may result in immediate termination of your access without refund.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-semibold text-foreground">6. Anti-Piracy</h2>
            <p>
              We actively monitor for unauthorized sharing and access. Your account activity, including IP addresses and device information, may be logged to detect and prevent piracy. Accounts found to be sharing access may be terminated immediately without refund.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-semibold text-foreground">7. Disclaimer — Not Financial Advice</h2>
            <p>
              The Course is for educational purposes only. Nothing in the Course constitutes financial advice, investment advice, trading advice, or any other kind of professional advice. Trading stocks and other financial instruments involves substantial risk of loss and is not suitable for every person. Past performance is not indicative of future results.
            </p>
            <p>
              SLS Trading, its instructors, and affiliates are not registered investment advisors, broker-dealers, or financial planners. You are solely responsible for your own trading and investment decisions. By using the Course, you acknowledge that you understand these risks and agree that SLS Trading shall not be held liable for any losses you incur.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-semibold text-foreground">8. Limitation of Liability</h2>
            <p>
              To the maximum extent permitted by law, SLS Trading and its affiliates shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including without limitation, loss of profits, data, or other intangible losses, resulting from your use of or inability to use the Course.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-semibold text-foreground">9. Account Termination</h2>
            <p>
              We reserve the right to suspend or terminate your account at any time for violation of these Terms, including but not limited to sharing access credentials, pirating content, or engaging in abusive behavior. In the event of termination for cause, no refund will be provided.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-semibold text-foreground">10. Changes to Terms</h2>
            <p>
              We may update these Terms from time to time. We will notify you of any material changes by posting the updated Terms on this page with a new "Last updated" date. Your continued use of the Course after changes are posted constitutes your acceptance of the updated Terms.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-semibold text-foreground">11. Contact</h2>
            <p>
              If you have questions about these Terms, contact us at <a href="mailto:sls25trading@gmail.com" className="text-primary hover:text-primary/80 transition-colors underline">sls25trading@gmail.com</a>.
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

export default Terms;
