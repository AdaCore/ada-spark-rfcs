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

Constructors
------------

Constructors are available to both class record and simple records.

Record and class record can declare constructors. The
constructor needs to be a procedure of the name of the object, taking an in out
or access reference to the object.

.. code-block:: ada

   package P is
      type T1 is class record
         procedure T1 (Self : in out T1);
         procedure T1 (Self : in out T1; Some_Value : Integer);
      end T1;

      type T2 is record
         procedure T2 (Self : in out T2; Some_Value : Integer);
      end T2;
   end P;

As soon as a constructor exist, an object cannot be created without calling one
of the available constructors, omitting the self parameter. This call is made on
the object creation, using the tagged / class type followed by 'Make and the
constructor paramters. When preceded by a `new` operator, it creates an
object on the heap. E.g:

.. code-block:: ada

   V : T1; -- OK, parameterless constructor
   V2 : T1 := T1'Make(42); -- OK, 1 parameter constructor
   V3 : T1'Ref := new T1;
   V4 : T1'Ref := new T1'Make(42);
   V5 : T2; -- NOT OK, there's no parameterless constructor

In the case of objects containing other objects, innermost objects constructors
are called first, before their containing object.

Copy constructor overload
-------------------------

Copy constructors overload are available to both class records and simple
records.

A special constructor, a copy constructor, has two parameters: self, and a
reference to an instance of the class. It's called when an object is
initialized from a copy. For example:

.. code-block:: ada

   package P is
      type T1 is class record
         procedure T1 (Self : in out T1; Source : T1);
      end T1;

If not specified, a default copy constructor is automatically generated.
It composes - it will will call the parent copy constructor, then copy field
by field its additional components, calling component constructors if necessary.

Note that, similar to the default constructor, copy constructor may be
explicitely or implicitely called:

.. code-block:: ada

   V1 : T; -- implicit default constructor call
   V2 : T := V1; -- implicit copy constructor call
   V3 : T := T'Make (V1); -- explicit copy constructor call

Initialization lists
--------------------

Constructors may need to initialize / call constructors on three categories of
data:

- fields within that object
- the parent object
- discriminants (see later section, possibly excluded from this proposal)

Initialization of these objects can be done with the `Initialize` aspect. For
example:

.. code-block:: ada

   type C is class record
      F : Integer;

      procedure C (Self : in out C; V : Integer);
   end C;

   type body C is class record
      procedure C (Self : in out C; V : Integer)
         with Initialize (F => V)
      is
      begin
         null;
      end C;
   end C;

Field initialization appens after explicit field initialization, for example:

.. code-block:: ada

   type C is class record
      F : Integer := 5;

      procedure C (Self : in out C);

      procedure C (Self : in out C; V : Integer);
   end C;

   type body C is class record
      procedure C (Self : in out C) -- no explicit initialization, V is assigned to 5
      is
      begin
         null;
      end C;

      procedure C (Self : in out C; V : Integer)
         with Initialize (F => V) -- Replaces initialization to 5 by V
      is
      begin
         null;
      end C;
   end C;

This becomes quite useful when using fields that are themselves object with
constructors, e.g.:

