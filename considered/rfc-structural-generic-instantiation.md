- Feature Name: Structural generic instantiation
- Start Date: 2023-03-03
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

This RFC proposes to allow "structural" instantiation of generics, that is to
be able to reference an implicit instance of a generic, that is denoted only by
its actual parameters, rather than by its name.

Motivation
==========

The expected benefits of this feature are:

1. Expressivity. Combined with other features that can be found in the [meta
   RFC](../meta/rfc-improved-generic-instantiations.md), we hope to make
   generic subprograms much more usable, and unblock potential use cases that
   would otherwise require language support to be expressive (Ada 2022's
   `Reduce` comes to mind).

2. Be able to refer to a "unique", structural instance of a generic. For
   example there will be a unique instance of `Ada.Containers.Vectors
   (Positive, Positive)`, and all people refering to it will refer to the same
   instance, which solves a long standing problem in generics, which is the
   ability to structurally reference unique entities.

See the high level RFC for examples.

Guide-level explanation
=======================

You can structurally refer to an implicit instantiation of a generic by naming
it. The (tentative) syntax for naming it is the following:

```ada
Ada.Unchecked_Deallocation [Integer, Integer_Access] (My_Int_Access);
```

By naming the generic, it will be implicitly instantiated, a key point being
that there is only one generic corresponding to `Ada.Unchecked_Deallocation
[Integer, Integer_Access]` at a high level, and every reference to it
references the same entity.

> *Note*
>
> It's not clear that we can actually guarantee that it will be compiled only
> once with a separate compilation model, which is why it is not mentioned
> above, but the goal is clearly to ensure that when possible, and when it's
> not, to minimize the number of instances actually generated.

This syntax does also allow naming parameters:

```ada
Ada.Unchecked_Deallocation [Object => Integer, Name => Integer_Access] (My_Int_Access);

Ada.Unchecked_Deallocation [Name => Integer_Access] (My_Int_Access);
--  NOTE: This relies on parameter inference
```

and empty parameter lists:

```ada
generic procedure Foo (A : Integer) is null;

Foo [] (12);

Ada.Unchecked_Deallocation [] (My_Int_Access);
--  NOTE: This relies on inference from name & type resolution context
```

> *Note*
>
> Do we want to allow `Ada.Unchecked_Deallocation (My_Int_Access)` - so,
> without any explicit syntactic instantiation indication ? Seems nifty and
> possible, but maybe too implicit.

Any generic can be instantiated, be it a package, procedure or function:

```ada
A : Ada.Containers.Vectors [Positive, Positive].Vector;
```

This allows generalized structural typing in Ada, and fixes a long standing
problem regarding generic types and modularity:

```ada
generic
    type Element_Type is private;
package Consume_Elements is
    package Elements_Vectors is new Ada.Containers.Vectors (Positive, Element_Type);

    procedure Consume_Elements (Elements : Elements_Vectors.Vector);
end Consume_Elements;

--  In another package/library

generic
    type Element_Type is private;
package Produce_Elements is
    package Elements_Vectors is Ada.Containers.Vectors (Positive, Element_Type);

    function Produce_Elements return Elements_Vectors.Vector;
end Produce_Elements;

--  No solution to use vectors produced by Produce_Elements.Produce_Elements in
--  Consume_Elements.Consume_Elements (appart from unchecked conversion).
```

There is a convoluted solution using generic formal packages, that is far from
ideal:

```ada
generic
    type Element_Type is private;
    with package Elements_Vectors is new Ada.Containers.Vectors (Positive, Element_Type);
procedure Consume_Elements (Elements : Elements_Vectors.Vector);

--  In another package/library

generic
    type Element_Type is private;
    with package Elements_Vectors is new Ada.Containers.Vectors (Positive, Element_Type);
function Produce_Elements return Elements_Vectors.Vector;

package Positive_Vectors is new Ada.Containers.Vectors (Positive, Positive);
function Produce_Positives is new Produce_Elements (Positive, Positive_Vectors);
procedure Consume_Positives is new Consume_Elements (Positive, Positive_Vectors);

Consume_Positives (Produce_Positives);
```

