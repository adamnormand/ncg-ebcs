# DNS cutover — Kinsta (WordPress) → GitHub Pages

Domain: `evidencebasedsolutions.ca`
DNS managed at: **Squarespace** (registrar / DNS panel)
Currently hosted at: **Kinsta** (WordPress)
Target: **GitHub Pages**, repo `adamnormand/ncg-ebcs`

Note the split: the domain is registered and its DNS served at Squarespace, while the
site itself runs at Kinsta. You change records at Squarespace; you decommission at
Kinsta. There is no Squarespace-hosted site involved.

Do not start until the static site is built, pushed to `main`, and verified at
`https://adamnormand.github.io/ncg-ebcs/`. DNS is the last step.

---

## 0. Before you touch anything

```bash
dig +noall +answer evidencebasedsolutions.ca A
dig +noall +answer evidencebasedsolutions.ca AAAA
dig +noall +answer www.evidencebasedsolutions.ca CNAME
dig +noall +answer www.evidencebasedsolutions.ca A
dig +noall +answer evidencebasedsolutions.ca MX
dig +noall +answer evidencebasedsolutions.ca TXT
```

Save the output. Screenshot the Squarespace DNS panel too.

Then lower TTL to **600 s** on the records you will change (`@` A/AAAA, `www`) and wait
out the *old* TTL — often 3600 s or more — before cutting over. This is what makes a bad
cutover a ten-minute problem instead of a day-long one.

---

## 1. Remove the Kinsta records

**Squarespace → Settings → Domains →** `evidencebasedsolutions.ca` **→ DNS → DNS Settings.**

You are looking for the records Kinsta told you to create when the site was set up:

| Type | Host | Current value |
|---|---|---|
| A | `@` | Kinsta's IPv4 for this site — a Google Cloud address, typically `34.x.x.x` or `35.x.x.x` |
| A *or* CNAME | `www` | the same IP, or `<sitename>.kinsta.cloud` |

Confirm the exact current value against **MyKinsta → Sites → [site] → Info → IP address**
before deleting, so the rollback value is the verified one rather than a guess.

**Leave everything else alone.** Specifically do not touch:

- `MX` — email for the domain stops the moment these go.
- `TXT` — SPF (`v=spf1 …`), `_dmarc`, and any DKIM selector records.
- Any `CNAME` for third-party services (mail, calendar, e-sign, analytics, verification).

---

## 2. Add the GitHub Pages records

| Type | Host | Value | TTL |
|---|---|---|---|
| A | `@` | `185.199.108.153` | 600 |
| A | `@` | `185.199.109.153` | 600 |
| A | `@` | `185.199.110.153` | 600 |
| A | `@` | `185.199.111.153` | 600 |
| AAAA | `@` | `2606:50c0:8000::153` | 600 |
| AAAA | `@` | `2606:50c0:8001::153` | 600 |
| AAAA | `@` | `2606:50c0:8002::153` | 600 |
| AAAA | `@` | `2606:50c0:8003::153` | 600 |
| CNAME | `www` | `adamnormand.github.io.` | 600 |

All four A and all four AAAA records are required — they are an anycast set, not
alternatives. The `www` CNAME points at the **user** subdomain, never at the repo path.

If the Squarespace editor rejects a bare `@`, use the domain itself or leave the host
field blank; its UI varies.

---

## 3. Configure the GitHub side

1. Commit a `CNAME` file at the repo root containing exactly:
   ```
   evidencebasedsolutions.ca
   ```
2. **Settings → Pages → Source:** *Deploy from a branch* → `main` / `/ (root)`.
3. **Settings → Pages → Custom domain:** `evidencebasedsolutions.ca` → Save.
   The DNS check fails until propagation catches up. Expected.
4. Once it passes, tick **Enforce HTTPS**. The certificate is issued automatically —
   usually minutes, occasionally up to 24 h. Do not tick it before the certificate
   exists or the site serves errors.

---

## 4. Verify

```bash
dig +noall +answer evidencebasedsolutions.ca A          # the four 185.199.x.153
dig +noall +answer www.evidencebasedsolutions.ca CNAME  # adamnormand.github.io.
dig +noall +answer evidencebasedsolutions.ca MX         # unchanged from step 0

curl -sSI https://evidencebasedsolutions.ca | head -1       # 200
curl -sSI http://evidencebasedsolutions.ca | head -1        # 301 -> https
curl -sSI https://www.evidencebasedsolutions.ca | head -1   # 301 -> apex
```

By hand: apex loads, `www` redirects, padlock valid, and **send a test email to an
address on the domain and confirm receipt.** A broken site is obvious within minutes;
broken mail is not.

Spot-check the old URLs as well — every path indexed by Google should still resolve.
See *URL parity* below.

---

## 5. Decommission Kinsta — only after 48 h clean

1. Raise TTLs back to 3600 s.
2. **Take a final full backup from MyKinsta and download it** before anything else.
   Once the site is deleted, the WordPress database and uploads are gone.
3. Remove the domain from the Kinsta site, then delete the site / close the plan.

Do not cancel Kinsta on cutover day. It costs one month's hosting to keep a working
rollback target, which is cheap.

---

## Rollback

Re-add the Kinsta A record captured in step 0 and remove the GitHub records. With TTL
at 600 s you are back inside ~10 minutes. Kinsta keeps serving the WordPress site
throughout — nothing there changes until step 5 — so rollback is purely a DNS action.

---

## One thing this migration breaks that DNS will not tell you about

**URL parity.** WordPress permalinks end in a trailing slash (`/about/`). GitHub Pages
serves `about/index.html` at `/about/`, so parity holds *if* the files are laid out that
way — which is why the structure in `README.md` uses `about/index.html` rather than
`about.html`. Before cutover, pull the full URL list from `sitemap_index.xml` (the
extraction script saves it) and confirm every one has a counterpart. Anything dropped
becomes a 404 with live inbound links pointing at it.

**No longer a concern: the contact form.** The WordPress form plugin would have had no
server to POST to on static hosting, and would have silently dropped enquiries. The
contact page is instead being rebuilt as plain published contact details with `mailto:`
and `tel:` links, so there is no form endpoint, no third-party form service, and no
server-side dependency anywhere in the stack. See `README.md` → *Decisions*.
