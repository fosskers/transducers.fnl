# transducers.fnl

## Unreleased

#### Added

- Transducer: `unique-by`
- Transducer: `once`
- Reducer: `quantities`
- Reducer: `for-each`
- Reducer: `all?` and `any?` as the proper forms of `all` and `any`. The latter
  have been deprecated but not removed.
- Source: `reversed` to iterate over a table in reverse order.

#### Fixed 

- Transduction over tables with LuaJIT.

