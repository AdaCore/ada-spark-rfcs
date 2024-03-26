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

The new class model is incompatible with the current tagged object model. In
order to make the distinction, new tagged types will be marked with the new
class reserved word:

.. code-block:: ada

   type A_Class is class record
      null;
   end A_Class;

This is another flavor of record, that can also accept `limited` and
distriminants, e.g.:

.. code-block:: ada

   type A_Class (X : Boolean) is limited class record
      null;
   end A_Class;

Note that as part of this proposal, the syntax `end <name>;` is accepted instead
of `end record;`. This is the only syntax available for classes, and optionally
allowed for other record types.

Reference-level explanation
===========================

Rationale and alternatives
==========================

The syntax for classes is inspired by tagged types. We could instead have
a syntax inspired by task or protected types, e.g.:

.. code-block:: ada

   class type I is
      F : Integer;

      procedure P (Self : in out T1; V : Integer);
   end I;

Drawbacks
=========


Prior art
=========

Unresolved questions
====================

Future possibilities
====================

