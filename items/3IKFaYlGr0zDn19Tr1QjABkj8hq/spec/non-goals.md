- **No runtime template engine.** Templates known only at run time are not served
  by this item.
- **No reflection, no `Funcs` registry, no runtime name resolution.**
- **No `*.tmpl` build convention.** Build-time use is an ordinary user `*_gen.tl`
  calling `compile`. The convention is its own item.
- **No URL, JavaScript or CSS contexts.** HTML text context only; the rest is its
  own item.
- **No context scanner.** Escaping is a type obligation, not an inferred property
  of surrounding markup.
