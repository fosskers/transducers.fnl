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

(fn split-into-table [line]
  "Split a CSV line into a table of values."
  (icollect [s (string.gmatch line "[^,]+")] s))

(fn fuse [keys vals]
  "Fuse the elements of two sequential tables into a single key-value table."
  (when (~= (length keys) (length vals))
    (error "Lengths of key and value tables do not match!"))
  (collect [i k (ipairs keys)]
    k (. vals i)))

;; --- Entry Points --- ;;

(fn unreduce [tbl]
  "Unwrap a reduced value `tbl`."
  (. tbl :transducers-reduced))

(fn reduced [item]
  "Announce to the transduction process that we are done, and the given `item` is
the final result."
  {:transducers-reduced item})

(fn reduced? [tbl]
  "Has a transduction been short-circuited? This tests the given `tbl` for a
certain shape produced by the `reduced' function, which itself is only called
within transducers that have the concept of short-circuiting, like `take'.

```fennel
(assert (not (reduced? [1])))
(assert (reduced? (reduced 1)))
(assert (reduced? (reduced false)))
```"
  (and (= :table (type tbl))
       (~= nil (unreduce tbl))))

(fn table-reduce [f id tbl ...]
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

(fn iter-reduce [f id iterator]
  "Reduce over the contents of a Lua iterator."
  (let [acc (accumulate [acc id item iterator &until (reduced? acc)]
              (f acc item))]
    (if (reduced? acc)
        (unreduce acc)
        acc)))

(fn file-reduce [f id path]
  "Reduce over all the lines of a file."
  (with-open [file (io.open path)]
    (iter-reduce f id (file:lines))))

(fn csv-reduce [f id path]
  "Reduce over all the lines of a CSV file."
  (with-open [file (io.open path)]
    (let [headers (split-into-table (file:read "*line"))]
      (fn recurse [acc]
        (let [line (file:read "*line")]
          (if (= nil line)
              acc
              (let [tbl (fuse headers (split-into-table line))
                    acc (f acc tbl)]
                (if (reduced? acc)
                    (unreduce acc)
                    (recurse acc))))))
      (recurse id))))

(lambda transduce [xform reducer source ...]
  "The entry point for processing a data source via transducer functions. It
accepts:

- `xform`: a chain of composed transducer functions, like `map' and `filter'.
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
Transducers can be composed with `comp':

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

Notice that the function passed to `map' can be of any arity to accomodate this."
  (let [init (reducer)
        xf (xform reducer)
        result (match source
                 {:transducers-iter iterator} (iter-reduce xf init iterator)
                 {:transducers-file path} (file-reduce xf init path)
                 {:transducers-csv path} (csv-reduce xf init path)
                 [] (table-reduce xf init source ...))]
    (xf result)))

;; --- Transducers --- ;;

(fn pass [reducer]
  "Just pass along each value of the transduction without transforming.

```fennel
(assert (table.= [1 2 3] (transduce pass cons [1 2 3])))
```

**Note:** This takes a `reducer` as an argument, but as seen in the example,
this function is expected to be passed plain, without any argument."
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
```

**Note:** This takes a `reducer` as an argument, but as seen in the example,
this function is expected to be passed plain, without any argument."
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
```

**Note:** This takes a `reducer` as an argument, but as seen in the example,
this function is expected to be passed plain, without any argument."
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
  "Yield `n`-length windows of overlapping values. This is different from `segment'
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

(fn group-by [f]
  "Group the input stream into tables via some function `f`. The cutoff criterion
is whether the return value of `f` changes between two consecutive elements of
the transduction.

```fennel
(let [res (transduce (group-by #(= 0 (% $1 2))) cons [2 4 6 7 9 1 2 4 6 3])]
  (assert (table.= [[2 4 6] [7 9 1] [2 4 6] [3]] res)))
```"
  (fn [reducer]
    (var prev :nothing)
    (var coll [])
    (fn [result input]
      (if (~= nil input)
          (let [fout (f input)]
            (if (or (= fout prev) (= prev :nothing))
                (do (set prev fout)
                    (table.insert coll input)
                    result)
                (let [tbl coll]
                  (set prev fout)
                  (set coll [input])
                  (reducer result tbl))))
          (= 0 (length coll)) (reducer result)
          (let [final (reducer result coll)]
            ;; See `segment` for why this extra check is necessary.
            (if (reduced? final)
                (reducer (unreduce final))
                (reducer final)))))))

(fn unique [reducer]
  "Only allow values to pass through the transduction once each.
Stateful; this uses a Table internally as a set, so could get quite heavy if
you're not careful.

```fennel
(let [res (transduce unique cons [1 2 1 3 2 1 2 \"abc\"])]
  (assert (table.= [1 2 3 \"abc\"] res)))
```

**Note:** This takes a `reducer` as an argument, but as seen in the example,
this function is expected to be passed plain, without any argument."
  (let [seen {}]
    (fn [result input]
      (if (~= nil input)
          (if (. seen input)
              result
              (do (tset seen input true)
                  (reducer result input)))
          (reducer result)))))

(fn dedup [reducer]
  "Remove adjecent duplicates from the transduction.

```fennel
(let [res (transduce dedup cons [1 1 1 2 2 2 3 3 3 4 3 3])]
  (assert (table.= [1 2 3 4 3] res)))
```

**Note:** This takes a `reducer` as an argument, but as seen in the example,
this function is expected to be passed plain, without any argument."
  (var prev :nothing)
  (fn [result input]
    (if (~= nil input)
        (if (= prev input)
            result
            (do (set prev input)
                (reducer result input)))
        (reducer result))))

(fn step [n]
  "Only yield every `n`th element of the transduction. The first element is always
included.

```fennel
(let [res (transduce (step 2) cons [1 2 3 4 5 6 7 8 9])]
  (assert (table.= [1 3 5 7 9] res)))
```"
  (when (< n 1)
    (error "The argument to step must be greater than 0."))
  (fn [reducer]
    (var curr 1)
    (fn [result input]
      (if (~= nil input)
          (if (= 1 curr)
              (do (set curr n)
                  (reducer result input))
              (do (set curr (- curr 1))
                  result))
          (reducer result)))))

(fn scan [f seed]
  "Build up successive values from the results of previous applications of a given
function `f`. A `seed` is also given, and appears as the first element passed
through the transduction.

```fennel
(assert (table.= [0 1 3 6 10] (transduce (scan add 0) cons [1 2 3 4])))
(assert (table.= [0 1] (transduce (comp (scan add 0) (take 2)) cons [1 2 3 4])))
```"
  (fn [reducer]
    (var prev seed)
    (fn [result input]
      (if (~= nil input)
          (let [old prev
                result (reducer result old)]
            (if (reduced? result)
                result
                (let [new (f prev input)]
                  (set prev new)
                  result)))
          (let [result (reducer result prev)]
            (if (reduced? result)
                (reducer (unreduce result))
                (reducer result)))))))

;; --- Reducers --- ;;

(fn count [acc input]
  "Count the number of elements that made it through the transduction.

```fennel
(assert (= 4 (transduce pass count [1 2 3 4])))
```

**Note:** This takes `acc` and `input` arguments, but as seen in the example,
this function is expected to be passed plain, without any arguments."
  (if (and (~= nil acc) (~= nil input)) (+ 1 acc)
      (~= nil acc) acc
      0))

(fn cons [acc input]
  "Build up a new sequential Table of all elements that made it through the
transduction.

```fennel
(assert (table.= [1 2 3] (transduce pass cons [1 2 3])))
```

**Note:** This takes `acc` and `input` arguments, but as seen in the example,
this function is expected to be passed plain, without any arguments."
  (if (and (~= nil acc) (~= nil input)) (do (table.insert acc input) acc)
      (~= nil acc) acc
      []))

(fn keyed [acc input]
  "Build up a key-value Table of all elements that made it through the
transduction. The input values can be key-value tables of any size; they will be
fused into a single result.

**Note:** This takes `acc` and `input` arguments, but as seen in the example,
this function is expected to be passed plain, without any arguments."
  (if (and (~= nil acc) (~= nil input))
      (do (each [key value (pairs input)] (tset acc key value))
          acc)
      (~= nil acc) acc
      {}))

;; (transduce (map (fn [s] {s (length s)})) keyed ["cats" "Hello" "there" "cats"])

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
        (~= nil acc) acc
      true)))

