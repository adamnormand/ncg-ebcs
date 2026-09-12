# ncg-ebcs

Static site for **Evidence Based Consulting Solutions** (`evidencebasedsolutions.ca`),
migrated off Kinsta-hosted WordPress (multisite subsite 9) to GitHub Pages.
No build step, no JavaScript, no dependencies.

## Status

| Step | State |
|---|---|
| Five main pages rebuilt | **Done** — Home, Services, About, Clients, Contact |
| Content, media and styling extracted | Done |
| Contact form replaced with `mailto:` | Done |
| 404, robots.txt, sitemap.xml | Done |
| DNS cutover runbook | Done — [`DNS.md`](DNS.md) |
| Team profile pages (5) | **Done** — clean URLs, old paths redirect |
| `/news/` | Not migrated — nothing links to it |
| GitHub Pages enabled | Not started |
| DNS switched | Not started (must be last) |

## Files

```
index.html            Home
services/index.html   Services
about/index.html      About
clients/index.html    Clients
contact/index.html    Contact
404.html              Not-found page (GitHub Pages serves this automatically)
assets/site.css       All styling, shared by every page
assets/               Logo, banners, hero, team portraits
robots.txt            Points crawlers at the sitemap
sitemap.xml           The five live URLs
favicon.svg           The old site had none
.nojekyll             Disables Jekyll processing
CNAME                 Custom domain — add at cutover, not before
```

Directory-style paths (`about/index.html`, not `about.html`) so URLs match the existing
WordPress permalinks and inbound links keep resolving. All links are document-relative,
so the site works from `file://`, from the `github.io` preview URL, and from the custom
domain without changes.

## Design system

Taken from the live site, not invented.

| Token | Value | Used for |
|---|---|---|
| `--navy` | `#081C31` | Primary buttons, icon, service card rule |
| `--green` | `#317D52` | Contact actions |
| `--band` | `#D1D1D1` | Pale section background, footer headings |
| `--dark` | `#252525` | Footer |
| `--text` | `#777777` | Body copy |
| `--title` | `#242424` | Headings |

Type is Lato 400/700 and Poppins 400/500/600, matching the theme's own Google Fonts
request. Elementor's global colour variables and its Roboto / Roboto Slab downloads were
untouched defaults the theme never used, and are not carried over.

## Still to migrate

**`/news/`** appears in the WordPress sitemap but nothing on the site links to it.
Confirm whether it should survive the migration at all. Nothing else is outstanding.

### Consultant profile URLs

WordPress served these on opaque paths. They now live on readable slugs, with the old
paths kept as redirect stubs so any existing inbound link or bookmark still resolves:

| Consultant | New URL | Redirects from |
|---|---|---|
| Dr. E. Kevin Kelloway | `/about/kevin-kelloway/` | `/about/elementor-367/` |
| Dr. Jennifer K. Dimoff | `/about/jennifer-dimoff/` | `/about/about-us/` |
| Dr. Stephanie Gilbert | `/about/stephanie-gilbert/` | `/about/about-us-2/` |
| Dr. Jane Mullen | `/about/jane-mullen/` | `/about/about-us-3/` |
| Dr. Mike Teed | `/about/mike-teed/` | `/about/about-us-4/` |

Each stub is a `meta refresh` with a `rel="canonical"` pointing at the new URL — the
static-hosting equivalent of a 301. Delete them once the old URLs stop being requested.

## Known defects on the live site, carried or corrected

| Issue | Where | Handling |
|---|---|---|
| Two team members linked to the same profile (`about-us-3`), leaving `about-us-4` orphaned | About | **Fixed.** The profile pages' own canonical URLs settled it: `about-us-3` is Dr. Mullen, `about-us-4` is Dr. Teed. Dr. Teed's button was the broken one. |
| All five profile pages titled `About Us` | Profiles | **Corrected** to the consultant's name. |
| Profile page says "Jane Mullen is an Professor" | Dr. Mullen | **Corrected** to "a Professor". |
| Profile page says "part of select team" | Dr. Teed | **Corrected** to "part of a select team". |
| `MENTAL HEARTH TRAINING FOR LEADERS` | Services | **Corrected** to *Health*. |
| "Learn more about each of the consulting team with specific the specific profiles provided." | About | **Corrected** — the duplicated words removed. |
| `Suject` | Contact form | Moot; the form is gone. |
| Page says "email or call us" but no phone number is published anywhere | Contact | **Flagged.** Add a number or drop "or call". |
| Six `<h1>` elements on one page | Services | **Corrected** — one `<h1>` per page, services demoted to `<h2>`. |
| `lang="fr-CA"` on English copy | All | **Corrected** to `en-CA`. |

## Deploy on GitHub Pages

1. Merge to `main` and push.
2. Settings → Pages → Source: *Deploy from a branch* → `main` / `/ (root)`.
3. Verify at `https://adamnormand.github.io/ncg-ebcs/`.
4. Only then: add `CNAME`, set the custom domain, tick *Enforce HTTPS*.

Full cutover procedure, including what to change at Squarespace and when to decommission
Kinsta: [`DNS.md`](DNS.md).
