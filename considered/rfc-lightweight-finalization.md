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
 
*note: we employ the term "finalization" throughout this RFC to denote control over the whole lifetime of an object, i.e. the same level of control that controlled objects procur today.

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
 - `Finalize` is called when an object of type `T` goes out of scope (for stack-allocated objects) or is explicitly deallocated (for heap-allocated objects).

### Examples

A simple implementation of shared pointers:

```ada
type T is record
   Value : Integer;
   Ref_Count : Natural := 0;
end record;

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
type File is limited ...
   with Finalize => Close;
```

### Heap-allocated finalized types

As already mentioned, today's controlled objects allocated on the heap through an access type T must be finalized when T goes out of scope. First of all, we propose to completely drop this guarantee for libary-level access types, meaning program termination will not require finalization of heap-allocated types. The rationale for this is that in most cases, finalization is used to reclaim memory or release resources, which the underlying system (if any) generally does regardless upon program termination. As for embedded systems, heap allocation is generally not available or restricted enough that this shouldn't have any impact.

As for nested access-to-finalized types, there are at least two simple ways to reason about them:
 - Don't do anything when such an access type goes out of scope.
 - Forbid such access types for now, until we have enough tools (such as an ownership system) to ensure that objects allocated through those access types are properly free'd (and therefore their finalize procedures properly called).

### Finalized tagged types

There are several ways to handle finalization of tagged types. The easiest one is to disallow those aspects on tagged types, and resort to controlled-types for those. In that case however, the difference in semantics w.r.t heap-allocated finalized types should be addressed.

The preferred option would be to support tagged types from scratch, where aspects are inherited by derived types and optionally overriden by those. Calls to the user-defined operations should then be dispatching whenever it makes sense.

### Finalized type components

TBD.

### Interoperability with controlled types

TBD.

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
