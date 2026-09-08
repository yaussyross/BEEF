import { createFileRoute } from "@tanstack/react-router";
import { createServerFn } from "@tanstack/react-start";
import { appendFile, mkdir } from "node:fs/promises";
import { useState } from "react";

/**
 * Waitlist capture. Submissions are appended (one JSON object per line) to
 * .run/waitlist.jsonl in the site working directory. The .run/ folder is
 * gitignored and lives on this machine, so entries survive a `bun run publish`
 * (rebuild + server restart) of THIS host. Honest limitation: this is
 * single-host, file-based persistence — it is not a managed database, so it
 * would not survive the sandbox being rebuilt elsewhere. Swap in the DB helper
 * (src/db.ts) once a DATABASE_URL is connected.
 */
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

const joinWaitlist = createServerFn({ method: "POST" })
  .validator((data: { email?: string }) => data)
  .handler(async ({ data }) => {
    const email = (data.email ?? "").trim().toLowerCase();
    if (!EMAIL_RE.test(email)) {
      return { ok: false, error: "That email looks a little undercooked. Try again?" };
    }
    const line = JSON.stringify({ email, ts: new Date().toISOString() }) + "\n";
    await mkdir(".run", { recursive: true });
    await appendFile(".run/waitlist.jsonl", line, "utf8");
    return { ok: true, email };
  }
);

export const Route = createFileRoute("/")({
  component: Home,
});

function Nav() {
  return (
    <header className="sticky top-0 z-40 border-b border-char/10 bg-cream/85 backdrop-blur-md">
      <div className="mx-auto flex max-w-6xl items-center justify-between px-5 py-4">
        <a href="#top" className="flex items-center gap-3">
          <span className="brand-mark text-2xl text-steak sm:text-3xl">BEEF</span>
          <span className="scribble hidden -rotate-3 text-lg text-sizzle sm:inline-block">
            aged to perfection
          </span>
        </a>
        <div className="flex items-center gap-6">
          <nav className="hidden items-center gap-6 text-sm font-medium text-char/80 md:flex">
            <a href="#the-cut" className="transition hover:text-steak">
              The cut
            </a>
            <a href="#flavor" className="transition hover:text-steak">
              Flavor
            </a>
            <a href="#marinate" className="transition hover:text-steak">
              Marinate
            </a>
          </nav>
          <a
            href="#join"
            className="rounded-full bg-steak px-5 py-2.5 text-sm font-bold text-cream shadow-lg shadow-steak/30 transition hover:-translate-y-0.5 hover:bg-beefer"
          >
            Join the waitlist
          </a>
        </div>
      </div>
    </header>
  );
}

const HERO_IMAGES = [
  { src: "/beef-model-01-pink-satin.jpg", rot: "-6deg", top: "5%", left: "-4%", w: "52%" },
  { src: "/beef-model-02-coral-tank.jpg", rot: "4deg", top: "30%", left: "38%", w: "46%", z: 1 },
  { src: "/beef-model-03-emerald-bomber.jpg", rot: "-3deg", top: "6%", left: "56%", w: "38%", z: 0 },
];

