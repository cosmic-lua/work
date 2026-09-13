Fixing any specific verb's algorithm (`fsck`'s per-item git calls are
filed separately as «5k6U_43IK»); the SQL-views seam («BZCt_Z5l7»);
running a full `git gc` (not `--auto`) anywhere in the hot path; touching
the real `cosmic-lua/work` clone's current packed state, which is fine
today and not itself evidence of a problem.
