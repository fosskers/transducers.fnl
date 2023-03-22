;; --- Utilities --- ;;

;; TODO Make this a macro.
(fn comp [f ...]
  "Function composition of `f` with any number of other functions.

`((comp f g h) 1)` is equivalent to `(f (g (h 1)))`.

```fennel
(let [f (comp #(+ 1 $1) #(length $1))]
  (assert (= 4 (f \"foo\"))))
```"
  (accumulate [fs f _ g (ipairs (table.pack ...))]
    ;; This let is necessary to prevent an infinite loop involving strange
    ;; binding semantics!
    (let [z fs]
      (fn [arg] (z (g arg))))))

(fn id [item]
  "The identity function. Yields what it was given.

```fennel
(assert (= 5 (id 5)))
```"
  item)

(fn unreduce [tbl]
  "Unwrap a reduced value."
  (. tbl :reduced))

(fn reduced [item]
  "Announce to the transduction process that we are done, and the given `item` is
the final result."
  {:reduced item})

(fn reduced? [tbl]
  "Has a transduction been short-circuited? This tests the given `tbl` for a
certain shape produced by the `reduced` function, which itself is only called
within transducers that have the concept of short-circuiting, like `take`.

```fennel
(assert (not (reduced? [1])))
(assert (reduced? {:reduced 1}))
(assert (reduced? {:reduced false}))
```"
  (and (= :table (type tbl))
       (~= nil (unreduce tbl))))

(fn reduce [f id tbl ...]
  (let [tables (table.pack ...)
        len (accumulate [shortest (length tbl) _ t (ipairs tables)]
              (math.min shortest (length t)))]
    (fn recurse [acc i]
      (if (> i len)
          acc
          (let [vals (icollect [_ t (ipairs tables)] (. t i))
                acc (f acc (. tbl i) (table.unpack vals))]
            (if (reduced? acc)
                (unreduce acc)
                (recurse acc (+ 1 i))))))
    (recurse id 1)))

(lambda transduce [xform reducer source ...]
  "The entry point for processing a data source via transducer functions. It
accepts:

- `xform`: a chain of composed transducer functions, like `map` and `filter`.
- `reducer`: a reducer function to \"collect\" or \"fold\" all the final elements together.
- `source`: a potentially infinite source of data (but usually a table).
- `...`: any number of additional sources.

# Basic Usage

Every transduction requires a data source, a way to transform individual
elements, and a way to collapse all results into a single value. These are the
arguments described above. To use them:

```fennel
(transduce
  (map #(+ 1 $1)) ;; (2) Transform each element.
  cons            ;; (3) Collecting each transformed element.
  [1 2 3])        ;; (1) Feed each source element through the chain.
```

# Composing Transducers

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

# Processing multiple source at once

It is possible to pass as many sources to `transduce` as you want. However, only
as many elements as held by the shortest source will be passed through. This is
analogous to how `zip` works in many languages. For example:

```fennel
(let [res (transduce (map #(+ $1 $2)) cons [1 2 3] [4 5 6 7])]
  (assert (table.= [5 7 9] res)))
```

Notice that the function passed to `map` can be of any arity to accomodate this."
  (let [init (reducer)
        xf (xform reducer)
        result (reduce xf init source ...)]
    (xf result)))

;; --- Transducers --- ;;

(fn pass [reducer]
  "Just pass along each value of the transduction without transforming.

```fennel
(assert (table.= [1 2 3] (transduce pass cons [1 2 3])))
```"
  (fn [result input]
    (if (~= nil input)
        (reducer result input)
        (reducer result))))

(fn map [f]
  "Apply a function `f` to all elements of the transduction.

```fennel
(assert (table.= [2 3 4] (transduce (map #(+ 1 $1)) cons [1 2 3])))
```"
  (fn [reducer]
    (fn [result input ...]
      (if (~= nil input)
          (reducer result (f input ...))
          (reducer result)))))

(fn filter [pred]
  "Only keep elements from the transduction that satisfy `pred`.

```fennel
(assert (table.= [2 4] (transduce (filter #(= 0 (% $1 2))) cons [1 2 3 4 5])))
```"
  (fn [reducer]
    (fn [result input]
      (if (~= nil input)
          (if (pred input)
              (reducer result input)
              result)
          (reducer result)))))