This solution is far from ideal, mainly because of its verbosity. It forces
instantiators to instantiate the generic themselves even in the (probable)
majority of cases where this modularity isn't needed. The consequence is that,
in practice, most generic code in Ada is not made to be modular.

Consider the solution with structural instantiations:

```ada
generic
    type Element_Type is private;
procedure Consume_Elements (Elements : Ada.Containers.Vectors [Positive, Element_Type].Vector);

--  In another package/library

generic
    type Element_Type is private;
function Produce_Elements return Ada.Containers.Vectors [Positive, Element_Type].Vector;

Consume_Elements [Positive] (Produce_Elements [Positive]);
```

Reference-level explanation
===========================

This is clearly not complete, we expect this draft to be completed during
prototyping.

### Syntax changes

Add the following syntax rule:

```
structural_generic_instantiation_reference ::=
    name [generic_actual_part]
```

And alter the `name` rule to include `structural_generic_instantiation_reference`

### Semantic changes

* Each `structural_generic_instantiation_reference` references a structural
  generic instantiation.

* This structural generic instantiation is semantically unique accross all
  units of the closure, so all references refer to the same instantiation.

* As soon as there exists one reference to a given structural instantiation,
  then it will be instantiated.

* Any generic can be instantiated, be it a package, procedure or function. A
  `structural_generic_instantiation_reference` will be syntactically valid in
  any context where a name is valid, and semantically valid in any context
  where a reference to the instantiated entity (subprogram or package) is
  valid.

Rationale and alternatives
==========================

The rationale is contained in the high level RFC on generics.

Drawbacks
=========

N/A

Prior art
=========

