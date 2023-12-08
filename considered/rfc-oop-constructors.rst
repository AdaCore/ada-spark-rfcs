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

Record, tagged records and class records can declare constructors. The
constructor needs to be a procedure of the name of the type, taking an in out
or access reference to the object.

.. code-block:: ada

   package P is
      type T1 is tagged record
         procedure T1 (Self : in out T1);
         procedure T1 (Self : in out T1; Some_Value : Integer);
      end T1;

      type T2 is record
         procedure T2 (Self : in out T2; Some_Value : Integer);
      end T2;
   end P;

As soon as a constructor exist, an objects cannot be created without calling one
of the available constructors, omitting the self parameter. This call is made on
the object creation, using the type followed by 'Make and the
constructor parameters. When preceded by a `new` operator, it creates an
object on the heap. E.g:

.. code-block:: ada

   V : T1; -- OK, parameterless constructor
   V2 : T1 := T1'Make(42); -- OK, 1 parameter constructor
   V3 : T1'Ref := new T1;
   V4 : T1'Ref := new T1'Make(42);
   V5 : T2; -- NOT OK, there's no parameterless constructor

In the case of objects containing other objects, innermost objects constructors
are called first, before their containing object.

Constructor as a Function
-------------------------

Constructors can be used in places where a function taking the same parameters
and returning a definite view of the type is expected, in particular as a value
for a generic parameter or an access-to-subprogram. For example:

