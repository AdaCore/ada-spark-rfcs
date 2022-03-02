- Feature Name: ghost fields
- Start Date: 2022-02-22
- RFC PR: #88
- RFC Issue: (leave this empty)

Summary
=======

Ghost fields are record components marked with the Ghost aspect, to specify
that their value should only be used in ghost code (in particular assertions),
and that they should be erased by the compiler unless ghost code is
activated. They provide a way to add verification-oriented data to record
types.

Motivation
==========

Currently, such verification-oriented data must be either added as regular
fields in record types, or be kept in completely separate ghost data
structures. In the first case, there is no verification that such data is not
used in regular non-ghost code, and this imposes some constraints on values
assigned to such fields (which cannot be a ghost expression). In the second
case, this forces changes to the API to pass additional parameters to
subprograms, as well as duplicating the hierarchy of data structures to
separate ghost from non-ghost fields.

Guide-level explanation
=======================

The Ghost aspect can be specified for a record component. An assignment
statement to such a component (in full or part) is a ghost statement. The rules
for referencing a ghost component are the same as for any other ghost
entity. Ghost entities should now be allowed inside the expression
corresponding to a ghost component inside an aggregate. Here is an example of
use of a ghost component:

```ada
   type Pair is record
      X, Y : Integer;
      Area : Integer with Ghost;  --  ghost component
   end record;

   function Compute_Area (X, Y : Integer) return Integer is (X * Y)
     with Ghost;

   function Create (X, Y : Integer) return Pair is
      (X => X, Y => Y, Area => Compute_Area (X, Y));  --  ghost reference

   procedure Assign (P : out Pair; X, Y : Integer) is
   begin
      P.X := X;
      P.Y := Y;
      P.Area := Compute_Area (X, Y);  --  ghost statement
   end Assign;
```

In order to guarantee that the program semantics are unaffected by the decision
to activate or not ghost code, the compiler should use the same size and layout
for record objects in both cases, using padding components instead of ghost
components when ghost code is not activated. For the record type above, the
compiler should compute a size and layout that takes component ``Area`` into
account, even when ghost code is deactivated. If specified explicitly, size and
representation clauses (or aspects) should also take component ``Area`` into
account:

```ada
   for Pair'Size use 3 * 32;

   for Pair use record
      X    at 0 range 0 .. 31;
      Y    at 4 range 0 .. 31;
      Area at 8 range 0 .. 31;
   end record;
```

Ghost components do not participate in the default equality, so that two
``Pair`` objects which only differ in their ``Area`` component should be
equal:

```ada
      P1 := (X => 1, Y => 2, Area => 8);
      P2 := (X => 1, Y => 2, Area => 12);
      pragma Assert (P1 = P2);  --  true assertion
```

Note that subtype predicates cannot refer to ghost entities, including ghost
components, as they are evaluated in type membership tests. Type invariants can
refer to ghost entities, including ghost components.

For cases where it is important that ghost components take no space, e.g. in
embedded applications where memory is scarse, or objects are mapped or
converted so the layout cannot be modified for ghost components, it is possible
to specify that they take a null size by using a private type of null size (a
null record) whose completion is in a private part with ``SPARK_Mode (Off)`` as
follows:

```ada
package P
  with SPARK_Mode
is

   package Model
     with Ghost
   is
      type T is private;

      function Get (P : T) return Integer
      with
        Import;

      procedure Set (A : out T; Val : T)
      with
        Import,
        Post => A = Val;

   private
      pragma SPARK_Mode (Off);

      type T is null record with Size => 0;

   end Model;

   use Model;

   type Pair is record
      X, Y : Integer;
      Area : T with Ghost;  --  ghost component
   end record;

   function Create (X, Y : Integer) return Pair
   with
     Post => Create'Result.X = X
       and then Create'Result.Y = Y
       and then Get (Create'Result.Area) = X * Y;

end P;
```

In the above code example (which is currently valid except for the ``with
Ghost`` aspects), ghost component ``Area`` is of type ``T`` which has null
size. GNATprove treats it as an abstract type thanks to the use of ``SPARK_Mode
(Off)`` in the private part of package ``Model``. The API for ``Pair`` must be
suitably annotated with contracts which specify how the value of ``Area`` is
impacted by changes to values of type ``Pair``. In particular here, a getter
function ``Get`` gives an integer value associated with a value of type ``T``,
which can be used in all such contracts, like the postcondition of
``Create``. The setter procedure ``Set`` can also be used directly to modify
the value of ghost component ``Area``. Note that all subprograms that deal only
with the ghost component are marked as imported, so the code must be compiled
with deactivated ghost code.

