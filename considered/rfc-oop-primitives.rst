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

Class objects
-------------

A new type of type is introduce, the `class` type. This type operates similarly
to tagged type (there are even situations where it can be derived from one)
with a number of differences:

- It's always a by-constructor type
- It cannot have coextensions (so no access-type discriminants)
- It primitives must follow the rules of First_Controlling_Parameter
- It always follows the rules of Default_Dispatching_Calls
- Primitives need to be declared within its scope - operations declared outside
  of its scope are not primitives.

When scoped, primitives need also to be defined in the scope of the type itself,
which leads to the introduction of a body section of the type in package
bodies. The following demonstrates the above:

.. code-block:: ada

   package P is
      type R is class record
         F : Integer;

         procedure Prim (Self : in out R; V : Integer);
       end record
       with private;

       procedure Not_A_Prim (Self : in out V);

   private

       type R is class record
         procedure Prim_2 (Self : in out R; V : Integer);
       end record;

   end P;

   package body P is

      type body R is record
         procedure Prim (Self : in out R; V : Integer) is
         begin
            Self.F := V;
         end record;

         procedure Prim_2 (Self : in out R; V : Integer) is
         begin
            Self.F := V + 1;
         end Prim_2;
       end record;

      procedure Not_A_Prim (Self : in out V) is
      begin
         null;
      end Not_A_Prim;

   end P;

Primitives declared within a type can only be called via prefix notation. When
primitives are declared in a scope, there can no longer be primitives declared
ouside of the scope, such declarations are non-primitives.

Scoped primitives can be referred to with their fully qualified notation (for
example, when using access to suprograms or renamings), for example here as
``P.R.Prim``.

Overriding and extensions
-------------------------

Extension of class record types work similarly to tagged records, with the
addition of the word class to make it clear that we're denoting a class
record extension, for example:

.. code-block:: ada

   package P is
      type T1 is class record
         procedure P (Self : in out T1);
      end record;

      type T2 is new T1 with class record
         procedure P (Self : in out T1);
      end record;
   end P;

Primitives can be marked optionally overriding, following Ada 2005 rules.
Inheritance model is single interitance of a class, multiple inheritance of
interfaces.

Interfaces
----------

Interfaces can now be specified with "class interface", but otherwise
operate as other interfaces (no concrete components or primitive):

.. code-block:: ada

   package P is
      type I is class interface
         procedure P (Self : in out I) is abstract;
      end record;
   end P;

Operators
---------

Operators can be declared as primitives:

.. code-block:: ada

   package P is
      type T1 is class record
         function "=" (Left, Right : T1) return Boolean;
         function "+" (Left, Right : T1) return T1;
      end record;

      type T2 is new T1 with class record
         procedure "=" (Left : T2; Right : T1);
         function "+" (Left : T2, Right : T1) return T1;
      end record;
   end P;

Note that when overriding an operator, only the first parameter changes to the
current class type.

Inheritance from regular tagged types
-------------------------------------

A class record from a tagged record or a regular interface. A class interface
can inherit from a regular interface. The opposite is not possible. For this
to be legal, the tagged record or regular interface inherited from should:

- Only have primitives which one controlling parameter which is the first one
- Have no controlling results
- Have no access discriminants

Primitives in the scope of regular records
------------------------------------------

It is possible to also scope primitives in regular records:

.. code-block:: ada

   package P is

      type R is record
         F : Integer;

         procedure Prim (Self : in out R; V : Integer);
       end record;

   end P;

Declaring primities outside of regular records is still possible. It's not
possible to declare primitives within a regular tagged record.

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

