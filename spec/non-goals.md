- `cosmic.toml` is not designed or touched here — it is the sibling
  "and" the spec bar's sizing rule says to cut out; file it as its own
  item once this one lands, so the two modules land as file-disjoint
  siblings.
- `cosmic.httpd` and `cosmic.tls` are not touched — `httpd` needs its
  own scoping pass around what "thin-wrap redbean's HTTP C" means for a
  Teal binding surface, and `tls` is blocked upstream (see Evidence).
- No CSV dialect beyond RFC 4180 (no Excel-specific quirks, no
  configurable quote character, no comment-line skipping, no header-row
  helpers like `csv.parse_with_header`) — those are extensions a later
  item can add once the base module has users.
- No streaming/large-file API (`csv.parse_file` reading incrementally)
  — `parse`/`stringify` operate on an in-memory string, matching
  `cosmic.json`'s and `cosmic.tar`'s existing shape.
