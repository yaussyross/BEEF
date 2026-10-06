# BEEF — Brand Direction

The visual and voice direction the app and store assets follow. Sources:
`design/brand-style-brief.md`, `design/hero-concept.md`,
`design/store/asset-notes.md`, and the implemented app theme in
`app/lib/theme/` (`beef_colors.dart`, `app_theme.dart`). Where the brief and
the shipped code differ, **the shipped code is authoritative for the app** and
the difference is called out.

## One-line identity
Campy, witty, confident, playful. "Drag brunch meets high fashion" — a wink,
never a leer. Saucy, not smutty; suggestive, never explicit.

**Headline (the brand line): "A cut above the rest."**
Alternates for subheads: "Get your beef on." / "Local. Fresh. Full of flavor."

## Voice
- **Saucy, not smutty** — humor does the flirting; copy never needs to be explicit.
- **Self-aware** — BEEF knows it's a hookup app and says so with a smirk.
- **Puns are currency** — food / butcher / gym / "beef" double-entendres, never forced.
- **Short sentences, punchy rhythm** — app copy reads in taps, not paragraphs.
- **Tone: witty > clever > cute. Never mean, never gatekeeping.**
- Voice examples in the brief: loading "Warming up the grill…", empty grid
  "Nobody here yet. Be the first slab of beef.", CTA "Get on the grill."

## Palette — implemented values (app theme, authoritative for code)
From `app/lib/theme/beef_colors.dart` (hex → Flutter `Color(0x…)`):

| Token | Hex | Dart constant | Use |
|-------|-----|---------------|-----|
| Steak Red (primary) | `#D62839` | `steak` `0xFFD62839` | Primary brand color: buttons, CTAs, brand mark |
| Beefer (deep red) | `#A4161A` | `beefer` `0xFFA4161A` | Deep accents, depth — replaces the brief's "Beef Brown" |
| Sizzle (orange) | `#F77F00` | `sizzle` `0xFFF77F00` | Warm accent: tags, badges, highlights |
| Berry (purple) | `#7B2CBF` | `berry` `0xFF7B2CBF` | Playful accent, gradients |
| Lime | `#B7E318` | `lime` `0xFFB7E318` | Fresh contrast accent ("local freshness", sizzle spark) |
| Cream (background) | `#FDF6E3` | `cream` `0xFFFDF6E3` | Warm off-white background — never cold |
| Char (ink/text) | `#1B1B1B` | `char` `0xFF1B1B1B` | Primary text, near-black ink |

**Deliberate drift from the brief (known and accepted):** the design brief and
the store assets use a slightly different set — Beef Brown `#6F2A1E`, Char
`#1E1B18`, Cream `#FBF3E8`, Margarita Lime `#A4C639`, Berry Punch `#B3146B`.
The app theme implements a tuned-down variant (`beefer`, `char`, `cream`,
`lime`, `berry` above). Steak Red and Sizzle are identical in both. **When
touching app UI, use the Dart constants; when producing store imagery, follow
`design/store/asset-notes.md`** (built from the brief palette). If the drift
ever needs reconciling, `beef_colors.dart` is the single source of truth for code.

**Hero gradient:** Steak Red → Sizzle → Berry (`#D62839 → #F77F00 → #7B2CBF`
in app tokens; `#D62839 → #F77F00 → #B3146B` in store assets). The app icon is
the BEEF wordmark in Cream on this gradient.

## Typography
- **Display / headline:** **Unbounded** (900/Black weight) — bold, geometric,
  letterspaced caps for the brand mark and headlines.
- **Body / UI:** **Space Grotesk** — clean, characterful, legible.
- Both are Google Fonts (free commercial license); the brief's fallback pairing
  if the flagship display face (Clash Display) isn't available. Working TTFs
  ship in `design/store/fonts/` (`Unbounded.ttf`, `SpaceGrotesk.ttf`, plus
  `dl.sh`/`setup.sh`).
- **Not yet bundled in the app:** `app/lib/theme/app_theme.dart` notes that
  bundling the Unbounded / Space Grotesk TTFs is a later polish step — the app
  currently runs on the default font. Bundling is on the roadmap (Phase 1.2).

## Imagery
- Six on-brand model photos live in `backend/public/`
  (`beef-model-01-pink-satin.jpg` … `beef-model-06-neon-yellow.jpg`) — the
  same set the landing page uses; tasteful/cheeky, never nude or explicit.
- ~75% white / ~25% other backgrounds across the set; saturated vibrant color
  grading (magenta, coral, emerald, neon) on warm/urban pieces.
- Editorial high-fashion lighting; confident poses, playful energy; bold
  color-blocking, graphic sunglasses, open shirts, fitted athletic wear.
- **All store/onboarding visuals are remixed from these six images — no new
  model photography** (see `design/store/asset-notes.md`).

## Store assets (ship in `design/store/`)
| File | Purpose |
|------|---------|
| `app-icon-1024.png` | Master icon (1024×1024, RGB, no alpha) — do not pre-round; stores mask it |
| `onboarding-1-18plus.png` … `onboarding-4-waitlist.png` | 1290×2796 onboarding screens (18+ gate → intent → privacy → waitlist) |
| `store-1-grid.png` … `store-6-community.png` | App Store / Play screenshots |
| `contact-sheet.png`, `build_assets.py` | Asset provenance / regeneration tooling |
| `fonts/` | Unbounded + Space Grotesk working TTFs |
| `asset-notes.md` | Exact palette/type per file — read before editing any store asset |

## Mood keywords
Confident · Campy · Witty · Playful · Warm · Appetizing · Fashion-forward ·
Editorial · Glamorous · Bold · Never-explicit · "A wink, not a leer"