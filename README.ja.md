# elisp-next

[elisp-react](https://github.com/modeverv/elisp-react) のための「ファイルがページになる」層です。React と Next.js の中間の書き心地を Emacs Lisp で実現します。

- **ファイルがアドレス。** `pages/channel/[id].el` は `/channel/ID` です。`pages/_layout.el` は全ページを囲み、ページを移ってもマウントされたままです。`pages/404.el` は、どのファイルにもないアドレスのページです。
- **ファイルが API のルート。** `api/later.el` が `/api/later` に答えます。elisp-studio のサーバー（ネイティブの Emacs、または studio のブラウザのタブ）の上で動きます。
- **両側で検査する型。** `shared/*.el` に `nextel-defschema` でレコードを定義します。ページとサーバーが同じファイルを読み込み、やりとりする値を検査します。

[English](README.md) · 使用例: [Parens](https://github.com/modeverv/elisp-react-youtube-similar)（YouTube 風の動画ブラウザ、[公開中](https://modeverv.github.io/elisp-react-youtube-similar/)）

| | Next.js | elisp-next |
|---|---|---|
| ページ | `app/watch/page.js` がコンポーネントを export | `pages/watch.el` に `(nextel-page WatchPage ...)` |
| そのアドレス | ファイルのパス | ファイルのパス: `pages/channel/[id].el` は `/channel/ID` |
| 全ページを囲むもの | `layout.js` | `pages/_layout.el`、`(nextel-layout Layout ...)` |
| 見つからないとき | `not-found.js` | `pages/404.el` |
| ページのデータ | サーバーコンポーネント | `:load`（awaitable）。待つ間は `:loading`、失敗は `:error` |
| タイトルと meta | `generateMetadata` | `:head` |
| リンク | `<Link href>` | `(Link (:href (nextel-href "/watch" :v id)) ...)` |
| API | `app/api/later/route.js` が `GET`、`POST` を export | `api/later.el` に `(nextel-handle "GET" ...)`、`(nextel-handle "POST" ...)` |
| 共有する型 | TypeScript の型 | `nextel-defschema`。両側で実行時に検査 |
| ルートの発見 | 開発サーバーが `app/` を監視 | Emacs が `routes.el` と `<script>` タグを書く（`M-x nextel-write-routes`、または保存のたびに） |

Lisp の接頭辞は `nextel-` です。`next-` は Emacs 自身のもの（`next-line`、`next-match`）だからです。

完全な API は、コーディングエージェントが推測せずに使えるように書いた [doc/api.md](doc/api.md)（英語）にあります。

## プロジェクトで使う

プロジェクトは elisp-next のコピーを `vendor/elisp-next/` に持ちます（ページは Lisp をプロジェクトから読み込み、elisp-studio のプレビューはほかのサイトのものを読み込まないためです）。

```sh
mkdir -p vendor/elisp-next
curl -L https://github.com/modeverv/elisp-next/archive/refs/tags/v0.1.0.tar.gz \
  | tar -xz --strip-components=1 -C vendor/elisp-next elisp-next-0.1.0/lisp elisp-next-0.1.0/bin elisp-next-0.1.0/LICENSE
```

`index.html` には、elisp-next が書く `<script>` タグの置き場所を2つ、アプリケーション自身の Lisp の前後に用意します。

```html
<div id="app">Loading Emacs…</div>
<!-- nextel:framework -->
<!-- /nextel:framework -->
<script type="text/emacs-lisp" src="lisp/app-helpers.el"></script>
<!-- nextel:pages -->
<!-- /nextel:pages -->
<script type="module" src="https://modeverv.github.io/elisp-react/js/elisp-react.js"></script>
```

それからルートを書き出します。Emacs（elisp-studio のものも含む）では次のとおりです。

```
M-x load-file RET vendor/elisp-next/lisp/nextel-build.el RET   セッションごとに1回
M-x nextel-write-routes     ページを足す・消す・名前を変えたあと
M-x nextel-routes-mode      pages/、api/、shared/ のファイルを保存するたびに
```

バッチでは `vendor/elisp-next/bin/nextel-routes` です（`--check` は CI 用、`--watch` は別のエディタ用）。`routes.el`（どのパターンがどのページか。`#app` にアプリケーションをマウントします）を書き、2つの置き場所を埋めます。ページはディレクトリを一覧できないので、書き出しが必要です。ページのファイルは自分のコンポーネントに名前を付けます。Next.js のファイルが export するのと同じです。

## ページ

```elisp
;;; pages/channel/[id].el --- /channel/ID
(nextel-page ChannelPage
  :load (lambda (route) (my-load-channel (nextel-param route :id)))
  :head (lambda (route data) (list :title (plist-get data :title) :description (plist-get data :about)))
  :loading (lambda (route) (jsx (p "読み込み中…")))
  :error (lambda (route error retry) (jsx (button (:on-click (lambda (_e) (funcall retry))) "再試行")))
  :render (lambda (self)
            (jsx (h1 (plist-get (nextel-data self) :title)))))
```

`nextel-page` は `react-define-component`（`:initial-state`、`:did-mount` などのキーも使えます）に4つのキーを足したものです。

| | |
|---|---|
| `:load (ROUTE)` | awaitable（`react-await`）。答えが来るとページを描き、その値は `(nextel-data SELF)` です。答えはルートごとに保存され（`react-query`）、戻るとすぐに表示されます。 |
| `:loading (ROUTE)`、`:error (ROUTE ERROR RETRY)` | 待つ間（失敗のあと読み込み直す間も）と、失敗したときに表示するもの。既定は `nextel-loading-function`、`nextel-error-function`。 |
| `:head (ROUTE DATA)` | `(:title TEXT :description TEXT :meta ((NAME . CONTENT) ...))`。文書のタイトルは `(funcall nextel-title-function TITLE)`。 |

ページは props として `:route`（plist `(:page :pattern :path :params :query)`）、`:data`、そして `nextel-page-props-function` が全ページに足すものを受け取ります。`(nextel-param SELF :id)`、`(nextel-query SELF "v")`、`(nextel-data SELF)` で読み、`(nextel-route)` は今表示しているルートです。

```elisp
;;; pages/_layout.el
(nextel-layout Layout
  :render (lambda (self)
            (jsx (div (header (Link (:href (nextel-href "/")) "ホーム"))
                      (main (react-props self :children))))))
```

| | |
|---|---|
| `(nextel-href PATTERN PARAMS...)` | アドレス。`(nextel-href "/channel/[id]" :id "UC1")` は `"#/channel/UC1"`、`(nextel-href "/watch" :v "x" :t 30)` は `"#/watch?v=x&t=30"`。 |
| `(Link (:href HREF ...) CHILD...)` | リンク。ハッシュ方式ではブラウザが辿る `<a>`、パス方式では Lisp が辿ります。 |
| `(nextel-go PATTERN PARAMS...)`、`(nextel-navigate HREF [REPLACE])` | Lisp から移動します。 |
| `nextel-navigate-functions` | 新しいアドレスのページを描いたあとに呼ぶ ROUTE の関数（先頭へのスクロール、ドロワーを閉じるなど）。 |
| `(nextel-reload)`、`(nextel-refresh)` | 全ページのデータを読み込み直す（データ源が変わったとき）、ページを描き直す（`nextel-page-props-function` の答えが変わったとき）。 |
| `nextel-url-mode`、`nextel-base-path` | `hash`（既定。`#/watch?v=ID`。どの静的ホストでも、elisp-studio のプレビューでも動く）または `path`（`nextel-base-path` の下の `/watch?v=ID`。サーバーはどのルートにも `index.html` を返す必要があります）。 |

## サーバー

プロジェクトの `server.el` は次の3行です。

```elisp
(declare-function nextel-server-load "nextel-server")   ; ないと起動のたびにバイトコンパイラが警告する
(load (expand-file-name "vendor/elisp-next/lisp/nextel-server.el" app-server-project-directory) nil t)
(nextel-server-load)
```

`shared/`、`api/` の補助ファイル（名前が `_` で始まるファイルとディレクトリ）を読み込み、`api/` のそれ以外の各ファイルをルートとして読み込みます。各ファイルは、メソッドごとに何をするかを書きます。

```elisp
;;; api/later.el --- GET と POST /api/later
(nextel-handle "GET"
  :returns '(list-of my-entry)
  :handler (lambda (_request) (app-server-read "later" nil)))

(nextel-handle "POST"
  :accepts 'my-entry
  :returns '(list-of my-entry)
  :handler (lambda (request)
             (app-server-write "later" (cons (plist-get request :body) (app-server-read "later" nil)))))
```

`REQUEST` は `(:method :path :params :body)` です。body はデータで（`app-server-data`）、評価されることはありません。クエリは `(app-server-parameter NAME)` で読みます。`:accepts` に合わない body は、どの項目が違うかを添えて断ります（400、`body.id is required`）。`:returns` に合わない答えはサーバーの誤りです（500、ログに出ます）。あとで返す答え（`app-server-defer`）も同じです。ファイルのないパスは 404、ファイルが扱わないメソッドは 405 です。サーバーはディレクトリを自分で読むので、新しいファイルは次の起動でルートになります。[elisp-studio](https://github.com/modeverv/elisp-studio) の `app-server.el` の上で、ネイティブの Emacs（`run.sh`）でも studio のブラウザのタブでも同じように動きます。

## 型

```elisp
;;; shared/my-types.el --- ページ（index.html）とサーバーの両方が読み込む
(nextel-defschema my-entry
  "後で見るために保存した動画。"
  (id string :required t)
  (title string)
  (saved number))
```

これで `make-my-entry`（検査つき）、`my-entry-p`、項目の `my-entry-id`、`my-entry-title`、`my-entry-saved` が定義されます。レコードは plist なので、Lisp のデータとして印字し、読み戻せます。型は `string`、`integer`、`number`、`boolean`、`symbol`、`keyword`、`any`、スキーマの名前、`(member VALUE...)`、`(list-of TYPE)`、`(vector-of TYPE)`、`(or TYPE...)` です。項目は `:required` でなければ nil でもかまいません。スキーマにないキーは誤りです。`(nextel-check TYPE VALUE)` は VALUE を返すか、どこが違うかを添えて `nextel-type-error` を出します（`my-entry.title: expected string, got 42`）。

ページは同じ型でサーバーに問い合わせます。

```elisp
(nextel-request "POST" "/api/later" :body entry :sends 'my-entry :returns '(list-of my-entry))
```

これは awaitable で、失敗は `(:status N :message TEXT)` です。答えが `:returns` に合わなければ `:status` は nil です（`POST /api/later[0].id: expected string, got 42`）。項目のアクセサはアプリケーションと同じ名前空間にあるので、`スキーマ-項目` が自分の関数とぶつからないようにスキーマの名前を付けます。

## 制限

- サーバー側での描画はありません（ハッシュはサーバーに届きません）。`nextel-url-mode` を `path` にすれば elisp-studio の `app-server-page-function` で描けるはずですが、未検証です。
- 全ページを最初に読み込みます（コード分割なし）。レイアウトは1つで、入れ子にはできません。ミドルウェアはありません。
- 型は値がやりとりされるときに検査されるもので、書いている途中には検査されません（型検査器はありません）。未定義の関数や引数の数の誤りは、今もバイトコンパイラが見つけます。
- 2026-11-16 の wasmacs の修正（[wasmacs#21](https://github.com/modeverv/wasmacs/issues/21)）より前は、ページの Emacs でフックが動きませんでした。ルーターは `nextel-navigate-functions` を自分で呼ぶので、どちらでも動きます。

## テスト

```sh
test/run-ert.sh    # react.el は ../elisp-react か $ELISP_REACT、app-server.el は ../elisp-studio か $ELISP_STUDIO
```

`lisp/` を警告をエラーとしてコンパイルし、`test/nextel-test.el` を実行します。型、パターン、ルーター（ページ、`:load`、`:loading`、`:error` と再試行、head、404、フック、パス方式とそのリンク）、`nextel-request`、ルートの書き出し、サーバー側（ファイルからのルート、`:accepts`、すぐの答えとあとの答えの `:returns`、404、405）です。

## ライセンス

MIT（`LICENSE`）。Emacs の中で動くアプリケーションを公開するときは、GPL と両立するライセンスにする必要があります。MIT はその1つです。
