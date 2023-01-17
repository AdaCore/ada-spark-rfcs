# Constrained Indefinite Arrays RFC

## Summary

This RFC proposes an addition to array types that allows to define them
with a static maximum size but still use them as if they were unconstrained.

An array defined with
```Ada
type Index is range 0 .. 32;

type Static_Array is array (Index range <>) of Element with
   Constrained;
```

Adding the aspect `Constrained` will force the compiler to always reserve
enough space to fit every possible range of an object of this type without
changing the high level behaviour of the type.

## Motivation

Arrays in Ada can be declared either with a specific range or with a `<>` to
allow any value in the range of the index type. While the former variant
has a static size and is constrained it can only be used with values of the
same length. Assigning shorter values will fail. The second variant is more
flexible in that regard. It can take values of any range as long as the range
can be expressed by the index type. However these arrays require more specific
language features for some operations, in particular the secondary stack.

In many projects, especially in the embedded or high integrity domain stack
boundedness is an important property. If stack boundedness needs to be
statically proven the secondary stack cannot be used as its boundedness cannot
be shown. Yet the ability to store values of an unknown length is still useful.
To provide this functionality without a secondary stack many projects use
the following workaround:

```Ada
subtype Static_String is String (1 .. 32);

type Sized_String is record
   Length : Natural;
   Value  : Static_String;
end record;
```

This construct allows to store a value of unknown length with a statically
known maximum size of 36 byte. It is however cumbersome to use as these objects
cannot use the `&` operator and slices easily.

## Reference Level Explanation

A new aspect `Constrained` is added.

## Syntax

No custom Syntax.

## Static Legality Rules

`Constrained` can only be added to array declarations that would create an
indefinite array. It can be used on both types and subtypes.

A subtype of a constrained array has the same behaviour as a subtype to a
regular array. If defined as indefinite, it will keep the `Constrained`
modifier but with a reduced static size. If defined with a specific constrained
range it will behave the same way it does without that aspect.

## Operational Semantics

Objects of an array type declared with `Constrained` will always be stored in a
memory zone that has the maximum size of that array type.
When returned from a function they behave as constrained types and do not
require the secondary stack.
Operations on that array such appending and slices will trigger the same checks
as they do for indefinite arrays.

## Unresolved Questions

* Whether there is a hard limit on the size of these arrays. Theoretically
  an array with that aspect and the index type `Long_Integer` would be
  2 ***** 64 * element size bytes large.
* Whether `Constrained` is a good name for that aspect.
* Whether the behaviour of arrays with this aspect is different from regular arrays.
  Assignments to regular arrays must have the same size as the current contents
  of that array. As contrained arrays have their maximum possible size allocated
  in memory it is possible to assign them values of different lengths or append
  additional elements with the `&` operator. Both operations must not exceed the
  maximum size of the array type.

## Alternatives

One could argue that the same behaviour can also be achieved by creating a
record type as described above and implement the correct operators. However
this would not solve the problem with slicing. Also while such an
implementation could be generic, the type itself likely cannot as generic
formal parameters are never considered static.