function Hero() {
  return (
    <section id="top" className="relative overflow-hidden">
      {/* soft gradient wash behind the headline block */}
      <div className="hero-wash-soft absolute inset-0 pointer-events-none" aria-hidden="true" />

      <div className="relative mx-auto grid max-w-6xl gap-12 px-5 pb-16 pt-16 sm:pt-24 md:grid-cols-2 md:items-center">
        {/* LEFT: copy */}
        <div className="relative">
          <span className="inline-flex items-center gap-2 rounded-full bg-cream/20 px-3 py-1 text-xs font-bold uppercase tracking-widest text-cream ring-1 ring-cream/40 backdrop-blur-sm">
            <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-lime" />
            Local · Fresh · Full of flavor
          </span>

          <h1 className="brand-mark mt-6 text-4xl uppercase leading-[1.05] text-cream sm:text-5xl lg:text-6xl">
            A cut above
            <br />
            the rest.
          </h1>

          <p className="scribble mt-3 -rotate-1 text-2xl text-lime">
            (well-marbled, obviously)
          </p>

          <p className="mt-6 max-w-md text-lg leading-relaxed text-cream/95">
            The free gay social app for friends, dates &amp; hookups — local,
            fresh, and full of flavor. No small talk required (but we won&rsquo;t
            judge you if you make some).
          </p>

          <div className="mt-9 flex flex-col items-start gap-3 sm:flex-row sm:items-center">
            <a
              href="#join"
              className="inline-flex items-center gap-2 rounded-full bg-cream px-8 py-4 text-base font-bold text-steak shadow-2xl shadow-char/30 transition hover:-translate-y-0.5 hover:shadow-char/40"
            >
              Join the waitlist
              <span aria-hidden="true">→</span>
            </a>
            <a
              href="#the-cut"
              className="inline-flex items-center gap-1 px-1 py-2 text-sm font-medium text-cream/90 underline decoration-cream/40 underline-offset-4 transition hover:text-cream"
            >
              Get a taste first →
            </a>
          </div>

          <p className="mt-4 text-sm italic text-cream/80">
            Get on the grill — no char required.
          </p>
        </div>

        {/* RIGHT: tilted overlapping model collage (the "grid") */}
        <div className="relative mx-auto h-[460px] w-full max-w-md sm:h-[520px]">
          {HERO_IMAGES.map((img) => (
            <img
              key={img.src}
              src={img.src}
              alt=""
              loading="eager"
              style={
                {
                  "--rot": img.rot,
                  top: img.top,
                  left: img.left,
                  width: img.w,
                  zIndex: img.z ?? 1,
                } as React.CSSProperties
              }
              className="animate-floaty absolute aspect-[4/5] rounded-2xl border-4 border-cream/90 object-cover shadow-2xl shadow-char/40"
            />
          ))}
          {/* grid pins */}
          <div className="absolute -right-2 top-1/2 -translate-y-1/2 -rotate-6 rounded-full bg-lime px-4 py-1.5 text-sm font-bold text-char shadow-lg">
            no char required
          </div>
        </div>
      </div>

      {/* social proof strip */}
      <div className="relative border-t border-cream/25 bg-char/10 backdrop-blur-sm">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-center gap-x-8 gap-y-2 px-5 py-4 text-sm font-semibold text-cream">
          <span>Free forever</span>
          <span className="hidden text-cream/40 sm:inline">·</span>
          <span>Ad-supported</span>
          <span className="hidden text-cream/40 sm:inline">·</span>
          <span>Friends, dates &amp; hookups</span>
          <span className="hidden text-cream/40 sm:inline">·</span>
          <span>No small talk required</span>
        </div>
      </div>
    </section>
  );
}

function Marquee() {
  const imgs = [
    "/beef-model-01-pink-satin.jpg",
    "/beef-model-02-coral-tank.jpg",
    "/beef-model-03-emerald-bomber.jpg",
    "/beef-model-04-hawaiian.jpg",
    "/beef-model-05-striped-tee.jpg",
    "/beef-model-06-neon-yellow.jpg",
  ];
  // double up for a seamless loop
  const row = [...imgs, ...imgs];
  return (
    <div className="relative overflow-hidden border-y border-char/10 bg-char py-2">
      <div className="animate-marquee flex w-max gap-3 px-3">
        {row.map((src, i) => (
          <div
            key={i}
            className="flex w-40 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-char/40 p-1"
          >
            <img
              src={src}
              alt=""
              loading="lazy"
              className="h-44 w-40 rounded-md object-cover"
            />
          </div>
        ))}
      </div>
      <div className="pointer-events-none absolute inset-y-0 left-0 w-16 bg-gradient-to-r from-char to-transparent" />
      <div className="pointer-events-none absolute inset-y-0 right-0 w-16 bg-gradient-to-l from-char to-transparent" />
    </div>
  );
}

