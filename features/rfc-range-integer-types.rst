- Feature Name: range_integer_types
- Start Date: 2023-11-10
- Status: Production

Summary
=======

RM-3.5.4(9) mandates a symmetric base range for signed integer types. This
requirement often necessitates the use of larger data types for arithmetic
operations, potentially introducing undesirable run-time overhead and
performance penalties, particularly in embedded systems.

This proposal introduces a new aspect for type definitions to explicitly
enforce the use of an unsigned base type, alleviating these issues.

Motivation
==========

Currently, an unsigned 64-bit integer type can be defined in Ada as:

.. code-block:: ada

  type Unsigned_64 is range 0 .. 2 ** 64 - 1 with Size => 64

However, this type implicitly assumes a symmetric base range that exceeds 64 bits.
Consequently, arithmetic operations on such a type are executed using 128-bit
operations. This is misleading, as the Size aspect suggests that operations would
utilize only 64 bits.

The use of larger types for arithmetic operations adversely affects performance
and, in some cases, necessitates software-based implementations in run-time
libraries instead of hardware operations. This issue is especially problematic fo
embedded applications. For instance, on a 64-bit architecture, a 64-bit
multiplication can be performed with a single hardware instruction, whereas a
128-bit multiplication requires multiple instructions and intermediate steps.

By allowing unsigned types with unsigned base ranges, we can ensure that arithmetic
operations are performed with the expected size, reducing performance overhead.

The following enhancement could be used to explicitly indicate this intention:

.. code-block:: ada

  type Uns_64 is range 0 .. 2 ** 64 - 1 with Size => 64, Unsigned_Base_Range => True

This ensures that arithmetic operations are carried out using 64 bits. Overflow
checking is based on the processor's carry state flag.

Guide-level explanation
=======================

Defining unsigned types with their expected ranges and bit widths should naturally
result in arithmetic operations using the same bit width. This behavior aligns with
the expectations of developers familiar with languages like C.

Symmetric base ranges are advantageous for avoiding numeric overflows during
intermediate calculations, when negative values arise from subtraction. However,
symmetric ranges impose significant performance costs.

Note that numeric overflow checking can be achieved without symmetric base ranges, as
most hardware uses the processor's carry state flag to signal overflows.

This proposal introduces a new explicit aspect for type declarations, which maintains
upward compatibility while reducing run-time overhead.

Reference-level explanation
===========================

For every subtype S of a signed integer type, S'Unsigned_Base_Range is an boolean
attribute that indicates whether the base range is unsigned. The default falue is
False.

Rationale and alternatives
==========================

An alternative to this proposal is defining unsigned types using modular type
definitions to avoid symmetric base ranges. However, modular types have fundamentally
different semantics compared to integer types, which may not align with the intended
use case.

Drawbacks
=========

Using unsigned base ranges limits the applicability of these types in contexts where
generic units expect regular signed integer types because potential assumptions on their
base ranges are no longer valid.

Prior art
=========

In C, unsigned types have a range that excludes negative values. Arithmetic operations
on such types use the same number of bits as the defined width of the type. While their
semantics differ, for example, unsigned types in C wrap around on overflow instead of
raising an exception, this behavior ensures consistent bit-width usage during
calculations. This proposal aligns Ada's behavior with such established practices.

Unresolved questions
====================

None.

Future possibilities
====================

None.