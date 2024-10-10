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

This is an extension of the extension of visibility sections of components.

Record can now declare both a public part and a private part, both in their
partial and full views, e.g.:

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