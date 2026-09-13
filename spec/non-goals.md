No git objects are written and no caller moves onto this module here. The
`meta` line set is unchanged — dropping `claim_batch` is the claims child's
change, made where `item.tl` declares the field (`grep -n "claim_batch ="
_work/item.tl`).
