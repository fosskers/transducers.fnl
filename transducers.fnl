;; --- Utilities --- ;;

(fn reduced? [tbl]
  "Has a transduction been short-circuited?"
  (and (= :table (type tbl))
       (~= nil (. tbl :reduced))))
  ;; (match tbl
  ;;   {:reduced _} true
  ;;   _ false))

;; (reduced? [1])
;; (reduced? {:reduced 1})
;; (reduced? {:reduced false})

(fn reduce [f id tbl]
  (let [len (length tbl)]
    (fn recurse [acc i]
      (if (> i len)
          acc
          (let [acc (f acc (. tbl i))]
            (if (reduced? acc)
                (. :reduced acc)
                (recurse acc (+ 1 i))))))
    (recurse id 1)))

(fn transduce [xform f tbl]
  (let [init (f)
        xf (xform f)
        result (reduce xf init tbl)]
    (xf result)))

;; --- Transducers --- ;;

(fn pass [reducer]
  "Just pass along each value of the transduction without transforming."
  (fn [result input]
    (if (~= nil input)
        (reducer result input)
        (reducer result))))

;; (transduce pass cons [1 2 3])

(fn map [f]
  "Apply a function F to all elements of the transduction."
  (fn [reducer]
    (fn [result input]
      (if (~= nil input)
          (reducer result (f input))
          (reducer result)))))

(fn filter [pred]
  "Only keep elements from the transduction that satisfy PRED."
  (fn [reducer]
    (fn [result input]
      (if (~= nil input)
          (if (pred input)
              (reducer result input)
              result)
          (reducer result)))))

;; (transduce (filter (fn [n] (= 0 (% n 2)))) cons [1 2 3 4 5])

;; --- Reducers --- ;;

(fn count [acc input]
  "Count the number of elements that made it through the transduction."
  (if (and (~= nil acc) (~= nil input)) (+ 1 acc)
      (~= nil acc) acc
      0))

;; (transduce (map (fn [n] (+ 1 n))) count [1 2 3 4])

(fn cons [acc input]
  (if (and (~= nil acc) (~= nil input)) (do (table.insert acc input) acc)
      (~= nil acc) acc
      []))

;; (transduce (map (fn [n] (+ 1 n))) cons [1 2 3 4])

(fn add [a b]
  "Add two numbers."
  (if (and (= nil a) (= nil b)) 0
      (and a (= nil b)) a
      (+ a b)))

;; (transduce pass add [1 2 3])

{:transduce transduce
 ;; --- Transducers --- ;;
 :pass pass
 :map map
 :filter filter
 ;; --- Reducers --- ;;
 :count count
 :cons cons
 :add add
 ;; --- Utilities --- ;;
 :reduced? reduced?}
