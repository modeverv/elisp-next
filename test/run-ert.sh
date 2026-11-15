#!/usr/bin/env bash
# The tests of elisp-next in a native Emacs: test/nextel-test.el, after
# compiling lisp/ with warnings as errors.
#   react.el:      $ELISP_REACT, or a checkout of elisp-react next to this one
#   app-server.el: $ELISP_STUDIO, or a checkout of elisp-studio next to this
#                  one (the server side; its tests are skipped without it)
set -euo pipefail
cd "$(dirname "$0")/.."
react="${ELISP_REACT:-../elisp-react}"
if [ ! -f "${react}/lisp/react.el" ]; then
  echo "react.el not found in ${react}; set ELISP_REACT" >&2
  exit 1
fi
emacs="${EMACS:-$("${react}/tools/find-emacs.sh")}"
exec "${emacs}" --batch -Q -L "${react}/lisp" -L lisp \
  --eval "(require 'bytecomp)" \
  --eval "(let ((byte-compile-error-on-warn t)
                (byte-compile-dest-file-function (lambda (_file) (concat (make-temp-name \"/tmp/nextel-\") \".elc\"))))
            (dolist (file (directory-files \"lisp\" t \"\\\\.el\\\\'\"))
              (unless (byte-compile-file file) (kill-emacs 1))))" \
  -l test/nextel-test.el -f ert-run-tests-batch-and-exit
