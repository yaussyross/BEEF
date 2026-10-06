# BEEF — Research: ad/store policy & market constraints

**Team research, not owner-ratified strategy.** Condensed from the researcher's
brief (persisted at handoff). These are findings + sources that *constrain the
product*; the strategy they support lives in `docs/BUSINESS.md` (owner-endorsed)
and the build order in `docs/ROADMAP.md`.

> Time-sensitive items (Grindr financials, FTC/Norway settlement status, exact
> ad-network policy text, CPMs) were grounded in the researcher's trained
> knowledge as of the research date and **must be verified against live sources
> before being relied on** (SEC filings, policy pages, regulator press
> releases).

## The three constraints that shape BEEF

1. **Store policy: dating OK, sexually explicit content banned.**
   - **Google AdMob** allows dating apps but **prohibits sexually explicit /
     adult content**; personalized ads are restricted on sensitive categories
     like dating (lower targeting, lower eCPM).
   - **Apple App Store**: dating is a recognized 17+ category; sexually
     explicit material is not allowed (Guideline 1.1.1); UGC apps must be
     moderated with blocking + reporting (Guideline 1.1.4).
   - **Google AdSense (web display) is effectively unavailable for dating**
     publishers — relevant only to the landing page, not the app.
   - **Meta Audience Network** restricts dating broadly (approval friction, low
     fill). Game-oriented networks (Unity, ironSource, AppLovin, etc.) disallow
     adult content; dating-adjacent fill is weak — use mediation if aggregated.
   - **Consequence:** to be on the stores *and* earn programmatic ad dollars,
     BEEF's core must be **suggestive-not-explicit, moderated, 18+ gated**.
     This is a design constraint, not an afterthought — it is enforced in the
     architecture (18+ trigger at the DB layer, keyword moderation,
     provenance-checked tasteful imagery).
   - **Adult ad networks are a strategic trap** (TrafficJunky, ExoClick,
     JuicyAds…): explicit ads risk Apple/Google removing the app, killing all
     distribution/revenue, and degrade the premium brand. Do not use them.

2. **The Grindr privacy precedent drives the privacy-first architecture.**
   - **Norway DPA (Datatilsynet):** Grindr fined for sharing users' precise
     geolocation + other personal data with ad partners without valid consent —
     GDPR violation (fine initially ~100M NOK ≈ €10M, later reduced — verify
     final amount).
   - **US FTC (2024):** proposed settlement alleging Grindr shared precise
     location **and HIV-status data** with advertising partners without consent;
     requires affirmative opt-in before sharing personal info with ad partners,
     deletion of collected data, and a comprehensive privacy program; Grindr
     agreed to stop sharing precision location and HIV-status info for
     advertising (verify finalization + terms).
   - **Lesson encoded in BEEF:** precise location never leaves the server;
     clients get bucketed distance only (`backend/src/lib/privacy.ts`,
     grid route); **no third-party ad SDK receives location in v1**;
     HIV-status-style sensitive fields don't exist in the schema. Privacy is
     both the trust differentiator and the legal shield.

3. **Legal/safety floor (FOSTA–SESTA, GDPR, store rules).**
   - **FOSTA–SESTA** (US, 2018): no §230 immunity for knowingly facilitating
     sex trafficking. Practical obligations: terms prohibiting commercial
     sexual solicitation/escorting, active moderation, a clear reporting
     channel incl. an **NCMEC CyberTipline path** for suspected CSAM, and
     good-faith cooperation with law enforcement. BEEF ships the moderation
     pipeline and a `ncmec.ts` stub (see `docs/ROADMAP.md`, Phase 1.3).
   - **GDPR Art. 9**: sexual orientation is a special category — heightened
     consent/safeguard requirements. Combining precise location with a dating
     profile is high-risk; BEEF's coarse-location design mitigates this.
   - **US state laws**: CCPA/CPRA opt-outs for geolocation sharing; Washington
     My Health My Data Act (2024) broadens "health data"; careful with facial
     recognition (BIPA, IL) if photo verification ever uses it.

## Market context (sizing is rough — verify before quoting anywhere)
- **Grindr** (NYSE: GRND): ~13–14M MAU, 190+ countries; revenue ~$260M (2023)
  → ~$340M (2024), subscription-first, ads secondary but growing (verify latest
  10-K). Proof the category supports large businesses — and that a **free,
  ad-supported, personality-forward** core with strong privacy defaults is an
  open lane: competitors mostly gate value behind subscriptions.
- **Global online dating** ~$9–10B+; gay-specific segment sizing is not
  publicly documented — treat gay niche numbers as estimates. Gay men
  historically over-index on dating-app usage and spend.
- **Blued** (BlueCity): delisted from Nasdaq 2022 amid China's data/privacy
  crackdown — cautionary tale on data sovereignty.
- **Caveat on the campy lane:** gay audiences reward confident wit and visual
  craft, but shallow camp reads as gimmick — it needs real design quality, and
  the ~75/25 model mix must pair with genuinely inclusive copy.

## Monetization reality (the honest part)
- **CPM/ARPDAU**: dating-app-specific numbers are not publicly disclosed —
  treat any "dating CPM" chart as unreliable. General mobile display/interstitial
  CPMs ~$2–$12; rewarded video ~$5–$20; dating ARPDAU estimates vary wildly
  (~$0.02–$0.30) and aren't reliable. Plan revenue that does **not** depend on
  a precise ARPDAU number.
- **Most realistic levers, in order:** (1) direct-sold/native partnerships with
  LGBTQ-friendly brands, tasteful sponsors, local venues/events; (2) house ads /
  own-brand placements (zero cost); (3) AdMob with no location; (4) later, light
  non-essential perks (extra filters, boosts) that keep the "free core" promise.
  This order is baked into `docs/ROADMAP.md` Phase 4.

## Not-a-clone guardrails
- A proximity grid is a functional idea (safe); Grindr's **trade dress** is not
  (distinctive blue/green grid, square tiles, tap-a-tile iconography, name/logo).
- BEEF differentiates visually and by feature: original name/colors/type/voice/
  icon set/empty-states/microcopy, intent tags ("friends/chat/date/hookup"),
  interest-led discovery, privacy/trust defaults, moderation-first safety.
- Build every feature from an **original spec with original copy** — never
  derived from a competitor's screenshots.

## Verification checklist (time-sensitive)
1. Grindr latest MAU / FY revenue and ad-revenue share (SEC 10-K).
2. FTC–Grindr settlement current status and final terms.
3. Norway DPA Grindr fine final amount/date.
4. Current AdMob / Apple / Meta dating-policy language (policies change).
5. Any published dating-app CPM/ARPDAU data (likely sparse — treat as unavailable).