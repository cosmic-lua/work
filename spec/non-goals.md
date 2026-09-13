- no change to the proxy or its allowlist grammar — hostname policy
  stays the proxy's; ports are the only new tier.
- no weakening: a host with neither netns nor ABI 4 reports exactly
  that, and a non-best-effort Box refuses as it does today.
