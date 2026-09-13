Ready when: `ls cosmic/http/router.tl` prints `cosmic/http/router.tl`.

That is the router child merged (its `*rest` patterns are how a static
handler is mounted); today the command reports the path as missing.

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
