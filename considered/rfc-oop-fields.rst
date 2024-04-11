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

A record and tagged record type can now have 3 declarative
region where fields can be declared:

- the package public view
- the package private view
- the record private view

A public view that allows for additional fields to be declared is denoted by
`with private` after its declaration. The private view of a record type can
then be split between its own public and private sections:

For example:

.. code-block:: ada

   package P is
      type R is record
         Pub : Integer;
       end R
       with private;

       type T is tagged record
          Pub : Integer;
       end T
       with private;

   private

      type R is record
         Priv : Integer;
      private
         Hidden : Integer;
      end R;

       type T is tagged record
         Priv : Integer;
       private
         Hidden : Integer;
       end T;
   end P;

Fields that are private to a type (noted `Hidden` in the above example) can
only be accessed through the primitives, constructors and destructors of that
very type. They are inaccessible to other subprograms, notably non-primitive
or overriden primitives.

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

