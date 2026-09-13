The C shapes stay: this is an annotation fix. Bundling `fd`+`path` into
one table, or making `Dir:read` return a record, is a contract change
that needs its own item, a `definitions.lua` update in the same commit,
and a cosmic wrapper pass (`cosmic/fs/ops.tl:381`, `cosmic/fs/file.tl:94`,
`cosmic/embed/init.tl:375` destructure `fd, path` today).
