- Feature Name: local_volatile_for_security_in_SPARK
- Start Date: 2019-05-07
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

Volatile variables in SPARK are interpreted as interfaces to the world external
to the SPARK program, typically the physical world. This forces volatile data
to be defined at library-level, so that effects through these variables can be
named after the names of these variable in Global/Depends contracts.

This is not the only use of volatile variables in Ada. A common use of volatile
data is to prevent optimizations, in order to implement defense against fault
injection attacks. For example:

   Cond : Boolean with Volatile;

   if not Cond then
      return;
   end if;

   if not Cond then
      return;
   end if;

   if Cond then
      --  here do some critical work
   end if;

In the code above, variable Cond is tested three times in a row. If the
variable is not marked as volatile, the three tests will be optimized into one
by the compiler, which defeats the protection against fault injection.

We propose to allow volatile data in SPARK for the use of preventing compiler
optimizations. Such data should be seen as non-volatile by the analyzer. The
proposed way to identify such volatile variables is through a dedicated aspect
No_Caching, similar to the existing four volatility properties defined in SPARK
for a variable (Async_Readers, Async_Writers, Effective_Reads and
Effective_Writes). The example above would read:

   Cond : Boolean with Volatile, No_Caching;

Motivation
==========

It is currently not possible in SPARK to declare local volatile data. While it
is possible in theory to work around this limitation by defining global
volatile data, this is both cumbersome, and inappropriate in most cases when
the data might be security-sensitive so that we want to limit its lifetime to
the duration of the call. In addition, the use of volatile data for preventing
optimization means that such data should ideally be treated as non-volatile
during analysis, which is not the case with current volatile data in SPARK
meant for interfaces.

This justifies the introduction of a new interpretation of volatile variables
as non-intentionally volatile, when a special volatility property is set.

Guide-level explanation
=======================

Volatile variables in SPARK can be specified with five additional properties:
Async_Readers, Async_Writers, Effective_Reads, Effective_Writes and No_Caching.
Property No_Caching can only be True when all other four properties are False,
corresponding to a use of volatility only for preventing compiler optimization,
and so the variable can be analyzed as if it was not volatile.

If none of these properties is explicitly specified on a variable, their
default is False for No_Caching and True for the other four.  This corresponds
to the common use of global volatile variables for interfaces (usually by
defining the address of the variable through an address clause or aspect).

Reference-level explanation
===========================

SPARK Reference Manual section 7.1.2 "External State" should be updated as
follows.

The definition of an "effectively volatile object" should be updated as
follows:

"An effectively volatile object is a volatile object for which at least one of
the four properties Async_Readers, Async_Writers, Effective_Reads and
Effective_Writes is True, or an object of an effectively volatile type."

After the presentation of the four properties of external states, there should
an addition:

"A fifth property No_Caching can be specified on a volatile object that is not
effectively volatile, to express that such a variable can be analyzed as not
volatile in SPARK, but that the compiler should not cache its value between
accesses to the object (e.g. as a defense against fault injection)."

The Legality Rules should be updated as follows:

- Legality rule 1 should say: "If an external state is declared without any of
  the external properties specified then all of the external properties [except
  No_Caching] default to a value of True."

- Legality rule 6 should add that the combination with all external properties
  valued False and No_Caching valued True is valid. Also, a value of False for
  No_Caching should be added to all the existing combinations.

Rationale and alternatives
==========================

We discussed using a value of False for all external volatility properties
instead of adding a new property. This has the disadvantage that it's not
immediately clear that this use is only for preventing compiler optimizations.

We discussed looking at the presence or absence of an address clause/aspect to
decide whether a volatile variable is meant for interfaces (address is
specified) or for preventing optimizations only (no address specified). This
has the disadvantage that it would introduce an effect from one aspect on the
interpretation of another. Plus it would not allow having library-level
variables for specifying interfaces if their address is not specified.

We discussed adding an aspect/pragma replacing Volatile for such uses. The
compiler would need to treat it as a synonym for Volatile. The disadvantage of
this approach is that it requires changes in the compiler in addition to
changes in the analyzer.

Until a solution is found for specifying this use of volatile variables, SPARK
users have no choice but to exclude parts of the code from SPARK analysis.

As this interpretation of volatile variables builds on the existing definition
of volatility properties, and simply assigns a meaning to a combination
previously illegal (all properties set to False) and clearly identified through
an additional property, it is fully backwards compatible, and rather minimal in
terms of language evolution.

Various names were discussed for the new property: No_Optimization, No_Caching,
Memory_Resident.

Drawbacks
=========

There are no major drawbacks of the general feature.

Prior art
=========

We don't know of prior work in the modelling of volatile variables for
analysis.

Unresolved questions
====================

None

Future possibilities
====================

This is a rather small feature, building on the extensive modelling of external
state as currently defined in SPARK. There are no planned extensions of that
model for now.
