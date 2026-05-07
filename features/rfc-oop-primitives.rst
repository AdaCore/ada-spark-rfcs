- Feature Name: Standard OOP model
- Start Date: May 5th 2020
- Status: Ready for prototyping

Summary
=======

Motivation
==========

Guide-level explanation
=======================

Class objects
-------------

A new type of type is introduced, the `class` type. This type operates similarly
to tagged types (there are even situations where it can be derived from one)
with a number of differences:

- It's always a by-constructor type
- It cannot have coextensions (so no access-type discriminants)
- Its primitives must follow the rules of First_Controlling_Parameter
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
       end R
       with private;

       procedure Not_A_Prim (Self : in out R);

   private

       type R is class record
         procedure Prim_2 (Self : in out R; V : Integer);
       end R;

   end P;

   package body P is

      type body R is
         procedure Prim (Self : in out R; V : Integer) is
         begin
            Self.F := V;
         end Prim;

         procedure Prim_2 (Self : in out R; V : Integer) is
         begin
            Self.F := V + 1;
         end Prim_2;
       end R;

      procedure Not_A_Prim (Self : in out R) is
      begin
         null;
      end Not_A_Prim;

   end P;

Note that the body section of a class type uses the form ``type body <name> is
... end <name>;`` and does not repeat ``class record`` nor the extension clause
of the parent type - the body only completes the primitives declared in the
spec.

Primitives declared within a type can only be called via prefix notation. When
primitives are declared in a scope, there can no longer be primitives declared
outside of the scope, such declarations are non-primitives.

Scoped primitives can be referred to with their fully qualified notation (for
example, when using access to subprograms or renamings), for example here as
``P.R.Prim``.

Overriding and extensions
-------------------------

Extension of class record types works similarly to tagged records, with the
addition of the word class to make it clear that we're denoting a class
record extension, for example:

.. code-block:: ada

   package P is
      type T1 is class record
         procedure P (Self : in out T1);
      end T1;

      type T2 is new T1 with class record
         procedure P (Self : in out T2);
      end T2;
   end P;

The corresponding bodies, including the body of the derived type, also use the
``type body <name> is ... end <name>;`` form. Neither ``class record`` nor the
``new T1 with`` extension clause are repeated:

.. code-block:: ada

   package body P is
      type body T1 is
         procedure P (Self : in out T1) is
         begin
            null;
         end P;
      end T1;

      type body T2 is
         overriding
         procedure P (Self : in out T2) is
         begin
            null;
         end P;
      end T2;
   end P;

Primitives can be marked optionally overriding, following Ada 2005 rules.
Inheritance model is single inheritance of a class, multiple inheritance of
interfaces.

Interfaces
----------

Interfaces can now be specified with "class interface", but otherwise
operate as other interfaces (no concrete components or primitives):

.. code-block:: ada

   package P is
      type I is class interface
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

      type T2 is new T1 with class record
         function "=" (Left : T2; Right : T1) return Boolean;
         function "+" (Left : T2; Right : T1) return T1;
      end T2;
   end P;

Note that when overriding an operator, only the first parameter changes to the
current class type.

Inheritance from regular tagged types
-------------------------------------

A class record can inherit from a tagged record or a regular interface. A class
interface can inherit from a regular interface. The opposite is not possible.
For this to be legal, the tagged record or regular interface inherited from
should:

- Only have primitives with one controlling parameter which is the first one
- Have no controlling results
- Have no access discriminants

Primitives in the scope of regular records
------------------------------------------

It is possible to also scope primitives in regular records:

.. code-block:: ada

   package P is

      type R is class record
         F : Integer;

         procedure Prim (Self : in out R; V : Integer);
       end R;

   end P;

Declaring primitives outside of regular records is still possible. It's not
possible to declare primitives within a regular tagged record.

Non-primitive scoped operations
-------------------------------

The only non-primitive operation allowed in a class record is a non-primitive
that has a class wide parameter of the enclosing type as the first parameter,
e.g.:

.. code-block:: ada

   type R is class record
      procedure P1 (Self : R'Class); -- legal

      procedure P2 (X1 : Integer; Self : R); -- error

      procedure P3 (X1 : Integer); -- error
   end R;

These class wide subprograms are called through prefix notation. They cannot
however be overridden, and a derived class cannot redefine any subprogram of
the same profile. E.g.:

.. code-block:: ada

   type C is new R with class record
      procedure P1 (Self : C'Class); -- illegal

      procedure P1 (Self : C); -- illegal

      procedure P1 (Self : C'Class; I : Integer);
      -- legal, this is a different profile
   end C;

Note that, as opposed to tagged types, class-wide subprograms declared outside
of the scope of a class record cannot be called through prefix notation.
Notably:

.. code-block:: ada

      type R is class record
         procedure P1 (Self : R'Class);
      end R;

      procedure P2 (Self : R'Class);

      V : R;
   begin
      V.P1; -- legal
      V.P2; -- error
      P2 (V); -- legal


Discriminants
-------------

Discriminants of class record need to be repeated on both public and private
declaration views, but not their body view (similar to e.g. protected types).
E.g:

.. code-block:: ada

   package P is
      type R (B : Boolean) is class record
         F : Integer;

         procedure Prim (Self : in out R; V : Integer);
       end R
       with private;

   private

       type R (B : Boolean) is class record
         procedure Prim_2 (Self : in out R; V : Integer);
       end R;

   end P;

   package body P is

      type body R is
         procedure Prim (Self : in out R; V : Integer) is
         begin
            Self.F := V;
         end Prim;

         procedure Prim_2 (Self : in out R; V : Integer) is
         begin
            if Self.B then
               Self.F := V + 1;
            end if;
         end Prim_2;
       end R;

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

