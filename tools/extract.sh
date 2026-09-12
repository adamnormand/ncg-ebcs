#!/usr/bin/env bash
#
# Extract content, media and rendered styling from the live WordPress site.
# Run this from any machine with normal internet access, then commit the
# resulting archive (or its unpacked contents) to this repo.
#
#   bash tools/extract.sh
#
# Produces ./ebcs-extract/ and ebcs-extract.tar.gz
#
set -euo pipefail

SITE="${SITE:-https://evidencebasedsolutions.ca}"
OUT="${OUT:-ebcs-extract}"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"

mkdir -p "$OUT"
echo "==> Target: $SITE"

# ---------------------------------------------------------------------------
# 1. Rendered mirror — HTML, CSS, JS, fonts and images exactly as served.
#    This is what preserves the *style*. The REST API alone will not.
# ---------------------------------------------------------------------------
echo "==> [1/5] Mirroring rendered site"
wget \
  --mirror \
  --page-requisites \
  --adjust-extension \
  --convert-links \
  --no-parent \
  --span-hosts \
  --domains="$(echo "$SITE" | sed -E 's#https?://##; s#/.*##'),www.$(echo "$SITE" | sed -E 's#https?://##; s#/.*##')" \
  --user-agent="$UA" \
  --wait=1 --random-wait \
  --tries=3 --timeout=30 \
  --directory-prefix="$OUT/mirror" \
  "$SITE/" || echo "    (wget exited non-zero — partial mirrors are still usable)"

# ---------------------------------------------------------------------------
# 2. Structured content via the WordPress REST API.
#    Clean per-page title/slug/rendered-HTML, without theme chrome.
# ---------------------------------------------------------------------------
echo "==> [2/5] WordPress REST API"
for ep in pages posts media categories tags users; do
  echo "    /wp-json/wp/v2/$ep"
  curl -fsS -A "$UA" "$SITE/wp-json/wp/v2/$ep?per_page=100" \
    -o "$OUT/api-$ep.json" \
    || echo "    (unavailable — REST API may be disabled or restricted)"
done
curl -fsS -A "$UA" "$SITE/wp-json/" -o "$OUT/api-root.json" || true

# ---------------------------------------------------------------------------
# 3. Every media file referenced by the media library.
#    Catches uploads the crawl missed (lazy-loaded, CSS backgrounds, PDFs).
# ---------------------------------------------------------------------------
echo "==> [3/5] Media library originals"
if [ -s "$OUT/api-media.json" ]; then
  mkdir -p "$OUT/media"
  grep -oE '"source_url":"[^"]+"' "$OUT/api-media.json" \
    | sed 's/"source_url":"//; s/"$//; s#\\/#/#g' \
    | sort -u > "$OUT/media-urls.txt"
  echo "    $(wc -l < "$OUT/media-urls.txt") files"
  wget -q --show-progress -A '*' -P "$OUT/media" -i "$OUT/media-urls.txt" \
       --user-agent="$UA" --tries=3 --timeout=30 || true
else
  echo "    (skipped — no api-media.json)"
fi

# ---------------------------------------------------------------------------
# 4. Reference metadata.
# ---------------------------------------------------------------------------
echo "==> [4/5] Metadata"
for path in sitemap.xml sitemap_index.xml robots.txt feed; do
  curl -fsS -A "$UA" "$SITE/$path" -o "$OUT/$(echo "$path" | tr / _).xml" 2>/dev/null || true
done

# ---------------------------------------------------------------------------
# 5. Contact details.
#    The contact page becomes plain mailto:/tel: links, so the exact addresses
#    and numbers currently published are needed verbatim. Never retyped.
# ---------------------------------------------------------------------------
echo "==> [5/5] Contact details"
{
  echo "# mailto: targets"
  grep -rhoE 'mailto:[^"<>[:space:]]+' "$OUT/mirror" 2>/dev/null \
    | sed "s/^mailto://" | tr -d "'\"" | sed "s/[?].*$//" | sort -u
  echo
  echo "# tel: targets"
  grep -rhoE 'tel:[^"<>[:space:]]+' "$OUT/mirror" 2>/dev/null \
    | sed "s/^tel://" | tr -d "'\"" | sort -u
  echo
  echo "# email-shaped strings anywhere in the markup"
  grep -rhoE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$OUT/mirror" 2>/dev/null \
    | sort -u
  echo
  echo "# rendered text of the contact page (addresses, hours, anything else)"
  find "$OUT/mirror" -path '*contact*' -name '*.html' -exec \
    sed -E 's/<[^>]+>/ /g; s/[[:space:]]+/ /g' {} \; 2>/dev/null | sort -u
} > "$OUT/contact-details.txt"
echo "    -> $OUT/contact-details.txt"

tar -czf ebcs-extract.tar.gz "$OUT"
echo
echo "Done. $(du -sh "$OUT" | cut -f1) in $OUT/, archived to ebcs-extract.tar.gz"
echo "Commit the archive (or $OUT/) to this repo and the rebuild can proceed."
