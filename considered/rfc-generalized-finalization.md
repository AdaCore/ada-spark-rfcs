# Generalized finalization

- Feature Name: generalized-finalization
- Start Date: 2020-11-23

## Summary

This RFC proposes, in a two step mechanism, to:

1. Introduce a new finalization mechanism that does not rely on tagged types
   and allows more relaxed semantics than today's controlled types

2. Specify `Ada.Finalization.Controlled` in terms of this new mechanism

The aim for the first item is to make some aspects of the current machinery
configurable, in such a way that:

* In a certain configuration, the exact semantic of current controlled objects
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

We propose to introduce a new aspect, `Finalizable`, with the following
specification:

```ada
type T is ...
   with Finalizable =>
     (Initialize => <Initialize_Procedure>,
      Adjust     => <Adjust_Procedure>,
      Finalize   => <Finalize_Procedure>,
      Relaxed_Finalization => True | False); -- Defaults to True
```

The three procedures have the same profile, taking a single `in out T`
parameter.

We follow the same dynamic semantics as controlled objects:

 - `Initialize` is called when an object of type `T` is declared without
   default expression.

 - `Adjust` is called after an object of type `T` is assigned a new value.

 - `Finalize` is called when an object of type `T` goes out of scope (for
   stack-allocated objects) or is explicitly deallocated (for heap-allocated
   objects). It is also called on the value being replaced in an assignment.

The `Relaxed_Finalization` configuration value is `True` by default, which
implies that:

* The compiler has permission to perform no automatic finalization of heap
  allocated objects: `Finalize` is only called when an object is implicitly
  deallocated. As a consequence, no-runtime support is needed for the implicit
  case, and no header will be maintained for this in heap-allocated controlled
  objects.

  Heap-allocated objects allocated through a nested access type definition will
  hence **not** be deallocated either. The result is simply that memory will be
  leaked in those cases.

* If an exception is raised out of the `Finalize` procedure, the compiler has
  permission to enforce **none of the guarantees specified by the Ada Reference
  Manual section 7.6.1 (14/1)**, and to instead just let the exception be
  propagated upwards.

In this mode, additionally, the `Finalize` and `Adjust` procedures are
automatically considered as having the `No_Raise` aspect specified (see [The
`No_Raise` RFC](rfc-noraise.md)).

> [!NOTE]
> Initially the design was to force people to annotate with `No_Raise`
> themselves. However, making it implicit is a better design in our opinion,
> because it will allow us to make the `Relaxed_Finalization` the default in
> some runtimes/configurations, without having to force people to annotate all
> of their existing code making use of `Controlled` with `No_Raise` aspects.

### Applicable types

This aspect shall be explicitly defined only on:

* Record types, tagged or not
* Private types for which the full-view is a record type

Any type that has a `Finalizable` aspect is a by-reference type.

The aspect is inherited by derived types. The compiler-generated calls to the
user-defined operations should then be dispatching whenever it makes sense,
i.e. the object in question is of classwide type and the class includes at
least one finalized-type.

> [!NOTE]
> This wildly simplifies the design and implementation of the feature, and is sufficient for all foreseen use cases. We don't want to consider:
> * What's the finalization of by-value types like integers
> * What it means to change this aspect in derived types
> * How to handle all of this in generics

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

For every other aspect that is not mentioned in that RFC, types with the
`Finalizable` aspect specified follow the semantics defined by the Ada
Reference Manual in section 7.6.

### New specification for `Ada.Finalization.Controlled`

`Ada.Finalization.Controlled` will now be specified as:

```ada
type Controlled is tagged private
with Finalizable => (Initialize => Initialize,
                     Adjust => Adjust,
                     Finalize => Finalize,
                     Relaxed_Finalization => False);

   procedure Initialize (Self : in out Controlled) is null;
   procedure Adjust (Self : in out Controlled) is null;
   procedure Finalize (Self : in out Controlled) is null;
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
   with Finalizable => (Adjust   => Adjust,
                        Finalize => Finalize);

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
      with Finalizable => (Finalize => Close);
```

Reference-level explanation
===========================

TBD.

Rationale and alternatives
==========================

The rationale for defining the `No_Raise` aspect in such a way will be put here
because it's essentially linked to its use in Finalization. We think it's fundamental that:

1. In development/testing setups, a finalizer raising an exception is as noisy
   as possible and crashes the application early
2. In some production setups, the above behavior is opt-out in certain cases

First, for a bit of context:

* In C++ a destructor should not raise an exception either. Starting from
  C++11, all destructors are implicitly declared as
  [noexcept](https://en.cppreference.com/w/cpp/language/noexcept_spec). This
  means that if a destructor raises an exception,
  [std::terminate](https://en.cppreference.com/w/cpp/error/terminate) will be
  called. An important thing to know though is that historically code that uses
  exceptions in C++ is very rare, and basic language operations rarely raise
  exceptions. This might explain why it seems OK in C++ world. IMO it's too
  drastic & dangerous in Ada.

* In Rust, the situation is a bit more complex. There are no exceptions in
  Rust, but there is panic, and 'panic' can use unwinding in some
  configurations, and can be caught. Depending on the configuration, panic drop
  implementations could panic. And some people think that in some configs, for
  resilient programming, being able to catch a panic, even from a drop, is a
  good idea. See the discussion here:
  https://github.com/rust-lang/lang-team/issues/97

A summary of the fundamental issues discussed in the Rust issue, and that are
relevant to us in Ada:

1. In dev and testing you definitely want an exception raised in your finalizer
   to be a fatal and not be spuriously caught by an exception handier that is
   too wide. In that regard, `Program_Error` probably fits the bill as well,
   but you don't want, at least by default, the behavior of just propagating
   exceptions.

To further this point, some libraries in Ada (like LAL but not only LAL) use
the pattern of exceptions being regular errors that can happen
(`Property_Error` in LAL for example). If such an error was raised in a
destructor, you'd want to catch that in order to refactor the code to not call
this code in the destructor if possible, or to catch the possible exception, in
order to avoid resources leaks.

2. **However**, in many production scenarios where you want to have resilient
   applications (The Rust thread cites web server. With the LAL example above,
   IDEs come to mind. In Ada in general, early abort scenarios can make us
   think of the Arianne scenario) having such an error crash your program is a
   bad idea, because it's too drastic. In those cases you want to continue even
   though you had an exception in a finalizer and might risk leaking some
   resources.

Other options that were discussed and considered:

* Make it erroneous to raise an exception from a `No_Raise` subprogram, and do
  nothing special in GNAT: an exception is raised, which may or not terminate
  immediately the execution depending on the runtime.

* Make it abort the program, like in C++ or in some Rust configurations. For
  the reasons above about resilent applications, making this the only available
  behavior seems non-desirable.

Drawbacks
=========

TBD.

Prior art
=========

TBD

Unresolved questions
====================

Finalized components with `Relaxed_Finalization => False`, in finalized records
with `Relaxed_Finalization => True` will have the old behavior defined in ARM
7.6.1 14/1. This is not a problem because a `Program_Error` will be propagated
out of them.

However we might want to emit a compiler warning for those cases, because
having legacy components with `Relaxed_Finalization => False` negates all the
benefits of the relaxed model.

Future possibilities
====================

Very probably, we want to add a `pragma Relaxed_Finalization_Everywhere` or
something that allows to change the mode for `Ada.Finalization.Controlled`, and
use this is constrained runtimes at the very least, or even make it the default
everywhere eventually, at least in `-gnatX`.
