- Feature Name: Standard OOP model
- Start Date: May 5th 2020
- RFC PR: 
- RFC Issue: 

Summary
=======

The objective of this proposal is to draft an OOP model for a hypothetical new version of Ada, closer to the models languages 
such as C++ and Java developers are accustomed to, fixing a number of oddities and vulnerabilities of the current Ada language.

Motivation
==========

The current Ada OOP model is source of a number of confusions and errors from people accustomed to OOP, in particular in
other languages such as C++ or Java. This proposal aims at adjusting the model to implement missing concept, fix Ada-specific 
vulnerabilities and retain some of the Ada advantages.

This proposal also attempts at keeping capabilities that do not need to be specifically removed to fit within a more intuitive
OOP model, such as e.g. discriminants and aggregates.

Experience shows that whenever possible, capabilities that can be enabled to regular records should as well. A good exemple of that
is the trend observed of people declaring Ada types tagged just for the purpose of having access to prefix notation, while such notation
does not require inheritance or dispatching. 

Guide-level explanation
=======================

The new design retains the difference between "regular" types and "classes". For consistency, both will be altered and consider that 
https://github.com/AdaCore/ada-spark-rfcs/pull/13 is implemented.

Class declaration
-----------------

The new class model is incompatible with the current tagged object model. In order to make the distinction, new tagged types will
be marked with the new class reserved word:

.. code-block:: ada

   type A_Class is class record
      null;
   end A_Class;

Primitives and components declarations
--------------------------------------

This new way of organizing components and primitives is available to both class records and simple records.

Under this new model, controlling primitives are declared within the lexical scope of their type. The first parameter of the
primitive has to be of the type of the record. This allows the user to decide on the naming convention, as well as the mode of
such parameter (in, out, in out, access, aliased). A record and and class record can have primitives declared both in the public 
and the private part. This is possibilty is extended to other components as well. The existence of a private part needs to be specified in the public part of a package with the notation "with
private". The following demonstrates the above:

.. code-block:: ada

   package P is
      type T1 is record
         F : Integer;
         
         procedure P (Self : in out T1; V : Integer); 
       end T1 
       with private;
       
       type T2 is class record
          F : Integer;
          
          procedure P (Self : in out T2; V : Integer);
       end T2
       with private;

   private

       type T1 is record
         F2 : Integer;
         
         procedure P2 (Self : in out T1; V : Integer); 
       end T1;
       
       type T2 is class record
          F2 : Integer;
          
          procedure P2 (Self : in out T2; V : Integer);
       end T2;

   end P;
   
   package body P is

       type body  T1 is record
         procedure P (Self : in out T1; V : Integer) is
         begin
            Self.F := V;
         end P;

         procedure P2 (Self : in out T1; V : Integer) is
         begin
            Self.F2 := V;
         end P2;
       end T1;
       
       type body T2 is record
         procedure P (Self : in out T2; V : Integer) is
         begin
            Self.F := V;
         end P;

         procedure P2 (Self : in out T2; V : Integer) is
         begin
            Self.F2 := V;
         end P2;
       end T2;

   end P;

In this model, it is not possible to write record types primitives outside of the scope anymore. Subprograms declared outside of such 
scope are just regular subprograms.

As a consequence, it's not possible anymore to have a record or a class record as a completion of a private type. This type now needs
to be marked either record private, or be a regular record with a private extension. For example

.. code-block:: ada

   package P is
      type T1 is record private;

      type T2 (<>) is record private; -- T2 is completed by a class, it has to be indefinite private view
      
      type T3 is record
         procedure P (Self : T3);
      end T3
      with private;

   private

       type T1 is record
         F2 : Integer;
         
         procedure P2 (Self : in out T1; V : Integer); 
       end T1;
       
       type T2 is class record
          F2 : Integer;
          
          procedure P2 (Self : in out T2; V : Integer);
       end T2;

       type T3 is record
          null;
       end T3;
   end P;

As for tagged types, there's a shortcut for a class private type, which means no public primitives or components:

.. code-block:: ada

   package P is
      type T1 is class private; 
   private
      type T1 is class record
         F2 : Integer;
         
         procedure P2 (Self : in out T1; V : Integer); 
       end T1;
   end P;

Class record can still be limited or have discriminants, in which cases the set of constaints that they have follow similar rules
as for tagged types.

Visibilty rules are the same as for types today. In particular, a class instance as access to private components of other instances of the same class.

Overriding and extensions
-------------------------

Extension of class record types work similarly to tagged records:

.. code-block:: ada

   package P is
      type T1 is class record
         procedure P (Self : in out T1);
      end T1;

      type T2 is new T1 with record
         procedure P (Self : in out T1);
      end T2;
   end P;

Primitives can be marked optionally overriding, following Ada 2005 rules. Inheritance model is single interitance of a class,
multiple inheritance of interfaces.

Interfaces and abstract types
-----------------------------

Intefaces and abstract types work the same way as for tagged types. Interfaces are specified differently, through 
"interface record", but otherwise operate as other interfaces (no concrete components or primitive):

.. code-block:: ada

   package P is
      type I is interface record
         procedure P (Self : in out I) is abstract;
      end I;
   end P;

Access types
------------

This capability is available to all types (including simple records).

This topic is to be considered in the context of a larger overall of access types. However, in the absence of such proposal,
the idea here is to have an access type declared implicitely at the same level as the type and accessible through the 'Ref notation.
An attribute 'Unchecked_Free is also declared, doing unchecked deallocation. 'Unchecked_Free can also be called directly on
the object. For example:

.. code-block:: ada

   package P is
      type T1 is class record
         procedure P (Self : in out T1);

         procedure P2 (Self : in out T1);
      end T1;
   end P;

   procedure Some_Procedure is
      V : T1'Ref := new T1;
      V2 : T1'Ref := new T1;
   begin
      T1'Unchecked_Free (V);
      V2'Unchecked_Free;
   end Some_Procedure;

For homogenity, 'Ref and 'Unchecked_Free are available to all Ada type - including pointers themesleves. It's now possible to write:

.. code-block:: ada

    V : T1'Ref'Ref := new T1'Ref;

'Ref access types for a given class object are compatible in the case of upcast, but need explicit conversions to downcast. You
can write:

.. code-block:: ada

   package P is
      type A is class record
         procedure P (Self : in out T1);
      end A;

      type B is new T1 with record
         procedure P (Self : in out T1);
      end B;
   end P;

   procedure Some_Procedure is
      A1 : A'Ref := new B;
      A2 : A'Ref;

      B1 : B'Ref := new B;
      B2 : B'Ref; 
   begin
      A2 := B1; -- OK, upcast, no need for pointer conversion
      B2 := A1; -- Illegal, downcast
      B2 := B'Ref (A1); -- OK, explicit downcast.
   end Some_Procedure;


Dispatching
-----------

A view to a (non-final) class record is dispatching, no matter if it's referenced in a primitive or not. So for example:

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

As a result, the reference to a class record is indefinite, unless it's declared final (see later).

In some cases, it's needed to reference a specific type for a non-dispatching call. In this case, there are two possibilities:

(1) only reference to the parent class is needed, this can be accessed through 'Super. If 'Super is applied on a type, this
refers to its direct parent. If it's applied on an object, it refers to the parent of the type of this object

(2) a reference to a specific definite type. Rules are the same as above, with the usage of 'Specific (either refering to a non 
dispatching specific type, or the specific view of the object):

For example:

.. code-block:: ada

   package P is
      type T1 is class record
         procedure P (Self : in out T1);
      end T1;

      type T2 is new T1 with record
         procedure P (Self : in out T2);
      end T2;
   end P;

   package body P is
      type T1 is class record
         procedure P (Self : in out T1) is
         begin
            null;
         end P; 
      end T1;

      type T2 is new T1 with record
         procedure P (Self : in out T2) is
         begin
            Self'Super.P;
            T2'Super (Self).P;
            Self'Specific.P;
            T2'Specific (Self).P;
         end P;
      end T2;
   end P;
   
Note that these can also be used to declare definite parameters, results or even variables:

.. code-block:: ada

  package P is
      type T1 is class record
         procedure P (Self : in out T1);
      end T1;
      
      V1 : T1; -- Illegal, T1 is indefinite;
      V : T1'Specific; -- Legal
      
Non-dispatching operations
--------------------------

The 'Specific notaton described above can also be used to declare non-primitive operations of a type. In this case, these operations
can be called through the usual prefix notation, but they cannot be overriden and can't be used for dispatching. For example:

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
     
Global object hierarchy
-----------------------

All class object implicitely derives from a top level object, Ada.Classes.Object, defined as follows:

.. code-block:: ada

   package Ada.Classes is
      type Object is class record
         function Image (Self : Object) return String;

         function Hash (Self : Object) return Integer;
      end Object;  
   end Ada.Classes;

Other top level primitives may be needed here.

Constructors and destructors
----------------------------

Constructors are available to both class record and simple records.

There is no controlled object in class records. Instead, class record can declare constructors and one destructor. The constructor
needs to be a procedure of the name of the object, taking an in out or access reference to the object. Destructors are named "final".

.. code-block:: ada

   package P is
      type T1 is class record
         procedure T1 (Self : in out T1);
         procedure T1 (Self : in out T1; Some_Value : Integer);

         procedure final (Self : in out T1);
      end T1;
      
      type T2 is class record
         procedure T2 (Self : in out T2; Some_Value : Integer);
      end T2;
   end P;

This specific proposals is linked to an overal finalization proposal. It may alter the actual syntax / reserved word for destructors.

As soon as a constructor exist, and object cannot be created without calling one of the available constructors, omitting the
self parameter. This call is made on the object creation, e.g.:

.. code-block:: ada

   V : T1; -- OK, parameterless constructor
   V2 : T1 (42); -- OK, 1 parameter constructor
   V3 : T1'Ref := new T1;
   V4 : T1'Ref := new T1 (42);
   V5 : T2; -- NOT OK, there's no parameterless constructor

A constructor of a child class always call its parent constructor before its own. It's either implicit (parameterless constructor) 
or explicit. When explicit, it's provided through the Super aspect, specified on the body of the constructor, for example:

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

Destructors are implicitely called in sequence - the parent destructor is always called after its child.

Copy constructor
----------------

Copy constructors are available to both class records and simple records.

A special constructor, a copy constructor, can be identified with the "Copy" aspect. It's called upon the copy of an object (for
example, an assignment). It can also be called explicitely, and needs to call parent constructors. It needs to be a constructor with 
two values of the same type. For example:

.. code-block:: ada

   package P is
      type T1 is class record
         procedure T1 (Self : in out T1; Source : T1)
	 with Copy; 
      end T1;
      
Note that to the difference of the Adjust function of controlled types, the copy constructor is responsible to do the actual copy from 
Source to Self - it's not done ahead of time. 

If not specified, a default constructor is automatically generated. It componses - it will will call the parent copy constructor,
then copy field by field its additional components, calling component constructors if necessary.


Constructors and discriminants
------------------------------

These considerations are applicatble to both class records and simple records.

When combined with discriminants, the discriminants values must be provided before the constructor values:

.. code-block:: ada

   package P is
      type T1 (L : Integer) is class record
         procedure T1 (Self : in out T1);
         procedure T1 (Self : in out T1; V : Integer);

	 X : Some_Array (1 .. L);
      end T1;
   end P;

   V : T1 (10)(10);

Note that the above can create ambiguous situations in corner cases, which are to be detected at compile time and resolved 
through e.g. naming:

.. code-block:: ada

   package P is
      type T1 (L : Integer := 0) is class record
         procedure T1 (Self : in out T1);
         procedure T1 (Self : in out T1; V : Integer);

	 case L is
            when 0 =>
               X : Integer;
            when others =>
               null;
          end case;
      end T1;
   end P;

   V : T1 (10); -- Illegal, is this a discriminant with default constructor or a default discriminant with a constructor?
   V2 : T1 (L => 10); -- Legal
   V3 : T1 (V => 10); -- Legal
   
Constructors default values and and aggregates
----------------------------------------------

