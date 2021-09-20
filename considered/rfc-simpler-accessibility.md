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

Deployment of alternative model
-------------------------------

The use of a restriction (e.g. "No_Dynamic_Accessibility_Checks") to employ the
proposed alternate accessibility model would both avoid the use of compiler
flags and communicate to those viewing source files that different rules are in
effect.

Standalone objects
------------------

```ada
Var        : access T := ...
Var_To_Cst : access constant T := ...
Cst        : constant access T := ...
Cst_To_Cst : constant access constant T := ...
```

We propose to define the accessibility levels of standalone objects of anonymous
access type (whether constants or variables) to be that of the level of their
object declaration. This has the feature of allowing many common use-cases 
without the employment of `Unchecked_Access` while still removing the need
for dynamic checks.

The most major benefit of this change would be compatibility with standard Ada rules.

For example, the following would be legal:

```ada
type T is null record;
type T_Ptr is access all T;
Anon  : access T := ...
Named : T_Ptr := Anon; -- Allowed
```

This is compatible with the [use of anonymous access types in
SPARK]. (http://docs.adacore.com/spark2014-docs/html/lrm/declarations-and-types.html#access-types).

Subprogram parameters
---------------------

```ada
procedure P (V : access T; X : access constant T);
```

We propose the following in terms of subprogram parameters:

When the type of a formal parameter is of anonymous access then, from the caller's perspective,
its level is seen to be at least as deep as that of the type of the corresponding actual
parameter (whatever that actual parameter might be) - meaning any actual can be used
for an anonymous access parameter without the use of 'Unchecked_Access.

```ada
declare
   procedure Foo (Param : access Integer) is ...
   X : aliased Integer;
begin
   Foo (X'Access); -- Allowed
   Foo (X'Unchecked_Access); -- Not necessary
end;
```

From the callee's perspective, the level of parameters and local variables of the callee would
be statically deeper than the level of anonymous access formal parameters - allowing locals of
the subprogram to be assigned local parameters, but not vice versa.

```ada
procedure P (V : access T; X : access constant T) is
   Local     : aliased T;
   Local_Ptr : access T;
begin
   V := Local'Access; -- Not allowed
   Local_Ptr := V; -- Allowed
end;
```

Function results
----------------

```ada
function Get (X : Rec) return access T;
```

We propose making anonymous access function result types have the level of the
innermost "master" of their enclosing function call in order to support the "identity"
function use-case while still allowing any actual parameter to be passed for an anonymous
access type formal.

For example:

```ada
declare
   type T is record
      Comp : aliased Integer;
   end record;
   function Identity (Param : access Integer) return access Integer is
   begin
      return Param; -- Legal
   end;
   X : access Integer;
begin
   X := Identity (X); -- Illegal
   X := Identity (X).all'Unchecked_Access; -- Legal
end;
```
  
In order to prevent upward conversions of anonymous function results (like below), we
also would need to assure that the level of such a result (from the callee's perspective)
is statically deeper:

```ada
declare
   type Ref is access all Integer;
   Ptr : Ref;
   function Foo (Param : access Integer) return access Integer is
   begin
       return Result : access Integer := Param; do
          Ptr := Ref (Result); -- Illegal
       end return;
   end;
begin
   declare
      Local : aliased Integer;
   begin
      Foo (Local'Access).all := 123;
   end;
end;
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

Any access discriminant will have the equivalent level of the its corresponding
discriminated typed - along with allocators of anonymous access types (the use of
`new` within an expression of an anonymous access type), whose main use case is
precisely to support access discriminants.

This has the nice side-effect of eliminating the notion of coextensions (the
use of an allocator of anonymous access type as the value of the discriminant
in an object declaration), which was proposed in Ada 2005 and not implemented
currently within GNAT.

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

Also, the two models (the Ada model and the proposed model), will have to be
able to co-exist since the proposed model is fundamentally incompatible on
many levels.

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

Future possibilities
====================

A natural next step is to look at the topic of accessibility in Ada and how
dynamic memory management strategies could be supported by the language or
libraries, in particular RAII, reference counting and ownership.
