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
      end T1;

      type T2 is new T with record
         final T2 (Self : in out T2);
      end T1;
   end P;

The destruction sequence works in the following way:
- If a type has an explicit destructor, it is first called.
- If a type has components hierarchy, wether or not it has an explicit
  destructor, the destructor sequence is called on each components.
- If a type is in a tagged hierarchy, wether or not it has an explicit
  destructor, the parent destructor sequence is called.

Destructors are not equivalent to finalization. A destructor for an object is
only called if the memory associated to the object is deallocated because:
- it is declared in a stack and the stack gets out of scope
- it is declared in another record that is itself getting deallocated
- it is explicitely deallocated by Unchecked_Deallocation

Notably and contrary to Ada finalization, destructors are not called if there's
no static or explicit destruction of the object. A destructor on an object
created on the heap which is never deallocated never get called.

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
