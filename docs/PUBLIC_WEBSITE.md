# Public website

The public website replaces the development placeholder at the owner's request.
It contains Home, Our work, Updates, About us, Get involved, Privacy, and five
photo stories and their photo galleries. Each story keeps two editorial images
inline and has an Open gallery button. The gallery opens over the story with
Previous/Next, a horizontally scrolling thumbnail strip and keyboard navigation.
Closing returns focus and scroll position to the story. Gallery URLs remain
shareable and open the same overlay on top of the corresponding story. The UX agent recommended visible editorial content, straightforward
navigation, a chronological reading list, direct support contact, and an optional
accessible enlarged photograph view. No cards, page selectors or refresh controls.

## Content provenance

- GCF's 24 June 2024 introductory email states its mission: positively impacting
  lives and promoting a deeper appreciation for life itself. Public copy paraphrases
  that statement and describes what is visible in the supplied photographs.
- Original GCF Drive collections identify Christmas 2022, Christmas 2023,
  the anniversary celebration, Blood Drive 2024 and Child's Month Treat 2025.
- `public-media-sources.json` maps every selected public image to its original
  collection and filename. Images are resized, auto-oriented and stripped of
  embedded metadata; full originals remain in the private library.
- Story years describe the activity, not a fabricated article publication date.
- No participant identities, impact totals, financial figures, partner claims,
  founding dates, registration or tax claims are inferred.
- The general contact email comes from GCF correspondence. Contributions and
  volunteering are enquiries via the visitor's mail app; no fake checkout,
  subscription form or delivery confirmation is presented.

## Public/private boundary

Public stories are an explicitly curated source collection in
`apps/web/src/public-site/content.ts`. The full supplied photo sets are represented
in `galleries.json`; inline photo choices remain independent. Public photos are
optimized for the viewer with small, lazily loaded thumbnails. They do not read from the admin database,
private object bucket, user accounts, audit trail or unpublished work. Website
publishing from the admin needs a separate explicit release workflow before it
can expose those records; creating or editing a draft must never publish it.

The shared admin data model and migration history are unchanged by this build.
Public editorial copy is not a second operational database. Do not add fundraising
balances, participant records or other operational facts here.

## Rendering and hosting

`npm run build` prerenders each public route with its own title, description,
canonical link and Open Graph data. The Elixir router serves only known page
names, the private admin shell, and public static assets. The sitemap includes
public pages only. `/admin` has `noindex,nofollow` and `no-store`; its authenticated
API still enforces all existing controls.

Local development uses the existing Vite server at port 4173. Production remains
on the existing Hetzner/Cloudflare setup. No new hosting service or remote asset
bucket is needed. Public images are versioned, optimized assets; browsing them
requires no connection to the private bucket.
