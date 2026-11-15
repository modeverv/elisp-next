# elisp-next

Files as pages for [elisp-react](https://github.com/modeverv/elisp-react): a layer between React and Next.js, in Emacs Lisp.

- **A file is an address.** `pages/channel/[id].el` is `/channel/ID`; `pages/_layout.el` is around every page and stays mounted; `pages/404.el` is the page of an address that no file has.
- **A file is an API route.** `api/later.el` answers `/api/later`, under elisp-studio's server (a native Emacs, or the studio's browser tab).
- **Types that both sides check.** `shared/*.el` defines records with `nextel-defschema`; the page and the server load the same file and check what crosses.

[日本語](README.ja.md) · Used by [Parens](https://github.com/modeverv/elisp-react-youtube-similar), a YouTube-like video browser ([live](https://modeverv.github.io/elisp-react-youtube-similar/)).

| | Next.js | elisp-next |
|---|---|---|
| A page | `app/watch/page.js` exports a component | `pages/watch.el` has `(nextel-page WatchPage ...)` |
| Its address | the file's path | the file's path: `pages/channel/[id].el` is `/channel/ID` |
| Around every page | `layout.js` | `pages/_layout.el`, `(nextel-layout Layout ...)` |
| Not found | `not-found.js` | `pages/404.el` |
| Data for a page | server components | `:load` (an awaitable); `:loading` and `:error` meanwhile |
| Title and meta | `generateMetadata` | `:head` |
| A link | `<Link href>` | `(Link (:href (nextel-href "/watch" :v id)) ...)` |
| An API | `app/api/later/route.js` exports `GET`, `POST` | `api/later.el` has `(nextel-handle "GET" ...)`, `(nextel-handle "POST" ...)` |
| Shared types | TypeScript types | `nextel-defschema`, checked at run time on both sides |
| Finding the routes | the dev server watches `app/` | Emacs writes `routes.el` and the `<script>` tags (`M-x nextel-write-routes`, or at every save) |

The Lisp prefix is `nextel-`: `next-` is Emacs's own (`next-line`, `next-match`).

The complete API, written so that a coding agent can work from it without guessing: [doc/api.md](doc/api.md).

## In a project

A project keeps a copy of elisp-next in `vendor/elisp-next/` (the page loads its Lisp from the project, and elisp-studio's preview loads nothing from other sites):

```sh
mkdir -p vendor/elisp-next
curl -L https://github.com/modeverv/elisp-next/archive/refs/tags/v0.1.0.tar.gz \
  | tar -xz --strip-components=1 -C vendor/elisp-next elisp-next-0.1.0/lisp elisp-next-0.1.0/bin elisp-next-0.1.0/LICENSE
```

`index.html` has two places for the `<script>` tags that elisp-next writes, around the application's own Lisp:

```html
<div id="app">Loading Emacs…</div>
<!-- nextel:framework -->
<!-- /nextel:framework -->
<script type="text/emacs-lisp" src="lisp/app-helpers.el"></script>
<!-- nextel:pages -->
<!-- /nextel:pages -->
<script type="module" src="https://modeverv.github.io/elisp-react/js/elisp-react.js"></script>
```

Then write the routes. In Emacs, elisp-studio's included:

```
M-x load-file RET vendor/elisp-next/lisp/nextel-build.el RET   once per session
M-x nextel-write-routes     after adding, removing or renaming a page
M-x nextel-routes-mode      at every save of a file of pages/, api/ or shared/
```

or in batch: `vendor/elisp-next/bin/nextel-routes` (`--check` for CI, `--watch` for another editor). It writes `routes.el` (which pattern is which page; it mounts the application at `#app`) and fills the two places. The page cannot list a directory, so this has to be written down; a page's file names its component, as a Next.js file exports one.

## Pages

```elisp
;;; pages/channel/[id].el --- /channel/ID
(nextel-page ChannelPage
  :load (lambda (route) (my-load-channel (nextel-param route :id)))
  :head (lambda (route data) (list :title (plist-get data :title) :description (plist-get data :about)))
  :loading (lambda (route) (jsx (p "Loading…")))
  :error (lambda (route error retry) (jsx (button (:on-click (lambda (_e) (funcall retry))) "Retry")))
  :render (lambda (self)
            (jsx (h1 (plist-get (nextel-data self) :title)))))
```

`nextel-page` is `react-define-component` (any of its keys: `:initial-state`, `:did-mount`, ...) with four more:

| | |
|---|---|
| `:load (ROUTE)` | An awaitable (`react-await`); the page renders when it has answered, with the value as `(nextel-data SELF)`. Answers are kept by route (`react-query`): Back shows them at once. |
| `:loading (ROUTE)`, `:error (ROUTE ERROR RETRY)` | What shows meanwhile (also while it loads again after a failure), and after a failure. Defaults: `nextel-loading-function`, `nextel-error-function`. |
| `:head (ROUTE DATA)` | `(:title TEXT :description TEXT :meta ((NAME . CONTENT) ...))`. The document's title is `(funcall nextel-title-function TITLE)`. |

A page gets the props `:route`, a plist `(:page :pattern :path :params :query)`, `:data`, and what `nextel-page-props-function` adds for every page. `(nextel-param SELF :id)`, `(nextel-query SELF "v")`, `(nextel-data SELF)` read them; `(nextel-route)` is the route shown now.

```elisp
;;; pages/_layout.el
(nextel-layout Layout
  :render (lambda (self)
            (jsx (div (header (Link (:href (nextel-href "/")) "Home"))
                      (main (react-props self :children))))))
```

| | |
|---|---|
| `(nextel-href PATTERN PARAMS...)` | An address: `(nextel-href "/channel/[id]" :id "UC1")` is `"#/channel/UC1"`, `(nextel-href "/watch" :v "x" :t 30)` is `"#/watch?v=x&t=30"`. |
| `(Link (:href HREF ...) CHILD...)` | A link. In the hash mode an `<a>` the browser follows; in the path mode Lisp follows it. |
| `(nextel-go PATTERN PARAMS...)`, `(nextel-navigate HREF [REPLACE])` | Go there from Lisp. |
| `nextel-navigate-functions` | Functions of a ROUTE, called after the page of a new address rendered (scroll to the top, close a drawer). |
| `(nextel-reload)`, `(nextel-refresh)` | Load every page's data again (its source changed); render the page again (what `nextel-page-props-function` says changed). |
| `nextel-url-mode`, `nextel-base-path` | `hash` (default: `#/watch?v=ID`, any static host, elisp-studio's preview) or `path` (`/watch?v=ID` under `nextel-base-path`; a server sends `index.html` for every route). |

## The server

`server.el` of the project:

```elisp
(declare-function nextel-server-load "nextel-server")   ; or the byte compiler warns at every start
(load (expand-file-name "vendor/elisp-next/lisp/nextel-server.el" app-server-project-directory) nil t)
(nextel-server-load)
```

loads `shared/`, the helpers of `api/` (files and directories whose name starts with `_`), and every other file of `api/` as a route, which says what each method does:

```elisp
;;; api/later.el --- GET and POST /api/later
(nextel-handle "GET"
  :returns '(list-of my-entry)
  :handler (lambda (_request) (app-server-read "later" nil)))

(nextel-handle "POST"
  :accepts 'my-entry
  :returns '(list-of my-entry)
  :handler (lambda (request)
             (app-server-write "later" (cons (plist-get request :body) (app-server-read "later" nil)))))
```

`REQUEST` is `(:method :path :params :body)`; the body is data (`app-server-data`), never evaluated; the query is `(app-server-parameter NAME)`. A body that is not of `:accepts` is refused with the field that is wrong (400, `body.id is required`); an answer that is not of `:returns` is the server's mistake (500, logged), also one that comes later (`app-server-defer`). A path with no file is 404, a method the file does not handle 405. The server reads the directory itself, so a new file is a route at the next start. It runs on [elisp-studio](https://github.com/modeverv/elisp-studio)'s `app-server.el`: under a native Emacs (`run.sh`) and in the studio's browser tab alike.

## Types

```elisp
;;; shared/my-types.el --- loaded by the page (index.html) and by the server
(nextel-defschema my-entry
  "A video kept for later."
  (id string :required t)
  (title string)
  (saved number))
```

defines `make-my-entry` (checked), `my-entry-p` and the fields `my-entry-id`, `my-entry-title`, `my-entry-saved`. A record is a plist, so it prints and reads as Lisp data. Types: `string`, `integer`, `number`, `boolean`, `symbol`, `keyword`, `any`, a schema's name, `(member VALUE...)`, `(list-of TYPE)`, `(vector-of TYPE)`, `(or TYPE...)`. A field may be nil unless `:required`; a key the schema does not name is an error. `(nextel-check TYPE VALUE)` returns VALUE or signals `nextel-type-error` with where it is wrong: `my-entry.title: expected string, got 42`.

The page asks the server with the same types:

```elisp
(nextel-request "POST" "/api/later" :body entry :sends 'my-entry :returns '(list-of my-entry))
```

an awaitable whose failure is `(:status N :message TEXT)`; `:status` is nil when the answer was not of `:returns` (`POST /api/later[0].id: expected string, got 42`). The fields' accessors share the application's namespace: name a schema so that `SCHEMA-FIELD` meets none of your functions.

## Limits

- No rendering on the server: the hash never reaches it. With `nextel-url-mode` `path`, elisp-studio's `app-server-page-function` could render pages; not tried.
- Every page is loaded at the start (no code splitting). One layout, not nested ones. No middleware.
- Types are checked when values cross, not while you type: there is no type checker. The byte compiler still finds unknown functions and wrong argument counts.
- The page's Emacs ran no hooks before wasmacs's fix of 2026-11-16 ([wasmacs#21](https://github.com/modeverv/wasmacs/issues/21)); the router calls `nextel-navigate-functions` itself, so either way they run.

## Tests

```sh
test/run-ert.sh    # react.el from ../elisp-react or $ELISP_REACT; app-server.el from ../elisp-studio or $ELISP_STUDIO
```

compiles `lisp/` with warnings as errors and runs `test/nextel-test.el`: types, patterns, the router (pages, `:load`, `:loading`, `:error` and retry, head, 404, the hook, the path mode and its links), `nextel-request`, writing the routes, and the server side (routes from files, `:accepts`, `:returns` for answers now and later, 404, 405).

## Licence

MIT (`LICENSE`). An application that runs in Emacs is to be under a GPL-compatible licence when it is published; MIT is one.
