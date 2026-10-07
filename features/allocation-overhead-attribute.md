- Feature ID: allocation-overhead-attribute
- Start Date: 2026-01-09
- Status: Proposed
- Owner: swbaird

Summary
=======

The size of the allocated object (in storage units) may be less than the
Size_In_Storage_Elements parameter value generated for the allocator.
There may be additional storage needed
for things like array bounds (if the actual subtype corresponding to
Element_Type is an unconstrained array subtype), or finalization-related
linkage, or alignment gaps between such additional data and the object
itself, etc. The length of a byte-array that is intended to hold such an
allocated object needs to account for this requirement for additional storage.
In choosing the length for such an array, it would be convenient to be able
to query an attribute (tentatively named
Max_Allocation_Overhead_In_Storage_Elements) which takes a subtype T as a
prefix and yields the maximum possible size (in storage_elements) of this
additional storage for an allocator of an access type whose designated
subtype is T.

Motivation
==========

This attribute would solve an implementation problem in
Ada.Containers.Bounded_Indefinite_Holders (which may also arise in other
contexts in the future, including customer code). This generic has a formal
parameter Max_Element_Size_in_Storage_Elements. The holder type's
implementation needs to include sufficient storage to hold an allocated
object of that size. To do this, the holder type has a component which is
an array of bytes; the implementation needs to choose a length for that array.
Because the object is created by an allocator, the required storage may be
larger than Max_Element_Size_In_Storage_Elements.

The compiler already has to deal with a very similar problem in order to
implement the RM-defined attribute Max_Size_In_Storage_Elements.
The implementation of that attribute is non-trivial because it requires
back-end-to-front-end communication (which is the opposite direction of
the usual information flow). That implementation is already in place.
To determine the additional storage requirement we are currently using
the formula
``Element_Type'Max_Size_In_Storage_Elements - Convert_To_Storage_Elements (Element_Type'Size)``
which works for most of the cases. However, this doesn't work when
the two quantities whose difference is being computed are too large
(consider evaluating Standard.String'Size on a 32-bit target). The current
implementation uses a hardcoded guess for such cases which often allocates
excess memory. However, there could exist situations where the result of
the guess is too small and an allocator that ought to succeed instead fails
due to insufficient storage.

Guide-level explanation
=======================

Consider the case of using an array of storage elements in implementing a
storage pool tailored for an access type with designated subtype S.
How large does that array need to be?

Suppose we know the maximum number of allocated objects that will exist at
any given time, N, and that size of each allocated object will not be
more than M storage elements. Suppose further that M is a multiple of
S'Alignment, that coextensions need not be considered, and that S has a
contiguous representation. One might guess that M*N storage elements would
suffice, but that would be wrong in some cases (even if the array is
appropriately aligned). Because the objects are being created by allocators,
there can be additional storage required; for example, if S is an
unconstrained array subtype, then storage might be needed to store the bounds
of each allocated object. Of particular interest is the case where S is
a generic formal private type (so little is known about the corresponding
actual type).

So a new attribute, S'Max_Allocation_Overhead_In_Storage_Elements, is
defined in order to provide an upper bound on the amount of storage an
allocator might require in addition to the storage needed for the
allocated object itself.

This new attribute simplifies computing the length of the array.

Reference-level explanation
===========================

For every subtype S, the universal-integer valued attribute
   S'Max_Allocation_Overhead_In_Storage_Elements
is defined.

Given an access type with designated subtype S and a Storage_Pool aspect
specification, the evaluation of an allocator of that type will (if no
exceptions are raised) include a call to either Allocate or
Allocate_From_Subpool. In either case, a Size_In_Storage_Elements parameter is
passed in. This attribute yields the maximum possible difference (for
any such allocator of any such access type) between the
Size_In_Storage_Elements parameter value and the size (in storage elements)
of the allocated object.

[Informal exposition:
This attribute yields the amount of storage required for an allocated object
in addition to the storage for the object itself. This additional storage
might be for array bounds (if S is an unconstrained array subtype), or for
finalization-related linkage (if S requires finalization), or for an
alignment-related gap between this additional data and the object itself,
or for some other implementation-defined reason.

If S'Size happens to be both definite (so that RM 13.3(48) does not apply)
and small enough that overflow is not an issue then
S'Max_Allocation_Overhead_In_Storage_Elements will typically equal
  S'Max_Size_In_Storage_Elements - Convert_To_Storage_Elements (S'Size)
, where Convert_To_Storage_Elements takes a size in bits and converts it to
a size in storage_elements (rounding up). This new attribute is useful for
coping with an arbitrary S.]

Rationale and alternatives
==========================

An alternative, suboptimal solution is already implemented in
Ada.Containers.Bounded_Indefinite_Holders.

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
