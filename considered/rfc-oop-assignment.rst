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

A new syntax is provided to all types to allow to override assignment:

.. code-block:: ada

   type T is null record;

   procedure ":=" (Destination : in out T; Source : T);

This capability is meant to replace use cases of `Adjust` in controlled types.
However, it is not a 1-to-1 replacement, as `Adjust` is called after a binary
copy and allows to modify the results, while these two subprogram are
responsible to copy and assign a value respectively.

Note that this operation is not called when initializing an object. Notably:

.. code-block:: ada

      V1 : T;
      V2 : T := V1; -- This is an initialization, calls copy constructor
   begin
      V2 := V1; -- This is an assignment, calling ":="

Initialization override is controlled by other mechanism, notably so-called
copy constructors.

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