Most languages with generics also have by default structural instantiation of
them. In fact it is pretty much the default paradigm for generics in most
languages (C++, C#, Java, Rust, Haskell, OCaml, etc), which makes it difficult
to identify the feature with such a specific name, because it is usually just
called "generics".

TODO: Try to fill out this section nonetheless

Issues to consider
==================

The accessibility level of an instance of a generic package can impact both
the static legality and the dynamic behavior of a program. Examples
illustrating this are provided below. This suggests that the point at which
an implicit instance is declared should be well-defined.

First, a static example:

    generic
    package G1 is
      Int : aliased Integer;
    end package;

    type Int_Ref is access all Integer;
    Ref : Int_Ref;

    package I1 is new G1;

    procedure Foo is
       package I2 is new G1;
    begin
       Ref := I1.Int'Access; -- legal
       Ref := I2.Int'Access; -- illegal
    end Foo;

One might argue that this is not a problem since we do not plan to allow
implicit instances of generic packages that declare variables. But the
entity declared in the generic have been a constant or even a subprogram
(with corresponding changes to the access type declaration).

Next, a dynamic example, referencing the same G1, Int_Ref, Ref, and I1
declarations:

     procedure Bar is
       package I2 is new G1;
       procedure Update_Ref (Value : access Integer) is
       begin
           Ref := Int_Ref (Value);
       end;
    begin
       Update_Ref (I1.Int'Access); -- succeeds
       Update_Ref (I2.Int'Access); -- raises Program_Error
    end;

Accessibility levels can also impact the results of membership tests
and the point at which finalization takes place. We presumably want all
these sorts of things to be well-defined for an implicitly declared instance.

A general approach that was discussed briefly at the meeting was to
hoist the implicit declaration of an instance to the outermost possible
scope. For example, if a formal parameter of a subprogram is an actual
parameter of an instance, then we can't hoist the implicit declaration
to some point outside of the subprogram. But what does "outermost possible"
mean in the case of renamings and subtype declarations? In a case like

    procedure Foo (N : Natural) is
       subtype S is String;
       function Eq (X, Y : S) return Boolean renames "=";
    begin
       Some_Generic (S, Eq).Some_Procedure;
    end;

can we hoist the implicit instance declaration outside of Foo?
What if we add a static constraint to the subtype declaration, as in
    subtype S is String (1 .. 10);
? Or a dynamic constraint, as in
    subtype S is String (1 .. N);
?

> Raph: For me we shouldn't try to be clever about those cases (so no resolving of renamings/subtypes)
> The right approach is for the compiler to show where the generic has been instantiated and why.

Is some cases, there may be no suitable declaration site and so the
implicit instance reference would presumably have to be rejected.
Consider an implicit instance with an actual parameter that is a
formal parameter of an expression function:
    function Expr_Func (N : Natural) is
       (Some_Generic(N).Some_Function);
       
Would we want to allow this? Note that implicitly replacing an
expression function with a "regular" function would give us a place
to declare the implicitly-declared instance, but it would also introduce
complexity (e.g., interactions with freezing).

> Raph: It's a shame that expression functions and regular functions have different semantics in that regard.
> I think this case can acceptably be flagged as illegal, at least for now, as long as we have decent
> error messages in the implementation.

====

When hoisting the implicit declaration of an instance, we probaby need to be
careful not to introduce a case where the instance is elaborated before
the corresponding generic body. We don't want to introduce an
access-before-elaboration failure. Similarly, if would not be good if we have a
subprogram that is never called and it contains a reference to an implicitly
declared package instance, and if that instance gets hoisted to some point outside
of the subprogram and then the elaboration of the instance propagates an exception.

> Raph: Can you give examples ?

====

We want to allow, but not require, sharing of implicitly declared instances
that have the same actual parameters. The idea is that program legality
and behavior should be unaffected by such sharing (or its absence). That's
one reason, for example, that we want to disallow implicit instances of
generics that have variable state (or which query variable state during their
elaboration).

One case that requires some thought is tagged type declarations. Consider
    subtype S1 is Some_Generic (Integer, "+").Some_Tagged_Type;
    subtype S2 is Some_Generic (Integer, "+").Some_Tagged_Type;
    Flag : Boolean := S1'Tag = S2'Tag;

If two tagged types have distinct tags and neither is descended from
the other, then allowing conversion between the types (implicit or
explicit) seems like it would lead to problems. So if we are going to
treat S1 and S2 as being subtypes of the same type, then the two
implicit instance references probably need to be somehow required to refer
to the same instance.

> Raph: That's a good point but yes. At the user level, we want there to be only one type.
>  In this particular case, it means that we *need* the emitted code to have only one tag
>  for this type.

Another somewhat similar case is access equality, as in

     type Ref is access procedure;
     Ptr1 : Ref := Some_Generic (Integer, "+").Proc'Access;
     Ptr2 : Ref := Some_Generic (Integer, "+").Proc'Access;
     Flag : Boolean := Ptr1 = Ptr2;

where Flag will probably be initialized to True if and only if instance
sharing occurs (although in this particular case, Flag might be False even
if sharing occurs because of RM 4.5.2(13)). Similar scenarios involving
an access-to-constant type are possible.

[Aside: hopefully we will not introduce any violation of the equivalence
rule for multi-identifier object declarations given in 3.3.1(7). We don't
want to treat
   X, Y : Some_Generic (Integer, "+").T;
differently than
   X : Some_Generic (Integer, "+").T;
   Y : Some_Generic (Integer, "+").T;
with respect to allowing/forbidding instance sharing]

One approach is to invent rules to eliminate optional instance sharing -
in cases where it makes a difference, sharing should be forbidden or
required. Another approach is to give up on the ideal that program
behavior should be unaffected by whether the implementation chooses to
share instances or not.

> Raph: Question: is there an ideal compilation model where we can guarantee sharing in 100% of the cases ? Under what constraints ? How would it look like ?