.. code-block:: ada

   generic
      type T (<>) is tagged record;

      with function F (V : Integer) return T;
   package G is

   end;

   package P is
      type T1 is tagged record
         procedure T1 (Self : in out T1);
         procedure T1 (Self : in out T1; Some_Value : Integer);
      end T1;

      type T2 is record
         procedure T2 (Self : in out T2; Some_Value : Integer);
      end T2;

      type Acc1 is access function (Some_Value : Integer) return T1;

      type Acc2 is access function (Some_Value : Integer) return T2;

      V1 : Acc1 := T1'Make'Access;
      V2 : Acc2 := T2'Make'Access;

      package I1 is new G (T1, T1'Make);
      package I2 is new G (T2, T2'Make);
   end P;

In presence of multiple constructors, the rules of overloading resolution
that apply to subprograms overall would apply here too.

Copy Constructor Overload
-------------------------

Copy constructors overload are available to both class records and simple
records.

A special constructor, a copy constructor, has two parameters: self, and a
reference to an instance of the class. It's called when an object is
initialized from a copy. For example:

.. code-block:: ada

   package P is
      type T1 is tagged record
         procedure T1 (Self : in out T1; Source : T1);
      end T1;

If not specified, a default copy constructor is automatically generated.
The implicit copy constructor will call the parent copy constructor, then copy
field by field its additional components, calling component copy constructors if
necessary.

Note that, similar to the parameterless constructor, copy constructor may be
explicitely or implicitely called:

.. code-block:: ada

   V1 : T; -- implicit parameterless constructor call
   V2 : T := V1; -- implicit copy constructor call
   V3 : T := T'Make (V1); -- explicit copy constructor call

Initialization Lists
--------------------

Constructors may need to initialize / call constructors on three categories of
data:

- fields within that object
- the parent object
- discriminants (see later section, possibly excluded from this proposal)

The following sections will describe all three cases.

Initialization of Components
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Initialization of components can be done in two ways:
- Through the default value provided at component declaration.
- Through an ``Initialize`` aspect that can rely on constructor parameters.

If the component is of a type that doesn't have a parameterless constructor, it has
to be initialized by on of these two mechanism.

Here's an example of using ``Initialize`` for such a case:

.. code-block:: ada

   type Some_Type is tagged record
      procedure Some_Type (Self : in out C; Some_Value : Integer);
   end Some_Type;

   type C is tagged record
      F : Some_Type;

      procedure C (Self : in out C; V : Integer);
   end C;

   type body C is tagged record
      procedure C (Self : in out C; V : Integer)
         with Initialize (F => Some_Type'Make (V))
      is
      begin
         null;
      end C;
   end C;

Note that if there is no initialization for components with no default
constructors, the compiler will raise an error:

.. code-block:: ada

   type Some_Type is tagged record
      procedure Some_Type (Self : in out C; Some_Value : Integer);
   end Some_Type;

   type C is tagged record
      F : Some_Type; -- Compilation error, F needs explicit constructor call
   end C;

When a component is mentioned in the initialization list, it overrides its
default initialization. Components that are not in the initialization list are
initialized as described at declaration time. For example:

.. code-block:: ada

   function Print_And_Return (S : String) return Integer is
   begin
      Put_Line (S);

      return 0;
   end;

   type C is tagged record
      A : Integer := Print_And_Return ("A FROM RECORD");
      B : Integer := Print_And_Return ("B FROM RECORD");

      procedure C (Self : in out C);
      procedure C (Self : in out C; S : String);
   end C;

   type body C is tagged record
      procedure C (Self : in out C)
      is
      begin
         null;
      end C;

      procedure C (Self : in out C; S : String)
         with Initialize (A => Print_And_Return (S))
      is
      begin
         null;
      end C;
   end C;

   V1 : C := C'Make; -- Will print A FROM RECORD, B FROM RECORD
   V2 : C := C'Make ("ATERNATE A"); -- Will print ATERNATE A, B FROM RECORD

Note for implementers - the objective of the semantic above is to make
initialization as efficient as possible and to avoid undecessary processing.
Conceptually, a developer would expect to have a specific initialization
procedure generated for each constructor (or maybe, have the initialization
directly expanded in the constructor).

Within an initialization list, the semantic is the same as the one for component
initialization as opposed to component assignment. As a consequence amongst
others, it is possible to initialize limited types:

.. code-block:: ada

   type R is limited record
      A, B : Integer;
   end record;

   type C is limited tagged record
      F : R;

      procedure C (Self : in out C);
   end C;

   type body C is limited tagged record
      procedure C (Self : in out C)
         with Initialize (F => [1, 2])
      is
      begin
         null;
      end C;
   end C;

The only components that a constructor can initialize in the initialization list
are its own. Parent components are supposed to be initialized by the parent
object. The following for example will issue an error:

.. code-block:: ada

   type Root is tagged record
      A, B : Integer;
   end record;

   type Child is new Root with record
      C : R;

      procedure Root (Child : in out C);
   end C;

   type body Child is tagged record
      procedure Child (Self : in out C)
         with Initialize (
            A => 1, -- Compilation Error
            B => 2, -- Compilation Error
            C => 3  -- OK
         )
      is
      begin
         null;
      end C;
   end C;

Initialization of Super View
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The super view object can also be initialized in the initialization list,
for example:

.. code-block:: ada

   type Root is tagged record
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

Note that any value can be provided to Super, either through the call of a
constructor or a copy of an already defined value. For example this also works:

.. code-block:: ada

   type Root is tagged record
      procedure Root (Self : in out Root; V : Integer);
   end Root;

   Default_Root : Root := Root'Make (42);

   type Child is new Root with record
      procedure Child (Self : in out Child);
   end Child;

   type body Child is new Root with record
      procedure Child (Self : in out Child)
         with Initialize (Super => Default_Root)
      is
      begin
         null;
      end Child;
   end Child;

In addition, initializing the ``Super`` is the only place where the constructor
of an abstract type can be called, as it will be completed by a concrete type.
For example:

.. code-block:: ada

   type Root is abstract tagged record
      procedure Root (Self : in out Root; V : Integer);
   end Root;

   type Child is new Root with record
      procedure Child (Self : in out Child);
   end Child;

   type body Child is new Root with record
      procedure Child (Self : in out Child)
         -- Root'Make can be called here to initialize Super
         with Initialize (Super => Root'Make (42))
      is
      begin
         null;
      end Child;
   end Child;

Valuation of Discriminants
^^^^^^^^^^^^^^^^^^^^^^^^^^

In the presence of constructors, discriminants can no longer be set by the code
creating the object, but rather the constructor itself. Here's an example
of legal and illegal code:

.. code-block:: Ada

   package P is
      type T1 (L : Integer) is tagged record
         X : Some_Array (1 .. L);
      end record;

      type T2 (L : Integer) is tagged record
         procedure T2 (Self : in out T2);

         X : Some_Array (0 .. L);
      end record;

      V1 : T1 (10); -- legal
      V2 : T2 (10); -- compilation error
   end P;

Discriminant value need to be set by the constructor as part of the
initialization list. For example:

.. code-block:: Ada

   package P is
      type T2 (L : Integer) is tagged record
         procedure T2 (Self : in out T2; Size : Integer);

         X : Some_Array (0 .. L);
      end record;

      type body T2 (L : Integer) is tagged record

         procedure T2 (Self : in out T2; Size : Integer)
            with Initialize (L => Size - 1)
         is
         begin
            null;
         end T2;

      end record;

      V2 : T2 := T2'Make (10);
   end P;

As for fields, only the discriminants of the current type can be initialized by
the initialization list, not the parents. In addition, in the presence of
constructors, the parent type discriminants are not set. For example:

.. code-block:: ada

   type Root (V : Integer) is tagged record
      procedure Root (Self : in out Child);
   end Root;

   -- note that we're not specifying Root discriminant as Root has a constructor
   type Child is new Root with record
      procedure Child (Self : in out Child);
   end Child;

Constructors and Type Predicates
--------------------------------

Type predicates are meant to check the consistency of a type. In the context
of a type that has constructor, the consistency is expected to be true when
exiting the constructor. In particular, the initializion list is not expected
to create a predicate-valid type - predicates will only be checked after the
constructor has been processed.

Constructors And Aggregates
---------------------------

Ada 2022 already allows arrays aggregates to be expressed through angular
brackets. This proposal extends that notation to record aggregates, so that you
can write:

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

   V1 : R1 := [1, 2]; -- prints Default Default
   V2 : R2 := [1, 2]; -- also prints Default Default

This means that units compiled with the new version of Ada will have a specific
backward incompatible change. Specifically, record initialized with an aggregate
used to bypass default initialization, they would not anymore. From a
functional standpoint, this would result in more code as well as different
behavior if the default initialization has side effects. This can be fixed
by offering constructors with the right parameters. These issues could be
identified statically by migration tools.

In terms of syntax, in the presence of an implicit or explicit parameterless
constructors, aggregates can be written as usual. The parameterless constructor
will be called implicitly before modification of the values by the aggregate.
If a non-parameterless constructor needs to be called, the delta aggregate
syntax can be used. For example:

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

   V1 : R := [1, 2]; -- prints "Default"
   V2 : R := [R'Make (42) with delta 1, 2]; -- prints "V = 42"

One of the consequences of the rules above is that it's not possible to use an
aggregate within a constructor as it would create an infinite recursion:

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
            Self := [1, 2, 3]; -- infinite recursion
         end T1;
      end T1;
   end P;

Constructors Presence Guarantees
--------------------------------

Constructors are not inherited. This means that a constructor for a given class
may not exist for its child.

By default, a class provide a parameterless constructor, on top of the copy
constructor. This parameterless constructor is removed as soon as explicit
constructors are provided. For example:

.. code-block:: ada

   type T1 is tagged record

   end record;

   type T2 is tagged record
      procedure T2 (Self : in out T1, X : Integer);
   end record;

   type T3 is new T2 with record
      procedure T3 (Self : in out T1, X : Integer, Y : Integer);
   end record;

   V1 : T1;        -- OK
   V2a : T2;       -- Compilation error, no parameterless constructor is present
   V2b : T2 := T2'Make (5);   -- OK
   V3 : T3 := T3'Make(5);    -- Compilation error, no more constructor with 1 parameter for T3
   V3 : T3 := T3'Make(5, 6); -- OK

Constructors and Generics
-------------------------

A type used an as a actual of a formal generic parameter is expected to have
a parameterless constructor. This is necessary to enable proper derivation and
allocation. For example:

.. code-block:: ada

   generic
      type T is tagged record;
   package G is
      V : T;
   end G;

   package P is

      type T1 is tagged record
         procedure T1 (Self : in out T1);
      end record;

      type T2 is tagged record
         procedure T2 (Self : in out T1; V : Integer);
      end record;

      package G1 is new G (T1); -- Legal
      package G2 is new G (T2); -- Illegal, T2 doesn't have a parameterless constructor

   end P;

Types without parameterless constructors behave like indefinite types in generics.
For example:

.. code-block:: ada

   generic
      type T (<>) is tagged record;
   package G is
      procedure Proc (V : T)
   end G;

   package P is

      type T1 is tagged record
         procedure T1 (Self : in out T1);
      end record;

      type T2 is tagged record
         procedure T2 (Self : in out T1; V : Integer);
      end record;

      package G1 is new G (T1); -- Legal
      package G2 is new G (T2); -- Legal

   end P;

There is no syntax to specify specific constructor on tagged formal. However,
such constructor can be passed as function as seen before, for example:

.. code-block:: ada

   generic
      type T (<>) is tagged record;
      function Create (V : Integer) return T;
   package G is
      V : T := Create (55);
   end G;

   package P is

      type T2 is tagged record
         procedure T2 (Self : in out T1; V : Integer);
      end record;

      package G2 is new G (T2, T2'Make); -- Legal

   end P;

Removing Constructors from Public View
--------------------------------------

A special syntax is provided to remove the default parameterless constructor
from the public view, without providing any other constructor. The full view of a
type is then responsible to provide constructor (with or without parameters).
Such object can only be created by code that has visibility over the
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

Rationale for Initialization Lists
----------------------------------

Languages like Java or Python do not require initialization lists. However, by
default, class fields are references and initialized by null. In system-level
languages like C++ or Ada, we want to be able to have fields as direct members
of their enclosing records (as opposed to references). However, these tagged records
may themselves have constructors that need parameters, such parameters may
not be known at the time of the description of the record. They should however
be known when the object is created. As a consequence, in Ada (similar to C++),
we introduced the concept of "Initialization List" which allows to provide
values to fields after receiving the constructor parameters.

Drawbacks
=========

Prior art
=========

Unresolved questions
====================

Future possibilities
====================

Record with Indefinite Fields
-----------------------------

With initialization lists, it becomes possible to envision record with
indefinite fields that are initialized at object creation. This is already
somewhat the case as types without parameterless constructors can already be
initialized by an initialization list and behave like indefinite types in
generics. We could consider allowing:

.. code-block:: Ada

   package P is
      type T1 (<>) is tagged record -- T1 is indefinite
	      X : String;

         procedure T1 (Val : String);
      end record;

      type body T1 (<>) is tagged record
         procedure T1 (Val : String)
            with Initialize (X => Val);
         begin
            null;
         end T1;
      end record;
   end P;

This could make such constructions easier to write than when they rely on a
discriminant value.
