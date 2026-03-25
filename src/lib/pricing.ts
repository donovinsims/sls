// Date-based pricing logic for SLS Trading Course
// Switches automatically from Early Bird ($149) to Regular ($199) on April 1, 2026

const EARLY_BIRD_DEADLINE = new Date("2026-04-01T00:00:00-05:00"); // America/Chicago
const EARLY_BIRD_CHECKOUT_URL =
  import.meta.env.VITE_STRIPE_EARLY_BIRD_LINK ?? "https://buy.stripe.com/8x2dR28179hqbAQbv56J200";
const REGULAR_CHECKOUT_URL =
  import.meta.env.VITE_STRIPE_REGULAR_LINK ?? "https://buy.stripe.com/5kQeV66X351a34kfLl6J201";

export function isEarlyBird(): boolean {
  return new Date() < EARLY_BIRD_DEADLINE;
}

export function getActivePrice(): number {
  return isEarlyBird() ? 149 : 199;
}

export function getCheckoutUrl(): string {
  return isEarlyBird()
    ? EARLY_BIRD_CHECKOUT_URL
    : REGULAR_CHECKOUT_URL;
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
