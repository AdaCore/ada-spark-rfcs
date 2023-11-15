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

or

```ada
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

To be completed

### Syntax changes

No syntax changes planned

### Semantic changes

When in the presence of a dependent type, as defined above, in a generic
formal, the instantiator of the generic can omit this type, either passing `<>`
explicitly, or just omitting it from the instantiation completely.

The compiler will deduce it from other parameters.

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

Discussion
==========

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
(or result) of a formal type, do we want to make inferences about the corresponding actual
subtype, or only about the corresponding actual type? The point is that 12.6(8) only requires mode conformance, not subtype conformance.
The following example is legal:

```ada
generic
   type T is private;
   with function F (X : T) return String;
package G is ... end G;

package I is new G (Natural, Integer'Image);
```

despite the fact that Integer'Image takes an Integer parameter, not a Natural parameter.
So if we omitted the first actual parameter and tried to infer it from the second, we'd have to assume subtype conformance.
That might be ok, but we should make an explicit decision about that point.

We'll need to define rules for dealing with both consistent and inconsistent overspecification of inferred generic actuals.
Consider:

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
mentioned above, an actual subprogram only has to be mode conformant). But do we want this complexity?

> WG: We **need** to get fancy, because else some cases will be illegal with infered parameters, that would otherwise be legal

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
