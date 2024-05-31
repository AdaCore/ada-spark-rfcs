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
