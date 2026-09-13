No change to the `--- env:` grammar (#1156 owns it). No change to which files
declare reads. No sweep for other multi-token declarations (the acceptance's
project.mk check is the tree-wide proof for the one known case; a second case
would surface the same way).