(fn any [pred]
  "Yield `true` if any element in the transduction satisfies `pred`. Short-circuits
the transduction as soon as the condition is met.

```fennel
(assert (not (transduce pass (any #(= 0 (% $1 2))) [1 3 5 7])))
(assert (transduce pass (any #(= 0 (% $1 2))) [1 3 5 7 2]))
```"
  (fn [acc input]
    (if (and (~= nil acc) (~= nil input))
        (let [test (pred input)]
          (if test
              (reduced true)
              false))
        (~= nil acc) acc
        false)))

(fn average [fallback]
  "Calculate the average value of all numeric elements in a transduction. A
`fallback` must be provided in case no elements made it through the
transduction (thus protecting from division-by-zero).

```fennel
(assert (= 3.0 (transduce pass (average -1) [1 2 3 4 5])))
```"
  (var items 0)
  (fn [acc input]
    (if (and (~= nil acc) (~= nil input))
        (do (set items (+ 1 items))
            (+ acc input))
        (~= nil acc)
        (if (= 0 items)
            fallback
            (/ acc items))
        0)))

(fn first [fallback]
  "Yield the first value of the transduction, or the `fallback` if there were none.

```fennel
(assert (= 6 (transduce (filter #(= 0 (% $1 2))) (first 0) [1 3 5 6 9])))
```"
  (fn [acc input]
    (if (and (~= nil acc) (~= nil input)) (reduced input)
        (~= nil acc) acc
        fallback)))

