return {
  final_remote_head = {
    file = "_work/stateplan.tl",
    before = 'observed_head ~= plan.expected_head',
    after = 'observed_head == plan.expected_head',
    test = "_work/stateplan_calls_test.tl",
  },
  shell_physical_author = {
    file = "_work/stateplan.tl",
    before = 'if name ~= transition.author.name or email ~= transition.author.email or date ~= transition.author.date then',
    after = 'if (name ~= transition.author.name or email ~= transition.author.email or date ~= transition.author.date) and false then',
    test = "_work/stateplan_trailers_test.tl",
  },
  tree_chunk_parent = {
    file = "_work/stateplan_calls.tl",
    before = 'base_tree = "$" .. id .. ".sha"',
    after = 'base_tree = ""',
    test = "_work/stateplan_calls_test.tl",
  },
  publication_repository_identity = {
    file = "_work/statestaging.tl",
    before = '"gitboard.publicationRepository"',
    after = '"gitboard.repository"',
    test = "_work/statepublish_cli_test.tl",
  },
}
