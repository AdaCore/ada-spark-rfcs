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

A record and tagged record type can now have 3 declarative regions where fields
can be declared:

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

In addition to the above, it is possible to add a `private` section within the
record itself:

.. code-block:: ada

   package P is
      type R is record
         Pub : Integer;
       private
         Pub_Hidden : Integer;
       end record
       with private; -- There are more fields in the private view

       type T is tagged record
          Pub : Integer;
       private
          Pub_Hidden : Integer;
       end record
       with private; -- There are more fields in the private view

   private

      type R is record
         Priv : Integer;
      private
         Priv_Hidden : Integer;
      end record;

       type T is tagged record
         Priv : Integer;
      private
         Priv_Hidden : Integer;
       end record;
   end P;

Fields that are private to a type can only be accessed if:
- The field is visible from the package visibilty rules
- The access in a primitive of that type, or a primitive of a derived type.

This is similar to the `protected` visibility level of languages such as Java
or C++.

For example:

.. code-block:: ada

   package P is
      type Root is record
         Pub : Integer;
      private
         Pub_Hidden : Integer;
      end record;

      procedure Primitive (Self : Root);

      type Child is new Root with null record;

      procedure Primitive (Self : Child);

      package Other is
         procedure Non_Primitive (Self : Root);
      end Other;
   end P;

   package body P is
      procedure Primitive (Self : Root) is
      begin
         Self.Pub := 1; -- OK
         Self.Pub_Hidden := 1; -- OK
      end Primivite;

      procedure Primitive (Self : Child) is
      begin
         Self.Pub := 1; -- OK
         Self.Pub_Hidden := 1; -- OK
      end Primivite;

      package Other is
         procedure Non_Primitive (Self : Root) is
         begin
            Self.Pub := 1; -- OK
            Self.Pub_Hidden := 1; -- Compilation Error
         end Non_Primitive;
      end Other;
   end P;

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

