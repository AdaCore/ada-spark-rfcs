- Feature Name: Lower Bound Constraint
- Start Date: 2020-02-28
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

The Ada programming language offers the ability to declare a so-called unconstrained array type in the form of:
type A is array (Integer range <>) of Integer;
This is one of the very powerful capabilities of the language. However, it also means performances hit in a number of cases. 
For example, when writing:

.. code-block:: ada

   procedure P (V : in out A; I : Integer) is
   begin
      V (I) := 0;
      
In order to properly do the assignment, the program needs to

- Load the lower bound of V
- Compute lower bound of V + I
 
In very tight performance constraints, these two operations may represent an unreasonable loss of performance against e.g. C. 
The proposal is to provide a mechanism to fix the lower bound of an unconstrained array, e.g.:

.. code-block:: ada

   type A is array (Integer range 1 .. <>) of Integer;

The consequences are as follows

- If the lower bound is a static expression, the compiler can now optimize operations and avoid loading from memory the lower bound
- If the lower bound is 0, the compiler can avoid arithmetic when accessing an element from Index
- The compiler can also optimize so called fat pointers by storing only one value (the length) instead of two.

Note that this also means that upon slicing, bounds are always slided towards the lower bound value.

Motivation
==========

This is specifically motivated by performances. In particular, when looking at low level driver implementation or HPC code where Ada 
doesn’t look favorable in front of C. These constraint meet certain users requirements in high integrity applications that Ada is
covering.

Guide-level explanation
=======================

Array types can force the lower bound value in the form:

.. code-block:: ada

  type A is array (Integer range 1 .. <>) of Integer;
  
As for bounds in general, that lower bound can be either a static or a dynamic expression, although (as for arrays in general) static 
expressions are those that provide the most benefit.

Array declarations are the same as usual. In particular, when bound are provided, the lower bound needs to be explicitly given:

.. code-block:: ada

  V : A (1 .. 10);
  
With these arrays, slices always slide towards the lower bound. In particular, if you write:

.. code-block:: ada

  type String is array (Positive range 0 .. <>) of Character;
  S : String := “Hello”
  P (S (1 .. 2));
  
  procedure P (S : String) is
  begin

In P, the indices of the String would be 0 .. 1 and not 1 .. 2.

Reference-level explanation
===========================

Not much to add here for now.

Rationale and alternatives
==========================

We could also provide a pragma/aspect, e.g.:

.. code-block:: ada

  type A is array (Integer range <>) of Integer with Min_Bound => 1;
  
However, this being a fundamental aspect of the type, it seems more natural that include it in the definition syntax.

Arguably, there’s also a way to achieve this today through a type with discriminant:

.. code-block:: ada

  type A_Base is array (Integer range <>) of Integer;
  
  type A (Last : Integer) is record
    Value : Float_Array_Base (0 .. Last);
  end record;
  
This is however a bit convoluted to write and use.

An alternative would be to use a predicate:

.. code-block:: ada

 type My_String is array (Integer range <>) of Character
   with Predicate => My_String'First = 0;

This opens other difficulties - a predicate can be an arbitrary condition, this would require the compiler to somehow understand that this specific expression means something. It also means that the predicate has an impact on the type structure, for which there's no provision at this stage. 

Drawbacks
=========

If we’re not convinced that the performance improvement is necessary, the change isn’t desirable.

Prior art
=========

This would allow to make Ada arrays match - when needed - they counterparts (most languages have a static lower bound at 0) while
keeping all the high level semantics and safety aspects.

Unresolved questions
====================

Nothing specific here.

Future possibilities
====================

We could introduce ways to ommit the lower bound when declaring an array of a type that has a fixed lower bound. Indeas include:

.. code-block:: ada

  V1 : A (10);
  V2 : A (<> .. 10);
  V3 : A (.. 10);

This is more of a "quality of life" / "cosmetic" feature comparted to the initial proposal. If we were going this route, this can be discussed separately.
