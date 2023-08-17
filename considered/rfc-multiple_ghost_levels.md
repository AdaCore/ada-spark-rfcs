- Feature Name: (fill me in with a unique ident, my_awesome_feature)
- Start Date: (fill me in with today's date, YYYY-MM-DD)
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

This proposal introduces two concepts:

- A new pragma Assertion_Level which allows to name a specific assertion level
  and its dependencies.
- An extension for the syntax of all assertions (preconditions,
  postconditions, assertions...) that allows to designate assertions
  as being related to a specific level.

Tools such as compilers, provers or static analysers will be able to be
configured to enable or not certain assertion levels.

Motivation
==========

When using programming by contract extensively, it is often necessary to
classify assertion for different purposes, and have this classification
impacting run-time code generation. A very common case is to differenciate
assertions that can be activated at run-time and generate tests from assertions
code that cannot be possibly compiled (because it's too slow, needs too much
memory or references entities that have no body) but is nonetheless useful
for the purpose of proof.

Guide-level explanation
=======================

Multiple Ghost scopes
---------------------

A new pragma is introduced, ``Assertion_Level``, which takes an identifier as
parameter. It can be used to defined custom assertion levels, for example:

```Ada
package Some_Package is
   pragma Assertion_Level (Silver);
   pragma Assertion_Level (Gold);
   pragma Assertion_Level (Platinium);
end Some_Package;
```

The pragma `Assertion_Level` needs to be used at library level in a package
specification.

New identifiers are introduced in the package Standard, defined as follows:

```Ada
package Standard is
   [...]

   pragma Assertion_Level (Default);
   pragma Assertion_Level (Runtime);
   pragma Assertion_Level (Static);

   [...]
end Ada.Ghost;
```

The Default assertion level is the one used in the absence of specific
parametrization of assertions. Code marked "Runtime" should always be
executed under all compiler settings. Code marked "Static" should never
be executed under any compiler setting.

Assertion levels are scoped like regular variables. They can be prefixed by
their containing package. They need to be declared at the library level.

Levels on Assertions
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

```Ada
procedure Sort (A : in out Some_Array)
   with Contract_Case =>
      (Gold      =>
          (Something      => (if A'Length > 0 then A (A'First) <= A (A'Last))
           Something_Else => Bla),
       Platinium => (for all I in A'First .. A'Last -1 =>
                     A (I) <= A (I-1)));
```

A given assertion can be provided for multiple assertion levels, for example:

```Ada
pragma Assert ([Gold, Platinium] => X > 5);
```

Levels on Entities
------------------

Entities can be associated with specific level of assertions. When that's the
case, the level is given as a parameter of the Ghost argument. A given entity
can be associated with more than one ghost scope. For example:

```Ada
V : Integer with Ghost => Platinium;

procedure Lemma with Ghost => [Static, Platinium];
```

Dependencies between assertion levels
-------------------------------------

When declaring assertion levels, you can describe dependencies, in other word,
what data can flow from one level of assertion to the other. This dependency is
unidirectional. For example:

```Ada
pragma Assertion_Level (Silver);
pragma Assertion_Level (Gold, Depends => [Silver]);
```

The above means that Gold assertions may depend on Silver, but the reverse is
not true.

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

By default, all assertions levels depends on `Runtime` level, and
`Static` level depends on all assertions levels that doesn't
explicitely or transitively depend on it (there are no circularities). The
following is valid:

```Ada
pragma Assertion_Level (Silver);
pragma Assertion_Level (Gold, Depends => [Silver]);
pragma Assertion_Level (Platinum, Depends => [Silver, Gold]);

X1 : Integer with Ghost => Platinum;
X2 : Integer := X1 with Ghost => Static;
```

User can create ghost levels that can never be compiled by introducing a
dependency on `Static`:

```Ada
pragma Assertion_Level (Silver_Static, Depends => [Static]);
```

Activating / Deactivating Assertions
------------------------------------

Specific assertions code can be activated / deactivated through an extension of
the Assertion_Policy pragma:

```Ada
pragma Assertion_Policy (Gold => Check, Platinium => Ignore);
```

Compiler options may also have an impact on the default policies.

Note that activating or deactivating assertion levels have an impact on dependent
ghost scopes as follows:
- Deactivating one assertion level will deactivate all assertion levels that are
  allowed to depend on it.
- Activating one assertion level will activate all ghost scopes that it depends
  on.

Reference-level explanation
===========================

See above

Rationale and alternatives
==========================

TBD

Drawbacks
=========

TBD

Prior art
=========

TBD

Unresolved questions
====================

TBD

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

