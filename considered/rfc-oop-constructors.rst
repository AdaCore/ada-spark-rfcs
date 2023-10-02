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

As soon as a constructor exist, and object cannot be created without calling one
of the available constructors, omitting the self parameter. This call is made on
the object creation, e.g.:

.. code-block:: ada

   V : T1; -- OK, parameterless constructor
   V2 : T1 (42); -- OK, 1 parameter constructor
   V3 : T1'Ref := new T1;
   V4 : T1'Ref := new T1 (42);
   V5 : T2; -- NOT OK, there's no parameterless constructor

A constructor of a child class always call its parent constructor before its
own. It's either implicit (parameterless constructor) or explicit. When
explicit, it's provided through the Super aspect, specified on the body of the
constructor, for example:

.. code-block:: ada

   package P is
      type T1 is class record
         procedure T1 (Self : in out T1; V : Integer);
      end T1;

      type T2 is new T1 with record
         procedure T2 (Self : in out T1);
      end T2;
   end P;

   package body P is
      type body T1 is class record
         procedure T1 (Self : in out T1; V : Integer) is
	      begin
	         null;
	      end T1;
      end T1;

      type body T2 is new T1 with record
         procedure T2 (Self : in out T1)
	        with Super (0) -- special notation for calling the super constructor. First parameter is omitted
	      is
	         null;
	      end T2;
      end T2;
   end P;

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
It componses - it will will call the parent copy constructor, then copy field
by field its additional components, calling component constructors if necessary.

Constructors and discriminants
------------------------------

These considerations are applicatble to both class records and simple records.

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

   V : T1 (10);

However, as soon as a constructor is provided, there is no default constructor
anymore (with the exception of the copy constructor):

.. code-block:: ada

   package P is
      type T1 (L : Integer) is class record
         procedure T1 (Self : in out T1);

	      X : Some_Array (1 .. L);
      end T1;
   end P;

   V : T1 (10); -- illegal

In the presence of discriminants, constructors are expected to set the
discriminant values through a special aspect `Constraints`:

.. code-block:: ada

   type T1 (L : Integer) is class record
      procedure T1 (Self : in out T1);

	   X : Some_Array (1 .. L);
   end T1;

   type body T1 (L : Integer) is class record
      procedure T1 (Self : in out T1)
         with Constraints (10)
      is
      begin
         null;
      end T1;
   end T1;

Constructors default values and and aggregates
----------------------------------------------

These considerations are applicatble to both class records and simple records.

Aggregates are still possible with class records. The order of evaluation for
fields is:

- their default value. Always computed
- the constructor
- any value from the aggregate

The rationale for this order is to go from the generic to the specific. This is
a departure from the existing Ada model where aggregate override default
initialization. Under this model, there is no more way to override default
initialization for records - if initialization should only be done some times
and not others, it is to be done in the constructor (which is available for
records and class records). With class records, aggreates are a shortcut for
field by field assignment after iniitalization.

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

      V : T1 := (Y => 2); -- V.Y = 2
      V2 : T1'Ref := new T1 (1)'(Y => 2); -- V.Y = 2
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
	         Self := (1, 2, 3);
         end T1;
      end T1;

      V : T1 := (A => 99, others => <>); -- V.A = 99, V.B = 2, V.C = 3.
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
   V2b : T2 (5);   -- OK
   V3 : T3 (5);    -- Compilation error, no more constructor with 1 parameter for T3
   V3 : T3 (5, 6); -- OK

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
      X : Some_T (5, 6); -- OK, we expect a 2 parameters con
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
