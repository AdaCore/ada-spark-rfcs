- Feature Name: multiple_levels_of_assertions
- Start Date: 2024-06-03
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

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
impacting run-time code generation. A very common case is to differenciate
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
------------------------------------

Specific assertions code can be activated/deactivated through an extension of
the ``Assertion_Policy`` pragma:

```Ada
pragma Assertion_Policy (Gold => Check, Platinium => Ignore);
```

Compiler options may also have an impact on the default policies.

Note that activating or deactivating assertion levels have an impact on dependent
assertion levels as follows:
- Deactivating one assertion level will deactivate all assertion levels that are
  allowed to depend on it.
- Activating one assertion level will activate all ghost scopes that it depends
  on.

Effects of multiple pragmas ``Assertion_Policy``, or multiple associations in
the same pragma ``Assertion_Policy``, are taken into account in order. So the
following deactivates preconditions, except for those at the ``Gold`` assertion
level, as all assertions and ghost entities at the ``Gold`` level are activated:

```Ada
pragma Assertion_Policy (Pre => Ignore);
pragma Assertion_Policy (Gold => Check);
```

and similarly for:

```Ada
pragma Assertion_Policy (Pre => Ignore, Gold => Check);
```

while the following activates all assertions and ghost entities at the ``Gold``
level, except for preconditions, as all preconditions are deactivated:

```Ada
pragma Assertion_Policy (Gold => Check);
pragma Assertion_Policy (Pre => Ignore);
```

and similarly for:

```Ada
pragma Assertion_Policy (Gold => Check, Pre => Ignore);
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

> If the assertion policy applicable to the declaration of a Ghost entity is Ignore, and this ghost entity occurs within an assertion expression, then the assertion policy which governs the assertion expression shall [also] be Ignore. Note that the assertion policy applicable to the declaration of a Ghost entity may be associated either with an assertion level, if the entity has an associated assertion level, or with the Ghost assertion kind otherwise. The assertion level which governs the assertion expression may also be associated either with an assertion level, if the assertion has an associated assertion level, or with an assertion kind otherwise (e.g., Pre for a precondition expression, Assert for the argument of an Assert pragma).

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

