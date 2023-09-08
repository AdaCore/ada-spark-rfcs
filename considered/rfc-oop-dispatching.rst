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

A view to a class record is a class wide view and is dispatching, no matter if
it's referenced in a primitive or not. So for example:

.. code-block:: ada

   type T is class record
      procedure P (Self : in out T1);
   end T1;

   procedure P (V : in out T) is
   begin
      V.P2; -- Dispatching
   end P;

A new notation, `'Specific'` is introduced when denoting a non-dispatching view
of an object. This can be used either at object declaration, or through an
explicit conversion. For example:

.. code-block:: ada

   procedure P (V : in out T) is
   begin
      V'Specific.P; -- Not dispatching, looks at V specific type
      T'Specific (Self).P; -- Not dispatching, calling P primitive of T
   end P;

   procedure P (V : in out T'Specific) is
   begin
      V.P; -- Not dispatching, looks at V is a type specific view.
   end P;

References to T behave like a tagged class wide type. Notably, when used in
local variables, their class or tag is set at initialization time:

.. code-block:: ada

      type T1 is class record
         procedure P (Self : in out T1);
      end T1;

      type T2 is new T1 with record
         procedure P (Self : in out T1);
      end T2;

      V1 : T1 := T1'(others => <>); -- This is a dispatching view of an object of type T1
      V2 : T2 := T2'(others => <>); -- This is a dispatching view of an object of type T2
      V3 : T1 := V2; -- This is a dispatching view of an object of type T2

   begin

      V3 := V2; -- OK, same class
      V1 := V3; -- Constraint_Error, tag differ

Such types cannot be used directly as a component declaration:

.. code-block:: ada

   type R is record
      V : T1; -- Compilation_Error, V2 is indefinite
   end record;

As a shortcut, if no initial value is provided, a variable of a given class
will be automatically initialized with its declared type:

.. code-block:: ada

   V1 : T1 := T1'(others => <>);
   V2 : T1; -- Legal, equivalent to the above

This is also true when using dynamic allocations:

.. code-block:: ada

   V1 : access T1 := new T1; -- Creating an instance of type T1

It is still possible to refer to a specific type when declaring objects:

.. code-block:: ada

   type R is record
      V1 : T1'Specific; -- OK, this is a reference to T1
   end record;

   V : T1'Specific; -- V can only be of type T1

   type Arr is array (Integer range <>) of T1'Specific;
   --  Arr contains specifically T1 references

Non-Dispatching Operations
--------------------------

The 'Specific notaton described above can also be used to declare non-primitive
operations of a type. In this case, these operations can be called through the
usual prefix notation, but they cannot be overriden and can't be used for
dispatching. For example:

.. code-block:: ada

  package P is
      type T1 is class record
         procedure P (Self : in out T1'Specific);
      end T1;

      type T2 is new T1 with null record;

  end P;

  procedure Some_Procedure is
     V : T1;
     V2 : T2;
  begin
     V.P; -- Legal, P is an operation of T1
     V2.P; -- Legal P is also an operation of T2, statically called

Note that while it's illegal to declare dispatching operations in the body of
the implementation of a class, it's still possible to declare non-dispatching
specific operations:

.. code-block:: ada

  package body P is
     type T1 is class record
         procedure P2 (Self : in out T1'Specific); -- Legal

         procedure P2 (Self : in out T1); -- Compilation Error
      end T1;
  end P;

Reference-level explanation
===========================


Rationale and alternatives
==========================

It is a potential vulnerability not to call an overriden primitive. This may
lead to an object to be in an state that has not been anticipated, in particular
when the role of the overriden primitive is to keep the state of the derived
object consistant. It's also commonly the case in most OOP languages that
dispatching is the default expected behavior and non dispatching the exception.

This also fix a common confusion in Ada, where the dispatching parameter of A
primitive is itself non-dispatching and requires so-called redispatching. The
following code becomes then much more natural to write:

.. code-block:: ada

   package P is
      type T1 is class record
         procedure P (Self : in out T1);

         procedure P2 (Self : in out T1);
      end T1;
   end P;

   package P is
      type body T1 is class record
         procedure P (Self : in out T1) is
         begin
            Self.P2; -- Dispatching
         end P;
      end T1;
   end P;


Drawbacks
=========


Prior art
=========


Unresolved questions
====================

Future possibilities
====================