function ValueProps() {
  const props = [
    {
      title: "Friends, dates & hookups",
      body: "Whatever your appetite, the buffet is open. One app, a whole menu — no gatekeeping, no shame, just your flavor of the night.",
      tag: "Grill it",
      color: "bg-steak",
    },
    {
      title: "Local. Fresh. Full of flavor.",
      body: "A grid of nearby guys, sliced and served by proximity. See who&rsquo;s close, who&rsquo;s fresh, and who&rsquo;s just your type.",
      tag: "Low & slow",
      color: "bg-sizzle",
    },
    {
      title: "Wildly free, forever",
      body: "Free to use, brought to you by tasteful in-app ads. Your inbox stays saucy, your wallet stays full.",
      tag: "Well-marbled",
      color: "bg-berry",
    },
  ];
  return (
    <section id="the-cut" className="mx-auto max-w-6xl px-5 py-20 sm:py-28">
      <div className="max-w-2xl">
        <p className="text-sm font-bold uppercase tracking-widest text-steak">
          The cut
        </p>
        <h2 className="brand-mark mt-3 text-3xl uppercase text-char sm:text-4xl">
          Get a taste first
        </h2>
        <p className="scribble mt-2 -rotate-1 text-2xl text-sizzle">
          (make it a double)
        </p>
      </div>

      <div className="mt-12 grid gap-6 md:grid-cols-3">
        {props.map((p) => (
          <div
            key={p.title}
            className="group flex flex-col rounded-3xl border border-char/10 bg-white/70 p-7 shadow-sm transition hover:-translate-y-1 hover:shadow-xl hover:shadow-char/10"
          >
            <span
              className={`inline-flex w-fit ${p.color} rounded-full px-3 py-1 text-xs font-bold uppercase tracking-widest text-cream`}
            >
              {p.tag}
            </span>
            <h3 className="brand-mark mt-5 text-lg uppercase text-char">
              {p.title}
            </h3>
            <p className="mt-3 text-[15px] leading-relaxed text-char/70">
              {p.body}
            </p>
          </div>
        ))}
      </div>
    </section>
  );
}

