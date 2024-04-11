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

In the presence of constructors, aggregates values are evaluated and assigned
after the contructor is executed. So the full sequence of evaluation for
fields of a class record is:

- the constructor
- any value from the aggregate

This respects the fundamental rule that constructors can never be bypassed. For
example:

.. code-block:: ada

   function Print_And_Return (S : String) return Integer is
   begin
      Put_Line (S);

      return 0;
   end;

   type R1 is record
      V, W : Integer := Print_And_Return ("Default");
   end record;

   type R2 is record
      V, W : Integer := Print_And_Return ("Default");

      procedure R2 (Self : in out R2);
   end record;

   V1 : R1 := (1, 2); -- prints Default Default
   V2 : R2 := (1, 2); -- also prints Default Default

This means that units compiled with the new version of Ada will have a specific
backward incompatible change. Specifically, record initialized with an aggregate
used to bypass default initialization, they would not anymore. From a
functional standpoint, this would result in more code as well as different
behavior if the default initialization has side effects. This can be fixed
by offering constructors with the right parameters. These issues could be
identified statically by migration tools.

There is a specific question on performances impact, as the new semantic would
evaluate default value where the current Ada semantic would not. This can be
solved by not using default initialization in the type, but to provide instead
a constructor that takes parameters to value all components. For example:

.. code-block:: ada

   type R1 is record
      V, W : Integer := Some_Value;
   end record;

Can become:

.. code-block:: ada

   type R1 is record
      V, W : Integer;

      procedure R1 (Self : in out R1; V, W : Integer);
   end record;

   type body R1 is record
      procedure R1 (Self : in out R1; V, W : Integer) is
      begin
         Self.V := V;
         Self.W := W;
      end R;
   end record;

As a consequence, writing:

.. code-block:: ada

   V1 : R1 := R1'Make(1, 2);

Can be made compiled as efficiently as before (in particular if the constructors
are inlined)

In terms of syntax, in the presence of an implicit or explicit parameterless
constructors, aggregates can be written as usual. The parameterless constructor
will be called implicitly before modification of the values by the aggregate.

If a non-parameterless constructor needs to be called, two syntaxes are available:
- if only some values need to be modified, a delta aggregate can be used
- if all values need to be modified, the syntax is "(<constructor call> with <values>)"
  which is very close to the current notation for extension aggregates. For example:

.. code-block:: ada

   type R is record
      V, W : Integer;

      procedure R (Self : in out R);

      procedure R (Self : in out R; V : Integer);
   end record;

   type R is record
      procedure R (Self : in out R) is
      begin
         Put_Line ("Default");
      end R;

      procedure R (Self : in out R; V : Integer) is
      begin
         Put_Line (f"V = {V}");
      end R;

   end record;

   V1 : R := (1, 2); -- prints "Default"
   V2 : R := (R'Make (42) with delta V => 1); -- prints "V = 42"
   V3 : R := (R'Make (42) with 1, 2);         -- also prints "V = 42"

One of the consequences of the rules above is that it's not possible to use an
aggregate within a constructor as it would create an infinite recursion:

.. code-block:: ada

   package P is
      type T1 is tagged record
         procedure T1 (Self : in out T1);

	      A, B, C : Integer;
      end T1;
   end P;

   package body P is
      type body T1 is tagged record
         procedure T1 (Self : in out T1) is
         begin
            Self := (1, 2, 3); -- infinite recursion
         end T1;
      end T1;
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