.. code-block:: ada

   type Some_Type is class record
      procedure Some_Type (Self : in out C, Some_Value : Integer);
   end Some_Type;

   type C is class record
      F : Some_Type;

      procedure C (Self : in out C; V : Integer);
   end C;

   type body C is class record
      procedure C (Self : in out C; V : Integer)
         with Initialize (F => Some_Type'Make (V))
      is
      begin
         null;
      end C;
   end C;

Note that in case fields have no default constructors (as it's the case above),
then constructs of the enclosing object have to provide explicit construction,
either through constructors or field initialization. E.g.:

.. code-block:: ada

   type Some_Type is class record
      procedure Some_Type (Self : in out C, Some_Value : Integer);
   end Some_Type;

   type C is class record
      F : Some_Type; -- Compilation error, F needs explicit constructor call
   end C;

The super view object can also be initialied in the initialization list,
for example:

.. code-block:: ada

   type Root is class record
      procedure Root (Self : in out Root; V : Integer);
   end Root;

   type Child is new Root with record
      procedure Child (Self : in out Child);
   end Child;

   type body Child is new Root with record
      procedure Child (Self : in out Child)
         with Initialize (Super => Root'Make (42))
      is
      begin
         null;
      end Child;
   end Child;

Constructors and discriminants
------------------------------

Note: We may be forbidding discriminants in the presence of constructors for
now and describe syntax in a separate RFC. The first question to answer is
wether we set discriminants in the constructor or externally.

These considerations are applicable to both class records and simple records.

When a type has discriminants, discriminants values are expected to be set by
the constructor. A type with such disriminants will be provided by default with a
constructor that takes these discriminants as input. E.g.:

.. code-block:: ada

   package P is
      type T1 (L : Integer) is class record
         --  implicitely declares procedure T1 (Self : in out T1, L : Integer);

	      X : Some_Array (1 .. L);
      end T1;
   end P;

   V1 : T1 (10); -- legacy syntax for creating objects, may be forbidden for class records
   V2 : T1 := T1'Make (10); -- constructor-like syntax

However, as soon as a constructor is provided, there is no default constructor
anymore (with the exception of the copy constructor):

.. code-block:: ada

   package P is
      type T1 (L : Integer) is class record
         procedure T1 (Self : in out T1);

	      X : Some_Array (1 .. L);
      end T1;
   end P;

   V1 : T1 (10); -- illegal
   V2 : T1 := T1'Make (10); -- illegal

In the presence of discriminants, constructors are expected to set the
discriminant values through the initialization list:

.. code-block:: ada

   type T1 (L : Integer) is class record
      procedure T1 (Self : in out T1);

	   X : Some_Array (1 .. L);
   end T1;

   type body T1 (L : Integer) is class record
      procedure T1 (Self : in out T1)
         with Initializes (L => 10)
      is
      begin
         null;
      end T1;
   end T1;

Constructors default values and aggregates
------------------------------------------

These considerations are applicatble to both class records and simple records.

Ada 2022 already allows homogeneous data structure aggregates to be expressed
through angular brackets. This proposal extends that notation to hetoregeneous
data structures, so that you can write:

.. code-block:: ada

   type R is record
      V, W : Integer;
   end record;

   X : R := [0, 2];

   type A is access all R;

   X2 : A := new R'[0, 2];

In the presence of constructors, aggregates values are evaluated and assigned
after the contructor is executed. So the full sequence of evaluation for
fields of a class record is:

- their default value
- the constructor
- any value from the aggregate

The rationale for this order is to go from the generic to the specific. This is
a departure from the existing Ada model where aggregate override default
initialization. Under this model, there is no more way to override default
initialization for records - if initialization should only be done some times
and not others, it is to be done in the constructor (which is available for
records and class records). With class records, aggreates are a shortcut for
field by field assignment after initialization.

Class record, and record that contain constructors, can only use the new
aggregate notation.

To maintain compatibilty, non-class record types (including tagged types) that
do not have constructors will still be initialized following legacy rules,
in particular field default values will not be computed if initialized by an
aggregate.

For example:

.. code-block:: ada

   package P is
      type T1 is class record
         procedure T1 (Self : in out T1; Val : Integer);

	      Y : Integer := 0;
      end T1;
   end P;

   package body P is
      type body T1 is class record
         procedure T1 (Self : in out T1; Val : Integer) is
	      begin
	          -- Y is 0 here
	          Self.Y := Val;
	          -- Y is val here
         end T1;
      end T1;

      V : T1 :=  T1'Make (42)'[Y => 2]; -- V.Y = 2
      V2 : T1'Ref := new T1'Make (42)'[Y => 2]; -- V.Y = 2
   end P;

Note that it's of course always possible (and useful) to use an aggreate within
a constructor, still as a shortcut to field by field assignment:

.. code-block:: ada

   package P is
      type T1 is class record
         procedure T1 (Self : in out T1);

	      A, B, C : Integer;
      end T1;
   end P;

   package body P is
      type body T1 is class record
         procedure T1 (Self : in out T1) is
	      begin
	         Self := [1, 2, 3];
         end T1;
      end T1;

      V : T1 := [A => 99, others => <>]; -- V.A = 99, V.B = 2, V.C = 3.
   end P;

Constructors presence guarantees
--------------------------------

Constructors are not inherited. This means that a constructor for a given class
may not exist for its child.

By default, a class provide a parameterless constructor, on top of the copy
constructor. This parameterless constructor is removed as soon as explicit
constructors are provided. For example:

.. code-block:: ada

   type T1 is class record

   end T1;

   type T2 is class record
      procedure T2 (Self : in out T1, X : Integer);
   end T2;

   type T3 is new T2 with record
      procedure T3 (Self : in out T1, X : Integer, Y : Integer);
   end T3;

   V1 : T1;        -- OK
   V2a : T2;       -- Compilation error, no parameterless constructor is present
   V2b : T2 := T2'Make (5);   -- OK
   V3 : T3 := T3'Make(5);    -- Compilation error, no more constructor with 1 parameter for T3
   V3 : T3 := T3'Make(5, 6); -- OK

Note that as a consequence, it's not possible to know what constructors will be
available when using a class record as a formal parameter of a generic. As
a consequence, expected constructors needs to be mentionned explicitely when
declaring such parameters:

.. code-block:: ada

   generic
      type Some_T is new T2 with
         procedure Some_T (Self : in out Some_T; X, Y : Integer);
      end Some_T;
   package G
      X : Some_T := Some_T'Make(5, 6); -- OK, we expect a 2 parameters con
   end G;

   package I1 is new G (T2); -- Compilation error, constructor missing
   package I1 is new G (T3); -- OK

Finally, a special syntax is provided to remove the default constructor from
the public view, without providing any other constructor. The full view of a
type is then responsible to provide constructor (with or without parameters).
Such object can only be instanciated by code that has visibility over the
private section of the package:

.. code-block:: ada

   package P is
      type T1 is class record
         procedure T1 (Self : in out T1) is abstract;
      end T1;
   private
      type T1 is class record
         procedure T1 (Self : in out T1);
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
