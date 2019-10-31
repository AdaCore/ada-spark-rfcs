- Feature Name: variants-for-recursive-subprograms
- Start Date: 2019-10-30
- RFC PR:
- RFC Issue:

Summary
=======

SPARK uses variants to prove termination of while loops. A loop variant has the
following syntax:

.. code-block:: ada

  pragma Loop_Variant (<Direction> => <Expression>, ...);

where ``Direction`` is either ``Increases`` or ``Decreases``, and ``Expression``
is a discrete expression which should increase/decrease in each iteration.

This RFC aims at introducing the same mechanism to prove termination of
recursive subprograms.

Motivation
==========

In general SPARK is concerned about partial correctness, which means that it
proves that a program is correct if it terminates. However, termination can be
a property of interest to users, which is why loop variants are in the
language. This property cannot be verified by SPARK currently if the program
involves recursive subprograms.

This issue has been in SPARK since the beginning, but it is becoming more
visible with the new support for access types in SPARK which allows the
construction of recursive data-structures. Indeed, most properties on these
structures can only be specified in a recursive way. As SPARK enforces a
strict ownership policy, even applicative algorithms sometimes need to be
implemented in a recursive way, making it all the more important to be able to
ensure termination.

In addition, for technical reasons, GNATprove is not able to track information
on recursive functions if they are not known to terminate. So a user generally
needs to annotate her recursive functions with ``Terminating`` annotations,
introducing checks which currently cannot be discharged by the tool.

Guide-level explanation
=======================

To verify that a recursive subprogram terminates, a variant must be supplied
for it using a ``Variant`` aspect. This aspect should contain a sequence of
pairs of a direction, which can be either ``Increases`` or ``Decreases``, and
a discrete expression. The expressions can mention the parameters of the
subprogram, or global objects it references (just like a precondition). When
a recursive call is encountered, a check is introduced to make sure that
the variants either increase or decrease depending on the mode. As
an example, let us consider a function computing a Fibonacci number:

.. code-block:: ada

   function Fibo (N : Natural) return Natural is
   begin
      if N < 3 then
         return 1;
      else 
         return Fibo (N - 1) + Fibo (N - 2);
      end if;
   end Fibo;

We could use the parameter ``N`` as a variant to ensure its termination:

.. code-block:: ada

   function Fibo (N : Natural) return Natural with
     Variant => (Decreases => N);

If this aspect is supplied, checks will be introduced at execution to make sure
that both recursive calls to ``Fibo`` are done on a strictly smaller value of
``N``. Just like for loops, if several variants are specified, a lexicographic
ordering will be used to compare them.

Checks are not be introduced at execution for indirect recursive calls, that
is, calls to subprograms which themselves will call the initial subprogram.
However, GNATprove is able to detect these cases. If a subprogram calls another
subprogram which is mutually recursive with it, GNATprove will check that both
subprogram have matching variants (they have variants with the same direction
and expressions of the same type in the same order) and that these variant
increase or decrease in the calls. For example, we can define two functions
``Even`` and ``Odd`` using mutual recursion as follows:

.. code-block:: ada

   function Even (N : Natural) return Boolean with
     Variant => (Decreases => N);

   function Odd (N : Natural) return Boolean with
     Variant => (Decreases => N);

   function Even (N : Natural) return Boolean is
   begin
      if N = 0 then
         return True;
      else 
         return Odd (N - 1);
      end if;
   end Even;

   function Odd (N : Natural) return Boolean is
   begin
      if N = 0 then
         return False;
      else 
         return Even (N - 1);
      end if;
   end Odd;

At runtime, no verifications are made that a call to ``Even`` or ``Odd`` will
terminate. GNATprove however will check that the variants on the declarations
match and that ``N`` strictly decrease when ``Even`` is called from ``Odd``
or ``Odd`` is called from ``Even``.

Reference-level explanation
===========================

