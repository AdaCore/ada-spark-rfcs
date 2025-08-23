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
- A potentially more involving and optional optimization could be for the compiler to optimize so called fat pointers by storing only one value (the length) instead of two. This would not need to be implemented initially (and definitely not an explicit requirement
in the language) but would be a potentially interesting option to have at some point

Note that this also means that upon slicing, bounds are always slided towards the lower bound value.

Motivation
==========

This is specifically motivated by performances. In particular, when looking at low level driver implementation or HPC code where Ada 
doesn’t look favorable in front of C. These constraint meet certain users requirements in high integrity applications that Ada is
covering.

There is also some conceptual motivation, as it allows you to fix the lower boundary and stop having to worry about it. Having 
a variable lower bound is a common source of mistake where people assume a certain lower bound on a parameter without realizing that
it may come from a slice (so much so that GNAT implemented specific warnings when detecting such assumptions). 

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

  type String is array (Natural range 0 .. <>) of Character;
  S : String := “Hello”
  P (S (1 .. 2));
  
  procedure P (S : String) is
  begin

In P, the indices of the String would be 0 .. 1 and not 1 .. 2.

Subtypes should allow to fix the lower bound of a given type. This would be useful for example for Strings, e.g.:

.. code-block:: ada
  
  subtype Fixed_String is String (1 .. <>); -- OK  
  subtype Fixed_String_2 is String (Natural range 1 .. <>); -- OK   
  
Assigning from a type with a unconstrained lower bound to a type with a lower bound should be doing the usual sliding:

.. code-block:: ada
  
  subtype Fixed_String is String (1 .. <>);
  S1 : String (2 .. 3) := "AB";
  S2 : Fixed_String := S1; -- S2 bounds are 1 .. 2

It is an error to declare an object with a lower bound different than the one provided by its type. For example

.. code-block:: ada
  
  subtype Fixed_String is String (1 .. <>);
  S1 : Fixed_String (Fixed_String'First .. 10); -- OK
  S2 : Fixed_String (1 .. 10); -- OK
  S3 : Fixed_String (2 .. 10); -- NOK
  
S3 should raise Contraint_Error - or potentially issue a compiler warning / error on obvious cases. 

Note that this proposal should also be generalized to multi-dimensional arrays, where one or more of the lower bounds could be fixed,
for example:

.. code-block:: ada

  type Int_Matrix_1 is array (Natural range 0 .. <>, Natural range <>) of Integer;
  type Int_Matrix_2 is array (Natural range <>, Natural range 0 .. <>) of Integer;
  type Int_Matrix_3 is array (Natural range 0 .. <>, Natural range 0 .. <>) of Integer;

The behavior should be similar to the one of single-dimension array, including in particular subtyping, assignment and slicing/sliding.

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

See also ARG previous discussions and proposals on http://www.ada-auth.org/cgi-bin/cvsweb.cgi/ai12s/ai12-0246-1.txt?rev=1.3 and http://www.ada-auth.org/ai-files/minutes/min-1801.html#AI246

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
