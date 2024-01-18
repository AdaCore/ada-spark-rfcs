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

   type T1_Ref is acecss all T1'Class;

   V3 : T1_Ref := new T1;
   V4 : T1_Ref := new T1'Make(42);
   V5 : T2; -- NOT OK, there's no parameterless constructor

In the case of objects containing other objects, innermost objects constructors
are called first, before their containing object.

While the rest of the RFC is written using the scoped notation describe above,
we will also provide a non scoped notation which can be used for any type. A
constructor is a function in the same scope as the type its construct, of the
same name, with at least one parameter `in out` of the type in question. The
above can be re-written:

.. code-block:: ada

   package P is
      type T1 is tagged record
         null;
      end record;

      procedure T1 (Self : in out T1);
      procedure T1 (Self : in out T1; Some_Value : Integer);

      type T2 is record
         null;
      end record;

      procedure T2 (Self : in out T2; Some_Value : Integer);
   end P;

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

Super Constructor Call
----------------------

By default, the parent constructor called is the parameterless constructor.
A parametric constructor can be called instead by using the ``Super`` aspect
in the constuctor body, For example:

.. code-block:: ada

   type Root is tagged record
      procedure Root (Self : in out Root; V : Integer);
   end Root;

   type Child is new Root with record
      procedure Child (Self : in out Child);
   end Child;

   type body Child is new Root with record
      procedure Child (Self : in out Child)
         with Super (42)
      is
      begin
         null;
      end Child;
   end Child;

Note that the constructor of an abstract type can be called here, for example:

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
         with Super (42)
      is
      begin
         null;
      end Child;
   end Child;


Initialization Lists
--------------------

Constructors may need to initialize / call constructors on two categories of
data:

- fields within that object
- discriminants

The following sections will describe these two cases:

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
         with Initialize (F => (1, 2))
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

Here's a full example demonstrating both a regular use of discriminant and a use
with the new notation:

.. code-block:: ada

   package P is

      type Reg_Root (L_Root : Integer) is tagged record
      V : String (1 .. L_Root);
      end record;

      type Reg_Child (L_Child_1, L_Child_2 : Integer) is new Reg_Root (L_Child_1) with record
      W : String (1 .. L_Child_2);
      end record;

      type New_Root (L_Root : Integer) is tagged record
      V : String (1 .. L_Root);

      procedure New_Root (Self : in out New_Root; L : Integer);
      end record;

      type New_Child (L_Child_2 : Integer) is new New_Root with record
      W : String (1 .. L_Child_2);

      procedure New_Child (Self : in out New_Child; L1, L2 : Integer);
      end record;

  end P;

  package body P is


   type body New_Root (L_Root : Integer) is tagged record
    procedure New_Root (Self : in out New_Root; L : Integer)
       with Initializes (L_Root => L)
    is
    begin
       null;
    end;
   end record;

   type body New_Child (L_Child_2 : Integer) is new New_Root with record
    procedure New_Child (Self : in out New_Child; L1, L2 : Integer)
        with Super (L1), Initializes (L_Child_2 => L2)
    is
    begin
       null;
    end;
   end record;

 end P;

Note that there are two significant differences between the "regular" types and
types that have constructors:
- the parent discriminant is not set at derivation anymore, but through the
call to the super constructor
- the child type does not need to declare additional discriminant anymore just
for the purpose of setting the parent ones.

Constructors and Type Predicates
--------------------------------

Type predicates are meant to check the consistency of a type. In the context
of a type that has constructor, the consistency is expected to be true when
exiting the constructor. In particular, the initializion list is not expected
to create a predicate-valid type - predicates will only be checked after the
constructor has been processed.

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
