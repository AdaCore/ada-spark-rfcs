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

Record, tagged records and class records can declare destructors. The
destructor needs to be called "final", taking an in out to the object:

.. code-block:: ada

   package P is
      type T is tagged record
         final T (Self : in out T1);
      end record;

      type T2 is new T with record
         final T2 (Self : in out T2);
      end record;
   end P;

An "unscoped" syntax for destructor is also available:

.. code-block:: ada

   package P is
      type T is tagged null record;
      for T'Destructor use My_Destructor;

      procedure My_Destructor (Self : in out T1);

      type T2 is new T with null record
      with Destructor => My_Destructor;

      procedure My_Destructor (Self : in out T2);
   end P;

The destruction sequence works in the following way:
- If a type has an explicit destructor, it is first called.
- If a type has components hierarchy, wether or not it has an explicit
  destructor, the destructor sequence is called on each components.
- If a type is in a tagged hierarchy, wether or not it has an explicit
  destructor, the parent destructor sequence is called.

Destructors are called following the same rules as Ada finalization.


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
