#!/usr/bin/env bash
#
# Extract content, media and rendered styling from the live WordPress site.
# Run on any machine with normal internet access, then commit the result.
#
#   bash tools/extract.sh
#
# Requires curl (present on macOS and Linux by default). Uses wget for the
# site mirror when available and falls back to a curl-based crawler when not,
# so a stock Mac needs no installs.
#
set -uo pipefail

SITE="${SITE:-https://evidencebasedsolutions.ca}"
HOST="$(printf '%s' "$SITE" | sed -E 's#^https?://##; s#/.*##')"
OUT="${OUT:-ebcs-extract}"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"

have() { command -v "$1" >/dev/null 2>&1; }
get()  { curl -fsSL -A "$UA" --compressed --max-time 60 --retry 2 "$1"; }
save() { curl -fsSL -A "$UA" --compressed --max-time 60 --retry 2 --create-dirs -o "$2" "$1"; }

have curl || { echo "FATAL: curl not found. Install it and re-run." >&2; exit 1; }
mkdir -p "$OUT"
echo "==> Target: $SITE"

if ! get "$SITE/" >/dev/null 2>&1; then
  echo "FATAL: cannot reach $SITE from this machine." >&2
  echo "       Check the URL, your connection, or any VPN/proxy in the way." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 1. Rendered mirror — HTML, CSS, JS, fonts, images as actually served.
#    This is what preserves the style. The REST API alone will not.
# ---------------------------------------------------------------------------
echo "==> [1/5] Mirroring rendered site"
if have wget; then
  echo "    using wget"
  wget --mirror --page-requisites --adjust-extension --convert-links --no-parent \
       --span-hosts --domains="$HOST,www.$HOST" --user-agent="$UA" \
       --wait=1 --random-wait --tries=3 --timeout=30 \
       --directory-prefix="$OUT/mirror" "$SITE/" \
    || echo "    (wget exited non-zero — a partial mirror is still usable)"
else
  echo "    wget not found — using the built-in curl crawler instead"
  echo "    (for a byte-exact mirror: brew install wget, then re-run)"
  mkdir -p "$OUT/mirror"

  # Page list: homepage + sitemap entries + internal links found on the homepage.
  { echo "$SITE/"
    get "$SITE/sitemap_index.xml" 2>/dev/null | grep -oE 'https?://[^< ]+\.xml' \
      | while read -r sm; do get "$sm" 2>/dev/null | grep -oE '<loc>[^<]+' | sed 's/<loc>//'; done
    get "$SITE/sitemap.xml"       2>/dev/null | grep -oE '<loc>[^<]+' | sed 's/<loc>//'
    get "$SITE/" 2>/dev/null | grep -oE 'href="[^"#?]+"' | sed 's/href="//; s/"$//' \
      | sed -E "s#^/#$SITE/#" | grep -E "^$SITE" 
  } 2>/dev/null | grep -viE '\.(jpe?g|png|gif|svg|webp|css|js|pdf|zip|ico|woff2?)$' \
    | sed 's#/$##' | sort -u > "$OUT/_pages.txt"
  echo "    $(wc -l < "$OUT/_pages.txt" | tr -d ' ') page(s) to fetch"

  : > "$OUT/_assets.txt"
  while read -r url; do
    [ -n "$url" ] || continue
    rel="${url#"$SITE"}"; rel="${rel#/}"
    dest="$OUT/mirror/${rel:-.}/index.html"
    echo "    $url"
    save "$url" "$dest" || { echo "      (failed)"; continue; }
    # Harvest asset references from this page.
    { grep -oE '(href|src|data-src)="[^"]+"' "$dest" | sed -E 's/^[a-z-]+="//; s/"$//'
      grep -oE 'url\([^)]+\)' "$dest" | sed -E 's/^url\(//; s/\)$//; s/^["'"'"']//; s/["'"'"']$//'
    } 2>/dev/null \
      | grep -viE '^(data:|mailto:|tel:|javascript:|#)' \
      | grep -iE '\.(css|js|png|jpe?g|gif|svg|webp|avif|woff2?|ttf|otf|eot|ico|pdf)(\?|$)' \
      | sed -E "s#^//#https://#; s#^/#$SITE/#" \
      | grep -E '^https?://' >> "$OUT/_assets.txt"
  done < "$OUT/_pages.txt"

  sort -u "$OUT/_assets.txt" -o "$OUT/_assets.txt"
  echo "    $(wc -l < "$OUT/_assets.txt" | tr -d ' ') asset(s)"
  while read -r a; do
    [ -n "$a" ] || continue
    path="$(printf '%s' "$a" | sed -E 's#^https?://##; s#\?.*$##')"
    save "$a" "$OUT/mirror/_assets/$path" >/dev/null 2>&1 || true
  done < "$OUT/_assets.txt"

  # Second pass: stylesheets reference fonts and background images of their own.
  find "$OUT/mirror/_assets" -name '*.css' 2>/dev/null | while read -r css; do
    grep -oE 'url\([^)]+\)' "$css" 2>/dev/null \
      | sed -E 's/^url\(//; s/\)$//; s/^["'"'"']//; s/["'"'"']$//' \
      | grep -viE '^data:' | sed -E "s#^//#https://#; s#^/#$SITE/#" \
      | grep -E '^https?://' | sort -u \
      | while read -r f; do
          p="$(printf '%s' "$f" | sed -E 's#^https?://##; s#\?.*$##')"
          save "$f" "$OUT/mirror/_assets/$p" >/dev/null 2>&1 || true
        done
  done
