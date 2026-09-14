return {
  four_attempts_instead_of_five = {
    file = "_work/statepublish.tl",
    before = 'for attempt = 1, 5 do',
    after = 'for attempt = 1, 4 do',
    test = "_work/statepublish_lifecycle_test.tl",
  },
  missing_dependency_cycle_witness = {
    file = "_work/graphguards.tl",
    before = 'if dep == id then',
    after = 'if false then',
    test = "_work/graphguards_test.tl",
  },
  parent_depth_off_by_one = {
    file = "_work/graphguards.tl",
    before = 'local current = index[parent]\n  for _ = 1, item.MAX_DEPTH do',
    after = 'local current = index[parent]\n  for _ = 1, item.MAX_DEPTH + 1 do',
    test = "_work/graphguards_test.tl",
  },
  unbounded_cli_claim = {
    file = "_work/stateclaim_cli.tl",
    before = 's.bounded = action == "take"',
    after = 's.bounded = false',
    test = "_work/stateclaim_capacity_test.tl",
  },
  missing_handover_workload = {
    file = "_work/indexddl.tl",
    before = "WHEN claim <> '' OR handover_head <> '' OR pr <> 0 OR result <> ''",
    after = "WHEN claim <> '' OR pr <> 0",
    test = "_work/stategate_test.tl",
  },
  pre_state_only_doing_bound = {
    file = "_work/stategate.tl",
    before = 'projected > flow.DOING_LIMIT and projected > previous',
    after = 'previous >= flow.DOING_LIMIT and projected >= 0',
    test = "_work/stategate_test.tl",
  },
  containers_count_as_doing = {
    file = "_work/indexddl.tl",
    before = 'AND NOT EXISTS (SELECT 1 FROM open_items c WHERE c.parent = i.id);',
    after = ';',
    test = "_work/stategate_test.tl",
  },
}
