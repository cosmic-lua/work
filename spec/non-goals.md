- Do not attempt the actual C port in this item.
- Do not touch `third_party/mbedtls` or delete anything yet — deletion
  is the last item in the chain this research produces, gated on every
  earlier piece having landed and `make -j$(nproc) o//tool/net/redbean
  o//tool/lua/test` passing with the 3.6-only link.
- Do not re-decide gh#184's fix here — it is its own item and this
  item's task 2 is satisfied by that item's outcome, not duplicated.
