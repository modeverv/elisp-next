#!/bin/sh
# The site of elisp-next (GitHub Pages): README.md as the home page and
# doc/api.md as api/, with their Japanese versions under ja/ and api/ja/,
# and the Markdown itself under doc/ for agents.  Made with elisp-react's
# tools/api-doc.mjs ($ELISP_REACT, or a checkout of elisp-react next to
# this one), which fails on a link to an anchor that is not there.
#   tools/site.sh OUT-DIR [--commit SHA]
set -eu
cd "$(dirname "$0")/.."
out="${1:?usage: tools/site.sh OUT-DIR [--commit SHA]}"; shift
react="${ELISP_REACT:-../elisp-react}"
doc="node $react/tools/api-doc.mjs --repo modeverv/elisp-next --version main"
rm -rf "$out" && mkdir -p "$out/doc"
$doc "$@" --in README.md --out "$out/index.html" --title "elisp-next" \
  --link "doc/api.md=api/" --link "doc/api.ja.md=api/ja/" --link "README.ja.md=ja/" --alt "日本語=ja/" \
  --nav "API reference=api/" --nav "elisp-react API=https://modeverv.github.io/elisp-react/api/"
$doc "$@" --in README.ja.md --out "$out/ja/index.html" --title "elisp-next" --lang ja \
  --link "doc/api.md=../api/" --link "doc/api.ja.md=../api/ja/" --link "README.md=../" --alt "English=../" \
  --nav "API リファレンス=../api/ja/" --nav "elisp-react API=https://modeverv.github.io/elisp-react/api/ja/"
$doc "$@" --in doc/api.md --out "$out/api/index.html" --title "elisp-next API" \
  --alt "日本語=ja/" --nav "Home=../" --nav "elisp-react API=https://modeverv.github.io/elisp-react/api/"
$doc "$@" --in doc/api.ja.md --out "$out/api/ja/index.html" --title "elisp-next API（日本語）" --lang ja \
  --link "doc/api.md=../" --alt "English=../" \
  --nav "ホーム=../../ja/" --nav "elisp-react API=https://modeverv.github.io/elisp-react/api/ja/"
cp doc/api.md doc/api.ja.md "$out/doc/"
cp SKILL.md "$out/SKILL.md"
