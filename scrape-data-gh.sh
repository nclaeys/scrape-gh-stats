#!/usr/bin/env bash
set -euo pipefail

# Usage: ./gh-traffic.sh owner/repo [--csv]
# Example: ./gh-traffic.sh openai/gpt-5 --csv

REPO="${1:?Repository (owner/repo) required}"
OUTPUT_LOCATION="${2:-$(pwd)}"
EXPORT_CSV=true

if [[ "${2:-}" == "--no-csv" ]]; then
  EXPORT_CSV=false
fi

# Extract repo name (after slash) for output folder
REPO_NAME="$(basename "$REPO")"
if $EXPORT_CSV; then
  OUTDIR="${OUTPUT_LOCATION}/${REPO_NAME}_stats"
  mkdir -p "$OUTDIR"
  echo "📂 CSV output will be written to $OUTDIR/"
fi

append_csv() {
  local file="$1"
  local header="$2"
  local data="$3"
  if [ ! -f "$file" ]; then
    echo "$header" > "$file"
  fi
  echo "$data" >> "$file"
  
  # Deduplicate (skip header, sort unique by first column, then reattach header)
  tmp=$(mktemp)
  { head -n1 "$file"; tail -n +2 "$file" | sort -t, -k1,1 -u; } > "$tmp"
  mv "$tmp" "$file"
}

echo "📊 Fetching traffic data for $REPO..."

echo "format of the data is: timestamp,total,unique"
echo -e "\n=== Views (last 14 days) ==="
VIEWS=$(gh api repos/$REPO/traffic/views | jq -r '.views[] | "\(.timestamp),\(.count),\(.uniques)"')
echo "$VIEWS" | awk -F, '{printf "%s,%s,%s\n",$1,$2,$3}'
if $EXPORT_CSV; then append_csv "$OUTDIR/views.csv" "timestamp,count,uniques" "$VIEWS"; fi

echo -e "\n=== Clones (last 14 days) ==="
CLONES=$(gh api repos/$REPO/traffic/clones | jq -r '.clones[] | "\(.timestamp),\(.count),\(.uniques)"')
echo "$CLONES" | awk -F, '{printf "%s,%s,%s\n",$1,$2,$3}'
if $EXPORT_CSV; then append_csv "$OUTDIR/clones.csv" "timestamp,count,uniques" "$CLONES"; fi

echo -e "\n=== Popular Paths (top 10) ==="
PATHS=$(gh api repos/$REPO/traffic/popular/paths | jq -r '.[] | "\(.path),\(.count),\(.uniques)"')
echo "$PATHS" | awk -F, '{printf "%s,%s,%s\n",$1,$2,$3}'
if $EXPORT_CSV; then append_csv "$OUTDIR/popular_paths.csv" "path,count,uniques" "$PATHS"; fi

echo -e "\n=== Popular Referrers (top 10) ==="
REFERRERS=$(gh api repos/$REPO/traffic/popular/referrers | jq -r '.[] | "\(.referrer),\(.count),\(.uniques)"')
echo "$REFERRERS" | awk -F, '{printf "%s,%s,%s\n",$1,$2,$3}'
if $EXPORT_CSV; then append_csv "$OUTDIR/popular_referrers.csv" "referrer,count,uniques" "$REFERRERS"; fi

