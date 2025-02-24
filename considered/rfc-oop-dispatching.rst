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

Dispatching and Class Wide Views
--------------------------------

A new library / partition level pragma is introduced, Default_Dispatching_Calls.
When active, calls to primitives are dispatching (when the tag can be
determined statically, the compiler may optimize the call to be static) unless
explicitely marked as static (for example, through 'Super). E.g:

.. code-block:: ada

   pragma Default_Dispatching_Calls (On);

   type Root is tagged null record;

   procedure P (Self : in out Root);

   type Child is new Root with null record;

   procedure P (Self : in out Root);

   type A_Root is access all Root;

   procedure P (V : in out Root) is
   begin
      V.P2; -- Dispatching
   end P;

   V : A_Root := new Child;

   V.P; -- dispatching

Default_Dispatching_Calls is On by default on new version of the language.

Multi-Parameter Dispatching
---------------------------

Under this new pragma Default_Dispatching_Calls, primitives with more than
one controlling parameter behave in the following way:

- If they're called on a dispatching call, then everything works as if all
  controlling parameters were converted to class wide view. And indeed, in that
  case, we would have dynamic tag check as you do today in Ada.

- If it's a non-dispatching call, today that's through 'Super, then you will
  statically select the primitive, and will need to be able to statically check
  the static type of all parameters.

For example:

.. code-block:: ada

   type Root is tagged null record;

   procedure Prim (A, B : Root);

   type Child is new Root with null record;

   overriding procedure Prim (A, B : Child);

   R1, R2 : Root;
   C1, C2 : Child;

   C1'Super.Prim (R2); -- static, legal
   C1'Super.Prim (C2'Super); -- static, legal
   C1'Super.Prim (C2); -- illegal, C2 is of the wrong type

Note that this is a problem when integrating with current Ada, pedantic Flare
does not support multi-parameter dispatching.

Dispactching on Returned Types
------------------------------

A tag indeterminate disatching call is illegal (as it is the case today). For
example:

.. code-block:: ada

     pragma Default_Dispatching_Calls;
     type T is tagged ... ;
     function Make return T; -- primitive
     Obj1 : T'Class := ...
     Obj2 : T'Class := Make; -- illegal
   begin
     Obj1 := Make; -- legal; use Obj1'Tag to dispatch


Reference-level explanation
===========================


Rationale and alternatives
==========================

It is a potential vulnerability not to call an overriden primitive. This may
lead to an object to be in an state that has not been anticipated, in particular
when the role of the overriden primitive is to keep the state of the derived
object consistant. It's also commonly the case in most OOP languages that
dispatching is the default expected behavior and non dispatching the exception.

This also fixes a common confusion in Ada, where the dispatching parameter of A
primitive is itself non-dispatching and requires so-called redispatching. The
following code illustrates the improvement:

.. code-block:: ada

   package P is
      type T1 is tagged null record;

      procedure P (Self : in out T1);

      procedure P2 (Self : in out T1);
   end P;

   package P is
      procedure P (Self : in out T1) is
      begin
         T1'Class (Self).P2; -- Dispatching in all cases
         Self.P2; -- Only dispatching with Default_Dispatching_Calls (On)
      end P;
   end P;


Drawbacks
=========


Prior art
=========


Unresolved questions
====================

Future possibilities
====================
