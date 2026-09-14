return {
  connector_message_rewritten = {
    file = "_work/stateplan.tl",
    before = "message = transition.message}}",
    after = "message = transition.message .. \"\\nmutated\"}}",
    test = "_work/native_connector_cycle_test.tl",
  },
  connector_bare_commit_alias = {
    file = "_work/stateplan.tl",
    before = "tool = \"github_create_commit\"",
    after = "tool = \"create_commit\"",
    test = "_work/native_connector_cycle_test.tl",
  },
  connector_bare_update_alias = {
    file = "_work/stateplan.tl",
    before = "tool = \"github_update_ref\"",
    after = "tool = \"update_ref\"",
    test = "_work/native_connector_cycle_test.tl",
  },
  connector_commit_legacy_repository_argument = {
    file = "_work/stateplan.tl",
    before = "repository_full_name = plan.frozen.repository, parent_sha = parent",
    after = "repo = plan.frozen.repository, parent_sha = parent",
    test = "_work/native_connector_cycle_test.tl",
  },
  connector_update_legacy_repository_argument = {
    file = "_work/stateplan.tl",
    before = "repository_full_name = plan.frozen.repository, branch_name = plan.frozen.branch",
    after = "repo = plan.frozen.repository, branch_name = plan.frozen.branch",
    test = "_work/native_connector_cycle_test.tl",
  },
  connector_wrong_branch = {
    file = "_work/stateplan.tl",
    before = "repository_full_name = plan.frozen.repository, branch_name = plan.frozen.branch",
    after = "repository_full_name = plan.frozen.repository, branch_name = \"other\"",
    test = "_work/native_connector_cycle_test.tl",
  },
  connector_forced_update = {
    file = "_work/stateplan.tl",
    before = "sha = parent, force = false}}",
    after = "sha = parent, force = true}}",
    test = "_work/native_connector_cycle_test.tl",
  },
  local_candidate_recorded_as_provider_result = {
    file = "_work/statepublish_cli.tl",
    before = "candidate.published = published_sha",
    after = "candidate.published = saved.candidate",
    test = "_work/native_connector_cycle_test.tl",
  },
  own_publication_masked_by_unrelated_conflict = {
    file = "_work/statepublish.tl",
    before = "local ok, err = refresh(s.root, remote, published)",
    after = "local ok, err = refresh(s.root, remote)",
    test = "_work/statepublish_lifecycle_test.tl",
  },
  four_push_attempts = {
    file = "_work/statepublish.tl",
    before = "for attempt = 1, 5 do",
    after = "for attempt = 1, 4 do",
    test = "_work/statepublish_lifecycle_test.tl",
  },
}
