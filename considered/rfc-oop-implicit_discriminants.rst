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

Indefinite fields
-----------------

It is now possible to declare a record as being "indefinite" without specifying
its discriminants, which allows to have indefinite fields, e.g.:

.. code-block:: Ada

      type T (<>) is record -- T1 is indefinite
         X : String; -- it's ok to have an indefinite field here

         procedure T (Self : in out T; Val : String); -- constructor

         procedure T (Self : in out T; Size : Integer); -- constructor
      end record;

Indefinite fields must be provided with a value  by the initialization list of
the constructor. For example:

.. code-block:: Ada

   package P is

      type body T (<>) is record
         procedure T (Self : in out T; Val : String)
            with Initialize (X => Val)
         is
         begin
            null;
         end T;

         procedure T (Self : in out T; Size : Integer)
            with Initialize (X => [1 .. Size => <>])
         is
         begin
            null;
         end T;
      end record;
   end P;

All other rules for disriminated record apply here (in particular with regards
to constraint checking).

Implementation note
-------------------

This feature may (and should) lead to more extensive usage of indefinite types,
e.g.:

.. code-block:: Ada

      type T (<>) is record -- T1 is indefinite
         A : String;
         B : String;
         C : String;
         D : String;

         procedure T (Self : in out T);
      end record;

Implementers need to be careful with implementation penalties. In particular,
computing (and accessing) the field D may require to load the value of the Size
of A, B and C and then add them. This is significantly more expensive than
a situation where D was referenced through a pointer.

Implementation should consider the size / performance trade-off, and either
store offsets or pointers in the type. The above could be expanded to:

.. code-block:: Ada

      type T (<>) is record -- T1 is indefinite
         _A_Location : access String;
         _B_Location : access String;
         _C_Location : access String;
         _D_Location : access String;
         A : String;
         B : String;
         C : String;
         D : String;

         procedure T (Self : in out T);
      end record;

      -- X.D is replaced by X._D_Location.all

or possibly:

.. code-block:: Ada

      type T (<>) is record -- T1 is indefinite
         _A_Offset : Positive range 0 .. 2 ** 16 - 1; -- we don't need 64 bits to store such offset, this could be implementation-defined
         _B_Offset : Positive range 0 .. 2 ** 16 - 1;
         _C_Offset : Positive range 0 .. 2 ** 16 - 1;
         _D_Offset : access String
         A : String;
         B : String;
         C : String;
         D : String;

         procedure T (Self : in out T);
      end record;

      -- X.D is replaced by (@D + X._D_Offset).all

Performances benchmarks could help chosing between these alternatives (there
may be others).


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

