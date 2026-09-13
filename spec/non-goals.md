- Not specific to chunked encoding — reproduces identically with
  `Content-Length`, so the fix belongs wherever the connection loop's
  `parse` call lives (`cosmic/http/init.tl`), not in either the
  core's or streaming's request-body-specific code.
