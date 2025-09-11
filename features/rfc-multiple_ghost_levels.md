- Feature Name: multiple_levels_of_assertions
- Start Date: 2024-06-03
- Status: Production

Summary
=======

This proposal introduces the concept of ``level of assertion``, introduced by a
new pragma. Assertions and ghost declarations can be associated with a
previously declared level. Only assertions and ghost code associated with
an active level are compiled into executable code.

In more details:

- A new pragma ``Assertion_Level`` allows the definition of a specific assertion
  level and its dependencies.
- Pragma ``Assertion_Policy`` is extended so that a level of assertion can
  be associated with a policy (either the standard ones ``Check`` and ``Ignore``
  or GNAT-specific ones).
- Most assertions (with the exception of ``Contract_Cases``) are extended so
  that a level can be associated with them.
- The ``Ghost`` aspect on ghost declarations is extended to allow specifying
  a level for the declaration.

The specification of levels should have no impact on static analysis or proof.

Motivation
==========

When using programming by contract extensively, it is often necessary to
classify assertions for different purposes, and have this classification
impacting run-time code generation. A very common case is to differentiate
assertions that can be activated at run-time from assertions used to generate
tests but cannot be possibly compiled (because it's too slow or needs too much
memory) and from assertion used for proof (for the reasons just given, or
because these assertions reference entities that have no body).

Guide-level explanation
=======================

Assertion levels
----------------

A new pragma is introduced, ``Assertion_Level``, which takes an identifier as
a parameter. It can be used to define custom assertion levels, for example:

```Ada
package Some_Package is
   pragma Assertion_Level (Silver);
   pragma Assertion_Level (Gold);
   pragma Assertion_Level (Platinium);
end Some_Package;
```

The pragma ``Assertion_Level`` needs to be used at library level in a package
specification.

New identifiers are introduced in the package Standard, defined as follows:

```Ada
package Standard is
   [...]

   pragma Assertion_Level (Runtime);
   pragma Assertion_Level (Static);

   [...]
end Standard;
```

Code marked "Runtime" should always be
executed under all compiler settings. Code marked "Static" should never
be executed under any compiler setting.

Assertion levels are scoped like regular names. They can be prefixed by
their containing package. They need to be declared at the library level.

Levels on assertions
--------------------

Assertions can be associated with specific level using the Ada arrow
assocations. This can be used in pragma Assert, Assume, Loop_Invariant, e.g.:

```Ada
pragma Assert (Gold => X > 5);
```

or in aspects Pre, Post, Predicate, Invariant, e.g.:

```Ada
procedure Sort (A : in out Some_Array)
   with Post =>
      (Gold      => (if A'Length > 0 then A (A'First) <= A (A'Last)),
       Platinium => (for all I in A'First .. A'Last -1 =>
                     A (I) <= A (I-1)));
```

Levels on ghost declarations
----------------------------

Ghost declarations can be associated with a specific level of assertion. When that's the
case, the level is given as a parameter of the Ghost argument. For example:

```Ada
V : Integer with Ghost => Platinium;

procedure Lemma with Ghost => Static;
```

Dependencies between assertion levels
-------------------------------------

When declaring assertion levels, you can describe dependencies, in other words,
what data can flow from one level of assertion to the other. Such a dependency is
unidirectional. For example:

```Ada
pragma Assertion_Level (Silver);
pragma Assertion_Level (Gold, Depends => [Silver]);
```

The above means that the ``Gold`` assertions may depend on ``Silver``, but the
reverse is not true.

Dependencies are transitive, e.g. in:

```Ada
pragma Assertion_Level (Silver);
pragma Assertion_Level (Gold, Depends => [Silver]);
pragma Assertion_Level (Platinum, Depends => [Gold]);
```

is equivalent to:

```Ada
pragma Assertion_Level (Silver);
pragma Assertion_Level (Gold, Depends => [Silver]);
pragma Assertion_Level (Platinum, Depends => [Silver, Gold]);
```

By default, all assertions levels depend on the ``Runtime`` level, and
the ``Static`` level depends on all assertions levels that don't
explicitly or transitively depend on it (there are no circularities). The
following is valid:

