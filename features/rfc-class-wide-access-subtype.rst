- Feature Name: Class-Wide Access Subtype
- Start Date: 2021-01-05
- Status: Proposed

Summary
=======

We propose to add a new constraint kind to restrict values of class-wide
access types. Values of constrained subtype could point to a given derived
type or a hierarchy. As with other subtypes this allows us to have
a more precise and clean code, eliminates the need of many extra
type-conventions and extra subtype declarations. Example:

.. code-block:: ada

  type Shape is abstract tagged private;
  type Shape_Access is access all Shape'Class;
  type Cube is new Shape with private;
  My_Cube : Shape_Access for access Cube := new Cube;

Now My_Cube.all designates a Cube object, but My_Cube still has
Shape_Access type. So you can initialize/use the object without
an extra convention to the Cube and in the same time you can use
the pointer where class-wide Shape_Access expected.

Motivation
==========

Subtypes are an important part of the Ada language. It makes code
more expressive and precise allowing both the reader and the compiler
better understand the author intend.

But for now access types has only null-exclusion constraint.

Proposed new constraint allows a restriction based on referenced values:
a restricted subtype can point only to the given derived type or class-wide
type. Having this restricted value the author doesn't need to convert
dereferenced value to the derived type.

As an example let's consider a typical pattern in OOP style. We declare a
type hierarchy for geomerty shapes and a procedure to register shape objects.

.. code-block:: ada

  type Shape is abstract tagged null record;
  type Shape_Access is access all Shape'Class;
  procedure Register (Object : Shape_Access);
  type Rectangle is new Shape with record
     Width, Height : Natural;
  end record;

Next code registers a Rectangle and a circle without using a new constraints.
The first approach uses an extra access type:

.. code-block:: ada

  type Rectangle_Access is access all Rectangle;  --  an extra type
  declare
     My_Rectangle : Rectangle_Access := new Rectangle;
  begin
     My_Rectangle.Width := 10;
     My_Rectangle.Heigth := 5;
     Register (Shape_Access (My_Rectangle));  --  an extra type convention
  end;

The first approach uses an extra type convention:

.. code-block:: ada

  declare
     My_Rectangle : Shape_Access := new Rectangle;
  begin
     Rectangle (My_Rectangle).Width := 10;  --  an extra type convention
     Rectangle (My_Rectangle).Heigth := 5;  --  an extra type convention
     Register (My_Rectangle);
  end;

With new constraint the code is cleaner:

.. code-block:: ada

  declare
     My_Rectangle : Shape_Access for access Rectangle := new Rectangle;
  begin
     My_Rectangle.Width := 10;  --  Dereference denotes Rectangle
     My_Rectangle.Heigth := 5;
     Register (My_Rectangle);  --  no extra type convention
  end;

In many cases new construct replaces anonymous access types. This
eliminates several issues with anonymous access types:

- accessibility level of object is "not clear" in many cases, in
  particular when object allocated in the call of a subprogram
- when passed object need to be stored somewhere it can't be safely
  converted to named access type
- use of .all'Unchecked_Access/.all'Unrestricted_Access doesn't work
  for 'null' pointer

All of these issues could be detected only during execution, and sometimes
in corner cases only.

Guide-level explanation
=======================

This RFC introduces a new kind of subtype constraint (class_wide_access_constraint).
It has a syntax form of **for access** *Name*, where *Name* is T or T'Class for some
tagged type T. The constraint is compatible only with an access-to-object type whose
designated subtype is a class-wide type.

With this constraint the author could define subtypes:

.. code-block:: ada

   subtype Rectangle_Access is Shape_Access for access Rectangle;

The Rectangle_Access still has Shape_Access type and can be used whereevere
Shape_Access is expected. In the same time (implicit or explicit) dereferenced value
denotes Rectangle type (if the access value is not null).

This constraint could be used in other places where constraint is allowed.
For example,

- in an object declaration:

.. code-block:: ada

     My_Rectangle : constant Shape_Access for access Rectangle := new Rectangle;

- in a return object declartion:

.. code-block:: ada

  return Result : Shape_Access for access Rectangle := new Rectangle do
     Result.Witch := 10;
     Result.Height := 5;
  end return;

The same syntax form of the constraint works for class-wide case:

.. code-block:: ada

   subtype Rectangle_Access is Shape_Access for access Rectangle'Class;

In this case dereference of the Rectangle_Access value has Rectangle'Class type.

Reference-level explanation
===========================

Add to *scalar_constraint* (in 3.2.2) a new rule

.. code-block::

  scalar_constraint ::= 
     range_constraint | digits_constraint | delta_constraint
     | class_wide_access_constraint
  
  class_wide_access_constraint ::=
    **for access** *type_*name

Add a corresponding rules for dereferenced values.

Rationale and alternatives
==========================

The nearest feature is anonymous access types, but they have issues (see above). 

In our point of view this new constraint kind fits well with Ada philosophy
and best practices.

Drawbacks
=========

None :)

Prior art
=========

This is too Ada specific to have a precedent in other languages, I guess.

Unresolved questions
====================

None found yet.


Future possibilities
====================

No other ideas yet.
