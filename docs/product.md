# NestNote product brief

Keep this file identical in `coltonswapp/nest-note` and `nest-note-web`.

## What it is

NestNote is a digital babysitter binder. Families keep household details in one place; sitters see what they need for each job, without digging through texts and screenshots.

App Store: [Sitting Guides: NestNote](https://apps.apple.com/us/app/sitting-guides-nestnote/id6744369370) (iPhone).

## Who it is for

- **Nest owners (parents / guardians)** — set up the household once, then share the right details for each sit.
- **Sitters** — join a session with a code and show up prepared.

## Domain language

Use these words. Do not invent synonyms in product copy.

| Term | Meaning |
| --- | --- |
| **Nest** | A household’s organized stash of info — codes, Wi‑Fi, routines, places, contacts, and more. |
| **Session** | A specific sitting job with dates, times, and the details shared for that booking. |
| **Invite code** | A short code a sitter enters to join a session. |
| **Nest owner** | The family member who manages the nest, sessions, and sitters. |
| **Sitter** | Someone who joins sessions and views what the family shared for that job. |
| **Session request** | A sitter-initiated ask; the nest owner accepts or adjusts dates and times. |

## How the product works

1. The family creates a nest and adds notes, routines, places, and contacts.
2. For each sit they create a session and choose what from the nest to include.
3. They invite the sitter with a code (or invite a saved sitter). The sitter joins in the app and sees only what was included for that booking.

Access is organized around sessions. Sitters do not get a standing view of the whole nest.

## Brand

- Name: **NestNote** (one word, capital N twice).
- Site: [nestnoteapp.com](https://www.nestnoteapp.com)
- Support: support@nestnoteapp.com
- Primary green: `#1CB71A` (RGB 28, 183, 26). Darker green for text on light backgrounds: `#0A5A07`.
- Voice: calm, practical, household — not generic SaaS. Prefer “sticky notes and texts” over “revolutionize childcare.”

## Repos and hosting

| Piece | Where |
| --- | --- |
| iOS app + Cloud Functions | `coltonswapp/nest-note` |
| Marketing site | `nest-note-web`, Cloudflare Pages |
| AASA / Password AutoFill | `app.nestnoteapp.com` (in the iOS repo, `cloudflare-aasa/`) |

The marketing site is static. Do not add the Firebase client SDK there. Future authenticated web features should call Cloud Functions in the iOS repo’s Firebase project, not talk to Firestore from the browser.

## URLs the iOS app already uses

Preserve these paths if the site replaces the current Framer site:

- `/terms`
- `/privacypolicy`
- `/contact`
- `/invite?code=`