A new aspect ``Variant``, and possibly a matching pragma, are introduced. The
syntax is the same as the one for pragma ``Loop_Variant``, using
``loop_variant_parameters`` as defined in SPARK RM 5.5.3
(see http://docs.adacore.com/spark2014-docs/html/lrm/statements.html#loop-invariants-variants-and-entry-values).
This aspect can be supplied on any subprogram.

For semantic checking, the discrete expressions supplied
are checked like preconditions, to make sure that they only mention visible
objects and parameters of the subprogram. Additionally, it is incorrect to
call the subprogram inside the variant. For example:

.. code-block:: ada
   G : Integer;

   procedure P (X : Integer; Y : in out Integer) with
     Variant => (Descreases => F (X), Increases => Y + G);  --  correct

   function F (X : Integer) return Integer with
     Variant => (Descreases => F (X));  --  incorrect

For dynamic semantics, all the expressions of the variant should be evaluated
and stored in constants at the beginning of the subprogram. When compiling the
subprogram, if a direct recursive call is encountered, a check is made that the
variants are modified appropriately as it is done for loop variants. For
example:

.. code-block:: ada

   procedure P (X : Integer; Y : in out Integer) with
     Variant => (Descreases => F (X), Increases => Y + G)
   is
   begin
     G := G + 1;
     P (X, Y);
   end P;

   function F (X : Integer) return Integer with
     Variant => (Descreases => X),
     Pre     => (if X > 0 then F (X - 1))
   is
     C : constant Integer := F (X - 1);
   begin
     return C + F (X - 2);
   end F;

could be handled like:

.. code-block:: ada

   procedure P (X : Integer; Y : in out Integer) is
     D1 : constant Integer := F (X);
     I1 : constant Integer := Y + G;
     procedure P_Ann (X : Integer; Y : in out Integer) with
      Pre => F (X) < D1 or else (F (X) = D1 and Y + G > I1)
     is
     begin
       P (X, Y);
     end P_Ann;
   is
   begin
     G := G + 1;
     P_Ann (X, Y);
   end P;

   function F (X : Integer) return Integer with
     Variant => (Descreases => X),
     Pre     => (if X > 0 then F (X - 1))
   is
     D1 : constant Integer := X;
     function F_Ann (X : Integer) is (F (X)) with
      Pre => X < D1 /\ (if X > 0 then F _Ann (X - 1));
     
     C : constant Integer := F_Ann (X - 1);
   begin
     return C + F_Ann (X - 2);
   end F;

For formal verification, expressions inside variants should be considered to be
read in assertions at the point of call (just like a precondition).
Additionally, on a mutually recursive call, the tool would check that:

  - the variants are compatible (ie. if ``F`` with variants ``F1, ..., Fn``
    calls ``G`` with variants ``G1, ..., Gm``, if ``k`` is the minimum of
    ``n`` and ``m``, for all ``i`` in ``1 .. k``, ``Fi`` and ``Gi`` have the
    same direction and the same type)
  - the values of the compatible variants increase / decrease strictly as
    specified.

Rationale and alternatives
==========================

Drawbacks
=========

Prior art
=========

In WhyMl, variants can be supplied for (mutually) recursive subprograms as
a sequence of expressions that should decrease using a well founded ordering
relation. By default, if no variants are supplied, the subprogram parameters
are used as variants. The order relation can be supplied explicitly if needed.

Unresolved questions
====================

- We should probably think about recursion through dispatching calls and
  possibly access subprograms.
- Should we do something about user-defined order relations?

Future possibilities
====================

- We could allow a new ``Structural`` kind of variant which would enforce
  structural decrease (the variant should be a path rooted at the initial
  variant). This kind of variant could possibly be checked at compile-time.
  However, it would not imply termination in Ada in general, but only in
  SPARK where cyclic data-structures cannot be constructed.
- I don't know how the No_Recursion is handled currently, but if there is a
  dynamic checking at execution, we could consider using a similar mechanism
  to check the variants.
