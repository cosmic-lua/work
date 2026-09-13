No change to the dated version scheme, CLI version format, debug-asset
verification coverage, release immutability settings, existing published
assets, or unrelated workflows.

A tag-qualified download URL is not itself proof that GitHub enforces
release immutability. This change proves the bytes downloaded during
verification equal this run's publication digest and remain unchanged
during execution. It does not promise that an administrator can never
replace assets later.

A post-publication failure marks the workflow failed; it does not undo
publication. Do not delete, replace, or unpublish a failed release here.
