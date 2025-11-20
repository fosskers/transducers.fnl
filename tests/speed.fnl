(local t (require :transducers))

;; (print (t.transduce t.pass t.count (t.csv "panasonic.csv")))

;; (t.transduce t.pass (t.csv-write "names.csv" ["Name"])
;;                     (t.csv-read "foo.csv"))

;; (fn to-table [n]
;;   {:index n
;;    :time (os.time)
;;    :date (os.date)
;;    :fun true})

;; (t.transduce (t.comp (t.take 1000000)
;;                      (t.map to-table))
;;              (t.csv-write "big.csv" [:index :time :date :fun])
;;              (t.ints 1))

;; (print "Done")

(let [sum (t.transduce (t.comp (t.filter-map #(. $1 :index))
                               (t.filter-map tonumber))
                       t.add
                       (t.csv-read "big.csv"))]
  (print (.. "Total: " sum)))

;; (t.transduce t.pass (t.average 0) [3.03 3.01 3.06])

;; (fn split [str]
;;   (icollect [s (string.gmatch str "[^,]+")] s))

;; (fn fuse [keys vals]
;;   "Fuse the elements of two sequential tables into a single key-value table."
;;   (when (~= (length keys) (length vals))
;;     (error "Lengths of key and value tables do not match!"))
;;   (collect [i k (ipairs keys)]
;;     k (. vals i)))

;; (with-open [file (io.open "big.csv")]
;;   (let [headers (split (file:read))
;;         sum (accumulate [sum 0 line (file:lines)]
;;               (-> (fuse headers (split line))
;;                   (. :index)
;;                   (tonumber)
;;                   (+ sum)))]
;;     (print (.. "Total: " sum))))
