return {
  forced_live_overlap = {
    file = "_work/stateclaim.tl",
    before = 'claim.take_refusal(st, caller, now, false, why)',
    after = 'claim.take_refusal(st, caller, now, force, why)',
    test = "_work/stateclaim_test.tl",
  },
  self_overlap_acquisition = {
    file = "_work/stateclaim.tl",
    before = 'if held then denial = "item is already claimed by this session; use renew or drop" end',
    after = 'if held and false then denial = "item is already claimed by this session; use renew or drop" end',
    test = "_work/stateclaim_cli_test.tl",
  },
  padded_sequence_indices_are_decimal = {
    file = "_work/singlehead_literal.tl",
    before = 'local index = tonumber(key, 10)',
    after = 'local index = tonumber(key)',
    test = "_work/boardtree_test.tl",
  },
  receipt_reacquisition_identity = {
    file = "_work/stateclaim_authority.tl",
    before = 'old.claim.id ~= st.root or old.claim.holder ~= st.holder',
    after = 'old.claim.holder ~= st.holder',
    test = "_work/stateclaim_authority_test.tl",
  },
  second_parent_receipt_authority = {
    file = "_work/stateclaim_authority.tl",
    before = '{"git", "rev-list", "--first-parent", st.control}',
    after = '{"git", "rev-list", st.control}',
    test = "_work/stateclaim_authority_test.tl",
  },
  expired_claim_authority = {
    file = "_work/stateclaim_authority.tl",
    before = 'if claim.status(st, os.time()) ~= "active" then',
    after = 'if claim.status(st, os.time()) ~= "active" and false then',
    test = "_work/stateclaim_authority_test.tl",
  },
  stale_snapshot_authority = {
    file = "_work/stateclaim_authority.tl",
    before = 'local head, herr = refs.read_ref(s.root, ref)',
    after = 'local head, herr = s.state_head, ref:sub(1, 0)',
    test = "_work/stateclaim_authority_test.tl",
  },
  expiry_never_releases = {
    file = "_work/claim.tl",
    before = 'if now >= st.expires_at then',
    after = 'if now >= st.expires_at and false then',
    test = "_work/stateclaim_test.tl",
  },
  renewal_changes_acquisition_identity = {
    file = "_work/stateclaim.tl",
    before = 'next_claim = {id = old.id, holder = old.holder, acquired_at = old.acquired_at,',
    after = 'next_claim = {id = boardtree.mint_claim_id(), holder = old.holder, acquired_at = old.acquired_at,',
    test = "_work/stateclaim_test.tl",
  },
  local_head_as_remote_canonical = {
    file = "_work/stateread_start.tl",
    before = 'local snapshot, err = refs.for_each_ref(root, cachedb.WATCH_PATTERNS)',
    after = 'local snapshot, err = refs.for_each_ref_raw(root, cachedb.WATCH_PATTERNS)',
    test = "_work/stateread_test.tl",
  },
  direct_claim_wrongly_uses_take_gate = {
    file = "_work/stateclaim_cli.tl",
    before = 's.session, s.op = caller, verb',
    after = 's.session, s.op, s.bounded = caller, verb == "claim" and "take" or verb, action == "take"',
    test = "_work/stateclaim_cli_test.tl",
  },
}
