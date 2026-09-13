Add `agents_md_lines` (and its `%+d` signed delta) to
`format_compare`'s summary line in `_build/size.tl`, following the
exact pattern already used for `lines`/`files`/`binary`/`public
modules` (e.g. append `, doctrine %d (%+d)` to the `string.format`
call and its argument list). Update `_build/size_test.tl`'s two
`format_compare` assertions (the handwritten-report comparison tests
around L78-124) to match the new line text exactly. No change to
`Report`/`REPORT_SPEC` or `report()` — the field already exists and
is already written every release; this only makes the existing
number visible in what actually gets published and diffed release
over release.
