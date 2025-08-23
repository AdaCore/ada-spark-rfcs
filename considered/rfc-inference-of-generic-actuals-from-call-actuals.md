- Feature Name: Inference of generic actuals from call actuals
- Start Date: 2023-03-03
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

This RFC builds up on top of [the structural generic instantiation
RFC](./rfc-structural-generic-instantiation.md), and proposes to be able to
infer generic actuals for structural generic instantiations, from the actuals
of the subprogram call, in cases where the structural generic instantiation
refers to a subprogram.

Motivation
==========

This RFC is part of the bigger high-level RFC about improving generic
instantiations ([here](../meta/rfc-improved-generic-instantiations.md)), so the
need arises from that context, and it's useful to go read the high level RFC to
understand the bigger picture.

The specific aim of this RFC is to make structural instantiation of subprograms
even more lightweight than it previously was, to allow almost seamless use of
generic subprograms as if their instances already existed.

The canonical examples that are shown elsewhere are, uses of
`Unchecked_Deallocation`, and expression of a reduction function on arrays:

```ada
--  Supporting code
generic
   type Index_Type is (<>);
   type El_Type is private;
   type Array_Type is array (Index_Type range <>) of El_Type;

   type Accum is private;
   with function Fn (Current : Accum; El : El_Type) return Accum;
function Reduce (Init : Accum; Arr : Array_Type) return Accum;

type Float_Array is array (Positive range <>) of Float;

function Sum (X: Float_Array) return Float
is
    --  Implicit instantiation of Reduce. All formals except `Fn` can be
    --  deduced from the type of `X`, and from the expected return type.
  (Reduce [Fn => "+"] (0.0, X))

type Float_Access is access all Float;

F : Float_Access := new Float'(Sum ([1.0, 2.0, 3.0, 4.0]));

--  Implicit instantiation of unchecked deallocation. Both type formals can be
--  deduced from the type of the access type passed as the actual.
Ada.Unchecked_Deallocation [] (F);
```

Guide-level explanation
=======================

In the context of the structural instantiation of a subprogram, there is often
enough information to deduce the generic actuals from the type of the actuals
of the subprogram call:

```ada
generic
   type Object (<>) is limited private;
   type Name is access  Object;
procedure Ada.Unchecked_Deallocation (X : in out Name);

type Integer_Access is access all Integer;

A : Integer_Access := new Integer'(12);

Ada.Unchecked_Deallocation [Integer, Integer_Access] (A);
--                                                    ^ Type of `A` is `Name`
--
--  Type `Object` can be deduced from type `Name` as per RFC about inference of
--  dependent formal types
```

This can also work in more complex cases, like the reduce case exposed in the
introduction.

The rules are:

* If a `structural_generic_instantiation_reference` is used as a call name,
  then, the parameters of the call can be used to determine the actuals for the
  generic instantiation.

* In terms of name & type resolution, it means that they're taken into account
  as type parameters in type resolution. If there is an ambiguity in the final
  result, eg. there are several interpretations possible for the names & types
  of entities in the complete context, then the code will be rejected.

* If a `structural_generic_instantiation_reference` is used as a call name for
  a function call, then the expected return type of the call can be used to
  determine the actuals for the generic instantiation.

Let's take another example:

```ada
generic
   type Index_Type is (<>);
   type Element_Type is private;
   type Array_Type is array (Index_Type range <>) of Element_Type;

   with function "<" (Left  : in Element_Type;
                      Right : in Element_Type)
          return Boolean is <>;

procedure Ada.Containers.Generic_Array_Sort (Container : in out Array_Type);

type Int_Array is array (Positive range <>) of Integer;
A : Int_Array := (12, 15, 28, 1, 2, 8, 6, 1000);

Generic_Array_Sort (A);
```

Here:

* The type of the generic formal `Array_Type` will be deduced from the type of
  the call actual `A`.

* The type of `Index_Type` and `Element_Type` will be deduced as per the
  [inference of dependent formal types RFC](../meta/rfc-improved-generic-instantiations.md)

* The `"<"` is deduced as per pre-existing instantiation rules.


Reference-level explanation
===========================

TBD

Rationale and alternatives
==========================

The rationale is contained in the high level RFC on generics.

Drawbacks
=========

N/A

Prior art
=========

This is very specific to Ada's generic formals system, but we could consider
that they way generic formal packages' own params can be deduced when
instantiating the generic, is pretty similar to what we propose here, so that
this is the extension of an already existing mechanism.
