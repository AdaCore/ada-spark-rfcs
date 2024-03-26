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

Final fields are available to both class records and simple records.

Class record support constant fields, which are field which value cannot be
changed after the constructor call, not even during aggregate which is
considered as a shortcut for assignment. For example:

.. code-block:: ada

   package P is
      type T1 is class record
         procedure T1 (Self : in out T1; Val : Integer);

         Y : final Integer := 0;
      end T1;
   end P;

   package body P is
      type body T1 is class record
         procedure T1 (Self : in out T1; Val : Integer) is
         begin
            -- Y is 0 here
            Self.Y := Val; -- Legal
            -- Y is val here
         end T1;
      end T1;

      V : T1 := (Y => 2); -- Illegal, Y is final
   end P;

Final classes
-------------

tagged record and class record also implement the concept of final classes,
which is a class not deriveable. There are two advantages of final classes:

- In terms of design, this makes it clear that this class is not intended to be
  derived. It's often the case where derivation is used just to have a class in
  a given framework but isn't prepared to be itself modified.
- A very significant one: a final class is effectively a definite type.
  As a result, it can be stored on the stack or as a component,
  calls to a view of a final class are not dispatching
  (the target is statically known).

.. code-block:: ada

   package P is
      type T1 is class record
         null;
      end T1;

      type T2 is final new T1 with record
         null;
      end T2;

      type T3 is new T2 with record -- Illegal, T2 is final
         null;
      end T3;

      V1 : T1; -- Illegal, T1 is indefinite
      V2 : T2; -- Legal, T2 is final.
   end P;

Reference-level explanation
===========================

Rationale and alternatives
==========================

Global object hierarchy
-----------------------

We consider a global object hierarchy:

All class object implicitely derives from a top level object,
Ada.Classes.Object, defined as follows:

.. code-block:: ada

   package Ada.Classes is
      type Object is class record
         function Image (Self : Object) return String;

         function Hash (Self : Object) return Integer;
      end Object;
   end Ada.Classes;

Other top level primitives may be needed here.

However, there are several elements that argue against this design:

- the language that implement that (Java) initially introduced that as a way
  to workaround lack of genericity and `void *` notation. Ada provides
  genericity, and in the extreme cases where `void *` is required,
  `System.Address` is a reasonable replacement.
- As opposed to Java, many types in Ada are not objects. This concept would then
  be far less ubiquitous.

As a consequence, the identified use case ended up being to narrow to justify
the effort.



Drawbacks
=========


Prior art
=========

Unresolved questions
====================

Future possibilities
====================