These considerations are applicatble to both class records and simple records.

Aggregates are still possible with class records. The order of evaluation for fields is:

- their default value. Always computed
- the constructor
- any value from the aggregate
 
The rationale for this order is to go from the generic to the specific. This is a departure from the existing Ada model where
aggregate override default initialization. Under this model, there is no more way to override default initialization for records - 
if initialization should only be done some times and not others, it is to be done in the constructor (which is available for records
and class records). With class records, aggreates are a shortcut for field by field assignment after iniitalization.
 
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

Note that it's of course always possible (and useful) to use an aggreate within a constructor, still as a shortcut to field by
field assignment:

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


Final fields
------------

Final fields are available to both class records and simple records.

Class record support constant fields, which are field which value cannot be changed after the constructor call, not even during 
aggregate which is considered as a shortcut for assignment. For example:

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
   
class record also implement the concept of final classes, which is a class not deriveable. There are two advantages of final classes:

- In terms of design, this makes it clear that this class is not intended to be derived. It's often the case where derivation is
  used just to have a class in a given framework but isn't prepared to be itself modified.
- A very significant one: a final class is effectively a definite type. As a result, it can be stored on the stack or as a component,
  calls to a view of a final class are not dispatching (the target is statically known). 
   
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
   
   
Operators and exotic primitives
-------------------------------

Class record do not provide dispatching on multiple parameters, on parameters other than the first, or dispatching on results. 
If you declare primitives with references to the type other than the first parameter, they will not be used for controlling. This 
means that parameters that are the same at top level may differ when deriving:

Operators can be declared as primitives:

.. code-block:: ada

   package P is
      type T1 is class record
         procedure "=" (Left, Right : T1);
      end T1;

      type T2 is new T1 with record
         procedure "=" (Left : T2; Right : T1);
      end T1;
   end P;
   
Body-only classes
-----------------

One limitation of the tagged type to lift under this system is the ability to declare a class only in the body of a package. This 
should be legal under this new system.

.. code-block:: ada

   package body P is
      type T2 is class record
         F : Integer;
         procedure P (Self : in out T2; V : Integer);
      end T2;
      
      type body T2 is class record
         procedure P (Self : in out T2; V : Integer) is
         begin
            Self.F := V;
         end P;
      end T2;
   end P;
   
Coextensions
------------

Under the current model, coextensions are replaced by constructors (it's possible to mandate an object to be used in the construction
of the class) and destructors (that same object can always be destroyed in the destructor). There is no way to create a coextension
on a class record.

Tagged types
------------

Under this proposal, tagged records and class record can co-exist, as they live in completely distinct hierarchies. Howeer, tagged
types should only be considered for a comptability and migration standpoint. Most tagged record use cases should be relatively easy
to move to class records.

Reference-level explanation
===========================


Rationale and alternatives
==========================


Drawbacks
=========


Prior art
=========

This proposal is heavily influence by C++, C# and Java (which arguably have influenced one another quite a lot).

Unresolved questions
====================

This proposal relies on the unified record syntax proposal, and will need to be updated in light of potential
revamped access model and finalization models.

A number of the capabilities of the standard run-time library rely today on tagged type. A thorough review should be made to
identify which should be removed (e.g. controlled type), which should be migrated, and which can actually be implemented without
relying on classes altogether (things such as streams or pools come to mind). The removal of coextensions types also supposes a 
different model for general iteration, as it currently relies on user-defined references (implemented through coextensions).

Future possibilities
====================

One important aspect of Ada is to allow data to be as static as possible. OOP typically requires the use of pointer. The Max_Size
proposal (https://github.com/QuentinOchem/ada-spark-rfcs/blob/max_size/considered/max_size.rst) is a independent proposal to allow
polymorphic object residing in automatic memory section such as fields or stack.

Some of the notations introduced could be extended to other types, such as protected or tasks type.

The "with private;" notation should also be extended to nested packages, allowing to differenciate to nest the private part of a 
nested package in the private part of its enclosing package.

The scoped primitive notation is currently specific to record types. It could be extended to all types (which would have the effect
or re-enabling the possibility to complete a simple private type by a record).
