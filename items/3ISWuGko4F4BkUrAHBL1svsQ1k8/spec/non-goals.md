The lint half of the class — `end_line_of` on `as function(any, any)`
(3IP9ijhv) — is a different walker in a different tree; untouched
here, the item stays open. No change to `is_function_block_opener`
(its `is` handling is already correct) or to the carried-depth
mechanics. No reformat of committed files: today's tree contains no
mangled instance (the one observed was fixed by hand in 3ISWHWQT).
