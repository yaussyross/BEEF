# BEEF — Store Production Assets

All store-facing visuals for the iOS (App Store) + Android (Google Play) launch.
Everything was produced from the existing brand direction (`brand-style-brief.md`, `hero-concept.md`)
and the existing on-brand model set (`beef-model-0*.jpg`). **No new model photography was generated —
all imagery is remixed from the 6 existing tasteful, non-explicit model images.**

## Palette & type
- **Colors (exact from brief):** Steak Red `#D62839`, Sizzle Orange `#F77F00`, Berry Punch `#B3146B`
  (hero gradient), Char ink `#1E1B18`, Cream `#FBF3E8`, Margarita Lime `#A4C639`, Beef Brown `#6F2A1E`.
- **Display type:** Unbounded 900 (Black). **Body/UI:** Space Grotesk. Both are the brief's
  "Google Fonts" fallback pairing. Working copies of the variable TTFs are saved in `fonts/`.

## Files

### App icon
| File | Purpose |
|------|---------|
| `app-icon-1024.png` (1024×1024, RGB, no alpha) | Master icon — the BEEF wordmark in Cream on the red→orange→berry hero gradient. **Do not pre-round or add transparent corners — the stores apply their own masking.** |

**Small-size note (read this):** The icon is the bare "BEEF" wordmark in Unbounded 900 set very large
against a high-contrast warm gradient, with a tiny lime "sizzle spark" accent. There is no thin type
and no fine detail, so it stays legible at 20–29 pt (home-screen) and at 16 pt (search/settings). The
four bold letterspaced caps are the only element that must survive; nothing else is load-bearing.

### Onboarding screens (4) — 1290×2796 portrait (iPhone 6.7"/scaleable canvas)
| File | Screen | Copy |
|------|--------|------|
| `onboarding-1-18plus.png` | 18+ gate | "Prove you're legal." / big red **18+** stamp / "BEEF is a strictly 18+ space, no exceptions…" / CTA "I'm 18 or older" |
| `onboarding-2-intent.png` | Friends · Dates · Hookups | "What's your beef today?" / intent pills Friend·Date·Hookup / "Pick a flavor" |
| `onboarding-3-privacy.png` | Privacy trust | "Your location is yours." / "We never sell your location to advertisers. Coarse mode. Opt-in sharing…" / trust ticks + "Keep it private" |
| `onboarding-4-waitlist.png` | Join waitlist/beta | "Get on the grill." / email field mock + "Join the waitlist" |

### Store-listing screenshots (6) — 1290×2796 portrait (one master set serves both stores)
| File | Feature | Headline copy |
|------|---------|---------------|
| `store-1-grid.png` | Grid proximity | "Nearby guys, one sizzling grid. Local. Fresh. Full of flavor." |
| `store-2-intent.png` | Intent tags | "Friends, dates & hookups." + tag list (gym · bear · travel · brunch …) |
| `store-3-chat.png` | Chat | "No small talk required." |
| `store-4-privacy.png` | Privacy/trust | "Your location is yours." + "Never sold to ad partners" |
| `store-5-discovery.png` | Interest discovery | "Taste your type." |
| `store-6-community.png` | Safety & moderation | "A wink, not a leer." (18+ verified · block & report · photo check · community rules) |

Each store screenshot carries a consistent brand footer tagline **"A CUT ABOVE THE REST."** and the
BEEF logo bar, so the set reads as one campaign.

## Resize the engineer must do per store
- **Master canvas:** all onboarding + screenshots are 1290×2796 (6.7″ class, same aspect ~0.461).
  These are clean portrait PNGs with a chart-flat layout — safe to downscale without reflow.
- **App Store (as of this build):**
  - 6.7″ display: 1290×2796 → use as-is (this is exactly the iPhone 14 Pro Max / 15-16 Pro Max class).
  - 6.5″ display (2nd slot option): 1242×2688 — resize down, layout holds.
  - 5.5″ display: 1242×2208 — resize down (aspect similar enough); content is top/bottom safe.
- **Google Play:** requires 1080×1920 minimum; upload the 1290×2796 and let Play scale, or resize a
  copy to 1080×2340 (Android flagship) for sharper rendering. Again safe to just scale.
- **Icon:** upload `app-icon-1024.png` directly in both consoles (1024×1024 is the required max).
  Do not add transparency.

Because every screen uses generous margins (≥130 px) and centered text with safe-area padding top and
bottom, a proportional downscale (not crop) is the only resize step needed. Run at 2×/3× rendering
check: at 1290 px wide there is ~430 px per logical pt on a 6.7″ device, so headline text renders crisp.

## Tastefulness / store-safety confirmation
- Nothing explicit or nude anywhere. All people appear fully clothed (fitted athletic wear, tanks,
  bombers, graphic tees) via the existing approved model set. No skin shown beyond shoulders/arms,
  consistent with what's already live on the marketing site.
- "Hookup" is named as an intent tag — permitted for dating apps at the 17+/18+ store ratings this
  product is targeting (same treatment as Grindr/Tinder). All discovery tags (gym, travel, brunch,
  film, bears, etc.) are PG. "A wink, not a leer" is the safety positioning.
- 18+ gating is shown in the onboarding flow (induces the age-gate requirement).
- All text is the established brand voice — campy, saucy-but-smut-free. No false or unverifiable claims.

## Reproducibility
- `build_assets.py` regenerates every asset from the brand tokens + model set (run with Pillow 12).
- `fonts/` holds the Unbounded + Space Grotesk variable TTFs used, for rebuilds/derivatives.
- `contact-sheet.png` is a quick 3-up preview of all 11 assets for review.