fi

# ---------------------------------------------------------------------------
# 2. Structured content via the WordPress REST API.
# ---------------------------------------------------------------------------
echo "==> [2/5] WordPress REST API"
for ep in pages posts media categories tags users; do
  if save "$SITE/wp-json/wp/v2/$ep?per_page=100" "$OUT/api-$ep.json" 2>/dev/null; then
    echo "    /wp-json/wp/v2/$ep"
  else
    echo "    /wp-json/wp/v2/$ep — unavailable (REST API disabled or restricted)"
  fi
done
save "$SITE/wp-json/" "$OUT/api-root.json" >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# 3. Media library originals — catches uploads the crawl missed.
# ---------------------------------------------------------------------------
echo "==> [3/5] Media library originals"
if [ -s "$OUT/api-media.json" ]; then
  grep -oE '"source_url":"[^"]+"' "$OUT/api-media.json" \
    | sed 's/"source_url":"//; s/"$//; s#\\/#/#g' | sort -u > "$OUT/media-urls.txt"
  echo "    $(wc -l < "$OUT/media-urls.txt" | tr -d ' ') file(s)"
  while read -r m; do
    [ -n "$m" ] || continue
    save "$m" "$OUT/media/$(basename "${m%%\?*}")" >/dev/null 2>&1 || true
  done < "$OUT/media-urls.txt"
else
  echo "    skipped (no api-media.json)"
fi

# ---------------------------------------------------------------------------
# 4. Metadata.
# ---------------------------------------------------------------------------
echo "==> [4/5] Metadata"
for path in sitemap.xml sitemap_index.xml robots.txt feed; do
  save "$SITE/$path" "$OUT/$(printf '%s' "$path" | tr / _)" >/dev/null 2>&1 || true
done

# ---------------------------------------------------------------------------
# 5. Contact details — transcribed verbatim, never retyped.
# ---------------------------------------------------------------------------
echo "==> [5/5] Contact details"
{
  echo "# mailto: targets"
  grep -rhoE 'mailto:[^"<>[:space:]]+' "$OUT/mirror" 2>/dev/null \
    | sed "s/^mailto://; s/[?].*$//" | tr -d "'\"" | sort -u
  echo; echo "# tel: targets"
  grep -rhoE 'tel:[^"<>[:space:]]+' "$OUT/mirror" 2>/dev/null \
    | sed "s/^tel://" | tr -d "'\"" | sort -u
  echo; echo "# email-shaped strings anywhere in the markup"
  grep -rhoE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$OUT/mirror" 2>/dev/null | sort -u
  echo; echo "# rendered text of the contact page"
  find "$OUT/mirror" -path '*contact*' -name '*.html' -exec \
    sed -E 's/<[^>]+>/ /g; s/[[:space:]]+/ /g' {} \; 2>/dev/null | sort -u
} > "$OUT/contact-details.txt"

rm -f "$OUT/_pages.txt" "$OUT/_assets.txt"
tar -czf ebcs-extract.tar.gz "$OUT"

echo
echo "======================================================================"
echo " Pages captured : $(find "$OUT/mirror" -name '*.html' 2>/dev/null | wc -l | tr -d ' ')"
echo " Stylesheets    : $(find "$OUT/mirror" -name '*.css' 2>/dev/null | wc -l | tr -d ' ')"
echo " Images/fonts   : $(find "$OUT/mirror" \( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.svg' -o -name '*.webp' -o -name '*.gif' -o -name '*.woff*' \) 2>/dev/null | wc -l | tr -d ' ')"
echo " Media library  : $(find "$OUT/media" -type f 2>/dev/null | wc -l | tr -d ' ')"
echo " Total size     : $(du -sh "$OUT" 2>/dev/null | cut -f1)"
echo "======================================================================"
echo
echo "If Stylesheets is 0, the style was not captured — say so rather than"
echo "committing, and use the browser 'Save Page As -> Complete' fallback."
echo
echo "Next:  git add ebcs-extract.tar.gz && git commit -m 'Add site extraction' && git push"
