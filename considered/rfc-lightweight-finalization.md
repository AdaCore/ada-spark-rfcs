- Feature Name: lightweight-finalization
- Start Date: 2020-11-23
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

We introduce a new finalization mechanism that does not rely on tagged types, has simpler semantics and weaker guarantees than today's controlled types in such a way that:
 1. It imposes less design constraints to users.
 2. It can be supported on broader range of platforms (e.g. embedded).
 3. It allows for an efficient implementation.
 
*Note: we abuse the term "finalization" throughout this RFC to denote control over the whole lifetime of an object, i.e. the same level of control that controlled objects procur today.*

Motivation
==========

First of all, current finalization based on controlled objects forces users to turn their untagged type into a tagged type in order for it to benefit from finalization. Thus, new legality rules apply (e.g. RM 3.9.2) which can break existing code in many different ways. One such example is illustrated below:
```ada
type T is tagged null record;
type U is record;

function F (X : T) return U;
```
In this situation, one cannot simply turn `U` into a controlled object, otherwise the subprogram `F` would become a primitive of two tagged types, which is forbidden.

Second, the guarantees provided by controlled types are very strong, requiring a complex implementation and incurring a substential runtime performance penalty. On some platform, it is extremely difficult (impossible?) to write an implementation that fulfills all those guarantees. 

One such guarantee is that an access-to-controlled type should finalize all objects that have been **heap-allocated** through it once it goes out of scope (*todo: link to RM*). The compiler must therefore generate code to keep track of these objects, untrack them upon explicit deallocation, etc., which obviously induces a significant overhead at runtime.

For the record, GNAT already supports some custom aspects to weaken the default guarantees mandated by the Ada specification, such as `pragma No_Heap_Finalization` and `pragma Finalize_Storage_Only`.

Guide-level explanation
=======================

We propose to introduce three new Ada 2012 aspects, analogous to the three controlled-type primitives, as in the following template:
```ada
type T is ...
   with Initialize => <Initialize_Procedure>,
        Adjust     => <Adjust_Procedure>,
        Finalize   => <Finalize_Procedure>;
```

The three procedures have the same profile, taking a single `in out T` parameter.

We follow the same dynamic semantics as controlled objects:
 - `Initialize` is called when an object of type `T` is declared without default expression.
 - `Adjust` is called after an object of type `T` is assigned a new value.
 - `Finalize` is called when an object of type `T` goes out of scope (for stack-allocated objects) or is explicitly deallocated (for heap-allocated objects). It is also called when on the value being replaced in an assignment.

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

A simple file handle that ensures resources are properly released (Taken from a discussion in [this RFC](https://github.com/AdaCore/ada-spark-rfcs/pull/29#issuecomment-539025062))
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

### Heap-allocated finalized types

As already mentioned, today's controlled objects allocated on the heap through an access type T must be finalized when T goes out of scope. First of all, we propose to completely drop this guarantee for libary-level access types, meaning program termination will not require finalization of heap-allocated types. The rationale for this is that in most cases, finalization is used to reclaim memory or release resources, which the underlying system (if any) generally does regardless upon program termination. As for baremetal platforms, heap allocation is either not available/allowed (meaning this is a non-issue) and if it is, we assume that manual deallocation is required and therefore finalization will be properly executed.

As for nested access-to-finalized types, there are at least two simple ways to reason about them:
 - Don't do anything when such an access type goes out of scope: it is the responsibility of users to finalize their object, much like it is their responsibility to free the memory.
 - Forbid such access types for now, until we have enough tools (such as an ownership system) to ensure that objects allocated through those access types are properly free'd (and therefore their finalize procedures properly called).

### Finalized tagged types

We propose that aspects are inherited by derived types and optionally overriden by those. The compiler-generated calls to the user-defined operations should then be dispatching whenever it makes sense, i.e. the object in question is of classwide type and the class includes at least one finalized-type.

### Composite types

When a finalized type is used as a component of a composite type, the latter should become finalized as well. The three primitives are derived automatically in order to call the primitives of their components. If that composite type was already user-finalized, we propose that the compiler calls the primitives of the components so as to stay consistent with today's controlled types's behavior. So, `Initialize` and `Adjust` are called on components before they are called on the composite object, but `Finalize` is  called on the composite object first. This is the easiest approach as it avoids confusing users and its semantics are already battle-tested, but could still be revised.

### Interoperability with controlled types

In order to simplify implementation, we propose to initially forbid any of these new aspects on a controlled-type, components of a controlled type, composite types of which any part is controlled and interfaces which are derived by a controlled type.

### Constant objects with finalization

The profile suggested above for the three primitives takes an `in out` parameter. How should we handle constant objects of a finalized type?

First, note that `Initialize` is out of the equation since constant object require explicit initialization. `Adjust` is also out because constant objects obviously cannot be reassigned to. We are therefore left with `Finalize`. We could either take the same approach as controlled-types and let the parameter be `in out`, or we could introduce a new aspect `Finalize_Constant` that is called in-place of `Finalize`, which takes an `in` parameter instead. In this scenario, we suggest a warning could be emitted if a type specifies `Finalize` but does not specify `Finalize_Constant` and a constant object of that type is declared.

Reference-level explanation
===========================

TBD.

Rationale and alternatives
==========================

TBD.

Drawbacks
=========

Since this partly overlaps with controlled-types, new users could get a bit lost.

Prior art
=========

TBD. Talk about RAII in languages such as C++.

Unresolved questions
====================

TBD.

Future possibilities
====================

TBD.
