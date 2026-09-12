# cosmic.http.static: serve a directory or the artifact's own /zip payload, content type from cosmo.http.find_content_type

## Goal

An htmx page needs `htmx.min.js` and a stylesheet served from
somewhere, and the cosmic answer is "from inside the binary": a
`--embed`-built artifact carries `embed/**` at `/zip/...`, so a static
handler over a root path serves a self-contained web app from one
file. The same handler over a filesystem directory serves a dev tree.

## Evidence

Ready when: `ls cosmic/http/router.tl` prints `cosmic/http/router.tl`.

That is the router child merged (its `*rest` patterns are how a static
handler is mounted); today the command reports the path as missing.

Traversal safety is bound already: `cosmo.IsAcceptablePath`
(`tool/net/definitions.lua:3023`) — "checks if path is acceptable ...
`.` or `..`" per the redbean docs. The content-type table is the
binding child's `cosmo.http.find_content_type`. File reads are
`cosmic.fs.read` (`cosmic/fs/init.tl`); `/zip/` paths read through it
already (the doc index does: `cosmic/doc/mentions.tl:12` `GUIDES_DIR =
"/zip/docs/guides"`).

## Change

New file `cosmic/http/static.tl` (module `cosmic.http.static`):

- `new(root: string, opts?: StaticOptions): Handler | nil, string` —
  `root` a directory (`fs.path.is_dir`, `cosmic/fs/path.tl:58`, at
  construction, else `nil, msg`);
  `/zip/...` roots work because `fs` reads the zip filesystem. `opts`:
  `index: string` (default `"index.html"`, served for a directory
  path), `cache_control: string` (default `"no-cache"`; the guide shows
  `"public, max-age=31536000, immutable"` for hashed assets).
- The handler takes the path to serve from `req.params.rest` when
  mounted under a `*rest` route, else from `req.path`; refuses with 404
  any path `cosmo.IsAcceptablePath` rejects or that escapes `root`
  after `fs.path.normalize` (`cosmic/fs/path.tl:135`);
  405 for a method other than GET/HEAD; 404 for a missing file; else
  200 with `Content-Type` from `find_content_type(path)` falling back
  to `application/octet-stream`, `Content-Length`, `Last-Modified`
  (`FormatHttpDateTime(mtime)`), `Cache-Control`; HEAD sends the head
  only. Files are read whole (`fs.read`) in this slice; a file over
  `max_body_bytes`... is not bounded by that (that is a request cap) —
  state the send cap: 64 MiB, `413`-free, `500` with a log line past
  it.
- Tests `cosmic/http/static_test.tl` (`--- requires: loopback-listen`
  only for the one end-to-end case; the rest pure against a
  `TEST_TMPDIR` tree): content types for `.html/.css/.js/.png/.zzz`,
  index file, `..` refused, a path outside root refused, HEAD, 405,
  `Last-Modified` format, and one request through `serve_one`.
- `cosmic/http/init_example.tl`: `Example_static` — mount at
  `/static/*rest`, fetch `/static/app.css` from a temp dir.

## Non-goals

- `Range` requests and `If-Modified-Since`/`ETag` conditional GETs:
  the next slice if a use appears; binding `ParseHttpRange` then.
- Directory listings.
- Compression.

## Access

- cosmic-lua/cosmic: read+write.
