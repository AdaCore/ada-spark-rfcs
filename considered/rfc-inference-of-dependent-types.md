- Feature Name: Inference of dependent types in generic instantiations
- Start Date: 2023-03-03
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

This RFC proposes to allow inference of types in generic specification, when
there is a way to deduce it from other generic parameters.

Motivation
==========

This RFC is part of the bigger high-level RFC about improving generic
instantiations ([here](../meta/rfc-improved-generic-instantiations.md)), so the
need arises from that context, and it's useful to go read the high level RFC to
understand the bigger picture.

However, even in the reduced context of explicit instantiations, it's easy to
understand the value of this feature with a few simple examples:

```ada
type Integer_Access is access all Integer;

procedure Free is new Unchecked_Deallocation (Name => Integer_Access);
```

or

```ada
type Arr is array (Positive range <>) of Integer;

package Int_Array_Sort
is new Ada.Containers.Generic_Array_Sort (Array_Type => Arr);
```

Guide-level explanation
=======================

In every case where a generic formal references other types, those types can
be other formal types. In those case, the user of the generic needs to pass
every type separately.


```ada
generic
    type Element_Type is private;
    type Index_Type is (<>);
    type Array_Type is array (Index_Type range <>) of Element_Type;
package Array_Operations is
    ...
end Array_Operations;

...

type Int_Array is array (Positive range <>) of Integer;

package Int_Array_Operations is new Array_Operations
  (Element_Type => Integer,
   Index_Type   => Positive,
   Array_Type   => Int_Array);
```

This feature allows the programmer to not have to pass type parameters that
could be deduced from other type parameters. In the example above, the language
can automatically deduce the index and element type from the array type that is
passed in:

```ada
package Int_Array_Operations is new Array_Operations (Array_Type => Int_Array);
```

* Generic formal array types (see the first example)

* Generic formal access types, where the accessed type can be deduced from the
  access type.

```ada
type Integer_Access is access all Integer;

procedure Free is new Unchecked_Deallocation (Name => Integer_Access);
```

* Generic formal subprograms, where any type can be deduced from the type of
  the formals of the subprogram

```ada
generic
   type Element_Type is private;
   type Array_Type is array (Positive range <>) of Element_Type;
   type Key_Type is private;
   with function Key (E : Element_Type) return Key_Type;
   with function "<" (L, R : Key_Type) return Boolean is (<>);
function Min_By (Self : Array_Type) return Element_Type;

-- usage:

type Person is record
   Name : Unbounded_String;
   Age  : Natural;
end record;

function Age_Of (P : Person) return Natural is (P.Age);

type Person_Array is array (Positive range <>) of Person;

function Min_By_Age is new Min_By
  (Array_Type => Person_Array, Key => Age_Of);
-- Element_Type inferred from Person_Array, Key_Type inferred from Age_Of

DB      : Person_Array := ...;
Younger : Person := Min_By_Age (DB);
```

> **Note**
> We decided to not include generic formal packages, because the implementer
> already has the option to not require the user to pass in the dependent
> types, via the `<>` syntax:
>
> ```ada
> generic
>    with package P is new Q (<>);
> ```

Reference-level explanation
===========================

### Syntax changes

No syntax changes planned

### Semantic changes

Ada RM 12.3(10) says:
   Each formal without an association shall have a default_expression,
   default_subtype_mark, or subprogram_default.

In the case of formal type, this rule is relaxed (that is, the corresponding
actual parameter can be omitted) in certain cases described below in which
the actual subtype can be inferred from another actual parameter and
therefore need not be provided explicitly. The corresponding "generic
actual parameter" (see RM 12.3(7)) is then the inferred actual subtype.
The resulting static and dynamic semantics are as if the actual subtype
had been specified explicitly. Here are the cases where this is allowed:

* If an actual parameter is provided (or is inferred) for a formal array type
  whose component type is a formal type of the same generic unit, then that
  actual component subtype can be inferred from the actual array type; it is
  the component subtype of the array type.

