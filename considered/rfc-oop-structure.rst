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




TBD TBD TBD - separate fields and primitives





Class declaration
-----------------

The new class model is incompatible with the current tagged object model. In
order to make the distinction, new tagged types will be marked with the new
class reserved word:

.. code-block:: ada

   type A_Class is class record
      null;
   end A_Class;

Primitives and components declarations
--------------------------------------

This new way of organizing components and primitives is available to both class
records and simple records.

Under this new model, controlling primitives are declared within the lexical
scope of their type. The first parameter of the primitive has to be of the type
of the record. This allows the user to decide on the naming convention, as well
as the mode of such parameter (in, out, in out, access, aliased). A record and
a class record can have primitives declared both in the public and the private
part. This is possibilty is extended to other components as well. The existence
of a private part needs to be specified in the public part of a package with
the notation "with private". The following demonstrates the above:

.. code-block:: ada

   package P is
      type T1 is record
         F : Integer;

         procedure P (Self : in out T1; V : Integer);
       end T1
       with private;

       type T2 is class record
          F : Integer;

          procedure P (Self : in out T2; V : Integer);
       end T2
       with private;

   private

       type T1 is record
         F2 : Integer;

         procedure P2 (Self : in out T1; V : Integer);
       end T1;

       type T2 is class record
          F2 : Integer;

          procedure P2 (Self : in out T2; V : Integer);
       end T2;

   end P;

   package body P is

       type body  T1 is record
         procedure P (Self : in out T1; V : Integer) is
         begin
            Self.F := V;
         end P;

         procedure P2 (Self : in out T1; V : Integer) is
         begin
            Self.F2 := V;
         end P2;
       end T1;

       type body T2 is record
         procedure P (Self : in out T2; V : Integer) is
         begin
            Self.F := V;
         end P;

         procedure P2 (Self : in out T2; V : Integer) is
         begin
            Self.F2 := V;
         end P2;
       end T2;

   end P;

In this model, it is not possible to write record types primitives outside of
the scope anymore. Subprograms declared outside of such scope are just regular
subprograms.

As a consequence, it's not possible anymore to have a record or a class record
as a completion of a private type. This type now needs to be marked either
record private, or be a regular record with a private extension. For example:

.. code-block:: ada

   package P is
      type T1 is record private;

      type T2 (<>) is record private;
      -- T2 is completed by a class, it has to be indefinite private view

      type T3 is record
         procedure P (Self : T3);
      end T3
      with private;

   private

       type T1 is record
         F2 : Integer;

         procedure P2 (Self : in out T1; V : Integer);
       end T1;

       type T2 is class record
          F2 : Integer;

          procedure P2 (Self : in out T2; V : Integer);
       end T2;

       type T3 is record
          null;
       end T3;
   end P;

As for tagged types, there's a shortcut for a class private type, which means no
public primitives or components:

.. code-block:: ada

   package P is
      type T1 is class private;
   private
      type T1 is class record
         F2 : Integer;

         procedure P2 (Self : in out T1; V : Integer);
       end T1;
   end P;

Class record can still be limited or have discriminants, in which cases the set
of constaints that they have follow similar rules as for tagged types.

Visibilty rules are the same as for types today. In particular, a class instance
as access to private components of other instances of the same class.

Class-private components
------------------------

Similarly to a nested package, it is possible to introduce "class private" fields
in the completion of a class type. These fields will only be visible to the
operations declared in the scope of the class. For example:

.. code-block:: ada

   package P is
      type T1 is class private;
   private
      type T1 is class record
         F2 : Integer;

         procedure P2 (Self : in out T1; V : Integer);

       private
         F3 : Integer; -- only accessible from operation of T1
       end T1;
   end P;

Entities outside of the T1 scope or children of T1 won't have access to this field.

Overriding and extensions
-------------------------

Extension of class record types work similarly to tagged records:

.. code-block:: ada

   package P is
      type T1 is class record
         procedure P (Self : in out T1);
      end T1;

      type T2 is new T1 with record
         procedure P (Self : in out T1);
      end T2;
   end P;

Primitives can be marked optionally overriding, following Ada 2005 rules.
Inheritance model is single interitance of a class, multiple inheritance of interfaces.

Interfaces and abstract types
-----------------------------

Intefaces and abstract types work the same way as for tagged types.
Interfaces are specified differently, through "interface record", but otherwise
operate as other interfaces (no concrete components or primitive):

.. code-block:: ada

   package P is
      type I is interface record
         procedure P (Self : in out I) is abstract;
      end I;
   end P;

Operators
---------

TBD TBD TBD





   This means that parameters that are the same at top level may
differ when deriving:

Operators can be declared as primitives:

.. code-block:: ada

   package P is
      type T1 is class record
         procedure "=" (Left, Right : T1);
      end T1;

      type T2 is new T1 with record
         procedure "=" (Left : T2; Right : T1);
      end T1;
   end P;

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

