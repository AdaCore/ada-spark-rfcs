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

A new kind of type is introduced, the `class` type. It behaves similarly to a
tagged type (and in some cases can derive from one), with the following
differences:

- It is always a by-constructor type
- It cannot have coextensions (so no access-type discriminants)
- Its primitives must follow the rules of First_Controlling_Parameter
- It always follows the rules of Default_Dispatching_Calls
- Primitives must be declared within the scope of the type; subprograms
  declared outside that scope are not primitives.

Because primitives are declared inside the type, their bodies must also be
provided inside the type. This motivates a new body section for the type,
placed within the enclosing package body. The example below illustrates the
overall structure:

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

Primitives can also be defined directly in the spec using expression functions,
as elsewhere in Ada. For example:

.. code-block:: ada

   type C is class record
      I : Integer;
      procedure Set (Self : in out C; V : Integer);
      function Get (Self : C) return Integer is (Self.I);
   end C;

The body section of a class type follows the same rule as a package body: it
is mandatory if and only if at least one primitive declared in the spec
requires completion. If every primitive is fully defined in the spec (for
example, all of them are expression functions, or there are none), the
``type body <name> is ... end <name>;`` section must be omitted.

Class primitives are always called via prefix notation. Subprograms declared
outside of the type scope that take an instance of the type as an argument are
not primitives, even when declared in the same declarative scope as the type.

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

A class record extension that does not add any new component or primitive can
be written using the ``with class null record`` form, mirroring
``with null record`` for tagged types:

.. code-block:: ada

   type C is class record
      ...
   end C;

   type R is new C with class null record;

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

Class-wide types and the ``'Class`` attribute
---------------------------------------------

The term *class* in this RFC names a kind of type declaration. It is distinct
from Ada's existing notion of *class-wide* types, which describes the
indefinite type rooted at a specific type and covering that type along with
all of its descendants. The two concepts coexist: for a class type ``T``,
``T'Class`` denotes the class-wide type rooted at ``T``, with the same meaning
as for tagged types.

Because primitive calls on class types dispatch by default
(Default_Dispatching_Calls), the ``'Class`` attribute is needed much less
often than with tagged types. It is still required in order to:

- declare a variable, parameter, component, or formal of an indefinite type
  that can hold any descendant of ``T`` (e.g. ``X : T'Class := ...``),
- perform membership tests, such as ``X in T'Class``,
- declare class-wide subprograms (see below).

Non-primitive scoped operations
-------------------------------

The only non-primitive operation allowed in a class record is a non-primitive
that has a class-wide parameter of the enclosing type as the first parameter,
e.g.:

.. code-block:: ada

   type R is class record
      procedure P1 (Self : R'Class); -- legal

      procedure P2 (X1 : Integer; Self : R); -- error

      procedure P3 (X1 : Integer); -- error
   end R;

The rationale is the following: ``P1`` is a non-dispatching operation that
still has a clear link to ``R`` and can be called through prefix notation on
any value of ``R'Class``, while also having access to the type's private
components. ``P2`` does relate to ``R`` but, because the controlling parameter
is not in first position, it cannot be invoked via prefix notation, which
defeats the point of scoping it inside the type. ``P3`` has no parameter
referring to ``R`` at all and therefore has no reason to live in the type's
scope.

These class-wide subprograms are called through prefix notation. They cannot
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


Variant records
---------------

Class records can have a variant part, following the same rules as regular
records. However, only components can appear in the variant part —
primitives must always be declared in the common part of the type. E.g.:

.. code-block:: ada

   type R (B : Boolean) is class record
      F : Integer;

      procedure Prim (Self : in out R);

      case B is
         when True =>
            F_True : Integer;
         when False =>
            F_False : Integer;
      end case;
   end R;

The rationale is that primitives are properties of the type as a whole and
participate in dispatching independently of the value of any discriminant;
allowing them in the variant part would have no meaningful semantics.


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

Scoped operations in regular records
------------------------------------

A natural extension of this RFC would be to allow scoping operations inside
regular (non-class) record types, for example:

.. code-block:: ada

   package P is

      type R is record
         F : Integer;

         procedure Prim (Self : in out R; V : Integer);
       end R;

   end P;

This is not limited to primitives: it would also cover constructors and
destructors, which raise a broader set of design questions. This topic is
deferred and should be revisited at the language design level as a follow-up.

