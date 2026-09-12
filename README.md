# ncg-ebcs

Static site for **Evidence Based Consulting Solutions** (`evidencebasedsolutions.ca`),
migrating off Squarespace to GitHub Pages. No build step, no dependencies.

## Status

| Step | State |
|---|---|
| Destination repo created | Done |
| DNS cutover runbook | Done — see [`DNS.md`](DNS.md) |
| Source content + media extracted | **Blocked** — see below |
| Static pages built | Not started (depends on extraction) |
| DNS switched | Not started (must be last) |

## Why extraction is blocked

This session's network egress policy refuses `evidencebasedsolutions.ca` on both
available paths (agent proxy `403` on CONNECT, and the fetch tool with
`EGRESS_BLOCKED`). The host is denied by policy, not unreachable, so it cannot be
crawled from here. Nothing was reconstructed from memory or search snippets — a
migration that invents a real firm's copy, layout and imagery is worse than no
migration.

Any one of these unblocks it:

1. Allow `evidencebasedsolutions.ca` in the session's egress policy, then re-run the crawl.
2. Export from Squarespace (`Settings → Import & Export → Export`) and commit the `.xml`.
3. Save the pages from a browser (`Save Page As → Complete`) and commit the HTML + asset folders.

Known page inventory, from search indexing only — to be confirmed against the live site:
`/` (Home), `/about/`, `/contact/`.

## Intended structure

```
index.html          Home
about/index.html    About
contact/index.html  Contact
assets/             Images, fonts, downloads — as served by the old site
CNAME               Custom domain (add at cutover, not before)
.nojekyll           Disables Jekyll processing on GitHub Pages
```

## Deploy on GitHub Pages

1. Push to the root of `main`.
2. Settings → Pages → Source: *Deploy from a branch* → `main` / `/ (root)`.
3. Settings → Pages → Custom domain: `evidencebasedsolutions.ca`. Tick *Enforce HTTPS*
   once the certificate is issued.

Do steps 2–3 **after** the real content is in place. Pointing the live domain at an
empty or placeholder repo takes the firm's site down for as long as it takes to notice.
