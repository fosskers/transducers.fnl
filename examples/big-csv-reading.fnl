;; This example reads a CSV file and sums the value of a particular field, both
;; in tranducer-style and hand-written vanilla Fennel. Not only is the latter
;; longer, it also performs (just slightly) worse. Transducers can be used
;; without performance guilt!

;; (local t (require :transducers))
;;
;; (let [sum (t.transduce (t.comp (t.filter-map #(. $1 :index))
;;                                (t.filter-map tonumber))
;;                        t.add
;;                        (t.csv-read "big.csv"))]
;;   (print (.. "Total: " sum)))

(fn split [str]
  (icollect [s (string.gmatch str "[^,]+")] s))

(fn fuse [keys vals]
  "Fuse the elements of two sequential tables into a single key-value table."
  (when (~= (length keys) (length vals))
    (error "Lengths of key and value tables do not match!"))
  (collect [i k (ipairs keys)]
    k (. vals i)))

(with-open [file (io.open "big.csv")]
  (let [headers (split (file:read))
        sum (accumulate [sum 0 line (file:lines)]
              (-> (fuse headers (split line))
                  (. :index)
                  (tonumber)
                  (+ sum)))]
    (print (.. "Total: " sum))))
