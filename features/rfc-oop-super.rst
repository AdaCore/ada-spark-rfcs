- Feature Name: Standard OOP model
- Start Date: May 5th 2020
- Status: Production

Summary
=======

Motivation
==========

Guide-level explanation
=======================

'Super attribute
----------------

A new attribute `'Super` is introduced, and can be applied to a an object of
these types. It refers to a static view of the object typed after the parent and
can be used to make non dispatching calls. For example:

.. code-block:: ada

   type T1 is tagged null record;

   procedure P (V : T1);

   type T2 is new T1 with null record;

   procedure P (V : T2);

   procedure Call (V : T2'Class) is
   begin
     V'Super.P; -- non-dispatching call to T1.V
   end Call;

Note that `'Super` being used to make non dispatching calls to primitives using
the parent view, it is only available is said view is of a derived type (there'S
no primitive to call otherwise).

Reference-level explanation
===========================

TBD

Rationale and alternatives
==========================

TBD

Drawbacks
=========

Prior art
=========

Unresolved questions
====================

Future possibilities
====================
