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
| Contact form replacement chosen | Not started — see `DNS.md` |
| DNS switched | Not started (must be last) |

## The one thing needed to proceed

This session has no general outbound web access. The egress policy is deny-by-default:
GitHub and search are reachable, ordinary HTTP is not — `example.com` is refused exactly
as `evidencebasedsolutions.ca` is. So the live site cannot be crawled from here, and
nothing was reconstructed from memory or search results. A rebuild that invents a real
firm's copy, layout and imagery is worse than no rebuild.

Run this on any machine with normal internet, then commit the result:

```bash
bash tools/extract.sh
git add ebcs-extract.tar.gz && git commit -m "Add site extraction" && git push
```

It takes a couple of minutes and produces `ebcs-extract/`:

| Output | Contents |
|---|---|
| `mirror/` | Rendered HTML, CSS, JS, fonts, images — as actually served. This is what preserves the **style**. |
| `api-pages.json`, `api-posts.json` | Clean per-page title, slug and rendered HTML, without theme chrome. |
| `api-media.json`, `media/` | Every file in the WordPress media library, originals included. |
| `sitemap_index.xml` | The full URL list, for confirming parity after cutover. |

The mirror and the REST API are deliberately both captured: the API gives clean content
but no styling, the mirror gives real styling but tangled markup. The rebuild uses the
API for text and the mirror for the design system — colours, type scale, spacing, assets.

**Alternatives if the script is inconvenient:** a full backup from MyKinsta (Sites →
Backups → Download), or wp-admin → Tools → Export. Either works; neither captures
rendered CSS, so pair it with a browser *Save Page As → Complete* on each page.

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