(fn filter-map [f]
  "Apply a function `f` to the elements of the transduction, but only keep results
that are non-nil.

```fennel
(let [res (transduce (filter-map #(. $1 1)) cons [[] [2 3] [] [5 6] [] [8 9]])]
  (assert (table.= [2 5 8] res)))
```"
  (fn [reducer]
    (fn [result input ...]
      (if (~= nil input)
          (let [x (f input ...)]
            (if (~= nil x)
                (reducer result x)
                result))
          (reducer result)))))

(fn drop [n]
  "Drop the first `n` elements of the transduction.

```fennel
(assert (table.= [1 2 3 4 5] (transduce (drop 0) cons [1 2 3 4 5])))
(assert (table.= [4 5] (transduce (drop 3) cons [1 2 3 4 5])))
(assert (table.= [] (transduce (drop 100) cons [1 2 3 4 5])))
```"
  (fn [reducer]
    (var dropped 0)
    (fn [result input]
      (if (~= nil input)
          (if (< dropped n)
              (do (set dropped (+ 1 dropped))
                  result)
              (reducer result input))
          (reducer result)))))

(fn drop-while [pred]
  "Drop elements from the front of the transduction that satisfy `pred`.

```fennel
(let [res (transduce (drop-while #(= 0 (% $1 2))) cons [2 4 6 8 9 10])]
  (assert (table.= [9 10] res)))
```"
  (fn [reducer]
    (var drop? true)
    (fn [result input]
      (if (~= nil input)
          (if (and drop? (pred input))
              result
              (do (set drop? false)
                  (reducer result input)))
          (reducer result)))))

(fn take [n]
  "Keep the first `n` elements of the transduction.

```fennel
(assert (table.= [] (transduce (take 0) cons [1 2 3 4 5])))
(assert (table.= [1 2 3] (transduce (take 3) cons [1 2 3 4 5])))
(assert (table.= [1 2 3 4 5] (transduce (take 100) cons [1 2 3 4 5])))
```"
  (fn [reducer]
    (var kept 0)
    (fn [result input]
      (if (~= nil input)
          (if (= kept n)
              (reduced result)
              (do (set kept (+ 1 kept))
                  (reducer result input)))
          (reducer result)))))

(fn take-while [pred]
  "Keep only elements which satisfy `pred`, and stop the transduction as soon as
any element fails the test.

```fennel
(assert (table.= [2 4 6 8] (transduce (take-while #(= 0 (% $1 2))) cons [2 4 6 8 9 2])))
```"
  (fn [reducer]
    (fn [result input]
      (if (~= nil input)
          (if (not (pred input))
              (reduced result)
              (reducer result input))
          (reducer result)))))

(fn enumerate [reducer]
  "Index every value passed through the transduction into a pair. Starts at 1.

```fennel
(let [res (transduce enumerate cons [\"a\" \"b\" \"c\"])]
  (assert (table.= [[1 \"a\"] [2 \"b\"] [3 \"c\"]] res)))
```"
  (var n 1)
  (fn [result input]
    (if (~= nil input)
        (let [pair [n input]]
          (set n (+ 1 n))
          (reducer result pair))
        (reducer result))))

(fn intersperse [elem]
  "Insert an `elem` between each value of the transduction.

```fennel
(assert (table.= [1] (transduce (intersperse 0) cons [1])))
(assert (table.= [1 0 2 0 3] (transduce (intersperse 0) cons [1 2 3])))
```"
  (fn [reducer]
    (var send? false)
    (fn [result input]
      (if (~= nil input)
          (if send?
              (let [result (reducer result elem)]
                (if (reduced? result)
                    result
                    (reducer result input)))
              (do (set send? true)
                  (reducer result input)))
          (reducer result)))))

(fn concat [reducer]
  "Concatenate all the subtables in the transduction.

```fennel
(assert (table.= [1 2 3 4 5 6] (transduce concat cons [[1 2] [3 4] [5 6]])))
(assert (table.= [1 2 3] (transduce (comp concat (take 3)) cons [[1 2] [3 4] [5 6]])))
```"
  (fn [result input]
    (if (~= nil input)
        (accumulate [r result _ i (ipairs input) &until (reduced? r)]
          (reducer r i))
        (reducer result))))

