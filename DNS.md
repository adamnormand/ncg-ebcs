# DNS cutover — Squarespace → GitHub Pages

Domain: `evidencebasedsolutions.ca`
Target: GitHub Pages, repo `adamnormand/ncg-ebcs`

Do not start until the static site is built, pushed to `main`, and verified at
`https://adamnormand.github.io/ncg-ebcs/`. DNS is the last step, not the first.

---

## 0. Before you touch anything

Record the current state so a rollback is mechanical, not archaeological:

```bash
dig +noall +answer evidencebasedsolutions.ca A
dig +noall +answer evidencebasedsolutions.ca AAAA
dig +noall +answer www.evidencebasedsolutions.ca CNAME
dig +noall +answer evidencebasedsolutions.ca MX
dig +noall +answer evidencebasedsolutions.ca TXT
```

Screenshot the Squarespace DNS panel as well. Then lower TTL to **600 s** on the
records you are about to change (A, AAAA, `www`) and wait out the *old* TTL —
typically 1–4 h — before the cutover. This is what turns a bad cutover into a
10-minute problem instead of a 24-hour one.

---

## 1. Disconnect the domain from the Squarespace site

Squarespace re-asserts its own A/CNAME records while a domain is still attached to a
site. Skipping this is the single most common reason a cutover silently reverts.

**Settings → Domains →** `evidencebasedsolutions.ca` **→ Connected site → Disconnect.**

Keep the domain *registered* at Squarespace — you are only detaching it from the
Squarespace-hosted site. Registration, renewal and email routing are unaffected.

---

## 2. Remove the Squarespace hosting records

**Settings → Domains →** `evidencebasedsolutions.ca` **→ DNS → DNS Settings.**

Delete these, if present:

| Type | Host | Value |
|---|---|---|
| A | `@` | `198.185.159.144` |
| A | `@` | `198.185.159.145` |
| A | `@` | `198.49.23.144` |
| A | `@` | `198.49.23.145` |
| CNAME | `www` | `ext-cust.squarespace.com` |
| CNAME | *(random string)* | `verify.squarespace.com` |

**Leave everything else alone.** In particular do not touch:

- `MX` records — email for the domain dies instantly if you remove these.
- `TXT` — SPF (`v=spf1 …`), DMARC (`_dmarc`), and any DKIM selector records.
- `CNAME` records for third-party services (mail, calendar, e-sign, analytics).

---

## 3. Add the GitHub Pages records

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

All four A records and all four AAAA records are required — they are GitHub's
anycast set, not alternatives. The `www` CNAME points at the **user** subdomain
(`adamnormand.github.io`), never at the repo path.

If the Squarespace editor rejects a bare `@`, use the domain itself
(`evidencebasedsolutions.ca`) or a blank host field — Squarespace's UI varies.

---

## 4. Configure the GitHub side

1. Commit a `CNAME` file at the repo root containing exactly:
   ```
   evidencebasedsolutions.ca
   ```
2. **Settings → Pages → Custom domain:** `evidencebasedsolutions.ca` → Save.
   GitHub runs a DNS check; it will fail until propagation catches up. That is expected.
3. Once the check passes, tick **Enforce HTTPS**. The Let's Encrypt certificate is
   issued automatically, usually within minutes but allow up to 24 h.

Do not tick *Enforce HTTPS* before the certificate exists — it will serve errors.

---

## 5. Verify

```bash
dig +noall +answer evidencebasedsolutions.ca A          # expect the four 185.199.x.153
dig +noall +answer www.evidencebasedsolutions.ca CNAME  # expect adamnormand.github.io.
dig +noall +answer evidencebasedsolutions.ca MX         # unchanged from step 0

curl -sSI https://evidencebasedsolutions.ca | head -1       # expect 200
curl -sSI http://evidencebasedsolutions.ca | head -1        # expect 301 to https
curl -sSI https://www.evidencebasedsolutions.ca | head -1   # expect 301 to apex
```

Then confirm by hand: apex loads, `www` redirects, the padlock is valid, and **send a
test email to an address on the domain and confirm receipt.** Email is the thing that
breaks quietly.

---

## 6. After 48 hours of clean operation

- Raise TTLs back to 3600 s.
- Cancel the Squarespace *site* subscription if it is separate from the domain
  registration. Keep the registration until you are ready to transfer it.

---

## Rollback

Re-add the records captured in step 0 and reconnect the domain to the Squarespace site
(step 1, in reverse). With TTL at 600 s the site is back within ~10 minutes. This is
why step 0 is not optional.

---

## Two things worth deciding before you start

**Registrar.** Leaving `.ca` registration at Squarespace after the site moves means
paying Squarespace for a service you have reduced to a DNS panel. Transferring to a
registrar you already use consolidates it. Do this *after* the cutover is stable —
never during.

**Apex vs. www.** The table above serves both, with `www` redirecting to the apex.
If the old site canonicalised to `www`, keep both live regardless so existing inbound
links and any print collateral continue to resolve.
