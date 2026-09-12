# ncg-ebcs

Static site for **Evidence Based Consulting Solutions** (`evidencebasedsolutions.ca`),
migrating off Kinsta-hosted WordPress to GitHub Pages. No build step, no dependencies.

## Status

| Step | State |
|---|---|
| Destination repo created | Done |
| DNS cutover runbook | Done — [`DNS.md`](DNS.md) |
| Extraction tooling | Done — [`tools/extract.sh`](tools/extract.sh) |
| Source content + media extracted | Homepage only — export was incomplete |
| Static pages built | Home done. Services / About / Clients / Contact **blocked** |
| Contact form | Decided — replaced by `mailto:` / `tel:` details, no form |
| DNS switched | Not started (must be last) |

## The export was incomplete — 1 page of 11

The Simply Static ZIP contained only `index.html`, but `page-sitemap.xml` in that
same export lists eleven URLs:

```
/                       /services/          /clients/           /contact/
/about/                 /news/              /about/about-us/    /about/about-us-2/
/about/about-us-3/      /about/about-us-4/  /about/elementor-367/
```

The homepage is rebuilt and faithful. The four other pages in the primary nav —
Services, About, Clients, Contact — have no source HTML, so they are not built and
their nav links currently 404.

**A second Simply Static run produced a byte-identical ZIP** — same MD5 on `index.html`,
same 1,748 files. So this is not a job that stopped early; the crawler completes the
homepage and all of its assets, then never queues the other URLs. The nav links are
present and root-relative (`/services/` etc.), so they are discoverable.

Things that fix it, cheapest first:

1. **Browser save (reliable, ~2 min).** Open each of `/services/`, `/about/`, `/clients/`
   and `/contact/` and use *Save Page As → Webpage, Complete*. The design system is
   already extracted from the homepage, so only these pages' content and images are
   still needed.
2. **Simply Static → Settings → Include/Exclude → Additional URLs**: add the four paths
   explicitly, one per line, then re-run.
3. **Simply Static → Diagnostics**: check for failures (WP-Cron disabled, memory limit,
   file permissions). On a multisite subsite, WP-Cron problems are the usual cause of a
   crawl queue that never advances.

Of the eleven, five matter: `/`, `/services/`, `/about/`, `/clients/`, `/contact/`.
The `about-us-N` and `elementor-367` entries are Elementor draft/revision artifacts —
confirm before publishing, but they are almost certainly not linked from anywhere.

## Decisions

**The contact form is dropped, not replaced.** The WordPress form plugin cannot work on
static hosting — there is no server to receive the POST. Rather than swapping it for a
hosted form service, the contact page publishes the details directly and lets people mail
from their own client:

```html
<a href="mailto:ADDRESS@evidencebasedsolutions.ca?subject=Website%20enquiry">ADDRESS@evidencebasedsolutions.ca</a>
<a href="tel:+1NPANXXXXXX">(NPA) NXX-XXXX</a>
```

Three rules this follows, all of which matter more than they look:

1. **The visible text is the address itself**, never "Email us". A `mailto:` link opens
   nothing for someone on webmail with no mail client configured — which is most people
   on a work desktop. If the address is only in the `href`, they hit a dead link. Shown
   as text, they copy it and carry on.
2. **`tel:` carries E.164 in the `href`** (`+14185551234`) and human formatting in the
   text. Dialers need the former; readers need the latter.
3. **A `?subject=` prefill** on the mail link, so enquiries from the site are
   identifiable at a glance in the inbox — cheap triage, no tracking.

Left plain rather than obfuscated. JavaScript address-scrambling breaks copy-paste and
screen readers to defeat scrapers that stopped being the binding constraint once server
-side spam filtering got good. Not worth the accessibility cost on a three-page site.

Exact addresses and numbers come from the extraction — `contact-details.txt` — and are
transcribed verbatim. A retyped address is a silently dead contact channel, the same
failure mode the form had.

## Intended structure

```
index.html           Home
about/index.html     About
contact/index.html   Contact
assets/              Images, fonts, downloads
tools/extract.sh     One-shot extractor for the live WordPress site
CNAME                Custom domain (add at cutover, not before)
.nojekyll            Disables Jekyll processing on GitHub Pages
```

Directory-style paths (`about/index.html`, not `about.html`) so URLs match the existing
WordPress permalinks exactly and inbound links keep resolving.

## Deploy on GitHub Pages

1. Push to the root of `main`.
2. Settings → Pages → Source: *Deploy from a branch* → `main` / `/ (root)`.
3. Settings → Pages → Custom domain: `evidencebasedsolutions.ca`, then *Enforce HTTPS*.

Do steps 2–3 **after** the real content is in place. Pointing the live domain at an empty
repo takes the firm's site down for as long as it takes someone to notice.

Full cutover procedure, including what to delete at Squarespace and when to decommission
Kinsta: [`DNS.md`](DNS.md).
