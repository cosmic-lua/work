Not re-opening the `new`-side derivation from «ihON_6fDu», which is correct
and landed. Not changing `briefmeasure.measure`'s row format or the
bare-header rendering for a genuinely empty list, which is deliberate and
tested (`_work/briefmeasure_test.tl:76-78`). Not touching `set --touches`,
which stays the way a caller states a list explicitly.
