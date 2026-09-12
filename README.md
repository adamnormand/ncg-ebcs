# ncg-ebcs

Static site for **Evidence Based Consulting Solutions** (`evidencebasedsolutions.ca`),
migrating off Kinsta-hosted WordPress to GitHub Pages. No build step, no dependencies.

## Status

| Step | State |
|---|---|
| Destination repo created | Done |
| DNS cutover runbook | Done — [`DNS.md`](DNS.md) |
| Extraction tooling | Done — [`tools/extract.sh`](tools/extract.sh) |
| Source content + media extracted | **Blocked — needs one command run on your machine** |
| Static pages built | Not started (depends on extraction) |
| Contact form | Decided — replaced by `mailto:` / `tel:` details, no form |
| DNS switched | Not started (must be last) |

## The one thing needed to proceed

This session has no general outbound web access. The egress policy is deny-by-default:
GitHub and search are reachable, ordinary HTTP is not — `example.com` is refused exactly
as `evidencebasedsolutions.ca` is. So the live site cannot be crawled from here, and
nothing was reconstructed from memory or search results. A rebuild that invents a real
firm's copy, layout and imagery is worse than no rebuild.

### Option A — Simply Static plugin (recommended, no terminal)

Everything happens inside wp-admin. On a multisite install, run it from the
**subsite's** own admin, not the network admin.

1. **Plugins → Add New →** search `Simply Static` (Patrick Posner) → Install → Activate.
2. **Simply Static → Settings → Deployment →** Delivery method: **ZIP archive**.
   URLs: **Relative** — keeps the export portable and easy to diff.
3. **Simply Static → Generate → Generate Static Files.** A three-page site takes a minute.
4. Download the ZIP, drop it in this repo, commit, push.

This produces exactly what the rebuild needs: rendered HTML, the full CSS cascade,
fonts, images, and every upload actually referenced by a page. It is the same thing
`tools/extract.sh` builds, produced server-side and more completely.

If the ZIP exceeds ~50 MB, the media library is carrying unused uploads — commit
`mirror/` unzipped instead, or prune first.

### Option B — extraction script

Run on any machine with normal internet. Needs only curl.

```bash
bash tools/extract.sh
git add ebcs-extract.tar.gz && git commit -m "Add site extraction" && git push
```

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
