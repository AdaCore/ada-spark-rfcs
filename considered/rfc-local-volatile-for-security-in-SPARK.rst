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
proposed way to identify such volatile variables is when the four volatility
properties defined in SPARK for a variable (Async_Readers, Async_Writers,
Effective_Reads and Effective_Writes) are False.

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
as non-intentionally volatile, when the four volatility properties are False.
This should be the default for local volatile variables.

Guide-level explanation
=======================

Volatile variables in SPARK can be specified with four additional properties:
Async_Readers, Async_Writers, Effective_Reads and Effective_Writes. Setting all
four properties to False means that this use of volatility is only for
preventing compiler optimization, and so the variable can be analyzed as if it
was not volatile.

If none of these properties is explicitly specified on a library-level
variable, their default is True. This corresponds to the common use of global
volatile variables for interfaces (usually by defining the address of the
variable through an address clause or aspect).

If none of these properties is explicitly specified on a local variable, their
default is False. This corresponds to the common use of local volatile
variables for preventing optimizations.

It should be illegal to specify the address of a volatile variable with all
four volatility properties set to False. This avoids interpreting it as
non-volatile in the analyzer while it is in fact used for interfaces.

Reference-level explanation
===========================

SPARK Reference Manual section 7.1.2 "External State" should be updated as
follows:

The definition of an "effectively volatile object" should be updated as
follows:

"An effectively volatile object is a volatile object or an object of an
effectively volatile type, for which at least one of the four properties
Async_Readers, Async_Writers, Effective_Reads and Effective_Writes is True."

The definition of external state should be updated as follows:

"External state is an effectively volatile library-level object or a state
abstraction which represents one or more effectively volatile objects."

The Legality Rules should be updated as follows:

- A new legality rule should say: "If a local volatile object or a local object
  of an effectively volatile type is declared without any of the external
  properties specified then all of the properties default to a value of
  False. [Such an object does not represent external state.]"

- Legality rule 6 should add that the combination with all properties valued
  False is valid.

Rationale and alternatives
==========================

We originally discussed a new volatile property No_Optimizations to denote that
a volatile variable is only meant to prevent optimizations, not to specify an
interface, but this had the disadvantage that it required more rules to define
what were the allowed combinations of volatility properties.

We also discussed looking at the presence or absence of an address
clause/aspect to decide whether a volatile variable is meant for interfaces
(address is specified) or for preventing optimizations only (no address
specified). This has the disadvantage that it would introduce an effect from
one aspect on the interpretation of another. Plus it would not allow having
library-level variables for specifying interfaces if their address is not
specified.

Until a solution is found for specifying this use of volatile variables, SPARK
users have no choice but to exclude parts of the code from SPARK analysis.

As this interpretation of volatile variables builds on the existing definition
of volatility properties, and simply assigns a meaning to a combination
previously illegal (all properties set to False), it is fully backwards
compatible, and rather minimal in terms of language evolution.

Drawbacks
=========

There are no major drawbacks of the general feature.

A possible counter argument for not having the new legality rule regarding
local volatile variables is that a vanilla volatile variable gets different
defaulted properties if it is library-level (all True) or local (all False). As
it corresponds to different use cases, it is not considered a major
drawback. Not having this new legality rule would force the user to
exhaustively state the value of all four properties:

   X : Integer with Volatile, Async_Readers => False, Async_Writers => False,
                              Effective_Reads => False, Effective_Writes => False;

or to pick any one property, as the others are then False by default as a
result:

   X : Integer with Volatile, Effective_Reads => False;

This is considered worse than the drawback just mentioned.

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
