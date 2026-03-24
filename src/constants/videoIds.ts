/**
 * Hardcoded backup of all 25 video IDs.
 * NOT used at runtime — videos load from the database.
 * This exists purely as disaster recovery: if the database is wiped,
 * use the "Re-seed Video IDs" button on /admin to restore from this file.
 */
export const VIDEO_BACKUP = Object.freeze([
  { sort_order: 1, title: "START HERE!", module: "Foundations", youtube_id: "rfO1GFfeYRE" },
  { sort_order: 2, title: "Course Overview", module: "Foundations", youtube_id: "e4vjMbwydN8" },
  { sort_order: 3, title: "The Day Trader's Mindset", module: "Foundations", youtube_id: "XbnxvNIzXos" },
  { sort_order: 4, title: "Charts, Timeframes & Tools", module: "Foundations", youtube_id: "CsqWSTEDBss" },
  { sort_order: 5, title: "Understanding Market Structure", module: "Foundations", youtube_id: "DtKYGHp0rbY" },
  { sort_order: 6, title: "Support & Resistance Mastery", module: "Market Structure", youtube_id: "NGndbpyLVbE" },
  { sort_order: 7, title: "S&R In Practice", module: "Market Structure", youtube_id: "FGri77Yq3tU" },
  { sort_order: 8, title: "M's & W's / Chart Patterns", module: "Market Structure", youtube_id: "54JAceqXhuM" },
  { sort_order: 9, title: "BOS vs CHOC", module: "Market Structure", youtube_id: "5Bn1H-fpmPY" },
  { sort_order: 10, title: "High-Probability Entries", module: "Entries & Setups", youtube_id: "QPPtkoxELyQ" },
  { sort_order: 11, title: "EMA Crossings & Signals", module: "Entries & Setups", youtube_id: "adVDa-wZoZg" },
  { sort_order: 12, title: "Fair Value Gaps", module: "Entries & Setups", youtube_id: "e8OX64J0XW8" },
  { sort_order: 13, title: "Confluence vs Strategy", module: "Entries & Setups", youtube_id: "3Qxq1hGdASE" },
  { sort_order: 14, title: "Managing Risk & Securing Profits", module: "Risk Management", youtube_id: "IQ1I4KTfMjs" },
  { sort_order: 15, title: "Taking Profit Options", module: "Risk Management", youtube_id: "w3puLc0Ku38" },
  { sort_order: 16, title: "Liquidity & Stop Placement", module: "Risk Management", youtube_id: "Ld9ex3dT4P8" },
  { sort_order: 17, title: "Payout & Capital Protection", module: "Risk Management", youtube_id: "StAiMkpJgCo" },
  { sort_order: 18, title: "Trading Continuation & Trend", module: "Advanced Strategies", youtube_id: "HkR7qQBXmig" },
  { sort_order: 19, title: "Lock and Reload", module: "Advanced Strategies", youtube_id: "7kjf4V0qFNw" },
  { sort_order: 20, title: "Live Trade Walkthrough", module: "Advanced Strategies", youtube_id: "M0b_9EzBs-A" },
  { sort_order: 21, title: "Prop Firms: Pros & Cons", module: "Advanced Strategies", youtube_id: "plLAKHHYgS4" },
  { sort_order: 22, title: "Eliminate Burnout", module: "Psychology & Review", youtube_id: "0vYM1-RyLjE" },
  { sort_order: 23, title: "Eliminating Stress & Anxiety", module: "Psychology & Review", youtube_id: "qfYVtM8IKqc" },
  { sort_order: 24, title: "Q&A Session 1", module: "Psychology & Review", youtube_id: "QJB-FS89g5Y" },
  { sort_order: 25, title: "Q&A Session 2", module: "Psychology & Review", youtube_id: "eGxtA8SCPPQ" },
]);
