# BEEF — One-Page Hero Concept

## Headline
# A cut above the rest.

## Subheadline (pick one / rotate)
- **Primary:** "The free gay social app for friends, dates, and hookups — local, fresh, and full of flavor."
- Alt A: "Grid-based proximity. Zero small talk required (but we won't judge)."
- Alt B: "Nearby guys, one sizzling grid. Get your beef on."

## CTA
- Primary button: **"Join the waitlist"** (Steak Red `#D62839`, cream text)
- Secondary (text link): "Get a taste first →" pointing to a short value-prop section.

## Campy brand-mark treatment
"**BEEF**" set huge in Unbounded/Clash Display, extended letterspaced caps, Steak Red, with a small hand-scribbled "aged to perfection" in the accent mesh below it. A subtle meat/cut marbling soundmark in the logo's negative space if the dev wants to push it.

---

## Layout sketch (desktop, above the fold)

```
┌─────────────────────────────────────────────────────────────┐
│  [logo: BEEF·aged to perfection]        Waitlist   [hamburger]│
│  ─────────────────────────────────────────────────────────  │
│  LEFT 1/2                          RIGHT 1/2                 │
│  ┌───────────────────┐            ┌───────────────────┐      │
│  │                   │            │   Model imagery    │      │
│  │  A CUT ABOVE      │            │  (overlapping grid  │     │
│  │  THE REST.        │            │  of 2-3 of the       │     │
│  │  [subheadline]    │            │  generated JPEGs,    │     │
│  │                   │            │  angled/blurred      │     │
│  │  J O I N T H E    │            │  like a proximity     │     │
│  │   W A I T L I S T │            │  grid)                │     │
│  │  [small note]     │            └───────────────────┘      │
│  └───────────────────┘                                        │
│   social proof strip: "Free · Ad-supported · For friends,    │
│   dates & hookups" (tiny icons)                              │
└─────────────────────────────────────────────────────────────┘
```

**Key moves:**
1. **Split layout:** left = headline + subhead + waitlist CTA; right = a tilted, overlapping collage of 2–3 model images edge-mounted like cards, echoing the "grid" mental model of the app itself. Rotate the collage on scroll to hint at the live grid.
2. **Campy microcopy** under the button ("Get on the grill — no char required.").
3. **Social proof strip** below: "Free forever · Ad-supported · Friends, dates & hookups · No small talk required."
4. **Gradient wash** of `#D62839 → #F77F00 → #B3146B` behind the headline block, cream background elsewhere, Char text.
5. **Mobile:** stack vertically — headline first, image collage below, CTA pinned; keep the 1:1 JPEGs as square tiles.

## Image → hero mapping (recommend)
- `beef-model-01-pink-satin.jpg` — primary hero (biggest tile, front).
- `beef-model-02-coral-tank.jpg` / `beef-model-05-striped-tee.jpg` — secondary tilted cards.
- `beef-model-03-emerald-bomber.jpg` (Black) & `beef-model-04-hawaiian.jpg` (Latino) — rotate through the grid/marquee to keep ~75/25 representation visible.

---

## Quick copy pass (ready to drop into dev's JSX)
```
Headline:  A cut above the rest.
Subhead:   The free gay social app for friends, dates & hookups —
           local, fresh, and full of flavor.
CTA:       Join the waitlist
Microcopy: Get on the grill — no char required.
Proof:     Free forever · Ad-supported · Friends, dates & hookups
```
