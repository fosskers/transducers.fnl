# Transducers.fnl

**Table of contents**

- [`add`](#add)
- [`all`](#all)
- [`comp`](#comp)
- [`cons`](#cons)
- [`count`](#count)
- [`filter`](#filter)
- [`filter-map`](#filter-map)
- [`map`](#map)
- [`mul`](#mul)
- [`pass`](#pass)
- [`reduced`](#reduced)
- [`reduced?`](#reduced-1)
- [`transduce`](#transduce)

## `add`
Function signature:

```
(add a b)
```

Add two numbers.

## `all`
Function signature:

```
(all pred)
```

Yield `true` if all elements of the transduction satisfy `pred`. Short-circuit
with `false` if any element fails the test.

## `comp`
Function signature:

```
(comp f ...)
```

Function composition.

## `cons`
Function signature:

```
(cons acc input)
```

**Undocumented**

## `count`
Function signature:

```
(count acc input)
```

Count the number of elements that made it through the transduction.

## `filter`
Function signature:

```
(filter pred)
```

Only keep elements from the transduction that satisfy PRED.

## `filter-map`
Function signature:

```
(filter-map f)
```

Apply a function F to the elements of the transduction, but only keep results
that are non-nil.

## `map`
Function signature:

```
(map f)
```

Apply a function F to all elements of the transduction.

## `mul`
Function signature:

```
(mul a b)
```

Multiply two numbers.

## `pass`
Function signature:

```
(pass reducer)
```

Just pass along each value of the transduction without transforming.

```fennel
(assert (table.= [1 2 3] (transduce pass cons [1 2 3])))
```

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

Has a transduction been short-circuited?

## `transduce`
Function signature:

```
(transduce xform f tbl ...)
```

**Undocumented**


<!-- Generated with Fenneldoc v1.0.0
     https://gitlab.com/andreyorst/fenneldoc -->
