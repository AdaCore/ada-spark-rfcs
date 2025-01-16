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

It is possible to declare empty public or private views either with an empty `record end record` section, or the shorthands `null record` syntax.

For example, all of the following type declarations are legal:

.. code-block:: ada

   package Legal is
      type R1 is null record with private;  -- This syntax is supported for declaring an empty public view

      type R2 is record
         Pub : Integer;
      end record
      with private;

      type R3 is record
      end record with private;  -- This record type has both public and private views empty

      -- Same as R1, R2, R3 in tagged type forms

      type T1 is tagged null record with private;

      type T2 is tagged record
         Pub : Integer;
      end record
      with private;

      type T3 is tagged null record with private;

   private

      type R1 is record
         Priv : Integer;
      end record;

      type R2 is record
      end record;

      type R3 is null record;  -- This record type has both public and private views empty

      type T1 is tagged record
         Priv : Integer;
      end record;

      type T2 is tagged null record;

      type T3 is tagged null record;

   end Legal;

As outlined in the example, it is legal to declare both public and private views as empty.

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

