- Feature Name: simpler_accessibility
- Start Date: 2020-06-15
- RFC PR: [#47](https://github.com/AdaCore/ada-spark-rfcs/pull/47)
- RFC Issue: (leave this empty)

Summary
=======

Over the years, the rules that govern accessibility in Ada, that is, what
operations on pointers are allowed, have grown to a point where they are
understood neither by implementers nor by users. We propose a simpler set of
rules that are mostly compatible with the current rules.

Motivation
==========

We'd like to restore a common understanding of accessibility rules for
implementers and users alike. The new rules should both be effective at
preventing errors and feel natural in Ada.

Guide-level explanation
=======================

The complexity of the rules that govern accessibility in Ada rest entirely on
the use of anonymous access types. These were [originally introduced in Ada
95](https://www.adaic.org/resources/add_content/standards/95rat/rat95html/rat95-p2-3.html#7)
for access parameters and access discriminants, then [liberally introduced
everywhere else in Ada
2005](https://www.adaic.org/resources/add_content/standards/05rat/html/Rat-3-3.html),
and [Ada 2012 further refined the
rules](http://www.ada-auth.org/standards/12rat/html/Rat12-6-4.html) to avoid
seemingly unexplainable accessibility check failures.

We propose to avoid completely the need for run-time accessibility checks,
which are:

1. difficult to implement, leading to subtle bugs in the compiler; and

2. difficult to understand, leading users to refrain from using anonymous
   access types for fear of possible rule violations.

We propose to distinguish three different uses of anonymous access types.

Standalone objects and parameters
---------------------------------

This concerns standalone objects, whether constants or variables:

```ada
Var        : access T := ...
Var_To_Cst : access constant T := ...
Cst        : constant access T := ...
Cst_To_Cst : constant access constant T := ...
```

and so-called _access parameters_, both of access-to-variable type and
access-to-constant type:

```ada
procedure P (V : access T; X : access constant T);
```

We propose to define their accessibility level to be infinite. This allows to
convert freely from a value of a named access type to such an anonymous type
(as the rule only allows going to a higher accessibility level corresponding to
a more nested scope, in order to avoid creating dangling pointers), but any
conversion in the other direction won't be allowed. If a user wants to do that
anyway, she will need to use attribute `Unchecked_Access` on the dereference of
the object (which requires the object not to be null):

```ada
type T_Ptr is access T;
Anon  : access T := ...
Named : T_Ptr := Anon.all'Unchecked_Access;
```

This is compatible with the [use of anonymous access types in
SPARK](http://docs.adacore.com/spark2014-docs/html/lrm/declarations-and-types.html#access-types).

Components and function results
-------------------------------

This concerns components of composite types (record and arrays):

```ada
type Rec is record
   Comp : access T;
end record;

type Arr is array (Index) of access T;
```

and function results:

```ada
function Get (X : Rec) return access T;
```

We propose to define their accessibility level to be the same as the one of
their designated type. Thus, such uses of anonymous types `access T` would be
equivalent to using a named access type defined at the same scope as the
designated type `T`.

This choice allows to convert freely from a value of such an anonymous type to
a named access type, which will necessarily be defined in the same or a nested
scope to have visibility over the designated type `T` (as the rule only allows
going to a higher accessibility level corresponding to a more nested scope),
but any conversion in the other direction won't be allowed. If a user wants to
do that anyway, she will need to use attribute `Unchecked_Access` on the
dereference of the object (which requires the object not to be null):

```ada
type T_Ptr is access T;

type Rec is record
   Comp : access T;
end record;

Named : T_Ptr := ...
R     : Rec;

R.Comp := Named.all'Unchecked_Access;
```

This is also compatible with the [use of anonymous access types in
SPARK](http://docs.adacore.com/spark2014-docs/html/lrm/declarations-and-types.html#access-types),
in particular because components of anonymous access type are currently not
allowed in SPARK. The new rules should make it possible to support such
components in SPARK, with in particular the benefit of allowing use of `access
Cell` during the definition of `Cell`:

```ada
type Cell is record
   Data : T;
   Next : access Cell;
end record;
```

Discriminants and allocators
----------------------------

Access discriminants were introduced in Ada 95 as a way to tie accessibility
levels to the scope where the object is declared, in order to allow code that
would be otherwise illegal. A special form of access discriminants called
coextensions was also introduced as a limited form of ownership. We propose to
abandon this complex kind of accessibility level and early form of ownership to
provide a simpler basis on which to provide more complete ownership for Ada in
the future.

Uses of access discriminants can be replaced by corresponding components. In
some cases where the Ada type system could check the absence of accessibility
rule violations thanks to the use of access discriminants, the user may now
have to use attribute `Unchecked_Access` [as mentioned
above](#components-and-function-results).

We also propose to forbid allocators of anonymous access types (the use of
`new` within an expression of an anonymous access type), whose main use case is
precisely to support access discriminants.

This has the nice side-effect of eliminating the notion of coextensions (the
use of an allocator of anonymous access type as the value of the discriminant
in an object declaration), which was proposed in Ada 2005 and never implemented
in any Ada compiler.

This is also compatible with the [use of anonymous access types in
SPARK](http://docs.adacore.com/spark2014-docs/html/lrm/declarations-and-types.html#access-types),
in particular because discriminants of anonymous access type are not allowed in
SPARK.

Reference-level explanation
===========================

Mostly TBD.

Ada 2012 introduced the notion of _master of the call_ to tie the accessibility
level of a function result to the scope where the object is returned to. This
was a solution to a problem with anonymous access function results and
overriding a dispatching function when the type extension is declared in a more
nested scope. As we plan on reverting this solution, we will need to adopt some
restrictions to detect the problematic cases. Such solutions were already
discussed as part of Ada 2012 design.

Another corner-case issue to deal with is the "dangling type" problem with
functions that have class-wide result types, to avoid returning a value of a
type defined in a nested scope to an object in an enclosing scope.

Rationale and alternatives
==========================

Many designs have been considered regarding accessibility in Ada. We feel that
the rules have gone too far in the direction of trying to provide safety at all
costs, with an opposite result in practice.

This design has the advantage of being easily explained in terms of the static
accessibility rules that govern operations on named access types, and to
require no run-time checking at all.

Drawbacks
=========

The drawback of adopting these new rules is that a user may need to use
attribute `Unchecked_Access` where she needed not to previously. In such cases,
the user is responsible for ensuring memory safety of the corresponding
accesses.

We are moving to a simpler, easier to understand model that is also more
restrictive and conservative. If the user needs to do things that the current
language allows and this new model does not, then the burden will be on the
user to avoid dangling reference problems. We are moving away from (complex,
hard-to-implement) safety guarantees that are provided by the language in favor
of leaving the user on their own with respect to safety in some common cases.

Prior art
=========

See the [rationales for Ada 95, Ada 2005 and Ada 2012 provided
earlier](#guide-level-explanation).

Unresolved questions
====================

It remains to be seen how much the new rules impact existing code, and what
automated migration tooling can be proposed.

Several of the choices above could be simplified further, by rejecting some
uses of anonymous access types, for example for standalone objects or function
results.

For [components and function results](#components-and-function-results), we
proposed to to define their accessibility level to be the same as the one of
their designated type. Another possible choice is to define their accessibility
level to be the same as the one of their enclosing declaration. The two both
share the property that they are equivalent to a named access type, but they
differ with respect to the level at which that equivalent named access type is
declared. If we discover problems with one (e.g., in the case where the
designated type is a generic formal type), we may want to consider the other
one.  So the "enclosing declaration level" scheme is available as a fall-back
if we run into trouble with the "designated type level" approach.

Future possibilities
====================

A natural next step is to look at the topic of accessibility in Ada and how
dynamic memory management strategies could be supported by the language or
libraries, in particular RAII, reference counting and ownership.
