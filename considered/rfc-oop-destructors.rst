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


Record and class record can declare destructors. The
destructor needs to be called "final", taking an in out to the object:

.. code-block:: ada

   package P is
      type T is class record
         final T (Self : in out T1);
      end T1;

      type T2 is class record
         final T2 (Self : in out T2);
      end T1;
   end P;

In hierarchies, destructors are implicitely called in sequence - the parent
destructor is always called after its child.

When composing objects together, fields that have destructors are called after
the containing object (you destroy from the outermost to the innermost, reverse
of the construction order).

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
