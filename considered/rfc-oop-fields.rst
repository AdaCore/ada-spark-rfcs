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

Components declarations
-----------------------

A record and tagged record type can now have 2 declarative regions where fields
can be declared:

- the package public view
- the package private view

A public view that allows for additional fields to be declared is denoted by
`with private` after its declaration. The private view of a record type can
then be split between its own public and private sections:

For example:

.. code-block:: ada

   package P is
      type R is record
         Pub : Integer;
       end record
       with private; -- There are more fields in the private view

       type T is tagged record
          Pub : Integer;
       end record
       with private; -- There are more fields in the private view

   private

      type R is record
         Priv : Integer;
      end record;

       type T is tagged record
         Priv : Integer;
       end record;
   end P;

Visibilty rules of these fields are following the usual package-visibilty rules.

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

