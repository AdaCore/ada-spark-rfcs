- Feature Name: spark_relaxed_initialization
- Start Date: 2019-06-07
- RFC PR:
- RFC Issue:

Summary
=======

SPARK enforces a stricter data initialization policy than Ada. In particular,
all in and in out parameters should be initialized before subprogram calls, and
all out parameters should be initialized after the call (see the user-guide for
more information: http://docs.adacore.com/spark2014-docs/html/ug/en/source/language_restrictions.html#data-initialization-policy).

This restriction is justified by two reasons. First, the technology used to
check for initialization (flow analysis) is not value dependent, so it does not
handle 'maybe' initialization well. Second, allowing less constraining
initialization policies would require adding annotations to subprograms, because
the analysis done by SPARK is modular on a per subprogram basis, so it cannot
guess what should be initialized or not when calling a subprogram.

In this RFC, we do not propose to change the data initialization policy enforced
by SPARK in general, but to add a new annotation, named Relaxed_Initialization,
to allow relaxing it on a case by case basis. This annotation would come as a
new aspect which can be used to exempt objects from the data initialization
policy of SPARK:

.. code:: ada

   V : T with Relaxed_Initialization;

   function F (X : in out T; Y : out T; Z : in T) return T
     with Relaxed_Initialization => (X, Y, Z, F'Result);

Initialization of objects marked with this aspect would only be enforced when
mandated by the Ada RM. In particular, initialization of scalars
would be enforced on reads. Verification of subtype predicates is also impacted
by this change as they are always enforced in SPARK, as soon as there is an
initialized subcomponent in an object.

In addition, to be able to speak about initialization of these objects in
contracts, we would introduce a new 'Initialized attribute which would be True
if the variable has been initialized:

.. code:: ada

   type T is record
     F, G : Integer;
   end record;

   procedure Init_F_Only (X : out T)
     with Relaxed_Initialization => X,
     Post => X.F'Initialized and then X.G'Initialized = X.G'Initialized'Old;

Motivation
==========

The main use of this feature is to accommodate patterns which are currently
forbidden by the strict data initialization policy of SPARK. For example, it
would allow having a Read procedure which would only initialize its Data out
parameter if no errors occurred during the read, as modeled by an Error flag:

.. code:: ada

   procedure Read_T (Data : out T; Error : out Boolean) with
        Relaxed_Initialization => Data,
        Post => (if not Error then Data'Initialized);

Additionally, it would allow verifying initialization of data on algorithms
which defeat the current initialization verification techniques. Indeed, as
initialization is currently verified using flow analysis, it is sometimes
impossible to verify correct application of the current data initialization
policy. This happens in particular when control flow enforcing correct
initialization is value dependent:

.. code:: ada

   Data_Initialized := False;

   if Some_Property then
     Data := ...;
     Data_Initialized := True;
   end if;
   ...
   if not Data_Initialized then
     Data := ...;
   end if;

This kind of pattern could be verified by the tool by using
Relaxed_Initialization on Data. Indeed, checking of initialization of objects
with the Relaxed_Initialization aspect would be done using proof, so it would
have the advantages and disadvantages of the technique. In particular, values
of objects would be tracked precisely, provided enough manual annotations are
provided (loop invariants...).

Guide-level explanation
=======================

It is possible to disable the strong data initialization policy of SPARK by
using the Relaxed_Initialization aspect. Exempted objects are no longer
subjected to initialization checks usually enforced at subprogram boundaries.
The aspect can be supplied on an object declaration:

.. code:: ada

   type T is record
     F, G : Integer;
   end record;

   V : T with Relaxed_Initialization;

No initialization checks occur when such an object occurs in the global contract
of a subprogram:

.. code:: ada

   procedure Init_V_F with
     Global => (In_Out => V);

   Init_V_F; --  V does not need to be initialized, neither on procedure entry
             --  nor on procedure exit.

To achieve a similar behavior when V is a parameter of the subprogram, the
Relaxed_Initialization aspect can be put on the subprogram, to disable the
data initialization policy on its parameters or on its result if it is a
function:

.. code:: ada

   procedure P (X : in out T; Y : out T; Z : in T)
     with Relaxed_Initialization => (X, Y, Z);
   function F return T
     with Relaxed_Initialization => F'Result;

Note that subprograms with parameters with Relaxed_Initialization don't
necessarily need to be called on objects with Relaxed_Initialization. For
example:

.. code:: ada

  function Get_F (X : T) return Integer with
     with Relaxed_Initialization => X
          Pre => ...; -- only require X.F to be initialized, see below

  V : T := (others => 0);
  C : Integer := Get_F (V);

However, if the object supplied as a parameter call does not have
Relaxed_Initialization, then it is subjected to the SPARK initialization
policy. For example, such an example would be illegal:

.. code:: ada

     V : T;
     C : Integer;
   begin
     V.F := 0;
     C := Get_F (V); --  Here V needs to be completely initialized

Conversely, it is also possible to supply an object with Relaxed_Initialization
to a subprogram which does not expect such an object. Here again, the object
will be subjected to the usual data initialization policy of SPARK:

.. code:: ada

  function Get_G (X : T) return Integer;
     V : T with Relaxed_Initialization;
     W : T := (others => 0) with Relaxed_Initialization;
     C : Integer := Get_G (W); --  This is OK as W is entirely initialized
  begin
     V.G := 0;
     C := Get_G (V); --  Here there is an error, V is not completely initialized

Abstract states should be annotated with Relaxed_Initialization when they
contain objects which are subjected to the aspect. Such an abstract state can
only contain components with Relaxed_Initialization [ This restriction is
introduced to make it easier to split the work between flow analysis and
proof in the context of partially visible abstract states ].

Finally, it is also possible to put this aspect on a type. Objects and
subcomponents of such a type are always exempt from SPARK's data
initialization policy. For example, it is not generally necessary to initialize
the whole content of a stack at declaration. To allow this, all stack objects
should be handled using the relaxed initialization policy. We can achieve this
by annotating the Stack type with the Relaxed_Initialization aspect:

.. code:: ada

  type Stack is record
    Top     : Natural;
    Content : Nat_Array;
  end record with
    Relaxed_Initialization;

Then, if we declare an object of the type Stack, it will be as if the object was
annotated with the Relaxed_Initialization aspect. Note that annotating types
allows to use Relaxed_Initialization in a fine grain manner, having only a part
of an object annotated with this aspect:

.. code:: ada

  subtype R_Int is Integer with Relaxed_Initialization;
  type T_2 is record
    F : R_Int;
    G : Integer;
  end record;
  V : T_2;

Here V.F is exempted from the usual data initialization policy of SPARK while
V.G is not.

Objects annotated the Relaxed_Initialization aspect are still subjected to
checks required by the Ada RM. In particular:

- Scalar objects and subcomponents should be initialized when read. This
  includes copy in and copy out of scalar subprogram parameters. As a result,
  out parameters of a scalar type need to be initialized at the end of the
  subprogram, even if they are subjected to the Relaxed_Initialization aspect.

- Subtype predicates should hold when objects are accessed, as well
  as on default initialization of an object if it has at least one subcomponent
  with a default value, and on exit of subprograms for out and in out
  parameters.

As initialization policy is no longer enforced by the language, we need a way
to enforce it inside subprogram contracts. This can be done using the
'Initialized attribute. This attribute can be used on any expression
which is subjected to the Relaxed_Initialization aspect. It returns True if the
object or the subcomponent has been initialized (meaning that all its scalar
subcomponents have been initialized and it fulfills its subtype predicate if
any). For example, it can be used in subprogram contracts to describe which
parts of the subprogram's inputs and outputs should be initialized before and
after the call:

.. code:: ada

  function Get_F (X : T) return Integer with
     with Relaxed_Initialization => X
          Pre => X.F'Initialized;

or inside subtype predicates to describe the type's initialization policy:

.. code:: ada

  type Stack is record
    Top     : Natural;
    Content : Nat_Array;
  end record with
    Relaxed_Initialization,
    Predicate => Top'Initialized
      and then (for all I in 1 .. Top => Content (I)'Initialized);

From a tool point of view, an important thing to understand, is that the
Relaxed_Initialization aspect changes the verification technique used internally
to verify proper initialization of data. Without this aspect, initialization is
checked by flow analysis (menu Examine ... in GPS). With this aspect, these
checks are handed over to the proof (menu Prove ... in GPS). This means that, if
you are using the tool in mode Examine (bronze level), you will lose
initialization checks with this aspect.

This difference will also impact you if you are using the tool in mode Proof, as
flow analysis and proof require different levels of annotations. In particular,
proof techniques require users to annotate their subprograms with pre and
postconditions, they won't be inferred for you. If you are using a loop, you
may also need to supply an invariant.

Note that you can take advantage of this change from flow analysis to proof even
if you don't need to relax the data initialization policy of SPARK. You can
use it to verify algorithms which defeat flow analysis, in general because they
are value dependent. For example, assume that you are using two loops to
initialize an array, one to initialize the even elements to 0 and one to
initialize to odd elements to 1:

.. code:: ada

  A : Nat_Array;

  for I in 1 .. Max / 2 loop
    A (I * 2) := 0;
  end loop;
  for I in 1 .. (Max + 1) / 2 loop
    A (I * 2 - 1) := 1;
  end loop;

Verifying this kind of pattern using flow analysis is bound to failure as it
requires a value dependent analysis. However, this analysis is achievable by
proof, provided you add the appropriate loop invariants:

.. code:: ada

  A : Nat_Array with Relaxed_Initialization;

  for I in 1 .. Max / 2 loop
    A (I * 2) := 0;
    pragma Loop_Invariant
      (for all K in 1 .. I * 2 => (if K mod 2 = 0 then A (K)'Initialized));
  end loop;
  for I in 1 .. (Max + 1) / 2 loop
    A (I * 2 - 1) := 1;
    pragma Loop_Invariant
      (for all K in A'Range => (if K mod 2 = 0 then A (K)'Initialized));
    pragma Loop_Invariant
      (for all K in 1 .. I * 2 => A (K)'Initialized);
  end loop;
  pragma Assert (A'Initialized);

Reference-level explanation
===========================

Relaxed_Initialization aspect
-----------------------------

The idea is to have a way to check initialization by proof instead of doing it
in flow analysis. Using the Relaxed_Initialization aspect allows to define
precisely which (parts of) an object should be handled by flow analysis or
proof.

An object has `relaxed initialization` if either:

- it is annotated with the Relaxed_Initialization aspect,
- it is a formal parameter and it occurs in the Relaxed_Initialization aspect
  of its enclosing subprogram, or
- its subtype is annotated with Relaxed_Initialization.

An expression has `relaxed initialization` if either:

- its subtype has relaxed initialization,
- it is an object which has relaxed initialization,
- it is a component (indexed component, selected component, slice, and
  possibly dereference) of an expression which has relaxed initialization,
- it is a conversion/qualification of an expression which has relaxed
  initialization,
- it is a concatenation/an aggregate and one
  of its subexpressions has relaxed initialization,
- it is an if expression/a case expression and one
  of its dependant expressions has relaxed initialization, or
- it is a function call and the function called has a Relaxed_Initialization
  aspect applying to its result.

Rules:

* When assigning an expression which has relaxed initialization into an object
  which does not have it, a check is emitted (by proof) to make sure that this
  object is fully initialized (this also includes parameters before and after
  call statements).
* When assigning an expression which does not have relaxed initialization into
  an object which has relaxed initialization, flow analysis checks proper
  initialization as it used to do (this also includes in out parameters before
  call statements).
* When reading an expression which has relaxed initialization, initialization
  of scalars and subtype predicates are checked (by proof). Reading includes
  access of subcomponents, parameter passing… Most operators (except
  concatenation) on composite types are considered to read the components
  too.

Initialized attribute
---------------------

The initialized attribute can be used on any expression with relaxed
initialization. It is true when all scalar components have been initialized and
all applicable subtype predicates hold.
The correct application of this aspect could be defined as legality rules.

To avoid incorrect data dependencies, out parameters and global of mode Output
are considered to be de-initialized at the beginning of a procedure call. In this way,
proof will make sure that the value prior to the call is never read.

For execution, we could either implement an approximation of this aspect, or
use Valid_Scalars as a first approximation. For proof, it means adding a flag to
scalar subcomponents of expressions with relaxed initialization to remember if
they are initialized or not.
As it may happen that a scalar is valid even though it has not been initialized,
so negative occurrences of the Initialized attribute may be interpreted differently
in proof and for execution. To retain the closest correspondence possible
between proof and execution, we could avoid assuming that ‘Initialized is
false in proof when a scalar is not initialized / on out parameters / globals
of mode Output and rather assume nothing. Here is an example:

.. code:: ada

  X : Integer;
  pragma Assert (not X'Initialized);

If X'Initialized is interpreted at runtime as X'Valid_Scalars, then the above
assertion will fail on most platforms. Indeed, any initial value for X will be
a valid integer value. Thus, GNATprove should not be able to prove the
assertion.

Interactions with flow related constructs
-----------------------------------------

Relaxed_Initialization should have no impact on generation of globals and
verification of Depends contracts.

The meaning of initialization related annotations, such as the Global contracts,
as well as the Initializes and Default_Initial_Condition aspects, are
slightly different for objects or types with Relaxed_Initialization.
Since mode Output of Global contracts no longer enforces initialization, it is
now possible to use it for partly initialized data, in place of mode In_Out. For
example, for a procedure initializing only one field of a record, we can use
either In_Out or Output:

.. code:: ada

  procedure Init_F with
    Global => (In_Out => V);
  procedure Init_G with
    Global => (Output => V);

However, to remain consistent with dependency contracts, we should not allow
reading the input value of a parameter of mode Output, both inside the
subprogram and afterward. For example, Init_F above can be supplied with a
contract stating that it preserves G, whereas Init_G cannot preserve F:

.. code:: ada

  procedure Init_F with
    Global => (In_Out => V),
    Post   => V.F'Initialized and V.G'Initialized = V.G'Initialized'Old;
  procedure Init_G with
    Global => (Output => V),
    Post   => V.F'Initialized = V.F'Initialized'Old; --  incorrect

In practice, it means havocking the initialization flag for Globals of mode
Output when they are specified (nothing is needed when they are inferred by
flow analysis, as, in this case, we are sure that the whole variable has been
written).

Mentioning an object with Relaxed_Initialization in an Initialize contract
is allowed for the sake of highlighting the dependency relations. It does not
imply however that the object is initialized after the package elaboration. To
express such a requirement, we should use Initial_Condition instead:

.. code:: ada

   package My_Pack with
     Initialize => (X => V),
     Initial_Condition => X.F'Initialized
   is
     X : T with Relaxed_Initialization;
     ...
   end My_Pack;

   package body My_Pack is
     ...
   begin
     X.F := V;
   end My_Pack;

If a type has Relaxed_Initialization, it can have a Default_Initial_Condition
which is not False, but, here again, it does not mean that the type is
completely initialized by default. If we want to know that it is initialized,
we can state it in the Default_Initial_Condition:

.. code:: ada

  type My_Stack is private with
    Default_Initial_Condition => Is_Empty (My_Stack);

  type My_Stack_Init is private with
    Default_Initial_Condition =>
      My_Stack'Initialized and then Is_Empty (My_Stack);

Rationale and alternatives
==========================

We have thought of only allowing Relaxed_Initialization on scalar types and
inheriting it on composite types, but it was considered too constraining. In
particular, it has the disadvantages of:

- Needing a new type (or several) each time we want to have a partially
  initialized object,
- Not allowing to have two convertible (record) types, one with a relaxed
  initialization and the other without.

We have considered reusing Valid_Scalars to mean initialized, but it was
considered awkward as it can be applied to a single scalar, and does not
include subtype predicate checking.

We have considered using a pragma Annotate (GNATprove, Relaxed_Initialization,
V); to mean that a variable V has relaxed initialization, but it was more
cumbersome than an aspect, and was a bit complicated (and heavy) when applied
to function parameters.

Drawbacks
=========

- It is an important implementation effort
- It will most probably generate corner cases complicated to handle as it is
  at the interface between flow analysis and proof and this interface is
  already complicated to deal with.

Prior art
=========

We did prototype this idea in GNATprove but with a simpler scope
(Relaxed initialization could only be supplied on scalar types and types with
relaxed initialization and types without could not be mixed).

Unresolved questions
====================

- This feature can probably have complicated interactions with tagged types and
  dispatching. Maybe it would be better to just disallow them.
- I have not thought about type invariants.
- We probably want to enforce initialization checks on intrinsic operators and
  predefined equality. Should we disallow parameters with relaxed initialization
  on them?
- Should we disallow relaxed initialization on scalar parameters / scalar result
  of functions?
- Should Relaxed_Initialization be inherited by subtypes?
- Maybe we should prevent use of ‘Initialized in code (non-ghost code).
- Maybe we should disallow storing types with Relaxed_Initialization inside
  types without to avoid complicated interactions between flow analysis and
  proof.
- What is the best executable semantics for ‘Initialized

Future possibilities
====================

- We could have a special handling of "dummy" initialization that is used in
  many cases in industry for defensive coding. Maybe only for scalar variables. 
  So that the initialisation is ignored in:

.. code:: ada

   V : T := Dummy with Partial_Initialization;

- Maybe we could translate ‘Valid as ‘Initialized for SPARK when used on types
  with relaxed initialization. Currently, objects are always assumed to be
  valid in SPARK.
