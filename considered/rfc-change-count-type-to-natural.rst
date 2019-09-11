- Feature Name: change_count_type_to_natural
- Start Date: 2019-09-11
- RFC PR:
- RFC Issue:

Summary
=======

Change the definition of Ada.Containers.Count_Type from

   type Count_Type is range 0 .. implementation-defined;

to

   subtype Count_Type is Natural;

in order to work around use-visibility issues occuring with this
type.

Motivation
==========

Comparing the result of the Length function on a container, as in

   if My_Container.Length > 1 then

generally does not work out-of-the-box, since the function Length
returns a type, Ada.Containers.Count_Type which is generally not
use-visible.

The solutions include either making this type use-visible by
adding a with clause and an use clause, or by adding an inelegant
explicit cast:

   if Natural (My_Container.Length) > 1 then

This is a minor annoyance.

Guide-level explanation
=======================

Nothing specific to add, the Containers would become slightly more
natural to use.

Reference-level explanation
===========================

Again, nothing specific to explain in the Reference manual.

Rationale and alternatives
==========================

My understanding is that, from the point of view of storage size being
used, the common implementations of Count_Type is already the same
as the implementation of Natural, so nothing changes with my proposal.

The other uses of Count_Type (typically, querying the maximum storage
of a container or setting limits to the number of stored elements) would
be affected as well, in a similar fashion.

The major impact is that the Count_Type is no longer a type that's
incompatible with Natural, meaning that accidental assignments and
comparisons may happen. This said, this is not something that seems
problematic to me. In addition, this is in line with the other instances
of "Length" in the language: the 'Length attribute returns an universal
integer, and Ada.Strings.Unbounded.Length returns a Natural as well.

Alternatives considered:

  * overload Ada.Containers.*.Length with another version which returns
    a Natural
    Con: this causes a lot of bloat, and is also backwards-incompatible
         in potentially forcing users to disambiguate.

  * add Ada.Containers.*.Len which returns a Natural
    Con: this also adds a lot of bloat, and "Len" is not idiomatic in Ada,
         where "Length" is preferred.

  * make the functions Ada.Containers.*.Length return a Natural rather than
    an Ada.Containers.Count_Type
    Con: this is slightly more distuptive.

  * inside each Container package, add
        type Count_Type is new Ada.Container.Count_Type;
    and have Length return this Count_Type; this would allow people "using"
    their container package to have visibility on the operator for the
    returned Count_Type.
    Con: this doesn't resolve the issue for the developers who are not
    "using" their Container package - which is more and more the case
    in practice now that the language supports dotted notation and
    "for xx of".

Drawbacks
=========

This change is backwards-incompatible, leading developers to change their
code to remove with/uses of Ada.Containers or explicit casts which are no
longer needed.

Prior art
=========

This is not a novel idea. As mentioned above, there are already "Length"
functions and attributes in Ada which return either a Natural or an
universal integer.

Unresolved questions
====================

None found.

Future possibilities
====================

None.
