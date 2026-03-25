// Date-based pricing logic for SLS Trading Course
// Switches automatically from Early Bird ($149) to Regular ($199) on April 1, 2026

const EARLY_BIRD_DEADLINE = new Date("2026-04-01T00:00:00-05:00"); // America/Chicago

export function isEarlyBird(): boolean {
  return new Date() < EARLY_BIRD_DEADLINE;
}

export function getActivePrice(): number {
  return isEarlyBird() ? 149 : 199;
}

export function getCheckoutUrl(): string {
  return isEarlyBird()
    ? "https://buy.stripe.com/8x2dR28179hqbAQbv56J200"
    : "https://buy.stripe.com/5kQeV66X351a34kfLl6J201";
}

export function getCtaText(): string {
  return `Start Learning — $${getActivePrice()}`;
}

export function getPriceNote(): string {
  if (isEarlyBird()) {
    return "$149 until April 1 — then it's $199. One payment, yours forever.";
  }
  return "One payment of $199. Yours forever.";
}

export function getStrikethroughPrice(): number | null {
  return isEarlyBird() ? 199 : null;
}
