return {
  incremental_history_range = {
    file = "_work/stateread_cache.tl",
    before = 'boardhistory.read(root, head, before)',
    after = 'boardhistory.read(root, head)',
    test = "_work/stateread_range_test.tl",
  },
  incremental_event_sequence = {
    file = "_work/stateread_cache.tl",
    before = '(sequences[id] or 0) + seq',
    after = 'seq',
    test = "_work/stateread_range_test.tl",
  },
  first_parent_range_boundary = {
    file = "_work/boardhistory.tl",
    before = 'oldest_parent ~= before',
    after = 'oldest_parent ~= before and false',
    test = "_work/stateread_range_test.tl",
  },
}