function Flavor() {
  const rows = [
    {
      img: "/beef-model-03-emerald-bomber.jpg",
      kicker: "The grid",
      title: "Nearby guys, one sizzling grid.",
      body: "Beef is a proximity app in the spirit of the classics — but with a real personality and none of the copycat energy. See who&rsquo;s close by, send a hello, and let the marbling do the talking.",
    },
    {
      img: "/beef-model-02-coral-tank.jpg",
      kicker: "The flavor",
      title: "Interest-led discovery.",
      body: "Find your cut by what actually gets you going — hobbies, muscle groups, weekend energy. Match on the meat AND the personality. This is where we separate from the herd.",
    },
    {
      img: "/beef-model-04-hawaiian.jpg",
      kicker: "The confidence",
      title: "A wink, not a leer.",
      body: "Saucy, cheeky, self-aware — but never smutty and never mean. Humor does the flirting around here, so you can be yourself without breaking a sweat.",
    },
  ];
  return (
    <section id="flavor" className="bg-char py-20 text-cream sm:py-28">
      <div className="mx-auto max-w-6xl px-5">
        <div className="max-w-2xl">
          <p className="text-sm font-bold uppercase tracking-widest text-sizzle">
            Flavor profile
          </p>
          <h2 className="brand-mark mt-3 text-3xl uppercase sm:text-4xl">
            Why BEEF&rsquo;s the main course
          </h2>
        </div>

        <div className="mt-14 space-y-16">
          {rows.map((r, i) => (
            <div
              key={r.title}
              className={`grid items-center gap-10 md:grid-cols-2 ${
                i % 2 === 1 ? "md:[&>*:first-child]:order-2" : ""
              }`}
            >
              <img
                src={r.img}
                alt=""
                loading="lazy"
                className="aspect-[4/3] w-full rounded-3xl border border-cream/15 object-cover shadow-2xl shadow-black/40"
              />
              <div>
                <p className="text-xs font-bold uppercase tracking-[0.3em] text-sizzle">
                  {r.kicker}
                </p>
                <h3 className="brand-mark mt-3 text-2xl uppercase">{r.title}</h3>
                <p className="mt-4 text-lg leading-relaxed text-cream/80">{r.body}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function WaitlistForm() {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<{ kind: "idle" | "busy" | "ok" | "err"; msg?: string }>({
    kind: "idle",
  });

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setStatus({ kind: "busy" });
    const res = await joinWaitlist({ data: { email } });
    if (res.ok) {
      setStatus({ kind: "ok", msg: "You're on the grill. Talk soon, handsome." });
      setEmail("");
    } else {
      setStatus({ kind: "err", msg: res.error });
    }
  }

  return (
    <section id="marinate" className="mx-auto max-w-6xl px-5 py-20 sm:py-28">
      <div className="overflow-hidden rounded-[2.5rem] hero-wash p-1 shadow-2xl shadow-steak/20">
        <div className="rounded-[2.2rem] bg-cream/95 px-6 py-16 text-center sm:px-12">
          <p className="text-sm font-bold uppercase tracking-widest text-berry">
            Marinate on the waitlist
          </p>
          <h2 className="brand-mark mx-auto mt-4 max-w-3xl text-3xl uppercase text-char sm:text-5xl">
            Get on the grill.
          </h2>
          <p className="scribble mx-auto mt-3 -rotate-1 text-2xl text-sizzle">
            (no char required)
          </p>
          <p className="mx-auto mt-4 max-w-xl text-char/70">
            Drop your email and we&rsquo;ll slide into your inbox the moment the
            grates are hot. First cut goes to the waitlist.
          </p>

          <form
            onSubmit={submit}
            className="mx-auto mt-10 flex max-w-xl flex-col gap-3 sm:flex-row"
          >
            <label htmlFor="waitlist-email" className="sr-only">
              Email address
            </label>
            <input
              id="waitlist-email"
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="you@somethingtasty.com"
              className="w-full flex-1 rounded-full border-2 border-char/15 bg-white px-6 py-4 text-char outline-none transition placeholder:text-char/40 focus:border-steak"
            />
            <button
              type="submit"
              disabled={status.kind === "busy"}
              className="rounded-full bg-steak px-8 py-4 font-bold text-cream shadow-lg shadow-steak/30 transition hover:-translate-y-0.5 hover:bg-beefer disabled:cursor-not-allowed disabled:opacity-60"
            >
              {status.kind === "busy" ? "Warming the grill…" : "Join the waitlist"}
            </button>
          </form>

          {status.kind === "ok" && (
            <p className="mt-5 font-medium text-green-700">{status.msg}</p>
          )}
          {status.kind === "err" && (
            <p className="mt-5 font-medium text-steak">{status.msg}</p>
          )}

          <div className="mt-8 flex flex-wrap items-center justify-center gap-x-6 gap-y-2 text-sm font-semibold text-char/60">
            <span>Free forever</span>
            <span>·</span>
            <span>Ad-supported</span>
            <span>·</span>
            <span>Friends, dates &amp; hookups</span>
            <span>·</span>
            <span>No small talk required</span>
          </div>
        </div>
      </div>
    </section>
  );
}

function Footer() {
  return (
    <footer className="bg-beefer py-12 text-cream">
      <div className="mx-auto max-w-6xl px-5 text-center">
        <div className="flex items-center justify-center gap-3">
          <span className="brand-mark text-3xl text-cream">BEEF</span>
          <span className="scribble -rotate-3 text-lg text-sizzle">
            fresh · local · full of flavor
          </span>
        </div>
        <p className="mx-auto mt-4 max-w-md text-sm text-cream/70">
          A free, ads-supported gay social app for friends, dates &amp; hookups.
          Inspired by the greats — never a copy. Classy, confident, saucy-not-smutty.
        </p>
        <div className="mx-auto mt-6 h-px w-24 bg-cream/25" />
        <p className="mt-6 text-xs text-cream/50">
          © {new Date().getFullYear()} BEEF. All rights reserved.
        </p>
      </div>
    </footer>
  );
}

function Home() {
  return (
    <div className="min-h-dvh bg-cream">
      <Nav />
      <Hero />
      <Marquee />
      <ValueProps />
      <Flavor />
      <WaitlistForm />
      <Footer />
    </div>
  );
}
