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

Records can now declare both a public part and a private part, both in their
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

To explain the visibility rules associated with the new public and private parts, we define the concept of _package-visibility_ which is associated with the public and private sections in a package declaration, and the concept of _type-visibility_ which is associated with the new public and
private sections in a record declaration. When discussing package-visibility, the terms _partial view_ and _full view_ are used to denote respectively the type declaration in the public section of a package, and the corresponding type declaration in the private section of that package.

The notions of package-visibility and type-visibility are somewhat independent because a type-public section can occur in the partial view and in the full view of a type, and the same is true for the type-private section.

Package-visibility is meant to control visibility from other package specs/bodies, child package specs/bodies, and nested package specs/bodies. These visibilty rules are already part of the Ada specification and need not be repeated here.

Type-visibility is meant to control visibility from primitive subprograms of the type, and non-primitive subprograms of the type. An expression in a primitive subprogram of a type has visibility over type-public and type-private components, as well as the type-public and type-private components of extended types. An expression outside of a primitive subprogram only has visibility to type-public sections of the type and type-public sections of extended types.

Both package-visibility and type-visibility must be satisfied to access a component. Thus a component is visible if and only if both package-visibility and type-visibility make it visible.

This new mechanims offers a feature similar to the `protected` visibility level of languages such as Java or C++. For example, in the following declarations `Pub_Hidden` is visible in primitives of `Root` and of derived types, and invisible otherwise.

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