```Ada
pragma Assertion_Level (Silver);
pragma Assertion_Level (Gold, Depends => [Silver]);
pragma Assertion_Level (Platinum, Depends => [Silver, Gold]);

X1 : Integer with Ghost => Platinum;
X2 : Integer := X1 with Ghost => Static;
```

The user can create assertion levels that can never be compiled into runtime code
by introducing a dependency on ``Static``:

```Ada
pragma Assertion_Level (Silver_Static, Depends => [Static]);
```

Activating/Deactivating Assertions
----------------------------------

Specific assertions code can be activated/deactivated through an extension of
the ``Assertion_Policy`` pragma:

```Ada
pragma Assertion_Policy (Silver => Check, Platinium => Ignore);
```

Compiler options may also have an impact on the default policies.

Note that activating or deactivating assertion levels have an impact on dependent
assertion levels as follows:
- Deactivating one assertion level will deactivate all assertion levels that are
  allowed to depend on it.
- Activating one assertion level will activate all all assertion levels that it
  depends on.

```Ada
pragma Assertion_Level (Silver);
pragma Assertion_Level (Gold, Depends => [Silver]);
pragma Assertion_Level (Platinum, Depends => [Silver, Gold]);

pragma Assertion_Policy (Platinum => Check);
--  Equivalent to indipendently applying:
--  Assertion_Policy (Silver   => Check);
--  Assertion_Policy (Gold     => Check);
--  Assertion_Policy (Platinum => Check);

pragma Assertion_Policy (Silver => Ignore);
--  Equivalent to indipendently applying:
--  Assertion_Policy (Silver   => Ignore);
--  Assertion_Policy (Gold     => Ignore);
--  Assertion_Policy (Platinum => Ignore);
```

Effects of multiple pragmas ``Assertion_Policy``, or multiple associations in
the same pragma ``Assertion_Policy``, are taken into account in order. So the
following deactivates preconditions, except for those at the ``Silver`` assertion
level, as all assertions and ghost entities at the ``Silver`` level are activated:

```Ada
pragma Assertion_Policy (Pre => Ignore);
pragma Assertion_Policy (Silver => Check);
```

and similarly for:

```Ada
pragma Assertion_Policy (Pre => Ignore, Silver => Check);
```

while the following activates all assertions and ghost entities at the ``Silver``
level, except for preconditions, as all preconditions are deactivated:

```Ada
pragma Assertion_Policy (Silver => Check);
pragma Assertion_Policy (Pre => Ignore);
```

and similarly for:

```Ada
pragma Assertion_Policy (Silver => Check, Pre => Ignore);
```

Reference-level explanation
===========================

We should decide if GNAT RM or SPARK RM should be updated, or both.

