- Feature Name: Import Array from Address
- Start Date: 2025-05-06
- Status: Proposed

Summary
=======

This proposal introduces the possibility of dynamically creating an access to
an Ada unconstrained array from an address and its bounds.

Motivation
==========

It is difficult today to create access to arrays created from outside of Ada,
e.g. when coming from C, as there's no way to dynamically create their
bounds. This proposal will make it possible and simplify interfacing
between system data and other languages.

Guide-level explanation
=======================

A new attribute is provided for arrays access types, `Address_To_Access`, which
takes as parameter an address as well as the bounds of the expected object.
For example:

```ada
   type Arr is array (Integer range <>) of Integer;
   type Arr_Access is access all Arr;

   function Create_C_Array_Of_Int (Size : Integer) return System.Address;
   pragma Import (C, Create_C_Array_Of_Int, "create_c_array_of_int");

   V : Arr_Access := Arr_Access'Address_To_Access (Create_C_Array_Of_Int (10), 1, 10);
```

This attribute is available for all arrays. Constrained arrays do not require
bounds to be provided. Multidimensional arrays will need dimensions to
be provided in order, and fixed lower bound only requires one dimension. For
example:

```ada
   type Constrained_Array is array (Integer range 1 .. 10) of Integer;
   type Constrained_Array_Access is access all Constrained_Array;

   type 2D_Array is array (Integer range <>, Integer range <>) of Integer;
   type 2D_Array_Access is access all 2D_Array;

   type FLB_Array is array (Integer range 1 .. <>) of Integer;
   type FLB_Array_Access is access all FLB_Array;

   function Create_C_Array_Of_Int (Size : Integer) return System.Address;
   pragma Import (C, Create_C_Array, "create_c_array_of_int);

   V1 : Constrained_Array_Access := Constrained_Array_Access'Address_To_Access
      (Create_C_Array_Of_Int (10));

   V2 : 2D_Array_Access := 2D_Array_Access'Address_To_Access
      (Create_C_Array_Of_Int (100), 1, 10, 1, 10);

   V3 : FLB_Array_Access := FLB_Array_Access'Address_To_Access
      (Create_C_Array_Of_Int (10), 10);
```

Attribute parameters are named either First, Last (in case of one dimension)
or First_n, Last_n (in case of n dimensions).

Reference-level explanation
===========================

TBD


Rationale and alternatives
==========================

The attribute could have been provided on arrays, and return an anonymous
access type instead. To some respect, not presuming the type of the object
and not requiring the creation of an explicit access type, might be better.
However, this requires performing all accessibility checks that don't really
make sense when addressing external memory. It's most likely that these checks
will need to be disabled anyway. Note that if accessibilty checks are required,
it is still possible to create a local array mapped to an address instead:

```ada
   type Arr is array (Integer range <>) of Integer;
   type Arr_Access is access all Arr;

   function Create_C_Array_Of_Int (Size : Integer) return System.Address;
   pragma Import (C, Create_C_Array_Of_Int, "create_c_array_of_int");

   V : aliased Arr (1 .. 10) with Address => Create_C_Array_Of_Int (10);
```

Drawbacks
=========

This introduces a new "unsafe" construction in Ada, although it is well identified
and easy to track/forbid.

This also adds more constraints on the implementation. Some compilers implement
access to arrays in a way that generates two pointers, one to the data and
another to the bounds, which can then be put in the same place when allocating
memory for Ada. The issue then becomes the free operation - if all memory is
allocated from Ada, it is possible to free both the data and the bounds at
the same time. However, in the example here, the address is externally provided
and is not necessarily expected to be freed from the Ada side. An alternate
implementation, such as putting the bounds of the object in the pointer as
opposed to indirectly referring to it, does fix this problem, but requires in-depth
changes. Note that this is also necessary for other RFCs (such as access to array
slice).

Prior art
=========

Rust has a very similar problem (and solution) with the `from_raw_parts`
function.

Unresolved questions
====================

TBD

Future possibilities
====================

TBD
