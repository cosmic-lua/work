- No change to the `CONFIG_LOG` success path (`return 3` at line
  2496) — its three-value success shape (`OK, prev_func, prev_udata`)
  is unaffected and out of scope.
- No decision here on whether to also raise on an undocumented
  `option` value — noted as a follow-on option above, not required.