Rules for [pragma
Assertion_Policy](https://docs.adacore.com/live/wave/gnat_rm/html/gnat_rm/gnat_rm/implementation_defined_pragmas.html#pragma-assertion-policy)
should be amended to allow ``ASSERTION_LEVEL`` as another form of ``ASSERTION_KIND``.

Pragma ``Assertion_Level`` should be described in GNAT RM.

The rules for changing the grammar of all assertions should be added somewhere.

Rules for [Ghost
entities](https://docs.adacore.com/live/wave/spark2014/html/spark2014_rm/subprograms.html#ghost-entities)
should be amended to allow the new syntax with an assertion level.

In that section of SPARK RM, legality rule 20 should be amended as follows:

> If the assertion policy applicable to the declaration of a Ghost entity is Ignore, and this ghost entity occurs within an assertion expression, then the assertion policy which governs the assertion expression shall [also] be Ignore. Note that the assertion policy applicable to the declaration of a Ghost entity may be associated either with an assertion level or with the Ghost assertion kind. The assertion level which governs the assertion expression may also be associated either with an assertion level or with an assertion kind (e.g., Pre for a precondition expression, Assert for the argument of an Assert pragma).

That way, all existing rules are applicable with minimal changes to the new
model. Instead of Ghost governing all ghost entities, an assertion level might
govern some ghost entities. Instead of a given assertion kind (say Pre)
governing all corresponding assertions (say preconditions), an assertion level
might govern some of these assertions.

An additional rule which would make sense to complement the above rule 20 is
that, if both the assertion and the ghost entity are governed by an assertion
level, then it should be the same assertion level, or the assertion level of
the assertion should depend on the assertion level of the ghost entity.  So
assuming we have the following definition of assertion levels:

```Ada
pragma Assertion_Level (Silver);
pragma Assertion_Level (Gold, Depends => Silver);
```

then the following is valid:

```Ada
X : Boolean with Ghost => Silver;
pragma Assert (Silver => X);
pragma Assert (Gold => X);
```

but the following is illegal:

```Ada
X : Boolean with Ghost => Gold;
pragma Assert (Silver => X);
```

while the rule does not forbid the following case (which will be rejected by
the compiler if assertion policies ``Silver => Ignore, Assert => Check`` is
used):

```Ada
X : Boolean with Ghost => Silver;
pragma Assert (X);
```

much like today we don't forbid the following case (which will be rejected by
the compiler if assertion policies ``Ghost => Ignore, Assert => Check`` is
used):

```Ada
X : Boolean with Ghost;
pragma Assert (X);
```

Compatibility of Ghost Aspects
------------------------------

This feature opens up the possibility of having separate Assertion_Policy
control mechanisms for each Ghost entity. Meaning new rules need to be added or
the existing ones need to be amended to take those scenarios into account.

The most important aspect in those rules should be that we do not want Ignored
Ghost code to affect Checked ghost code. Meaning that we need to check that the
active Assertion_Policy for each Ghost entity is compatible.

Additionally we would like to guide the user to use dependencies between the
defined Assertion_Levels to ensure that the code is still valid and does not
have any side-effects if the policy for one Assertion_Level is changed.

In order for that we need to define the term compatibility for Ghost aspect.

Ghost aspect between entities A and B are **"compatible"** when:
- Both entities have a ghost aspect with an Assertion_Level and then the Ghost
pragma of A is compatible with B if:
   - the Assertion_Level of A is B or A depends on B
   - the Assertion_Level of B is Static or B depends on Static
- At least one entity has a Ghost aspect without an assertion level

Ghost aspects between entities A and B are **"strictly compatible"** when:
- Both entities have a ghost aspect with an Assertion_Level and then the Ghost
pragma of A is compatible with B if:
   - the Assertion_Level of A is B or A depends on B
   - the Assertion_Level of B is Static or B depends on Static
- A has a Ghost aspect without an Assertion_Level, B has a Ghost aspect with an
Assertion_Level, and the Assertion level of B is or depends on Static.
- Both entities have a Ghost aspect without an Assertion_Level.

The idea is that the compatibility between the Ghost aspects should also
guarantee that the active Assertion_Policies are compatible. In practice only
**strict compatibility** assures that. As it also prevents cases where Ghost
aspects without Assertion_Levels are mixed with Ghost aspects that have an
Assertion_Level. This means that each entity can indipendently enabled or
disabled.

However there are some legacy cases that might break existing code if
this policy was added everywhere. Thus in those scenarios we should just focus
on regular **compatibility**. Meaning we just check the compatibility when both
entities are using Assertion_Levels.

Declaration of Ghost Entities within Ghost Entitities
-----------------------------------------------------

We need to update Rule 2 in the SPARK RM to define what is the Ghost Aspect of
entities defined within other entities if not specified.

We also want to avoid scenarios where conflicting Assertion_Policies are used if
the Ghost aspect ofthe child entity is defined. We want to avoid scenarios where
there is an enabled Ghost entity within a Ghost entity that is disabled.

The following SPARK RM 6.9 (2) rule should state the following:

```
The Ghost aspect of an entity declared inside of a ghost entity (e.g., within the body of a ghost subprogram) is defined to be the same Ghost aspect as the parent entity unless explicitly specified.

Otherwise an entity within a ghost entity already has a Ghost aspect then the Ghost aspect of the child entity should have a compatible Assertion_Policy applied to it. Meaning that if the Assertion_Policy for the package is Ignore then it cannot contain any entities that have an Assertion_Policy with Check inside it.

Additionally the specified Ghost aspect must be compatible with the Ghost aspect of the parent entity.

This check on Assertion_Levels compatibility should not be applied to generic instances within a package.

The Ghost aspect of an entity implicitly declared as part of the explicit declaration of a ghost entity (e.g., an implicitly declared subprogram associated with the declaration of a ghost type) is defined to be the same Ghost aspect as the parent type.

The Ghost aspect of a child of a ghost library unit is defined to have the same Ghost aspect unless explicitly specified. Otherwise the specified Ghost aspect of the child must be compatible with the ghost aspect of the ghost library unless the child package is a generic instance.
```

For this rule we are using regular compatibility of Ghost aspects should be
used.

Note that in practice it is impossible to assure that the Ghost aspects are
compatibile for generic instantiations.

A likely scenario is where a user defines a Ghost package with their own
Assertion_Level L1 and uses a container from the SPARK containers library which
is using an Assertion_Level defined in the SPARK library.
- Entities within the L1 package need to have either the L1 Assertion_Level or something that depends on
 L1
- The formal containers are using predefined Assertion_Levels and new dependencies cannot be added to it.


```Ada
--  We can only declare the following:
pragma Assertion_Level (L1, Depends => Silver);

--  The user cannot add dependencies to predefined labels
--  to satisfy the Assertion_Level compatibility.
--  pragma Assertion_Level (Silver , Depends => L1);

package Pack with Ghost => L1 is

   -- Will use Assertion_Level Silver defined is SPARK library
   package My_Maps is new SPARK.Containers.Formal.Hashed_Maps (...);

end Pack;
```


Modification of Ghost Variables
-------------------------------

Previously Rule 20 prevented the Ghost code from reaching assertions and Rule 15
prevented the change of Assertion_Policy for a ghost entity after its
declaration. Technically those two rules were enough for preventing checked
Ghost variables from being modified by ignored ghost entities. However since now
you can now control the Assertion_Policy for each ghost entity separately are
now able to do so legally according to the existing rules.

In order to deal with modification of Ghost variables the following rule should
be added under SPARK RM 6.9:

```
If the Assertion_Policy governing the declaration of a ghost variable is Check then its value cannot be modified by any ghost entity whose Assertion_Policy is Ignore.
```
Additionally it could state that
```
The Ghost aspect of the entity being modified should be compatible with the Ghost entity that is modifying it.
```

Modification of Ghost Variables by Ghost Procedures
---------------------------------------------------

In addition to checking what data is modifying a ghost variable there should be
a rule that states that enabled ghost variables should not be modified
(assigned to / called as an out parameter of a procedure) within disabled
ghost regions.

The following rule should be added to SPARK RM 6.9:

```
If the Assertion_Policy governing the declaration of a Ghost variable is Check then its value cannot be modified by a call to a Ghost procedure whose Assertion_Policy is Ignore.
```
Additionally it could state:
```
The Ghost aspect of the entity being modified should be strictly compatible with the Ghost procedure that is modifying it.
```

Here are some example scenarios.

Illegal unless L2 depends on L1:

```Ada
procedure Incr (X : in out Integer) with Ghost => L1;

procedure Incr_Or_Not (X : in out Integer) with Ghost => L2 is
begin
  Incr (X);
end Incr_Or_Not
```

Also illegal (Unless L2 depends on Static):

```Ada
procedure Incr (X : in out Integer) with Ghost;

procedure Incr_Or_Not (X : in out Integer) with Ghost => L2 is
begin
  Incr (X); -- Error
end Incr_Or_Not;
```

Also illegal

```Ada
procedure Incr (X : in out Integer) with Ghost => L1;

procedure Incr_Or_Not (X : in out Integer) with Ghost is
begin
  Incr (X);  -- Error
end Incr_Or_Not;
```


Modification of Global Ghost variables within Ghost regions
-----------------------------------------------------------
Additionally care should be taken when a checked global Ghost variable are assigned
within a Ghost region that is ignored.


The following rule should be added to SPARK RM 6.9:
```
If the Assertion_Policy governing the declaration of a ghost variable is Check then its value cannot be modified in a ghost region where the active Assertion_Policy is Ignore.
```
Additionally it could state that
```
The Ghost aspect of the region modifying a Ghost variable should be strictly compatible with the Ghost aspect of the Ghost variable that it is modifying.
```

Consider the following example where an L2 ghost variable is modified within an
L1 function then the behaviour can change depending if L1 is enabled or not if
it is not dependent on L2.

```Ada
X : Integer := 0 with Ghost => L2;

procedure Incr with Ghost => L1 is
begin
   X := X + 1;  --  Error
end Incr;

procedure Foo with Ghost => L2 is
begin
   Incr;
   pragma Assert (X > 0);
end Foo;
```
The above example would be fine if L1 depends on L2.

Rationale and alternatives
==========================

Assertion levels can be approached today with a combination of static
configuration to define the assertion levels, and if-expressions inside
assertions. So to have the effect of:

```Ada
pragma Assertion_Level (Silver);
pragma Assertion_Level (Gold, Depends => [Silver]);
pragma Assertion_Policy (Gold => Ignore, Silver => Check);
pragma Assert (Gold => X > 5, Silver => X > 0);
```

one can write:

```Ada
Silver : constant Boolean := True;
Gold : constant Boolean := False;
pragma Assert ((if Gold then X > 5) and then (if Silver then X > 0));
```

But this does not allow selectively including ghost declarations, unless one
uses preprocessing.

This also does not perform any checking that an assertion at ``Gold`` level
cannot reference ``Silver``-level ghost entities, contrary to the current
proposal.

Drawbacks
=========

This proposal adds a lot of complexity to the syntax of all assertions and
ghost declarations, which will need to be supported in many tools for that
feature to be usable.

Prior art
=========

JML (for Java) and ACSL (for C) contain features that resemble assertion
levels in that they allow separated specifications of intended functionality,
but the levels cannot be separately selected when compiling the code.

While it was envisioned at some previous point, in [its latest
version](https://isocpp.org/files/papers/P2900R6.pdf), the proposed contracts
for C++26 do not include the ability to assign an assertion level to a contract
assertion

Unresolved questions
====================

The [Ghost
aspect](https://docs.adacore.com/live/wave/spark2014/html/spark2014_rm/subprograms.html#ghost-entities)
is currectly defined as a Boolean-valued representation aspect. This is
incompatible with its use above to optionally specify an assertion level as in
``Ghost => Silver``, as ``Silver`` here could also be interpreted as a Boolean
value. A possibility is to instead use a new aspect to optionally specify an
assertion level, as in:

```Ada
V : Integer with Ghost, Assertion_Level => Platinium;
```

The syntax change proposed for assertions is quite unusual for Ada, as it
replaces a Boolean value by a choice between a Boolean value, and a non-empty
list of associations (which does not include the parentheses). While parsing it
should not be problematic, it remains to decide whether this is sufficiently in
line with the rest of the language.

Future possibilities
====================

We could envision to activate / deactivate ghost code across an entire call
graph, introducing a new pragma ``Deep_Assertion_Policy``. For example:

```Ada
   if Urgency = Low then
      pragma Deep_Assertion_Policy (Safety => Enabled, Performance => Disabled);
      Call_Something; -- all Safety is disabled here
   else
      pragma Deep_Assertion_Policy (Safety => Disabled, Performance => Enabled);
      Call_Something; -- all Safety is disabled here
   end if;

   -- Go to whatever state we had before the if.
```

Or through a different example:

```Ada
   begin
      pragma Deep_Assertion_Policy (Safety => Enabled);
      Call_Something; -- all Safety is disabled here at that level and below
   exception when others =>
      pragma Deep_Assertion_Policy (Safety => Disabled);
      Log_Safey_Error;
      Call_Something; -- try again without safety, but then treat the result
      --  with caution
   end;

   -- Go to whatever state we had before the if.
```

This could help model various execution modes in a high integrity application,
allowing to implement degraded safety mode when needed. Knowning wether this
kind of advanced capabilty is valuable would require some industrial feedback.

