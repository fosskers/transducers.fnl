# Transducers (0.1.0)
Ergonomic, efficient data processing.

**Table of contents**

- [`add`](#add)
- [`all`](#all)
- [`any`](#any)
- [`comp`](#comp)
- [`concat`](#concat)
- [`cons`](#cons)
- [`count`](#count)
- [`csv-read`](#csv-read)
- [`csv-write`](#csv-write)
- [`cycle`](#cycle)
- [`dedup`](#dedup)
- [`drop`](#drop)
- [`drop-while`](#drop-while)
- [`enumerate`](#enumerate)
- [`file`](#file)
- [`filter`](#filter)
- [`filter-map`](#filter-map)
- [`first`](#first)
- [`fold`](#fold)
- [`group-by`](#group-by)
- [`intersperse`](#intersperse)
- [`ints`](#ints)
- [`iter`](#iter)
- [`keyed`](#keyed)
- [`last`](#last)
- [`map`](#map)
- [`mul`](#mul)
- [`pass`](#pass)
- [`reduced`](#reduced)
- [`reduced?`](#reduced-1)
- [`repeat`](#repeat)
- [`scan`](#scan)
- [`segment`](#segment)
- [`step`](#step)
- [`take`](#take)
- [`take-while`](#take-while)
- [`transduce`](#transduce)
- [`unique`](#unique)
- [`unreduce`](#unreduce)
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

## `any`
Function signature:

```
(any pred)
```

Yield `true` if any element in the transduction satisfies `pred`. Short-circuits
the transduction as soon as the condition is met.

```fennel
(assert (not (transduce pass (any #(= 0 (% $1 2))) [1 3 5 7])))
(assert (transduce pass (any #(= 0 (% $1 2))) [1 3 5 7 2]))
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

**Note:** This takes a `reducer` as an argument, but as seen in the example,
this function is expected to be passed plain, without any argument.

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

**Note:** This takes `acc` and `input` arguments, but as seen in the example,
this function is expected to be passed plain, without any arguments.

## `count`
Function signature:

```
(count acc input)
```

Count the number of elements that made it through the transduction.

```fennel
(assert (= 4 (transduce pass count [1 2 3 4])))
```

**Note:** This takes `acc` and `input` arguments, but as seen in the example,
this function is expected to be passed plain, without any arguments.

## `csv-read`
Function signature:

```
(csv-read path)
```

Given a `path` to a CSV file, create a Transducer Source that yields all lines
of the file as key-value Tables.

```fennel
(transduce pass count (csv-read "data.csv"))
```

## `csv-write`
Function signature:

```
(csv-write path headers)
```

Given a `path` to write to and a table of `headers` (fields) to keep, write
all CSV data that made it through the transduction.

```fennel
(transduce pass (csv-write "names.csv" ["Name"])
                (csv-read "data.csv"))
```

## `cycle`
Function signature:

```
(cycle tbl)
```

Given a `tbl`, endlessly yields its elements.

```fennel
(assert (table.= [1 2 3 1 2] (transduce (take 5) cons (cycle [1 2 3]))))
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

**Note:** This takes a `reducer` as an argument, but as seen in the example,
this function is expected to be passed plain, without any argument.

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

**Note:** This takes a `reducer` as an argument, but as seen in the example,
this function is expected to be passed plain, without any argument.

## `file`
Function signature:

```
(file path)
```

Given a `path`, create a Transducer Source that yields all the lines of its
file.

To count the lines of a file:

```fennel
(transduce pass count (file "README.org"))
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

## `first`
Function signature:

```
(first fallback)
```

Yield the first value of the transduction, or the `fallback` if there were none.

```fennel
(assert (= 6 (transduce (filter #(= 0 (% $1 2))) (first 0) [1 3 5 6 9])))
```

## `fold`
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

## `ints`
Function signature:

```
(ints start ?step)
```

Yield all integers, beginning with `start` and advancing by an optional `?step`
which can be positive or negative. If you only want a specific range within the
transduction, then use [`take-while`](#take-while) within your transducer chain.

```fennel
(assert (table.= [1 2 3 4 5] (transduce (take 5) cons (ints 1))))
(assert (table.= [1 0 -1 -2 -3] (transduce (take 5) cons (ints 1 -1))))
```

## `iter`
Function signature:

```
(iter iterator)
```

Given any `iterator`, create a Transducer Source that yields all of its input.

```fennel
(let [res (transduce pass cons (iter (string.gmatch "hello,world,cats" "[^,]+")))]
  (assert (table.= ["hello" "world" "cats"] res)))
```

## `keyed`
Function signature:

```
(keyed acc input)
```

Build up a key-value Table of all elements that made it through the
transduction. The input values can be key-value tables of any size; they will be
fused into a single result.

**Note:** This takes `acc` and `input` arguments, but as seen in the example,
this function is expected to be passed plain, without any arguments.

## `last`
Function signature:

```
(last fallback)
```

Yield the final value of the transduction, or the `fallback` if there were none.

```fennel
(assert (= 10 (transduce pass (last 0) [2 4 6 7 10])))
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

**Note:** This takes a `reducer` as an argument, but as seen in the example,
this function is expected to be passed plain, without any argument.

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
certain shape produced by the [`reduced`](#reduced) function, which itself is only called
within transducers that have the concept of short-circuiting, like [`take`](#take).

```fennel
(assert (not (reduced? [1])))
(assert (reduced? (reduced 1)))
(assert (reduced? (reduced false)))
```

## `repeat`
Function signature:

```
(repeat item)
```

Endlessly yield a given `item`.

```fennel
(assert (table.= [5 5 5] (transduce (take 3) cons (repeat 5))))
```

## `scan`
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

- `xform`: a chain of composed transducer functions, like [`map`](#map) and [`filter`](#filter).
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

### Processing multiple source at once

It is possible to pass as many sources to `transduce` as you want. However, only
as many elements as held by the shortest source will be passed through. This is
analogous to how `zip` works in many languages. For example:

```fennel
(let [res (transduce (map #(+ $1 $2)) cons [1 2 3] [4 5 6 7])]
  (assert (table.= [5 7 9] res)))
```

Notice that the function passed to [`map`](#map) can be of any arity to accomodate this.

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

**Note:** This takes a `reducer` as an argument, but as seen in the example,
this function is expected to be passed plain, without any argument.

## `unreduce`
Function signature:

```
(unreduce tbl)
```

Unwrap a reduced value `tbl`.

## `window`
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


---

License: GPLv3


<!-- Generated with Fenneldoc v1.0.0
     https://gitlab.com/andreyorst/fenneldoc -->