(fn segment [n]
  "Partition the input into tables of `n` items. If the input stops, flush any
accumulated state, which may be shorter than `n`.

```fennel
(assert (table.= [[1 2 3] [4 5]] (transduce (segment 3) cons [1 2 3 4 5])))
```"
  (when (< n 1)
    (error "The argument to segment must be a positive integer."))
  (fn [reducer]
    (var coll [])
    (fn [result input]
      (if (~= nil input)
          (do (table.insert coll input)
              (if (< (length coll) n)
                  result
                  (let [seg coll]
                    (set coll [])
                    (reducer result seg))))
          (= 0 (length coll)) (reducer result)
          (let [final (reducer result coll)]
            ;; Because we are in this branch of the (outer) `if`, the result was
            ;; already supposed to be fully reduced. By dipping back into the
            ;; transducer chain to pass through any remaining segment, the
            ;; result might come back "reduced" again. If it is, we need to do a
            ;; manual unwrap before making the final "victory lap" down to the
            ;; core reducer.
            (if (reduced? final)
                (reducer (unreduce final))
                (reducer final)))))))

(fn window [n]
  "Yield `n`-length windows of overlapping values. This is different from `segment`
which yields non-overlapping windows. If there were fewer items in the input
than `n`, then this yields nothing.

```fennel
(let [res (transduce (window 3) cons [1 2 3 4 5])]
  (assert (table.= [[1 2 3] [2 3 4] [3 4 5]] res)))
```"
  (when (< n 1)
    (error "The argument to window must be a positive integer."))
  (fn [reducer]
    (var queue [])
    (fn [result input]
      (if (~= nil input)
          (do (table.insert queue input)
              (let [len (length queue)]
                (if (< len n) result
                    (= len n) (let [dest []]
                                (table.move queue 1 len 1 dest)
                                (reducer result dest))
                    (let [dest []]
                      (table.remove queue 1)
                      (table.move queue 1 (length queue) 1 dest)
                      (reducer result dest)))))
          (reducer result)))))

;; --- Reducers --- ;;

(fn count [acc input]
  "Count the number of elements that made it through the transduction.

```fennel
(assert (= 4 (transduce pass count [1 2 3 4])))
```"
  (if (and (~= nil acc) (~= nil input)) (+ 1 acc)
      (~= nil acc) acc
      0))

(fn cons [acc input]
  "Build up a new sequential Table of all elements that made it through the
transduction.

```fennel
(assert (table.= [1 2 3] (transduce pass cons [1 2 3])))
```"
  (if (and (~= nil acc) (~= nil input)) (do (table.insert acc input) acc)
      (~= nil acc) acc
      []))

(fn add [a b]
  "Add two numbers `a` and `b`. Unlike the normal `+`, this can be passed to
higher-order functions and behaves as a legal reducer.

```fennel
(assert (= 0 (add)))
(assert (= 1 (add 1)))
(assert (= 3 (add 1 2)))
```"
  (if (and (= nil a) (= nil b)) 0
      (and a (= nil b)) a
      (+ a b)))

(fn mul [a b]
  "Multiply two numbers `a` and `b`. Unlike the normal `*`, this can be passed to
higher-order functions and behaves as a legal reducer.

```fennel
(assert (= 1 (mul)))
(assert (= 2 (mul 2)))
(assert (= 6 (mul 2 3)))
```"
  (if (and (= nil a) (= nil b)) 1
      (and a (= nil b)) a
      (* a b)))

(fn all [pred]
  "Yield `true` if all elements of the transduction satisfy `pred`. Short-circuit
with `false` if any element fails the test.

```fennel
(assert (transduce pass (all #(= 3 (length $1))) [\"abc\" \"def\" \"ghi\"]))
(assert (not (transduce pass (all #(= 3 (length $1))) [\"abc\" \"de\" \"ghi\"])))
```"
  (fn [acc input]
    (if (and (~= nil acc) (~= nil input))
        (let [test (pred input)]
          (if (and acc test)
              true
              (reduced false)))
        (and (~= nil acc) (= nil input)) acc
        true)))

(fn table.= [a b]
  "Recursively determine if two tables are equal, non-Baker style."
  (match (type a)
    :table (and (= (length a) (length b))
                (transduce (map table.=) (all id) a b))
    _ (= a b)))

{:transduce transduce
 ;; --- Transducers --- ;;
 :pass pass
 :map map
 :filter filter
 :filter-map filter-map
 :drop drop
 :drop-while drop-while
 :take take
 :take-while take-while
 :enumerate enumerate
 :intersperse intersperse
 :concat concat
 ;; --- Reducers --- ;;
 :count count
 :cons cons
 :add add
 :mul mul
 :all all
 ;; --- Utilities --- ;;
 :comp comp
 :reduced reduced
 :reduced? reduced?}
