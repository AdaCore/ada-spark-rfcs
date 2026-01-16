- Feature ID: allocation-overhead-attribute
- Start Date: 2026-01-09
- Status: Proposed
- Owner: swbaird

Summary
=======

The size of the allocated object (in storage units) may be less than the
Size_In_Storage_Elements parameter. There can be additional storage needed
for things like array bounds (if the actual subtype corresponding to
Element_Type is an unconstrained array subtype), or finalization-related
linkage, or alignment gaps between such additional data and the object
itself, etc. The length of the byte-array needs to account for this
requirement for additional storage. It would be convenient to be able to
query an attribute (tentatively named Max_Allocation_Overhead_In_Storage_Elements)
which takes a subtype T as a prefix and yields the maximum possible size
(in storage_elements) of this additional storage.

Motivation
==========

This attribute would solve a suboptimal implementation detail in
Ada.Containers.Bounded_Indefinite_Holders (which may also arise in other
contexts in the future). This generic has a formal parameter
Max_Element_Size_in_Storage_Elements. The holder type's implementation needs
to include sufficient storage to hold an object of that size. To do this, the
holder type has a component which is an array of bytes and the implementation
needs to choose a length of that array. The required storage may be larger
that Max_Element_Size_In_Storage_Elements.

The compiler already has to deal with a very similar problem in order to
implement the RM-defined attribute Max_Size_In_Storage_Elements.
The implementation of that attribute is non-trivial because it requires
back-end-to-front-end communication (which is the opposite direction of
the usual information flow). That implementation is already in place.
To determine the additional storage requirement we are currently using
the formula
``Element_Type'Max_Size_In_Storage_Elements - Convert_To_Storage_Units (Element_Type'Size)``
which works for most of the cases. However, this doesn't work when
the two quantities whose difference is being computed are too large
(consider evaluating Standard.String'Size on a 32-bit target). The current
implementation uses a hardcoded guess for such cases which mostly allocates
excess memory. However, there could exist situations where the result of
the guess is not sufficient and storage becomes too small.

Guide-level explanation
=======================

!! TBD

Explain the proposal as if it was already included in the language and you were
teaching it to another Ada/SPARK programmer. That generally means:

- Introducing new named concepts.

- Explaining the feature largely in terms of examples.

- Explaining how Ada/SPARK programmers should *think* about the feature, and
  how it should impact the way they use it. It should explain the impact as
  concretely as possible.

- If applicable, provide sample error messages, deprecation warnings, or
  migration guidance.

For implementation-oriented RFCs (e.g. for RFCS that have no or little
user-facing impact), this section should focus on how compiler contributors
should think about the change, and give examples of its concrete impact.

For "bug-fixes" RFCs, this section should explain briefly the bug and why it
matters.

Reference-level explanation
===========================

!! TBD

This is the technical portion of the RFC. Explain the design in sufficient
detail that:

- Its interaction with other features is clear.
- It is reasonably clear how the feature would be implemented.
- Corner cases are dissected by example.

The section should return to the examples given in the previous section, and
explain more fully how the detailed proposal makes those examples work.

Rationale and alternatives
==========================

An alternative, suboptimal solution is already implemented.

Drawbacks
=========

There are no known drawbacks of implementing this feature.

Compatibility
=============

The change is invisible to the user.

Open questions
==============

None

Prior art
=========

N/A

Unresolved questions
====================

None

Future possibilities
====================

N/A