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
       (~= nil (. tbl :reduced))))

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
                (. acc :reduced)
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

;; (transduce (filter-map #(. $1 1)) cons [[] [2 3] [] [5 6] [] [8 9]])

;; --- Reducers --- ;;

(fn count [acc input]
  "Count the number of elements that made it through the transduction."
  (if (and (~= nil acc) (~= nil input)) (+ 1 acc)
      (~= nil acc) acc
      0))

;; (transduce (map #(+ 1 $1)) count [1 2 3 4])

(fn cons [acc input]
  "Build up a new sequential Table of all elements that made it through the
transduction."
  (if (and (~= nil acc) (~= nil input)) (do (table.insert acc input) acc)
      (~= nil acc) acc
      []))

;; (transduce (map #(+ 1 $1)) cons [1 2 3 4])

(fn add [a b]
  "Add two numbers."
  (if (and (= nil a) (= nil b)) 0
      (and a (= nil b)) a
      (+ a b)))

;; (transduce pass add [1 2 3])

(fn mul [a b]
  "Multiply two numbers."
  (if (and (= nil a) (= nil b)) 1
      (and a (= nil b)) a
      (* a b)))

;; (transduce pass mul [2 4 6])

(fn all [pred]
  "Yield `true` if all elements of the transduction satisfy `pred`. Short-circuit
with `false` if any element fails the test."
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
