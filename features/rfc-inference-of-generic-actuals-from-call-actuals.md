- Feature Name: Inference of generic actuals from call actuals
- Start Date: 2023-03-03
- Status: Design

Summary
=======

This RFC builds up on top of [the structural generic instantiation
RFC](./rfc-structural-generic-instantiation.md), and proposes to be able to
infer generic actuals for structural generic instantiations, from the actuals
of the subprogram call, in cases where the structural generic instantiation
refers to a subprogram, or to a package declaring the called subprogram.

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

function Sum (X : Float_Array) return Float
is
    --  Implicit instantiation of Reduce. All formals except `Fn` can be
    --  deduced from the type of `X`, and from the expected return type.
  (Reduce (Fn => "+") (0.0, X));

type Float_Access is access all Float;

F : Float_Access := new Float'(Sum ([1.0, 2.0, 3.0, 4.0]));

--  Implicit instantiation of unchecked deallocation. Both type formals can be
--  deduced from the type of the access type passed as the actual.
Ada.Unchecked_Deallocation () (F);
```

Guide-level explanation
=======================

In the context of the structural instantiation of a subprogram, there is often
enough information to deduce the generic actuals from the type of the actuals
of the subprogram call:

```ada
generic
   type Object (<>) is limited private;
   type Name is access Object;
procedure Ada.Unchecked_Deallocation (X : in out Name);

type Integer_Access is access all Integer;

A : Integer_Access := new Integer'(12);

Ada.Unchecked_Deallocation (Integer, Integer_Access) (A);
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
  result, e.g. there are several interpretations possible for the names & types
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


Inference through generic packages
----------------------------------

Nothing in the above restricts the mechanism to generic subprograms. The base
[structural generic instantiation
RFC](./rfc-structural-generic-instantiation.md) allows all three kinds of
generics to be instantiated structurally, so a
`structural_generic_instantiation_reference` denoting a generic *package* can
appear as the prefix of a call, and the actuals of that call can then be used to
infer the actuals of the package instantiation:

```ada
generic
   type Element_Type is private;
package Signatures
   with Allow_Structural_Instantiation
is
   function Hash (E : Element_Type) return Hash_Type;
   procedure Swap (Left, Right : in out Element_Type);
end Signatures;

X, Y : Integer;

H : Hash_Type := Signatures ().Hash (X);
--                          ^^        ^ Type of `X` is `Element_Type`, so
--                                      `Element_Type => Integer`

Signatures ().Swap (X, Y);
```

The rule is the same one as for subprograms, only stated one level up: the
call's actuals (and, for a function call, the expected return type) participate
in the resolution of the enclosing `structural_generic_instantiation_reference`,
whether that reference denotes the called subprogram itself or the package that
declares it. As before, if the complete context admits several interpretations,
the code is rejected.

Two things are worth spelling out:

* Only the formals that actually show up in the profile of the called
  subprogram (directly, or indirectly through the [inference of dependent
  formal types RFC](../meta/rfc-improved-generic-instantiations.md)) can be
  inferred this way. A package formal that the called subprogram's profile
  never mentions has to be given explicitly, or defaulted:

```ada
generic
   type Element_Type is private;
   type Extra is private;
package P with Allow_Structural_Instantiation is
   function F (E : Element_Type) return Boolean;
end P;

B : Boolean := P (Extra => Integer).F (X);
--  `Element_Type` inferred from `X`, `Extra` cannot be and is given explicitly.
```

* Inference stops at the call: it doesn't work backwards from a use of a *type*
  declared in the instance, since a type name carries no actuals to infer from.
  `Vectors ().Vector` remains illegal, `Vectors (Positive, Positive).Vector` is
  the way to write it.

There is no new restriction on the packages themselves: they simply have to
satisfy the constraints the base RFC already imposes on anything carrying
`Allow_Structural_Instantiation` — in particular no mutable global state and no
non-`in` object formals, which is what makes it acceptable for the compiler to
share (or duplicate) the implicit instance freely. This matters more for
packages than for subprograms, because a package instance is the thing that
would own state if it were allowed any; a generic package holding a variable
cannot be structurally instantiated at all, and therefore cannot be reached
through inference either.

Note also that the accessibility and hoisting rules of the base RFC apply
unchanged: the implicit package instance is deemed declared in the topmost scope
where the equivalent explicit instantiation would be legal, which for an
inferred instantiation is bounded by the entities whose types were used for the
inference.

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
that the way generic formal packages' own params can be deduced when
instantiating the generic, is pretty similar to what we propose here, so that
this is the extension of an already existing mechanism.
