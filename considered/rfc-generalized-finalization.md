- Feature Name: lightweight-finalization
- Start Date: 2020-11-23
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

## Summary

This RFC proposes, in a two step mechanism, to:

1. Introduce a new finalization mechanism that does not rely on tagged types
   and has more modular semantics than today's controlled types

2. Specify `Ada.Finalization.Controlled` in terms of this new mechanism

The aim for the first item is to make some aspects of the current machinery
configurable, in such a way that:

* In a certain configuration, the exact semantic of current controlled object
  is implemented

* Simpler configurations are available, where the amount of constraints imposed
  on the implementation is not as big, and the implementation can both be
  simpler and faster.

*Note: we abuse the term "finalization" throughout this RFC to denote control
over the whole lifetime of an object, i.e. the same level of control that
controlled objects procur today.*

## Motivation

### Tagged type constraints

Current finalization based on controlled objects forces users to
turn their untagged type into a tagged type in order for it to benefit from
finalization. Thus, new legality rules apply (e.g. RM 3.9.2) which can break
existing code in many different ways. One such example is illustrated below:

```ada
type T is tagged null record;
type U is record;

function F (X : T) return U;
```

In this situation, one cannot simply turn `U` into a controlled object,
otherwise the subprogram `F` would become a primitive of two tagged types,
which is forbidden.

In general, taggedness, imposes compile-time and run-time constraints (More
memory used, interaction with other features, etc) that people might not want
to tackle just to get finalization.

### Guarantees

The guarantees provided by controlled types are very strong, requiring a
complex implementation and incurring a substantial runtime performance penalty.

* One such guarantee is that an access-to-controlled type should finalize all
  objects that have been **heap-allocated** through it once it goes out of
  scope (*todo: link to RM*). The compiler must therefore generate code to keep
  track of these objects, untrack them upon explicit deallocation, etc., which
  obviously induces a significant overhead at runtime.

* The other is guarantees with regard to Bounded (Run-Time) Errors (see RM
  7.6.1), or in other words, what happens in the case an exception is raised
  during finalization.

The first point makes implementation of finalization on constrained resources
platforms a lot harder, because the run-time support needed to implement it has
a significant cost. Qualification efforts must also take the associated code
into account.

It also comes at a cost in terms of run-time, because heap-allocated controlled
objects are added to global linked lists, that must be maintained over the
life-time of objects.

The second point is the main obstacle in having fast finalization of
stack-allocated controlled objects.

For the record, GNAT already supports some custom aspects to weaken the default
guarantees mandated by the Ada specification, such as `pragma
No_Heap_Finalization` and `pragma Finalize_Storage_Only`.

## Guide-level explanation

### Aspect-based finalization

We propose to introduce three new aspects, analogous to the three
controlled-type primitives, as in the following template:

```ada
type T is ...
   with Initialize => <Initialize_Procedure>,
        Adjust     => <Adjust_Procedure>,
        Finalize   => <Finalize_Procedure>;
```

The three procedures have the same profile, taking a single `in out T`
parameter.

We follow the same dynamic semantics as controlled objects:

 - `Initialize` is called when an object of type `T` is declared without
   default expression.

 - `Adjust` is called after an object of type `T` is assigned a new value.

 - `Finalize` is called when an object of type `T` goes out of scope (for
   stack-allocated objects) or is explicitly deallocated (for heap-allocated
   objects). It is also called when on the value being replaced in an
   assignment.

However the following differences are enforced by default when compared to the
current Ada controlled-objects finalization model:

* No automatic finalization of heap allocated objects: `Finalize` is only
  called when an object is implicitly deallocated. As a consequence, no-runtime
  support is needed for the implicit case, and no header will be maintained for
  this in heap-allocated controlled objects.

  Heap-allocated objects allocated through a nested access type definition will
  hence **not** be deallocated either. The result is simply that memory will be
  leaked in those cases.

