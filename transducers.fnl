;; --- Utilities --- ;;

(fn non-nil? [x]
  "Stronger than just checking for truthiness, since a value of false might have
been intended elsewhere."
  (not (= nil x)))

(fn reduced? [tbl]
  "Has a transduction been short-circuited?"
  (and (= :table (type tbl))
       (not (= nil (. tbl :reduced)))))
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
    (if (non-nil? input)
        (reducer result input)
        (reducer result))))

;; (transduce pass cons [1 2 3])

(fn map [f]
  "Apply a function F to all elements of the transduction."
  (fn [reducer]
    (fn [result input]
      (if (non-nil? input)
          (reducer result (f input))
          (reducer result)))))

(fn filter [pred]
  "Only keep elements from the transduction that satisfy PRED."
  (fn [reducer]
    (fn [result input]
      (if (non-nil? input)
          (if (pred input)
              (reducer result input)
              result)
          (reducer result)))))

;; (transduce (filter (fn [n] (= 0 (% n 2)))) cons [1 2 3 4 5])

;; --- Reducers --- ;;

(fn count [acc input]
  "Count the number of elements that made it through the transduction."
  (if (and (non-nil? acc) (non-nil? input)) (+ 1 acc)
      (non-nil? acc) acc
      0))

;; (transduce (map (fn [n] (+ 1 n))) count [1 2 3 4])

(fn cons [acc input]
  (if (and (non-nil? acc) (non-nil? input)) (do (table.insert acc input) acc)
      (non-nil? acc) acc
      []))

;; (transduce (map (fn [n] (+ 1 n))) cons [1 2 3 4])

{:transduce transduce
 ;; --- Transducers --- ;;
 :pass pass
 :map map
 :filter filter
 ;; --- Reducers --- ;;
 :count count
 :cons cons
 ;; --- Utilities --- ;;
 :reduced? reduced?}
