# Hobbit Moon

> A quiet life, shared.

Hobbit Moon is an early PC-game prototype about ordinary days in an original, cosy take on Hobbiton: tending a garden, wandering home at moonrise, and inviting friends into the same village.

The first milestone is intentionally small and playable in a browser. It is the foundation for a future desktop build, not a claim that the multiplayer game is finished.

## What is here now

- A handcrafted canvas village slice at [`/game`](./game.html): realtime movement, in-world dialogue, garden/pond/market activities, cooking, meals, weather, a guided first-day path, save-backed day rollover, and a local invite code.
- A public-facing marketing page at [`/`](./index.html).
- A Supabase-ready multiplayer schema in [`supabase/migrations/0001_hobbit_moon.sql`](./supabase/migrations/0001_hobbit_moon.sql).
- A graceful local demo mode when Supabase environment variables are not configured.
- GitHub Actions checks for tests and the production build.
- Vercel configuration for the marketing page and `/game` route.

## Run it locally

```bash
npm install
npm run dev
```

Then open the URL Vite prints. Use `npm run check` for the same tests and build run by CI.

## Product direction

The long-term shape is a PC-first village-life game with:

1. **A daily rhythm** — gardening, cooking, errands, fishing, letters, and small seasonal rituals.
2. **A village that remembers** — homes, paths, relationships, weather, and player choices persist.
3. **Shared villages** — accounts, invite codes, a small group of friends, and safe ownership rules.
4. **A gentle multiplayer layer** — asynchronous visits and cooperative activities before real-time complexity.
5. **A desktop client** — package the stable client for Windows/macOS/Linux once the core loop is proven.

## Hosted multiplayer setup

Copy `.env.example` to `.env.local` and add a Supabase project URL plus its publishable anon key. Apply the SQL migration in a Supabase project before enabling hosted auth or village persistence. Never place a service-role key in client-side environment variables.

The schema is deliberately limited to profiles, villages, membership, and invites for this first slice. Realtime world state, moderation, presence, and save-versioning should be added only after the game loop has been playtested.

## Roadmap

- [x] Establish the visual direction and playable movement slice
- [x] Add local invite-code flow and hosted-schema foundation
- [ ] Add a real account flow and persistent village saves
- [x] Add gardening, inventory, shop, weather, NPC schedules, and the first cooking/meal loop
- [ ] Expand the solo loop with relationships, requests, seasonal content, and deeper interiors
- [ ] Add invite redemption and multiplayer permissions
- [ ] Add a desktop shell and downloadable test build
- [ ] Replace prototype art with an original production asset pack

## Naming and rights note

This is an original prototype inspired by cosy village-life games and the pastoral charm associated with Hobbiton. It is not affiliated with or endorsed by Tolkien Enterprises, Middle-earth Enterprises, Nintendo, ConcernedApe, or their respective rights holders. Any public or commercial release using third-party names, settings, or protected elements would require a separate rights review.
