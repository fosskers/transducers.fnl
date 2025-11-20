(local t (require :transducers))

(let [sum (t.transduce t.pass
                       t.add
                       [1 2 3 4 5])]
  (print (.. "Total: " sum)))