(fn last [fallback]
  "Yield the final value of the transduction, or the `fallback` if there were none.

```fennel
(assert (= 10 (transduce pass (last 0) [2 4 6 7 10])))
```"
  (fn [acc input]
    (if (and (~= nil acc) (~= nil input)) input
        (~= nil acc) acc
        fallback)))

(fn csv-write [path headers]
  "Given a `path` to write to and a table of `headers` (fields) to keep, write
all CSV data that made it through the transduction.

```fennel :skip-test
(transduce pass (csv-write \"names.csv\" [\"Name\"])
                (csv-read \"data.csv\"))
```"
  (let [f (assert (io.open path :w))]
    (f:write (.. (table.concat headers ",") "\n"))
    (fn [acc input]
      (if (and (~= nil acc) (~= nil input))
          (-> (icollect [_ k (ipairs headers)] (. input k))
              (table.concat ",")
              (.. "\n")
              (f:write))
          (~= nil acc) (do (f:flush)
                           (f:close)
                           true)
          true))))

(fn fold [f seed]
  "The fundamental reducer. `fold` creates an ad-hoc reducer based on
a given 2-argument function `f`. A `seed` is also required as the initial
accumulator value, which also becomes the return value in case there were no
input left in the transduction.

Functions like `math.max` cannot be used as-is as reducers since they require at
least 1 argument. For functions like this, `fold` is appropriate.

```fennel
(assert (= 1000 (transduce pass (fold math.max 0) [1 2 3 4 1000 5 6])))
```"
  (fn [acc input]
    (if (and (~= nil acc) (~= nil input)) (f acc input)
        (~= nil acc) acc
        seed)))

;; --- Sources --- ;;

(fn file [path]
  "Given a `path`, create a Transducer Source that yields all the lines of its
file.

To count the lines of a file:

```fennel :skip-test
(transduce pass count (file \"README.org\"))
```"
  {:transducers-file path})

(fn csv-read [path]
  "Given a `path` to a CSV file, create a Transducer Source that yields all lines
of the file as key-value Tables.

```fennel :skip-test
(transduce pass count (csv-read \"data.csv\"))
```"
  {:transducers-csv path})

(fn iter [iterator]
  "Given any `iterator`, create a Transducer Source that yields all of its input.

```fennel
(let [res (transduce pass cons (iter (string.gmatch \"hello,world,cats\" \"[^,]+\")))]
  (assert (table.= [\"hello\" \"world\" \"cats\"] res)))
```"
  {:transducers-iter iterator})

;; --- Misc. --- ;;

(fn table.= [a b]
  "Recursively determine if two tables are equal, non-Baker style."
  (match (type a)
    :table (and (= (length a) (length b))
                (transduce (map table.=) (all (fn [x] x)) a b))
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
 :segment segment
 :window window
 :group-by group-by
 :unique unique
 :dedup dedup
 :step step
 :scan scan
 ;; --- Reducers --- ;;
 :count count
 :cons cons
 :keyed keyed
 :fold fold
 :add add
 :mul mul
 :all all
 :any any
 :first first
 :last last
 :csv-write csv-write
 ;; --- Sources --- ;;
 :iter iter
 :file file
 :csv-read csv-read
 ;; --- Utilities --- ;;
 :comp comp
 :reduced reduced
 :reduced? reduced?
 :unreduce unreduce}
