- Feature Name: Standard OOP model
- Start Date: May 5th 2020
- RFC PR:
- RFC Issue:

Summary
=======

Motivation
==========

Guide-level explanation
=======================

A new attribute `'Super` is introduced, and can be applied to a class type, a
tagged type, or an object of these types.

In the case of a type, it refers to its direct parent. E.g.:

.. code-block:: ada

   type T1 is tagged null record;

   procedure P (V : T1);

   type T2 is tagged null record;

   procedure P (V : T2);

   type C1 is class record
      procedure P (V : C1);
   end C1;

   type C2 is class record
      procedure P (V : C2);
   end C2;

   V1 : T2'Super; -- V1 is of type T1

   V2 : C2'Super; -- V2 is of type C1

In the case of an object, it refers to the parent of the static type of that
object. For example:

.. code-block:: ada

  procedure Call (V : T2'Class) is
  begin
     V'Super (V).P; -- static call to T1.V
  end Call;

  procedure Call (V : C2) is
  begin
     V'Super (V).P; -- static call to C1.V
  end Call;

Note that while the value of `'Super` is always statically known, it may
not be directly visible in the code. For example:

.. code-block:: ada

  package P is
     type A is tagged record with private;
     type B is new A with private; -- B'Super is C,
   private
     type A is tagged record with private;
     type C is new A with null record.
     type B is new C with private;
   end P;

   type Root is tagged null record;
   type Child is new Root with null record;

   generic
      type T is new Root with private;
   package G is
      -- T'Super is only known at instantiation time
   end G;

   package I1 is new G (Root); -- T'Super is Root
   package I1 is new G (Child); -- T'Super is Child

Reference-level explanation
===========================

Rationale and alternatives
==========================

Drawbacks
=========

Prior art
=========

Unresolved questions
====================

Future possibilities
====================
