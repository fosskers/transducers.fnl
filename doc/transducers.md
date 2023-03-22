# Transducers.fnl

**Table of contents**

- [`add`](#add)
- [`all`](#all)
- [`comp`](#comp)
- [`concat`](#concat)
- [`cons`](#cons)
- [`count`](#count)
- [`dedup`](#dedup)
- [`drop`](#drop)
- [`drop-while`](#drop-while)
- [`enumerate`](#enumerate)
- [`filter`](#filter)
- [`filter-map`](#filter-map)
- [`group-by`](#group-by)
- [`intersperse`](#intersperse)
- [`map`](#map)
- [`mul`](#mul)
- [`pass`](#pass)
- [`reduced`](#reduced)
- [`reduced?`](#reduced-1)
- [`segment`](#segment)
- [`step`](#step)
- [`take`](#take)
- [`take-while`](#take-while)
- [`transduce`](#transduce)
- [`unique`](#unique)
- [`window`](#window)

## `add`
Function signature:

```
(add a b)
```

Add two numbers `a` and `b`. Unlike the normal `+`, this can be passed to
higher-order functions and behaves as a legal reducer.

```fennel
(assert (= 0 (add)))
(assert (= 1 (add 1)))
(assert (= 3 (add 1 2)))
```

## `all`
Function signature:

```
(all pred)
```

Yield `true` if all elements of the transduction satisfy `pred`. Short-circuit
with `false` if any element fails the test.

```fennel
(assert (transduce pass (all #(= 3 (length $1))) ["abc" "def" "ghi"]))
(assert (not (transduce pass (all #(= 3 (length $1))) ["abc" "de" "ghi"])))
```

## `comp`
Function signature:

```
(comp f ...)
```

Function composition of `f` with any number of other functions.

`((comp f g h) 1)` is equivalent to `(f (g (h 1)))`.

```fennel
(let [f (comp #(+ 1 $1) #(length $1))]
  (assert (= 4 (f "foo"))))
```

## `concat`
Function signature:

```
(concat reducer)
```

Concatenate all the subtables in the transduction.

```fennel
(assert (table.= [1 2 3 4 5 6] (transduce concat cons [[1 2] [3 4] [5 6]])))
(assert (table.= [1 2 3] (transduce (comp concat (take 3)) cons [[1 2] [3 4] [5 6]])))
```

## `cons`
Function signature:

```
(cons acc input)
```

Build up a new sequential Table of all elements that made it through the
transduction.

```fennel
(assert (table.= [1 2 3] (transduce pass cons [1 2 3])))
```

## `count`
Function signature:

```
(count acc input)
```

Count the number of elements that made it through the transduction.

```fennel
(assert (= 4 (transduce pass count [1 2 3 4])))
```

## `dedup`
Function signature:

```
(dedup reducer)
```

Remove adjecent duplicates from the transduction.

```fennel
(let [res (transduce dedup cons [1 1 1 2 2 2 3 3 3 4 3 3])]
  (assert (table.= [1 2 3 4 3] res)))
```

## `drop`
Function signature:

```
(drop n)
```

Drop the first `n` elements of the transduction.

```fennel
(assert (table.= [1 2 3 4 5] (transduce (drop 0) cons [1 2 3 4 5])))
(assert (table.= [4 5] (transduce (drop 3) cons [1 2 3 4 5])))
(assert (table.= [] (transduce (drop 100) cons [1 2 3 4 5])))
```

## `drop-while`
Function signature:

```
(drop-while pred)
```

Drop elements from the front of the transduction that satisfy `pred`.

```fennel
(let [res (transduce (drop-while #(= 0 (% $1 2))) cons [2 4 6 8 9 10])]
  (assert (table.= [9 10] res)))
```

## `enumerate`
Function signature:

```
(enumerate reducer)
```

Index every value passed through the transduction into a pair. Starts at 1.

```fennel
(let [res (transduce enumerate cons ["a" "b" "c"])]
  (assert (table.= [[1 "a"] [2 "b"] [3 "c"]] res)))
```

## `filter`
Function signature:

```
(filter pred)
```

Only keep elements from the transduction that satisfy `pred`.

```fennel
(assert (table.= [2 4] (transduce (filter #(= 0 (% $1 2))) cons [1 2 3 4 5])))
```

## `filter-map`
Function signature:

```
(filter-map f)
```

Apply a function `f` to the elements of the transduction, but only keep results
that are non-nil.

```fennel
(let [res (transduce (filter-map #(. $1 1)) cons [[] [2 3] [] [5 6] [] [8 9]])]
  (assert (table.= [2 5 8] res)))
```

## `group-by`
Function signature:

```
(group-by f)
```

Group the input stream into tables via some function `f`. The cutoff criterion
is whether the return value of `f` changes between two consecutive elements of
the transduction.

```fennel
(let [res (transduce (group-by #(= 0 (% $1 2))) cons [2 4 6 7 9 1 2 4 6 3])]
  (assert (table.= [[2 4 6] [7 9 1] [2 4 6] [3]] res)))
```

## `intersperse`
Function signature:

```
(intersperse elem)
```

Insert an `elem` between each value of the transduction.

```fennel
(assert (table.= [1] (transduce (intersperse 0) cons [1])))
(assert (table.= [1 0 2 0 3] (transduce (intersperse 0) cons [1 2 3])))
```

## `map`
Function signature:

```
(map f)
```

Apply a function `f` to all elements of the transduction.

```fennel
(assert (table.= [2 3 4] (transduce (map #(+ 1 $1)) cons [1 2 3])))
```

## `mul`
Function signature:

```
(mul a b)
```

Multiply two numbers `a` and `b`. Unlike the normal `*`, this can be passed to
higher-order functions and behaves as a legal reducer.

```fennel
(assert (= 1 (mul)))
(assert (= 2 (mul 2)))
(assert (= 6 (mul 2 3)))
```

## `pass`
Function signature:

```
(pass reducer)
```

Just pass along each value of the transduction without transforming.

```fennel
(assert (table.= [1 2 3] (transduce pass cons [1 2 3])))
```

## `reduced`
Function signature:

```
(reduced item)
```

Announce to the transduction process that we are done, and the given `item` is
the final result.

## `reduced?`
Function signature:

```
(reduced? tbl)
```

Has a transduction been short-circuited? This tests the given `tbl` for a
certain shape produced by the `reduced` function, which itself is only called
within transducers that have the concept of short-circuiting, like `take`.

```fennel
(assert (not (reduced? [1])))
(assert (reduced? {:reduced 1}))
(assert (reduced? {:reduced false}))
```

## `segment`
Function signature:

```
(segment n)
```

Partition the input into tables of `n` items. If the input stops, flush any
accumulated state, which may be shorter than `n`.

```fennel
(assert (table.= [[1 2 3] [4 5]] (transduce (segment 3) cons [1 2 3 4 5])))
```

## `step`
Function signature:

```
(step n)
```

Only yield every `n`th element of the transduction. The first element is always
included.

```fennel
(let [res (transduce (step 2) cons [1 2 3 4 5 6 7 8 9])]
  (assert (table.= [1 3 5 7 9] res)))
```

## `take`
Function signature:

```
(take n)
```

Keep the first `n` elements of the transduction.

```fennel
(assert (table.= [] (transduce (take 0) cons [1 2 3 4 5])))
(assert (table.= [1 2 3] (transduce (take 3) cons [1 2 3 4 5])))
(assert (table.= [1 2 3 4 5] (transduce (take 100) cons [1 2 3 4 5])))
```

## `take-while`
Function signature:

```
(take-while pred)
```

Keep only elements which satisfy `pred`, and stop the transduction as soon as
any element fails the test.

```fennel
(assert (table.= [2 4 6 8] (transduce (take-while #(= 0 (% $1 2))) cons [2 4 6 8 9 2])))
```

## `transduce`
Function signature:

```
(transduce xform reducer source ...)
```

The entry point for processing a data source via transducer functions. It
accepts:

- `xform`: a chain of composed transducer functions, like `map` and `filter`.
- `reducer`: a reducer function to "collect" or "fold" all the final elements together.
- `source`: a potentially infinite source of data (but usually a table).
- `...`: any number of additional sources.

### Basic Usage

Every transduction requires a data source, a way to transform individual
elements, and a way to collapse all results into a single value. These are the
arguments described above. To use them:

```fennel
(transduce
  (map #(+ 1 $1)) ;; (2) Transform each element.
  cons            ;; (3) Collecting each transformed element.
  [1 2 3])        ;; (1) Feed each source element through the chain.
```

### Composing Transducers

Fennel already supplies `each`, `collect`, and `accumulate`, so if we could only
do one transformation at a time then Transducers wouldn't be useful. Luckily
Transducers can be composed:

```fennel
(let [res (transduce (comp (filter-map #(. $1 1))
                           (filter #(= 0 (% $1 2)))
                           (map #(* 2 $1)))
                     cons
                     [[] [1 3] [] [4 6] [] [7 9] [] [10 12]])]
  (assert (table.= [8 20] res)))
```

This transduction works over a potentially infinite stream of tables. It says:

1. Keep only the first element of non-empty tables.
2. Then, of those, keep only even numbers.
3. Then, of those, multiply them by 2.

The surviving values are then collected into a new table.

### Processing multiple source at once

It is possible to pass as many sources to `transduce` as you want. However, only
as many elements as held by the shortest source will be passed through. This is
analogous to how `zip` works in many languages. For example:

```fennel
(let [res (transduce (map #(+ $1 $2)) cons [1 2 3] [4 5 6 7])]
  (assert (table.= [5 7 9] res)))
```

Notice that the function passed to `map` can be of any arity to accomodate this.

## `unique`
Function signature:

```
(unique reducer)
```

Only allow values to pass through the transduction once each.
Stateful; this uses a Table internally as a set, so could get quite heavy if
you're not careful.

```fennel
(let [res (transduce unique cons [1 2 1 3 2 1 2 "abc"])]
  (assert (table.= [1 2 3 "abc"] res)))
```

## `window`
Function signature:

```
(window n)
```

Yield `n`-length windows of overlapping values. This is different from `segment`
which yields non-overlapping windows. If there were fewer items in the input
than `n`, then this yields nothing.

```fennel
(let [res (transduce (window 3) cons [1 2 3 4 5])]
  (assert (table.= [[1 2 3] [2 3 4] [3 4 5]] res)))
```


<!-- Generated with Fenneldoc v1.0.0
     https://gitlab.com/andreyorst/fenneldoc -->
