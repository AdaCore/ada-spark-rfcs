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

Primitives and Declarations
---------------------------

Under this new model, primitives are declared within the lexical scope of their
type. The first parameter of the primitive has to be of the type of the record.
This allows the user to decide on the naming convention, as well as the mode of
such parameter (in, out, in out, access, aliased). A record and
a class record can have primitives declared both in the public and the private
part. This is possibilty is extended to other components as well. The existence
of a private part needs to be specified in the public part of a package with
the notation "with private". The following demonstrates the above:

.. code-block:: ada

   package P is
      type R is record
         F : Integer;

         procedure P (Self : in out R; V : Integer);
       end R
       with private;

      type T is tagged record
         F : Integer;

         procedure P (Self : in out T; V : Integer);
      end T
      with private;

      type C is class record
         F : Integer;

         procedure P (Self : in out C; V : Integer);
      end C
      with private;

   private

       type R is record
         procedure P2 (Self : in out R; V : Integer);
       end R;

       type T is class record
          procedure P2 (Self : in out T; V : Integer);
       end T;

       type C is class record
          procedure P2 (Self : in out C; V : Integer);
       end T;

   end P;

   package body P is

       type body R is record
         procedure P (Self : in out R; V : Integer) is
         begin
            Self.F := V;
         end R;

         procedure P2 (Self : in out R; V : Integer) is
         begin
            Self.F := V + 1;
         end P2;
       end R;

       type body T is tagged record
         procedure P (Self : in out T; V : Integer) is
         begin
            Self.F := V;
         end R;

         procedure P2 (Self : in out T; V : Integer) is
         begin
            Self.F := V + 1;
         end P2;
       end T;

      type body C is class record
         procedure P (Self : in out C; V : Integer) is
         begin
            Self.F := V;
         end R;

         procedure P2 (Self : in out C; V : Integer) is
         begin
            Self.F := V + 1;
         end P2;
       end C;

   end P;

Primitives declared within a type can only be called via prefix notation. In
the specific case of a class record, subprogram declared outside of the lexical
scope are not primitive (they can't be called via prefix notation, they can't
be overriden).

A direct consequence of the above is that it's not possible anymore to have a
record or a class record as a completion of a private type. This type now needs
to be marked either record private, or be a regular record with a private
extension. For example:

.. code-block:: ada

   package P is
      type T1 is record private;

      type T2 (<>) is record private;
      -- error, T2 is completed by a class, it has to be indefinite private view

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

Operators can be declared as primitives:

.. code-block:: ada

   package P is
      type T1 is class record
         function "=" (Left, Right : T1) return Boolean;
         function "+" (Left, Right : T1) return T1;
      end T1;

      type T2 is new T1 with record
         procedure "=" (Left : T2; Right : T1);
         function "+" (Left : T2, Right : T1) return T1;
      end T1;
   end P;

Note that when overriding an operator, only the first parameter changes to the
current class type.

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

