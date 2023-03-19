(fn transduce [xform f tbl]
  (let [init (f)
        xf (xform f)
        result (reduce xf init tbl)]
    (xf result)))

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

;; --- Transducers --- ;;

(fn map [f]
  "Apply a function F to all elements of the transduction."
  (fn [reducer]
    (lambda [result ?input]
      (if (non-nil? ?input)
          (reducer result (f ?input))
          (reducer result)))))

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

{:transduce transduce
 ;; --- Transducers --- ;;
 :map map
 ;; --- Reducers --- ;;
 :count count
 :cons cons
 ;; --- Utilities --- ;;
 :reduced? reduced?}
