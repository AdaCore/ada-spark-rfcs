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
a tagged record can have primitives declared both in the public and the private
part. This is possibility is extended to other components as well. The existence
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

   private

       type R is record
         procedure P2 (Self : in out R; V : Integer);
       end R;

       type T is class record
          procedure P2 (Self : in out T; V : Integer);
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

   end P;

Primitives declared within a type can only be called via prefix notation. When
primitives are declared in a scope, there can no longer be primitives declared
ouside of the scope, such declarations are non-primitives.

A new aspect is introduced, Scoped_Primitives, to allow to mark a type as
following the scoped primitive model even if no explicit primitives are scoped.

Once a tagged hierarchy is marked as receiving scoped primitives, it can no
longer go back to the previous way of declaring primitives.

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

Interfaces
----------

Interfaces can now be specified with "interface record", but otherwise
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
      type T1 is tagged record
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

