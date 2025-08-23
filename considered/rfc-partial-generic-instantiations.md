- Feature Name: Partial instantiation of generics
- Start Date: 2023-04-11
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

However, unlike other RFCs of that series, this one is pretty orthogonal to the
rest, and would provide usability benefits even if the rest of the RFCs were
not to be implemented.

The idea is to be able to create "new" generic specifications from existing
ones, by just specifying a subset of their parameters. This would simplify some
uses of generics, and would make creating "specialized" instances much easier.

Guide-level explanation
=======================

The idea is to be able to create "new" generic specifications from existing
ones, by just specifying a subset of their parameters.

Here is an example with `Ada.Containers.Vectors`:

```ada
generic
   type Index_Type is range <>;
   type Element_Type is private;

   with function "=" (Left  : in Element_Type;
                      Right : in Element_Type)
          return Boolean is <>;

package Ada.Containers.Vectors is ...

generic package Vecs
is Ada.Containers.Vectors (Index_Type => Positive);

package Float_Vectors is new Vecs (Float);
```

In the above example, the formal part between `generic` and `package` is empty,
which means that remaining params are infered from the partially instantiated
specification.

While this can be practical in simple cases:

* We want to let people the ability to fully specify formals
* We want to allow more complex patterns like reordering/renaming formals

Which leads us to the more complete syntax:

```ada
generic
   type El_T is private;
   with function "=" (Left : in El_T; Right : in El_T) return Boolean is <>;
package Vecs is Ada.Containers.Vectors
  (Index_Type   => Positive,
   Element_Type => El_T,
   "="          => "=");
```

While generic formal parts for standard containers are pretty simple, there
were experiments by AdaCore with creating much more generic specifications for
containers, in the `ada-traits-containers` library, and specializations of
those packages were provided, see for example
[this](https://github.com/AdaCore/ada-traits-containers/blob/master/src/conts-maps-indef_def_unbounded.ads)

The problem with this pattern is that:

* Entities from the `Impl` package are not automatically forwarded, so
  uses have to go through `Instantiation.Impl.`

* Means of forwarding are explicit (see the renamings/subtypes lower in the
  spec)

Using structural instantiations together with partial instantiations from this
RFC, and anonymous subprograms, one could write:

```ada
generic
   type Key_Type (<>) is private;
   type Element_Type is private;
   type Container_Base_Type is abstract tagged limited private;
   with function Hash (Key : Key_Type) return Hash_Type;
   with function "=" (Left, Right : Key_Type) return Boolean is 
   with procedure Free (E : in out Key_Type) is null;
   with procedure Free (E : in out Element_Type) is null;
package Conts.Maps.Indef_Def_Unbounded is
  Conts.Maps.Generics
    (Keys                => Conts.Elements.Indefinite [Key_Type, Conts.Global_Pool, Free].Traits,
     Elements            => Conts.Elements.Definite [Element_Type, Free => Free].Traits,
     Hash                => Hash,
     "="                 =>
       function (Left : Key_Type; Right : Keys.Traits.Stored) return Boolean
       is (Left = Right.all),
     Probing             => Conts.Maps.Perturbation_Probing,
     Pool                => Conts.Global_Pool,
     Container_Base_Type => Container_Base_Type);
```

Alternatively, if we consider that having "inline" syntax for sub-elements is a
problem - for example, because for anonymous functions, it doesn't exist yet -
we can introduce a syntax to introduce declarations inbetween the formal part
and the partial instantiation:

```ada
generic
   type Key_Type (<>) is private;
   type Element_Type is private;
   type Container_Base_Type is abstract tagged limited private;
   with function Hash (Key : Key_Type) return Hash_Type;
   with function "=" (Left, Right : Key_Type) return Boolean is <>;
   with procedure Free (E : in out Key_Type) is null;
   with procedure Free (E : in out Element_Type) is null;
declare
   package Keys is new Conts.Elements.Indefinite
     (Key_Type, Pool => Conts.Global_Pool, Free => Free);
   package Elements is new Conts.Elements.Definite
     (Element_Type, Free => Free);
   function "=" (Left : Key_Type; Right : Keys.Traits.Stored) return Boolean
     is (Left = Right.all) with Inline;
package Conts.Maps.Indef_Def_Unbounded is Conts.Maps.Generics
  (Keys                => Keys.Traits,
   Elements            => Elements.Traits,
   Hash                => Hash,
   "="                 => "=",
   Probing             => Conts.Maps.Perturbation_Probing,
   Pool                => Conts.Global_Pool,
   Container_Base_Type => Container_Base_Type);
```

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

TBD
