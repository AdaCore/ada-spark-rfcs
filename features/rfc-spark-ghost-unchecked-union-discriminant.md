- Feature Name: spark_ghost_unchecked_union_discriminant
- Start Date: 2026-04-02
- Status: Design

Summary
=======

Allow discriminant of unchecked union types to be accessed in restricted
cases for verification purposes.

Motivation
===========


Ada mandates that discriminant of unchecked union types (used to interface C union) cannot be read, as per legality rule B.3.3 (9/5). This is
cumbersome in the context of verification with SPARK, as the discriminant
carry information pertinent to the specification. For example, some
subprograms may only work for a subclass of discriminants. Without the
ability to access the discriminant in contracts, this cannot be specified.

We propose that said discriminant can be read in ghost code, as long as the
assertion level depends on Static. Since ghost code at level static will
never be compiled, the absence of a physical discriminant to read is not
an issue.

Reference-level explanation
===========================

Legality rule B.3.3 (9/5) is relaxed: the list of cases in which a
name denoting a discriminant of a type with Unchecked_Union is allowed to
occur is extended by ghost code with an assertion level depending on Static.

Rationale and alternatives
==========================

Reading discriminants of unchecked union types could be integrated
in the framework of ghost fields. This is arguably a simpler case,
since the access can never be compiled in the first place.
