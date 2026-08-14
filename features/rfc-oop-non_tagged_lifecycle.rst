- Feature Name:
- Start Date:
- RFC PR:
- RFC Issue:

Summary
=======

Motivation
==========

Constructors have been added to tagged and class types in Flare. They also need
to be added to regular record types, as we need to promote non OOP usage when
necessary and useful. However, non-tagged types introduce a different kind of
derivation that needs to be described in its own right. Another issue relates
to by-copy vs. by-reference parameter passing: we need to ensure that
constructors (and in particular the copy constructor) are properly described
here.

This proposal also describes the behavior of 'Assign and 'Destructor.

Guide-level explanation
=======================

Constructors
------------

Constructors can be provided to non-tagged non-class types with the same
syntax as class types, by adding a constructor in their scope, e.g.:

.. code-block:: ada

   type B is record

      F : Integer;

      procedure B'Constructor (Self : in out B; V : Integer);

   end B;

Constructors can then be implemented as other scoped primitives:

.. code-block:: ada

   type body B is

      procedure B'Constructor (Self : in out B; V : Integer) is
      begin
         Self.F := V;
      end B'Constructor;

   end B;

Rules on initialization lists, component initialization, default constructors
and constructor calls are all the same as for tagged constructors. The only
difference is that non-tagged constructors do not have a Super invocation.

Assign
------

'Assign is provided for record types similar to tagged types. It is called
in place of copy where the object to be assigned has to be modified (i.e.,
otherwise that's a copy constructor call), and is expected to perform the
actual copy. The From parameter refers to the original source object, is
passed by reference, and is not expected to be modified. As for tagged
types, From is typed after the root type of the derivation chain, so that
conversions can be handled. However, as calls are static, the compiler is
expected to optimize the calls when necessary, in particular replacing them
by binary copies when possible. E.g.:

.. code-block:: ada

   type Root is record
      procedure Root'Assign (Self : in out Root; From : Root);
   end Root;

   type Child is new Root with record
      procedure Child'Assign (Self : in out Child; From : Root);
   end Child;

   V : Root;
   W : Child;

   W := Child (V); -- calls Assign on Child, statically resolved.

Assign and Mutable Discriminants
--------------------------------

There is one case where an assignment does not lead to a call to 'Assign:
mutable objects, i.e. objects whose discriminants have default values and
may change through assignment. When the source and the target of an
assignment have different discriminant values, the target cannot be
modified in place by 'Assign: it first needs to be destroyed, then
re-created with the new constraints. The compiler inserts a check on the
discriminants and expands the assignment into a call to 'Destructor
followed by a call to the by-copy constructor when they differ. E.g.:

.. code-block:: ada

   type Rec (V : Boolean := False) is record

      case V is
         when True =>
            A : Integer;

         when False =>
            B : Float;
      end case;

      procedure Rec'Constructor (Self : in out Rec; From : Rec);
      procedure Rec'Destructor (Self : in out Rec);
      procedure Rec'Assign (Self : in out Rec; From : Rec);

   end Rec;

   R1 : Rec := Rec'(V => True, A => 1);
   R2 : Rec := Rec'(V => False, B => 1.0);

begin

   R1 := R2;
   --  if R1.V /= R2.V then
   --     R1'Destructor;
   --     Rec'Constructor (R1, R2);
   --  else
   --     R1'Assign (R2);
   --  end if;

As a consequence, a mutable type that does not provide a by-copy
constructor cannot be assigned.

Note that this issue is specific to non-tagged types: class records with
defaulted discriminants do not exist, so the discriminants of a class
object can never change through an assignment.

Destructors
-----------

Destructors can be provided to non-tagged non-class types with the same
syntax as class types, e.g.:

.. code-block:: ada

   type B is record

      F : access Integer;

      procedure B'Destructor (Self : in out B);

   end B;

As for tagged types, the destructor is called when the object reaches the
end of its lifetime. It may also be called as part of an assignment that
changes the constraints of a mutable object, prior to the by-copy
construction of the new value, as described in the OOP aggregates and
assignments RFC. As for other non-tagged operations, calls are static and
the compiler is expected to optimize them when possible.

On simple derivation, the destructor is inherited by the derived type,
which may replace it by declaring its own. Consistent with constructors,
there is no Super invocation: the destructor of the derived type is
responsible for the whole destruction (which it can fully perform, since
simple derivation cannot add components).

Simple Derivation
-----------------

When performing simple derivation, derived types "inherit" all constructors
of the parent type. They may add or remove constructors. However, unlike
tagged derivation, 'Super is not available: there is no concept of "calling
the parent constructor" (or the parent destructor or assign). An operation
declared on the derived type fully replaces the parent's one, and is alone
responsible for the whole operation. For example:

.. code-block:: ada

   type Root is record

      F : Integer;

      procedure Root'Constructor (Self : in out Root; V : Integer);
      procedure Root'Constructor (Self : in out Root; V : String);

   end Root;

   type Child is new Root with record
      --  This cannot add components, only primitives and constructors / destructors

      procedure Child'Constructor (Self : in out Child; V : Integer) is abstract; -- removing constructor
      procedure Child'Constructor (Self : in out Child; V : Float);
   end Child;

   R1 : Root := Root'Make (1);     -- legal
   R2 : Root := Root'Make ("1");   -- legal
   C1 : Child := Child'Make (1.0); -- legal
   C2 : Child := Child'Make (1);   -- illegal
   C3 : Child := Child'Make ("1"); -- legal

Parameter Passing
-----------------

Parameters can be passed by reference or by copy as long as the record type
does not provide any by-copy constructor. If a by-copy constructor is provided,
then the compiler must pass any object as a reference, similar to tagged or
limited types. E.g.:

.. code-block:: ada

   type A is record

      F : Integer;

      procedure A'Constructor (Self : in out A);
   end A;

   type B is record
      procedure B'Constructor (Self : in out B; From : B);
   end B;

   procedure P1 (V : in out A); -- V may be passed by copy or reference
   procedure P2 (V : in out B); -- V has to be passed by reference

Reference-level explanation
===========================

Rationale and alternatives
==========================

Why record in addition to tagged/class records?
-----------------------------------------------

Support for regular records in addition to class and tagged records adds some
level of complexity in the language that in some respects could be avoided.
However, these types are much more effective at run-time as they don't require
dispatching, and the compiler may be able to optimize calls more effectively.
They should be favored whenever inheritance is not necessary, and they are as
flexible as tagged/class types for most lifetime operations.

Drawbacks
=========

Prior art
=========

Unresolved questions
====================

Future possibilities
====================