* The `Finalize` procedure should have have the `No_Throw` aspect specified
  (see [TODO ADD LINK TO NEW RFC](rfc-nothrow.md)). If that's not the case, a
  compilation error will be raised.

Additionally, two other configuration aspects are added,
`Legacy_Heap_Finalization` and `Exceptions_In_Finalize`:

* `Legacy_Heap_Finalization`: Uses the legacy automatic finalization of
  heap-allocated objects

* `Exceptions_In_Finalize`: Allow people to have a finalizer that raises, with
  the corresponding execution time penalities.

### New specification for `Ada.Finalization.Controlled`

`Ada.Finalization.Controlled` will now be specified as:

```ada
type Controlled is abstract tagged null record
with Initialize => Initialize,
     Adjust => Adjust,
     Finalize => Finalize,
     Legacy_Heap_Finalization, Exceptions_In_Finalize;

   procedure Initialize (Self : in out Controlled) is abstract;
   procedure Adjust (Self : in out Controlled) is abstract;
   procedure Finalize (Self : in out Controlled) is abstract;
```

### Examples

A simple example of a ref-counted type:
```ada
type T is record
   Value : Integer;
   Ref_Count : Natural := 0;
end record;

procedure Inc_Ref (X : in out T);
procedure Dec_Ref (X : in out T);

type T_Access is access all T;

type T_Ref is record
   Value : T_Access;
end record
   with Adjust   => Adjust,
        Finalize => Finalize;

procedure Adjust (Ref : in out T_Ref) is
begin
   Inc_Ref (Ref.Value);
end Adjust;

procedure Finalize (Ref : in out T_Ref) is
begin
   Def_Ref (Ref.Value);
end Finalize;
```

A simple file handle that ensures resources are properly released (Taken from a
discussion in [this
RFC](https://github.com/AdaCore/ada-spark-rfcs/pull/29#issuecomment-539025062))

```ada
   type File (<>) is limited private;

   function Open (Path : String) return File;

   procedure Close (F : in out File);
private
   type File is limited record
      Handle : ...;
   end record
      with Finalize => Close;
```

### Finalized tagged types

Aspects are inherited by derived types and optionally overriden by those. The
compiler-generated calls to the user-defined operations should then be
dispatching whenever it makes sense, i.e. the object in question is of
classwide type and the class includes at least one finalized-type.

However note that for simplicity, it is forbidden to change the value of any of
those new aspects in derived types.

> [!NOTE]
> This is needed for the two configuration aspects `Legacy_Heap_Finalization`
> and `Exceptions_In_Finalize`, in order to avoid having to pessimize
> code-generation. It also seems completely useless to change the value of any
> of `Initialize`, `Adjust`, or `Finalize` in tagged types where you could just
> override the primitive that implements those operations.

### Composite types

When a finalized type is used as a component of a composite type, the latter
should become finalized as well. The three primitives are derived automatically
in order to call the primitives of their components.

If that composite type was already user-finalized, we propose that the compiler
calls the primitives of the components so as to stay consistent with today's
controlled types's behavior.

So, `Initialize` and `Adjust` are called on components before they
are called on the composite object, but `Finalize` is  called on the composite
object first. This is the easiest approach as it avoids confusing users and its
semantics are already battle-tested, but could still be revised.

### Interoperability with controlled types

As a consequence of the redefinition of the `Controlled` type as a base type
with the new aspects defined, interoperability with controlled type naturally
follows the definition of the above rules. In particular we expect that:

* It should be possible to have a new finalized type have a controlled type
  component
* It should be possible to have a controlled type have a finalized type
  component

### Other run-time aspects

For every other aspect that is not mentioned in that RFC, those new finalized
types follow the semantics defined by the Ada Reference Manual in section 7.6.

Reference-level explanation
===========================

TBD.

Rationale and alternatives
==========================

TBD.

Drawbacks
=========

TBD.

Prior art
=========

TBD. Talk about RAII in languages such as C++.

Unresolved questions
====================

TBD.

Future possibilities
====================

TBD.
