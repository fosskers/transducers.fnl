# Transducers (1.0.0)
Ergonomic, efficient data processing.

**Table of contents**

- [`transduce`](#transduce)
- [`pass`](#pass)
- [`map`](#map)
- [`filter`](#filter)
- [`filter-map`](#filter-map)
- [`drop`](#drop)
- [`drop-while`](#drop-while)
- [`take`](#take)
- [`take-while`](#take-while)
- [`enumerate`](#enumerate)
- [`intersperse`](#intersperse)
- [`concat`](#concat)
- [`segment`](#segment)
- [`window`](#window)
- [`group-by`](#group-by)
- [`unique`](#unique)
- [`unique-by`](#unique-by)
- [`dedup`](#dedup)
- [`step`](#step)
- [`scan`](#scan)
- [`count`](#count)
- [`cons`](#cons)
- [`keyed`](#keyed)
- [`add`](#add)
- [`mul`](#mul)
- [`average`](#average)
- [`all?`](#all)
- [`any?`](#any)
- [`all`](#all-1)
- [`any`](#any-1)
- [`first`](#first)
- [`last`](#last)
- [`csv-write`](#csv-write)
- [`fold`](#fold)
- [`iter`](#iter)
- [`file`](#file)
- [`repeat`](#repeat)
- [`cycle`](#cycle)
- [`ints`](#ints)
- [`csv-read`](#csv-read)
- [`comp`](#comp)
- [`reduced`](#reduced)
- [`reduced?`](#reduced-1)
- [`unreduce`](#unreduce)

## Entry

High-level entrypoints.

### `transduce`
Function signature:

```
(transduce xform reducer source ...)
```

The entry point for processing a data source via transducer functions. It accepts:

- `xform`: a chain of composed transducer functions, like [`map`](#map) and [`filter`](#filter).
- `reducer`: a reducer function to "collect" or "fold" all the final elements together.
- `source`: a potentially infinite source of data (but usually a table).
- `...`: any number of additional sources.

#### Basic Usage

Every transduction requires a data source, a way to transform individual
elements, and a way to collapse all results into a single value. These are the
arguments described above. To use them:

```fennel
(transduce
  (map #(+ 1 $1)) ;; (2) Transform each element.
  cons            ;; (3) Collecting each transformed element.
  [1 2 3])        ;; (1) Feed each source element through the chain.
```

#### Composing Transducers

Fennel already supplies `each`, `collect`, and `accumulate`, so if we could only
do one transformation at a time then Transducers wouldn't be useful. Luckily
Transducers can be composed with [`comp`](#comp):

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

#### Processing multiple source at once

It is possible to pass as many sources to `transduce` as you want. However, only
as many elements as held by the shortest source will be passed through. This is
analogous to how `zip` works in many languages. For example:

```fennel
(let [res (transduce (map #(+ $1 $2)) cons [1 2 3] [4 5 6 7])]
  (assert (table.= [5 7 9] res)))
```

Notice that the function passed to [`map`](#map) can be of any arity to accomodate this.

## Transducers

Various 'mapping' functions.

### `pass`
Function signature:

```
(pass reducer)
```

Just pass along each value of the transduction without transforming.

```fennel
(assert (table.= [1 2 3] (transduce pass cons [1 2 3])))
```

**Note:** This takes a `reducer` as an argument, but as seen in the example,
this function is expected to be passed plain, without any argument.

### `map`
Function signature:

```
(map f)
```

Apply a function `f` to all elements of the transduction.

```fennel
(assert (table.= [2 3 4] (transduce (map #(+ 1 $1)) cons [1 2 3])))
```

### `filter`
Function signature:

```
(filter pred)
```

Only keep elements from the transduction that satisfy `pred`.

```fennel
(assert (table.= [2 4] (transduce (filter #(= 0 (% $1 2))) cons [1 2 3 4 5])))
```

### `filter-map`
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

### `drop`
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

### `drop-while`
Function signature:

```
(drop-while pred)
```

Drop elements from the front of the transduction that satisfy `pred`.

```fennel
(let [res (transduce (drop-while #(= 0 (% $1 2))) cons [2 4 6 8 9 10])]
  (assert (table.= [9 10] res)))
```

### `take`
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

### `take-while`
Function signature:

```
(take-while pred)
```

Keep only elements which satisfy `pred`, and stop the transduction as soon as
any element fails the test.

```fennel
(assert (table.= [2 4 6 8] (transduce (take-while #(= 0 (% $1 2))) cons [2 4 6 8 9 2])))
```

### `enumerate`
Function signature:

```
(enumerate reducer)
```

Index every value passed through the transduction into a pair. Starts at 1.

```fennel
(let [res (transduce enumerate cons ["a" "b" "c"])]
  (assert (table.= [[1 "a"] [2 "b"] [3 "c"]] res)))
```

**Note:** This takes a `reducer` as an argument, but as seen in the example,
this function is expected to be passed plain, without any argument.

### `intersperse`
Function signature:

```
(intersperse elem)
```

Insert an `elem` between each value of the transduction.

```fennel
(assert (table.= [1] (transduce (intersperse 0) cons [1])))
(assert (table.= [1 0 2 0 3] (transduce (intersperse 0) cons [1 2 3])))
```

### `concat`
Function signature:

```
(concat reducer)
```

Concatenate all the subtables in the transduction.

```fennel
(assert (table.= [1 2 3 4 5 6] (transduce concat cons [[1 2] [3 4] [5 6]])))
(assert (table.= [1 2 3] (transduce (comp concat (take 3)) cons [[1 2] [3 4] [5 6]])))
```

**Note:** This takes a `reducer` as an argument, but as seen in the example,
this function is expected to be passed plain, without any argument.

### `segment`
Function signature:

```
(segment n)
```

Partition the input into tables of `n` items. If the input stops, flush any
accumulated state, which may be shorter than `n`.

```fennel
(assert (table.= [[1 2 3] [4 5]] (transduce (segment 3) cons [1 2 3 4 5])))
```

### `window`
Function signature:

```
(window n)
```

Yield `n`-length windows of overlapping values. This is different from [`segment`](#segment)
which yields non-overlapping windows. If there were fewer items in the input
than `n`, then this yields nothing.

```fennel
(let [res (transduce (window 3) cons [1 2 3 4 5])]
  (assert (table.= [[1 2 3] [2 3 4] [3 4 5]] res)))
```

### `group-by`
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

### `unique`
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

**Note:** This takes a `reducer` as an argument, but as seen in the example,
this function is expected to be passed plain, without any argument.

### `unique-by`
Function signature:

```
(unique-by f)
```

Like [`unique`](#unique), but determine uniqueness via a given function `f`.

```fennel
(let [res (transduce (unique-by #(. $1 2)) cons [[:a 1] [:b 2] [:c 1] [:d 3]])]
  (assert (table.= [[:a 1] [:b 2] [:d 3]] res)))
```

### `dedup`
Function signature:

```
(dedup reducer)
```

Remove adjecent duplicates from the transduction.

```fennel
(let [res (transduce dedup cons [1 1 1 2 2 2 3 3 3 4 3 3])]
  (assert (table.= [1 2 3 4 3] res)))
```

**Note:** This takes a `reducer` as an argument, but as seen in the example,
this function is expected to be passed plain, without any argument.

### `step`
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

### `scan`
Function signature:

```
(scan f seed)
```

Build up successive values from the results of previous applications of a given
function `f`. A `seed` is also given, and appears as the first element passed
through the transduction.

```fennel
(assert (table.= [0 1 3 6 10] (transduce (scan add 0) cons [1 2 3 4])))
(assert (table.= [0 1] (transduce (comp (scan add 0) (take 2)) cons [1 2 3 4])))
```

## Reducers

Reduction 'targets'. Also known as 'folds'.

### `count`
Function signature:

```
(count acc input)
```

Reducer: Count the number of elements that made it through the transduction.

```fennel
(assert (= 4 (transduce pass count [1 2 3 4])))
```

**Note:** This takes `acc` and `input` arguments, but as seen in the example,
this function is expected to be passed plain, without any arguments.

### `cons`
Function signature:

```
(cons acc input)
```

Reducer: Build up a new sequential Table of all elements that made it through
the transduction.

```fennel
(assert (table.= [1 2 3] (transduce pass cons [1 2 3])))
```

**Note:** This takes `acc` and `input` arguments, but as seen in the example,
this function is expected to be passed plain, without any arguments.

### `keyed`
Function signature:

```
(keyed acc input)
```

Reducer: Build up a key-value Table of all elements that made it through the
transduction. The input values can be key-value tables of any size; they will be
fused into a single result.

**Note:** This takes `acc` and `input` arguments, but as seen in the example,
this function is expected to be passed plain, without any arguments.

### `add`
Function signature:

```
(add a b)
```

Reducer: Add two numbers `a` and `b`. Unlike the normal `+`, this can be passed
to higher-order functions and behaves as a legal reducer.

```fennel
(assert (= 0 (add)))
(assert (= 1 (add 1)))
(assert (= 3 (add 1 2)))
```

### `mul`
Function signature:

```
(mul a b)
```

Reducer: Multiply two numbers `a` and `b`. Unlike the normal `*`, this can be
passed to higher-order functions and behaves as a legal reducer.

```fennel
(assert (= 1 (mul)))
(assert (= 2 (mul 2)))
(assert (= 6 (mul 2 3)))
```

### `average`
Function signature:

```
(average fallback)
```

Reducer: Calculate the average value of all numeric elements in a transduction.
A `fallback` must be provided in case no elements made it through the
transduction (thus protecting from division-by-zero).

```fennel
(assert (= 3.0 (transduce pass (average -1) [1 2 3 4 5])))
```

### `all?`
Function signature:

```
(all? pred)
```

Reducer: Yield `true` if all elements of the transduction satisfy `pred`.
Short-circuit with `false` if any element fails the test.

```fennel
(assert (transduce pass (all? #(= 3 (length $1))) ["abc" "def" "ghi"]))
(assert (not (transduce pass (all? #(= 3 (length $1))) ["abc" "de" "ghi"])))
```

### `any?`
Function signature:

```
(any? pred)
```

Reducer: Yield `true` if any element in the transduction satisfies `pred`.
Short-circuits the transduction as soon as the condition is met.

```fennel
(assert (not (transduce pass (any? #(= 0 (% $1 2))) [1 3 5 7])))
(assert (transduce pass (any? #(= 0 (% $1 2))) [1 3 5 7 2]))
```

### `all`
Function signature:

```
(all pred)
```

Deprecated: Use [`all?`](#all) instead.

### `any`
Function signature:

```
(any pred)
```

Deprecated: Use [`any?`](#any) instead.

### `first`
Function signature:

```
(first fallback)
```

Reducer: Yield the first value of the transduction, or the `fallback` if there
were none.

```fennel
(assert (= 6 (transduce (filter #(= 0 (% $1 2))) (first 0) [1 3 5 6 9])))
```

### `last`
Function signature:

```
(last fallback)
```

Reducer: Yield the final value of the transduction, or the `fallback` if there
were none.

```fennel
(assert (= 10 (transduce pass (last 0) [2 4 6 7 10])))
```

### `csv-write`
Function signature:

```
(csv-write path headers)
```

Reducer: Given a `path` to write to and a table of `headers` (fields) to keep,
write all CSV data that made it through the transduction.

```fennel
(transduce pass (csv-write "names.csv" ["Name"])
                (csv-read "data.csv"))
```

### `fold`
Function signature:

```
(fold f seed)
```

The fundamental reducer. `fold` creates an ad-hoc reducer based on
a given 2-argument function `f`. A `seed` is also required as the initial
accumulator value, which also becomes the return value in case there were no
input left in the transduction.

Functions like `math.max` cannot be used as-is as reducers since they require at
least 1 argument. For functions like this, `fold` is appropriate.

```fennel
(assert (= 1000 (transduce pass (fold math.max 0) [1 2 3 4 1000 5 6])))
```

## Sources

Sources of data to iterate over.

### `iter`
Function signature:

```
(iter iterator)
```

Source: Given any `iterator`, create a Transducer Source that yields all of its
input.

```fennel
(let [res (transduce pass cons (iter (string.gmatch "hello,world,cats" "[^,]+")))]
  (assert (table.= ["hello" "world" "cats"] res)))
```

### `file`
Function signature:

```
(file path)
```

Source: Given a `path`, create a Transducer Source that yields all the lines of
its file.

To count the lines of a file:

```fennel
(transduce pass count (file "README.org"))
```

### `repeat`
Function signature:

```
(repeat item)
```

Source: Endlessly yield a given `item`.

```fennel
(assert (table.= [5 5 5] (transduce (take 3) cons (repeat 5))))
```

### `cycle`
Function signature:

```
(cycle tbl)
```

Source: Given a `tbl`, endlessly yields its elements.

```fennel
(assert (table.= [1 2 3 1 2] (transduce (take 5) cons (cycle [1 2 3]))))
```

### `ints`
Function signature:

```
(ints start ?step)
```

Source: Yield all integers, beginning with `start` and advancing by an optional
`?step` which can be positive or negative. If you only want a specific range
within the transduction, then use [`take-while`](#take-while) within your transducer chain.

```fennel
(assert (table.= [1 2 3 4 5] (transduce (take 5) cons (ints 1))))
(assert (table.= [1 0 -1 -2 -3] (transduce (take 5) cons (ints 1 -1))))
```

### `csv-read`
Function signature:

```
(csv-read path)
```

Source: Given a `path` to a CSV file, create a Transducer Source that yields all
lines of the file as key-value Tables.

```fennel
(transduce pass count (csv-read "data.csv"))
```

## Utilities

### `comp`
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

### `reduced`
Function signature:

```
(reduced item)
```

Announce to the transduction process that we are done, and the given `item` is
the final result.

### `reduced?`
Function signature:

```
(reduced? tbl)
```

Has a transduction been short-circuited? This tests the given `tbl` for a
certain shape produced by the [`reduced`](#reduced) function, which itself is only called
within transducers that have the concept of short-circuiting, like [`take`](#take).

```fennel
(assert (not (reduced? [1])))
(assert (reduced? (reduced 1)))
(assert (reduced? (reduced false)))
```

### `unreduce`
Function signature:

```
(unreduce tbl)
```

Unwrap a reduced value `tbl`.


---

License: GPLv3


<!-- Generated with Fenneldoc v1.0.1
     https://gitlab.com/andreyorst/fenneldoc -->