* Similarly for each of the formal array's index types that is a formal type of
  the same generic generic unit: the actual index subtype can be inferred from
  the actual array type and is the corresponding index subtype of the array
  type.

* Analogous rules apply if an actual parameter is provided (or is inferred) for
  a formal access type whose designated type is a formal type of the same
  generic unit, or for a formal discriminated type having one or more
  discriminants of a formal type of the same generic unit.

* Analogous rules apply if an actual parameter is explicitly provided for a
  formal subprogram whose profile includes a parameter or result whose type is
  a formal type of the same generic unit, and the actual subprogram parameter
  name statically denotes a directly visible subprogram, and no other
  subprograms with the same defining name are directly visible at the point
  where that name is resolved. (So no inference from an actual subprogram if
  any nontrivial overload resolution is required to identify the subprogram.)

> [!NOTE]
> An actual parameter for a generic formal object of a generic formal type
> does not allow the corresponding actual subtype to be inferred. Similarly, no
> actual subtypes can be inferred from the actual parameter corresponding to a
> formal package, or from the designated subtype of any kind of anonymous
> access type (such as a discriminant type, a formal parameter type, or a
> function result type). Some of these rules may be relaxed at some point.]

> [!TIP]
> If we allow inference from formal object parameters, there are subtleties involving
> anonymous object types to consider. And in-out mode formal objects would need
> to be treated like subprograms for inferring subtypes, as opposed to types.]]

In some cases, a type won't be infered:

* If a generic formal type has a `default_subtype_mark`, then the corresponding
  actual subtype cannot be inferred.

* If a generic formal type is referenced within the enclosing
  `generic_formal_part` other than via a `subtype_mark` that does not occur
  within an expression, then the corresponding actual subtype cannot be
  inferred.

> [!TIP]
>   We don't want to allow something like
>
>     generic
>       type T is private;
>       X : Integer := T'Size;
>       type Ref is access T;
>     package G1 is end G1;
>     type Float_Ref is access Float;
>     package I1 is new G (Ref => Float_Ref);
>
> or
>
>     generic
>        type T is private;
>        type Ref is access T;
>        Sp : Root_Storage_Pool'Class := Ref'Storage_Pool;
>        type Ref_Vector is array (Positive range <>) of Ref;
>     package G2 is end G2;
>     type Float_Ref is access Float;
>     type Float_Ref_Vector is array (Positive range <>) of Float_Ref;
>     package I2 is new G2 (Ref_Vector => Float_Ref_Vector);

If the same actual subtype is inferrable from multiple sources (e.g., if one
formal type is mentioned as both the component type and as an index type for a
formal array type, or if one formal type is mentioned as the designated type of
two formal access types), then all of the resulting inferred subtypes shall be
subtypes of the same type.

With one exception, all of the inferred subtypes shall statically match each
other. The one exception: if a given actual subtype is inferred both from one
or more actual subprogram parameters and from one or more actual non-subprogram
parameters, then this static matching requirement is ignored for the
parameter/result subtypes of the actual subprogram parameters; the inferred
actual *subtype* (as opposed to *type*) is determined solely by the actual
non-subprogram parameters.

Rationale and alternatives
==========================

The rationale is contained in the high level RFC on generics.

As far as alternatives go, we could imagine a world where developers don't even
have to specify the dependent formals:

```ada
generic
   type Array_Type is array (<>) of <>;
package Array_Operations is
   subtype Index_Type is Array_Type'Index_Type;
   subtype Element_Type is Array_Type'Element_Type;
end Array_Operations;

...

type Int_Array is array (Positive range <>) of Integer;

package Int_Array_Operations is new Array_Operations
  (Array_Type   => Int_Array);
```

However, the current alternative has the advantage of being backwards
compatible with existing generic declarations.

Drawbacks
=========

N/A

Prior art
=========

This is very specific to Ada's generic formals system, but we could consider
that they way generic formal packages' own params can be deduced when
instantiating the generic, is pretty similar to what we propose here, so that
this is the extension of an already existing mechanism.

Future possibilities
====================

As mentioned earlier, we could extend inference mechanisms that has purposedly
been kept limited so far:

We could infer types from:

* Formal objects in some cases
* Formal packages
* Formal tagged types with a parent

We could also relax the rules wrt. inference of a type from formal subprograms.
For the moment we completely forbid any cases where the designated set of
subprograms is overloaded, but we might want to change that.

Discussion/Notes
================

Types are not overloadable, so omitting earlier actual parameters does not complicate
resolving the name of an actual type in an instance. This is not true for subprograms.
Do we really want to require an implementation to support something like

```ada
procedure Foo is

   type T1 is null record;

   type T2 is null record; -- only T2 has both Procs defined

   type T3 is null record;

   procedure Actual_Proc1 (X1 : T1) is null;

   procedure Actual_Proc1 (X2 : T2) is null;

   procedure Actual_Proc2 (X2 : T2) is null;

   procedure Actual_Proc2 (X3 : T3) is null;

   generic
      type Formal_Type is private;

      with procedure Formal_Proc1 (X : Formal_Type);

      with procedure Formal_Proc2 (X : Formal_Type);
   package G is

   end G;

   package I is new G

      (-- Formal_Type => T2, -- [To be inferred]

       Formal_Proc1 => Actual_Proc1,

       Formal_Proc2 => Actual_Proc2);

begin

  null;

end Foo;
```

? Whatever resolution rules we want to impose need to be defined.

> WG (Steve, Daniel, Romain, Raph): Let's put in place the rule "if the name of an actual, without context, designates more than one entity, the actual won't participate in resolution"
> This restriction might be relaxed at a later stage (or not)

If an actual subprogram is given and the corresponding formal subprogram has a parameter
(or result) of a formal type, do we want to make inferences about the
corresponding actual subtype, or only about the corresponding actual type? The
point is that 12.6(8) only requires mode conformance, not subtype conformance.

The following example is legal:

```ada
generic
   type T is private;
   with function F (X : T) return String;
package G is ... end G;

package I is new G (Natural, Integer'Image);
```

despite the fact that Integer'Image takes an Integer parameter, not a Natural
parameter. So if we omitted the first actual parameter and tried to infer it
from the second, we'd have to assume subtype conformance. That might be ok, but
we should make an explicit decision about that point.

We'll need to define rules for dealing with both consistent and inconsistent
overspecification of inferred generic actuals. Consider:

```ada
generic
    type Designated is private;
    type Ref1 is access Designated;
    type Ref2 is access Designated;
package G is end G;

type Nat_Ref is access Natural;
type Int_Ref is access Integer;

type Legal_Inst (Ref1 => Nat_Ref, Ref2 => Nat_Ref);
type Illegal_Inst (Ref1 => Nat_Ref, Ref2 => Int_Ref);
```

If we want to get fancy, we can say that an inferred subtype from a formal type
takes precedence over an inferred subtype from a formal subprogram (because, as
mentioned above, an actual subprogram only has to be mode conformant). But do
we want this complexity?

> WG: We **need** to get fancy, because else some cases will be illegal with
> infered parameters, that would otherwise be legal

```ada
generic
    type Designated is private;
    type Ref1 is access Designated;
    with function F (X : T) return String;
package G is end G;

package Inst is new G (Nat_Ref, Integer'Image) -- Would be illegal if we don't get fancy, but legal if you pass `Designated` explicitly
```

Tuck: What about formal objects?  If a type is passed in along with a formal object, presumably the formal object by itself would be enough to determine the corresponding actual *type*.  Presumably again the inferred *subtype* of the actual would default to that of the object, unless there is a stronger matching requirement from some other formal.

Steve: Another possible form of inference that we are not addressing here has to do with a pair of formal packages, with the second being an instance of a generic declared in the first (possibly an implicitly declared "sprouted" child of the first as per RM 10.1.1(19)). Given "generic with package I1 is new G1 (<>); with package I2 is new I1.G2 (<>); package My_Generic is ...", the first actual parameter in an instantiation of My_Generic is determined by the second and therefore could be safely omitted (if this were allowed). This proposal is only about inferring actual subtypes, not inferring actual packages, so such an omission is not allowed.
