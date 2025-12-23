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
necessary and useful. However, non-tagged type introduce a different kind of
derivation that needs to be described in its own right. Another issue relates
to by-copy v.s. by-reference parameter passing, we need to ensure that
constructors (and in particular copy constructor) are properly described here.

This proposal also describe the behavior of 'Clone.

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

Constructor can then be implemented as other scoped primitives:

.. code-block:: ada

   type body B is record

      procedure B'Constructor (Self : in out B; V : Integer) is
      begin
         Self.F := V;
      end B'Constructor;

   end B;

Rules on initialization lists, component initialization, default constructors,
constructors calls, are all the same as for tagged constructors. The only
difference is that non-tagged constructors do not have a Super invocation.

Clone and Adjust
----------------

Clone and Adjust are provided for record types smilar to tagged types. However,
as calls are static, the compiler is expected to optimize the calls when
necessary.

In the context of a conversion, which is one of the main reason why both
Clone and Adjust are necessary, Clone is called on the source type while
Adjust is on the destination type. E.g.:


.. code-block:: ada

   type Root is record
      procedure Root'Clone (Self : Root; To : in out Root);
      procedure Root'Adjust (Self : in out Root; From : Root);
   end Root;

   type Child is new Root with record
      procedure Child'Clone (Self : Child; To : in out Child);
      procedure Child'Adjust (Self : in out Child; From : Root);
   end Child;

   V : Root;
   W : Child;

   W := Child (V); -- calls Clone on Root, then Adjust on Chidl.

Simple Derivation
-----------------

When performing simple derivation, derived types "inherits" from all constructors
of the parent type. It may add or remove constructors. However, unlike tagged
derivation, there's no concept of calling the Super constructor in the derived
type. For example:

.. code-block:: ada

   type Root is record

      F : Integer;

      procedure Root'Constructor (Self : in out Root; V : Integer);
      procedure Root'Constructor (Self : in out Root; V : String);

   end Root;

   type Child is new Root with record
      --  This cannot add components, only primitives and constructors / destructors

      procedure Child'Constructor (Self : in out Child; V : Integer) is abstract; -- removing constructor
      procedure Child'Constructor (Self : in out Chidl; V : Float);
   end Child;

   R1 : Root := Root'Make (1);     -- legal
   R2 : Root := Root'Make ("1");     -- legal
   C1 : Child := Child'Make (1.0); -- legal
   C2 : Child := Child'Make (1);   -- illegal
   C3 : Child := Child'Make ("1");   -- legal

Parameter Passing
-----------------

Parameters can be passed by reference or by copy as long as the record type
does not provide any by-copy constructor. If a by-copy constructor is provided,
then the compiler must pass any object as a reference, similar to tagged or
limited types. Eg.:

.. code-block:: ada

   type A is record

      F : Integer;

      procedure A'Constructor (A : in out A);
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

Support for regular record in addition to class and tagged record adds some
level of complexity in the language that to some respect could be avoided.
However, these types are much more effective at run-time as they don't require
dispatching, and the compiler may be able to optimize calls more effectively.
They should be favored whenever inheritance is not necessary, and as flexible
as tagged/class type for most lifetime operations.

Drawbacks
=========

Prior art
=========

Unresolved questions
====================

Future possibilities
====================


