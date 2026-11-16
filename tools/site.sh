#!/bin/sh
# The site of elisp-next (GitHub Pages): README.md as the home page,
# doc/api.md as api/, and the Markdown itself under doc/ for agents.  Made
# with elisp-react's tools/api-doc.mjs ($ELISP_REACT, or a checkout of
# elisp-react next to this one), which fails on a link to an anchor that
# is not there.
#   tools/site.sh OUT-DIR [--commit SHA]
set -eu
cd "$(dirname "$0")/.."
out="${1:?usage: tools/site.sh OUT-DIR [--commit SHA]}"; shift
react="${ELISP_REACT:-../elisp-react}"
doc="node $react/tools/api-doc.mjs --repo modeverv/elisp-next --version main"
other="elisp-react API=https://modeverv.github.io/elisp-react/api/"
rm -rf "$out" && mkdir -p "$out/doc"
$doc "$@" --in README.md --out "$out/index.html" --title "elisp-next" \
  --link "doc/api.md=api/" --nav "API reference=api/" --nav "$other"
$doc "$@" --in doc/api.md --out "$out/api/index.html" --title "elisp-next API" \
  --nav "Home=../" --nav "$other"
cp doc/api.md "$out/doc/api.md"
cp SKILL.md "$out/SKILL.md"
