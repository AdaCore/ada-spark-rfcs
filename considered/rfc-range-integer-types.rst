- Feature Name: range_integer_types
- Start Date: 2023-11-10
- RFC PR:
- RFC Issue:

Summary
=======

RM-3.5.4(9) imposes a symmetric base range for signed integer types. I would like
to remove the need for a symmetric base range because it imposes the use of larger
types to perform arithmetic operations, potentially burdening embedded
applications with undesirable run-time needs and performance overhead.

Motivation
==========

You can define an unsigned 64-bit integer type containing values between 0 and
2 ** 64 - 1 as:

.. code-block:: ada

  type Unsigned_64 is range 0 .. 2 ** 64 - 1 with Size => 64

Currently, this type definition has a symmetric base range that does not fit within
64-bit, meaning that arithmetic operations on the previously defined 64-bit type
are performed in 128-bit. It is also misleading because the Size aspect would let
the coder think that it would use 64-bit operations.

Using a larger type can harm the performance of the operation, and sometimes force
the operation to be implemented in software (within a run-time library) instead of
hardware. This is particularly unfortunate for embedded applications. For example,
on a 64-bit hardware architecture, a 64-bit multiplication can be performed with a
single hardware instruction, while a 128-bit multiplication needs a series of
hardware instructions working on intermediate results.

Guide-level explanation
=======================

Defining an unsigned type using the expected range and its required number of bits
is a sensible way to do it. It is also natural to expect arithmetic operations to
be performed using the same number of bits (as in languages like C).

Proper implementation of numeric overflow checking does not need to use a symmetric
base range. Typical hardware signals numeric overflows on arithmetic operations with
the processor carry state flag.

Hence, the implementation of proper Ada semantics does not need to use a larger
base range.

Reference-level explanation
===========================

The proposed rewording for RM-3.5.4(9) would be the following:

  A range_integer_type_definition defines an integer type whose base range includes
  at least the values of the simple_expressions. A range_integer_type_definition also
  defines a constrained first subtype of the type, with a range whose bounds are given
  by the values of the simple_expressions, converted to the type being defined.

Rationale and alternatives
==========================

Unsigned types could be defined using a modular type definition to prevent the
symmetric base range instead. However, the semantics of the two integer type definitions
are very different.

Drawbacks
=========

None found, this change is backwards-compatible; implementations can continue to do what
they currently do (define a symmetric base type for signed integer types).

Prior art
=========

This is the way unsigned types are defined in other languages, like C.

Unresolved questions
====================

None.

Future possibilities
====================

None.