Reference-level explanation
===========================

The changes are located in section 6.9 of the SPARK Reference Manual.

Change:
> if one were to take a valid SPARK program and remove all ghost entity
> declarations from it and all "innermost" statements, declarations, and
> pragmas which refer to those declarations (replacing removed statements with
> null statements when syntactically required), then the resulting program
> might no longer be a valid SPARK program
into
> if one were to take a valid SPARK program and remove all ghost entity
> declarations from it and all "innermost" statements, declarations,
> pragmas and record_component_associations which refer to those declarations
> (replacing removed statements with null statements when syntactically required),
> with padding inserted in record types to replace ghost components,
> then the resulting program might no longer be a valid SPARK program

Static Semantics

Rule 3 should replace:
> it is an assignment statement whose target is a ghost variable; or
by:
> it is an assignment statement whose target is part of a ghost variable or component; or

Add a rule:
> If the Ghost assertion policy in effect at the point of elaboration of
> a record_component_association for a ghost component in an aggregate is Ignore,
> then the elaboration of that construct (at run time) has no effect.

Legality Rules

Rule 5 should replace:
> a package, or a generic package
by:
> a record component, a package, or a generic package

Rule 5 should remove:
> ghost components of non-ghost record types, or

Rule 7 should replace:
> A ghost type or object shall not be effectively volatile.
by:
> A ghost type or object, or a type or object having a ghost component part,
> shall not be effectively volatile.

Rule 10 should add, as a place where a ghost entity can be referenced:
> from within an expression of a record_component_association
> for a ghost component in an aggregate; or

Rule 13 should replace:
> If the Ghost assertion policy in effect at the point of the declaration of a
> ghost variable is Check, then the Ghost assertion policy in effect at the point
> of any assignment to a part of that variable shall be Check.
by:
> If the Ghost assertion policy in effect at the point of the declaration of a
> ghost variable or component is Check, then the Ghost assertion policy in effect
> at the point of any assignment to a part of that variable or component shall be Check.

Dynamic Semantics

Add a rule:
> Ghost components are ignored when defining the behavior of the predefined
> equality operators and predefined stream-oriented attributes for a record
> type with ghost components.

Rationale and alternatives
==========================

The main choice when defining the semantics of ghost components is to decide:

- whether they are executable or not, and
- whether they impact the representation of types (size, layout) or not.

The current proposal proposes to:

- make ghost components executable, leaving the decision to compile code
  involving ghost components into executable code to the Ghost assertion policy
  mechanism, as for other ghost code.
- have the same type representation when ghost code is activated or not.

An alternative would be to make ghost components never executable, which would
require any ghost code referring to ghost components to be disabled. The
benefit of that approach is that ghost components could be ignored when
computing the type representation.

Another alternative would be to have executable ghost components, but change
the type representation depending on whether ghost components are activated or
not. The benefit of that approach is that no padding space is used when ghost
components are deactivated. The big drawback is that computations that involve
type representation values (like the type's size) are different when ghost
components are activated or not.

Yet another alternative would be to have executable ghost components, but store
them in a special data structure (e.g. a map from object addresses to the
corresponding ghost component values, for each ghost component), so that they do
not impact the representation of objects. The drawback of that approach is that
it is more complex, and that it causes some issues with the activation of ghost
components changing the decision to pass objects of that type by reference or
by copy, when finalization of controlled objects is required.

Drawbacks
=========

This is a conservative extension of the current rules, and it does not overly
constrain the solution, so that refinements could be adopted later (e.g. to
reduce the size of types when ghost components are deactivated).

Prior art
=========

Other programming languages that target formal program verification include
ghost fields: [Why3](http://why3.lri.fr/doc/syntaxref.html#modules),
[Dafny](https://dafny-lang.github.io/dafny/DafnyRef/DafnyRef.html#33-declaration-modifiers).

Ghost code is not executable in these languages, so the above discussion
regarding alternatives for ghost components is not relevant for them.

Unresolved questions
====================

- Is the current proposal sufficient to support common use cases?

Future possibilities
====================

It could be interesting in some cases to reduce the size of types when ghost
components are deactivated, by checking that this has no effect on the behavior
of the program, possibly through restrictions on how type representation values
are used.

It could also be possible to support the case of ghost components with null size,
which would not be executable (leading to a compilation error if Ghost policy is
Check at the point of declaration of the ghost component). The benefit would be
that such ghost components would not impact the size of the enclosing record type.
