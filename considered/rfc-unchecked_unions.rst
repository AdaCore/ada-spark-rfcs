- Feature Name: Unchecked Unions Overlay
- Start Date: 2020-10-15
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

The Ada programming language offers the feature of pragma Unchecked_Union,
which can be used to annotate an unconstrained discriminant record type. On
such types, all discriminant checks are suppressed at execution, but execution
is still considered erroneous if such a check would fail. This RFC proposes to
change that and allow such executions.


Motivation
==========

The main motivation for this RFC comes from SPARK usage. While dynamic checks
for discriminant are suppressed, static checks still need to be verified by
GNATprove, as we want to exclude erroneous executions. But these checks are
almost always unprovable, as there is no way to specify the value of the
discriminant e.g. in assertions. This is because of RM B.3.3 9(2):

> Any name that denotes a discriminant of an object of an unchecked union type
> shall occur within the declarative region of the type.

As a consequence, uses of pragma Unchecked_Union in SPARK programs that intend
to apply formal verification require many annotations to suppress unproved
checks.

Another minor justification for this change is that the intention of
Unchecked_Union is to interface with C unions. While the use of C unions for
memory overlay / unchecked conversion purposes results in undefined behavior
according to the C standard, it is nevertheless common practice in C programs
and supported by most compilers (source:
https://stackoverflow.com/questions/252552/why-do-we-need-c-unions).

Guide-level explanation
=======================

Pragma Unchecked_Union can be used to annotate an constrained discriminant
record type. For such types, at execution, all discriminant checks are
suppressed, and the discriminant can only be used in the type declaration
itself (See RM B.3.3 for more details).

A discriminant record declaration that is annotated with pragma Unchecked_Union
is subject to a static check. This check is identical to the static check
currently performed for Address clauses. It checks that the definition of the
discriminant record does not allow for the introduction of invalid values, even
if the discriminant checks (which are suppressed) would fail. If the static
check succeeds, the execution of the construct is not erroneous even if the
discriminant check would fail. In effect, this allows the programmer to use
Unchecked_Union as a way to convert between two (or more) types, similar to an
unchecked conversion.

.. code-block:: ada

  --  This type declaration raises a static check because
  --  reading from the F1 field might result in invalid values.
  type U (Flag : Boolean := False) is
     record
         case Flag is
             when False =>
                 F1 : Float;
             when True =>
                 F2 : Integer := 0;
         end case;
      end record;
  pragma Unchecked_Union (U);

  --  This type definition is allowed as no invalid values can be created.
  type T (Flag : Boolean := False) is
     record
         case Flag is
             when False =>
                 F1 : Byte_Array (1 .. 4);
             when True =>
                 F2 : Integer := 0;
         end case;
      end record;
  pragma Unchecked_Union (T);
  X : T := (Flag => True, F2 => 25);
  Y : Byte := X.F1 (2); -- no check

Reference-level explanation
===========================

The RM already contains a definition for subtypes to be "suitable for unchecked
conversion":

A subtype ``S`` is said to be `suitable for unchecked conversion` if:

- ``S`` has a contiguous representation. No part of ``S`` is of a tagged type,
  of an access type, of a subtype that is subject to a predicate, of a type
  that is subject to a type_invariant, of an immutably limited type, or of a
  private type whose completion fails to meet these requirements.

- Given the size N of ``S`` in bits, there exist exactly 2**N distinct values
  that belong to ``S`` and contain no invalid scalar parts.  [In other words,
  every possible assignment of values to the bits representing an object of
  subtype ``S`` represents a distinct value of ``S``.]

The new rules concerning unchecked unions are as follows:

1. The discriminant can only appear in the "case" part of a variant part. This
  rule is to avoid that the discriminant be used for sizes of fields of array
  type, which would likely result in violation of subsequent rules anyway.
2. Every subtype of a component which appears in a variant part has to be
   suitable for unchecked conversion;
3. For every variant part of the record, the sum of the sizes of the components
   of each component list shall be identical.
4. The size of the entire record type with Unchecked_Union shall be equal to
   the sum of the sizes of its components, where for each variant part, an
   arbitrary component list is chosen for this computation.

.. code-block:: ada

  --  This type declaration is rejected as the discriminant is not only used in
  --  the case part of the variant part.
  type A (X : Integer := 100) is
     record
         case X is
             when 0 =>
                 F1 : Boolean;
             when others =>
                 F2 : String (1 .. X);
         end case;
      end record;
  pragma Unchecked_Union (U);

  --  This type declaration raises a static check because
  --  the two branches of the variant part don't have the same size.
  type A (Flag : Boolean := False) is
     record
         case Flag is
             when False =>
                 F1 : Byte;
             when True =>
                 F2 : Integer;
         end case;
      end record;
  pragma Unchecked_Union (U);

Drawbacks
=========

With this new semantics, unintended uses of Unchecked_Union with incorrect
discriminant values will go undetected. Such uses will not result in runtime
errors (assuming a GNATprove analysis has been completed), but it still might
not be the intended program behavior.

Rationale and Alternatives
==========================

Another alternative consists in making the discriminant checks of
Unchecked_Union provable in SPARK. This could be done for example by
considering discriminants of Unchecked_Union records as ghost fields, which can
be referenced in assertions and modified via ghost code. The main issue with
this alternative approach is the complexity of the rules related to ghost
fields, which currently do not exist in Ada or SPARK.
