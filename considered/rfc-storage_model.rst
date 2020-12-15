- Feature Name: Storage_Model
- Start Date: 2020-??-??
- RFC PR: 
- RFC Issue: (leave this empty)

Summary
=======

This features proposes to redesign the concepts of Storage Pools, into
a more efficient model allowing higher performances and easier integration with
low footprint embedded run-times.

It also extends it to support distributed memory models, in particular to 
support interactions with GPU, as initially proposed under 
https://github.com/AdaCore/ada-spark-rfcs/pull/51/.

As an other extension of the model, it proposes to allow the specification of
specific allocators / deallocators not only for object creates dynamically 
through accessors but also statically.

Motivation
==========

The current Storage Pools, while very powerful concept of Ada, rely heavily on 
the usage of object orientation and controlled objects. While there
is no conceptual reason to use these two concepts, they unfortunatly imposes
constraints in terms of performances (e.g. dispatching calls involve an
indirection that is slower and can't be inlined) and run-time footprint (
controlled types and finalization relies on full-runtime capabilities on e.g.
GNAT).

A limitation of pools is that they doesn't allow to describe copy of data 
between different pools of memory, as would be necessary e.g. for distributed 
systems such as CPU / GPU.

Under this proposal, the current storage pool APIs should become specific use 
cases of the generic memory model proposed here.


Guide-level explanation
=======================

Aspect Storage_Model_Type
-------------------------

A Storage model is a type which is associated with an aspect 
"Storage_Model_Type", e.g.:

.. code-block:: Ada

   type A_Model is null record
      with Storage_Model_Type;

Storage_Model_Type itself allow for 6 parameters:

- Address_Type, the type of the address managed by this model.
- Allocate, a procedure used for allocating memory in this model
- Deallocate, a procedure used for deallocating memory in this model
- Copy_In, a procedure used to copy memory from native memory to this model
- Copy_Out, a procedure used to copy memory from this model to native memory
- Storage_Size, a function returning the amount of memory left

By default, Address_Type is System.Address, and all other 5 procedures are 
performing native operations (e.g. the allocator is the native new allocator).
Users can decide to specify one or more of these. When an Address_Type is
specified and different than System.Address, the all other 5 procedures have
to be specified.

The profile of these procedures are as follow:

.. code-block:: Ada

   procedure Allocate 
     (Model           : in out Storage_Data_Model; 
      Storage_Address : out Address_Type;      
      Size            : Storage_Count; 
      Alignment       : Storage_Count);

   procedure Deallocate 
     (Model           : in out Storage_Data_Model; 
      Storage_Address : out Address_Type;
      Size            : Storage_Count;   
      Alignment       : Storage_Count);    

   procedure Copy_In 
     (Model   : in out Storage_Data_Model; 
      From    : System.Address;
      To      : Address_Type; 
      Offset  : Storage_Count;
      Size    : Storage_Count);

   procedure Copy_Out
     (Model  : in out Storage_Data_Model; 
      From   : Address_Type; 
      Offset : Storage_Count;
      To     : System.Address; 
      Size   : Storage_Count);

   function Storage_Size
     (Pool : Storage_Data_Model)
      return Storage_Count;
  
Here's an example of how this could be instantiated in the context of CUDA:

.. code-block:: Ada

   package CUDA_Memory is

      type CUDA_Storage_Model is null record 
         with Storage_Model_Type => (
            Address_Type => CUDA_Address,
            Allocate     => CUDA_Allocate,
            Deallocate   => CUDA_Deallocate,
            Copy_In      => CUDA_Copy_In,
            Copy_Out     => CUDA_Copy_Out,
            Storage_Size => CUDA_Storage_Size
         );

      type CUDA_Address is new System.Address;
      --  We're assuming for now same address size on host and device

      procedure CUDA_Allocate 
        (Model           : in out CUDA_Storage_Data_Model; 
         Storage_Address : out CUDA_Address;
         Size            : Storage_Count; 
         Alignment       : Storage_Count);

      procedure CUDA_Deallocate 
        (Model           : in out CUDA_Storage_Data_Model; 
         Storage_Address : out CUDA_Address;
         Size            : Storage_Count;   
         Alignment       : Storage_Count);    

      procedure CUDA_Copy_In 
        (Model  : in out CUDA_Storage_Data_Model; 
         From   : System.Address; 
         To     : CUDA_Address; 
         Offset : Storage_Count;
         Size   : Storage_Count);

      procedure CUDA_Copy_Out
        (Model   : in out CUDA_Storage_Data_Model; 
         From    : CUDA_Address; 
         Offset  : Storage_Count;
         To      : System.Address; 
         Size    : Storage_Count);

      with function CUDA_Storage_Size
        (Pool : CUDA_Storage_Data_Model)
         return Storage_Count return Storage_Count'Last;

      CUDA_Memory : CUDA_Storage_Model;

   end CUDA_Memory;

Aspect Storage_Model
--------------------

A new aspect, Storage_Model, allows to specify the memory model associated 
to a subtype. Under this aspect, allocations and deallocations
will come from the specified memory model instead of the standard ones. In 
addition, if write operations are needed for initialization, or if there is a 
copy of the target object from and to a standard memory area, the Read and 
Write function will be called. When used in conjunction with access types,
it allows to encompass the capabilities of storage pools, e.g.:

.. code-block:: Ada

   procedure Main is
      type Integer_Array is array (Integer range <>) of Integer;

      type Integer_Array is array (Integer range <>) of Integer;

      subtype Host_Array_Type is Integer_Array;
      subtype Device_Array_Type is Integer_Array 
         with Storage_Model => CUDA_Memory;
      
      type Host_Array_Access is access all Host_Array_Type;
      type Device_Array_Access is access all Device_Array_Type;
      
      procedure Free is new Unchecked_Deallocation 
         (Host_Array_Type, Host_Array_Access);
      procedure Free is new Unchecked_Deallocation 
         (Device_Array_Type, Device_Array_Access);

      Host_Array : Host_Array_Access := new Integer_Array (1 .. 10);

      Device_Array : Device_Array_Access := new Host_Array (1 .. 10);
      --  Calls CUDA_Storage_Model.Allocate to allocate the fat pointers and
      --  the bounds, then CUDA_Storage_Model.Write to copy the values of the
      --  boundaries.
   begin
      Host_Array.all := (others => 0);

      Device_Array.all := Host_Array.all; 
      --  Calls CUDA_Storage_Model.Write to write to the device array from the
      --  native memory.

      Host_Array.all := Device_Array.all; -- Calls CUDA_Storage_Model.Write.
      --  Calls CUDA_Storage_Model.Read to read from the device array and 
      --  write to native memory.

      Free (Host_Array);

      Free (Device_Array);
      --  Calls CUDA_Storage_Model.Deallocate;
   end;

It can however also be used in the context of data that does not require 
explicit dynamic allocation and deallocation, e.g.:

.. code-block:: Ada

   procedure Main is
      type Integer_Array is array (Integer range <>) of Integer;

      subtype Host_Array_Type is Integer_Array;
      subtype Device_Array_Type is Integer_Array 
         with Storage_Model => CUDA_Memory;

      Host_Array : Host_Array_Type := (1 .. 10);

      Device_Array : Device_Array_Type (1 .. 10);
      --  Calls CUDA_Storage_Model.Allocate to allocate the fat pointers and
      --  the bounds, then CUDA_Storage_Model.Write to copy the values of the
      --  boundaries.
   begin
      Host_Array := (others => 0);

      Device_Array := Host_Array; 
      --  Calls CUDA_Storage_Model.Write to write to the device array from the
      --  native memory.

      Host_Array := Device_Array; -- Calls CUDA_Storage_Model.Write.
      --  Calls CUDA_Storage_Model.Read to read from the device array and 
      --  write to native memory.

      --  Calls CUDA_Storage_Model.Deallocate on Device_Array;
   end;

Taking 'Address of an object with a specific memory model returns an object of 
the type of the address for that memory category, which may be different from 
System.Address.   

When copy are performed between two specific data models, the native memory
is used as a temporary between the two. E.g.:

.. code-block:: Ada

  subtype Foo_I is Integer with Storage_Model => Foo;
  subtype Bar_I is Integer with Storage_Model => Bar;

    X : Foo_I;
    Y : Bar_I;
  begin
    X := Foo_I (Y);

conceptually becomes:

.. code-block:: Ada

    X : Foo_I;
    T : Integer;
    Y : Bar_I;
  begin
    T := Integer (Y);
    X := Foo_I (T);

System.Storage_Model.Native_Model
---------------------------------

A new package is created, System.Storage_Model. It declares in particular a
model "Native_Model" that refers to the default native memory. When applied
to storage models, the effect is a no-op. It can be used to explicitely declare
usage of native global memory, which is convenient in some situations. It is
also useful as a live reference of the profile for the various functions.

.. code-block:: Ada

   package System.Storage_Model is

      subtype Native_Address is System.Address;

      type Native_Storage_Model_Type is limited private 
         with Storage_Model_Type => (
            Address_Type => Native_Address,
            Allocate     => Native_Allocate,
            Deallocate   => Native_Deallocate,
            Copy_In      => Native_Copy_In,
            Copy_Out     => Native_Copy_Out,
            Storage_Size => Native_Storage_Size'Last
         );

      procedure Native_Allocate 
        (Model           : in out Native_Storage_Model_Type; 
         Storage_Address : out Native_Address;
         Size            : Storage_Count; 
         Alignment       : Storage_Count);

      procedure Native_Deallocate 
        (Model           : in out Native_Storage_Model_Type; 
         Storage_Address : out Native_Address;
         Size            : Storage_Count;   
         Alignment       : Storage_Count);    

      procedure Native_Copy_In 
        (Model  : in out Native_Storage_Model_Type; 
         From   : System.Address; 
         To     : Native_Address; 
         Offset : Storage_Count;
         Size   : Storage_Count);

      procedure Native_Copy_Out
        (Model   : in out Native_Storage_Model_Type; 
         From    : Native_Address; 
         Offset  : Storage_Count;
         To      : System.Address; 
         Size    : Storage_Count);

      with function Native_Storage_Size
        (Pool : Native_Storage_Data_Model)
         return Storage_Count return Storage_Count'Last;

      Native_Memory : Native_Storage_Model_Type;
   
   private
      
   end System.Storage_Model;

Offset in Storage_Model
-----------------------

In some situations, copies in and out are not done on the object itself, but
on a component of such object (e.g. for record and array types). For example:

.. code-block:: Ada

      type R is record
         A, B : Integer;
      end record;

      V : R with Storage_Model => Some_Model;
      X : Integer := 98;
   begin
      V.B := X; -- Will call Copy_In with offset 4 assuming 32 bits integer.
      
Aspect Storage_Section_Type
---------------------------

On top of Storage_Model, this proposal also introduces the concept of 
Storage_Section. A storage section allows to introduce a specific section of
a storage model that can be managed separately, and possibly deallocated at
once. It is working at the same level (and replacing) Ada 2012 subpools.

A Storage_Section_Type is declared using the name of the model it is a section
of - by default the default native model, and an allocator that describes how
to create memory in such section. E.g.:

.. code-block:: Ada

      type My_Model_Type is null record with Storage_Model_Type (...)

      type My_Section_Type is null record 
         with Storage_Section => (
            Storage_Model => My_Model,
            Allocate      => My_Section_Allocate
         );

      procedure My_Section_Allocate 
        (Model           : in out My_Model_Type; 
         Section         : in out My_Section_Type
         Storage_Address : out CUDA_Address;
         Size            : Storage_Count; 
         Alignment       : Storage_Count);

      My_Model   : My_Model_Type;
      My_Section : My_Section_Type with Enclosing_Storage_Model => My_Model;

      subtype Some_Type is Integer with Storage_Model => My_Section;

      V : Some_Type;

As seen above, a section can be provided instead of a model to the 
Storage_Model attribute. In this case, the only change is that allocation is
done through the My_Section_Allocate call instead of the default allocator. 
Like before, this is resolved statically.

Subtypes Compatibility
----------------------

Since memory models statically instrument allocation, deallocation and copies, 
it is necessary to know at compile time which to call. While this is not an
issue for object at the global or stack level, it is when referenced through
pointers.

As a consequence to the above, it is illegal for a pointer to point to an 
object with a different storage model than its designated target, or to
assigned to a pointer a value comping from another pointer with an different
storage model. For example:

.. code-block:: Ada

      type My_Model_Type is null record with Storage_Model_Type (...)

      Model : My_Model_Type;

      subtype My_Integer is Integer with Storage_Model => Model;

      type P1 is access all Integer;
      type P2 is access all My_Integer;
   
      V1 : P1 := new My_Integer; -- Illegal, incompatible models.
      V2 : P2 := V1; -- Illegal, incompatble models

However, the above is not true if both models end up being sections of the
same model, for example the following is legal:

.. code-block:: Ada

      type My_Model_Section_Type is null record with Storage_Section_Type (...)

      Section : My_Model_Section_Type with 
         Enclosing_Storage_Model => System.Storage_Model.Native_Model;

      subtype My_Integer is Integer with Storage_Model => Section;

      type P1 is access all Integer;
      type P2 is access all My_Integer;
   
      V1 : P1 := new My_Integer; 
      V2 : P2 := V1; 

Components and Storage Models
-----------------------------

A subtype and its representation always belongs to a unique storage model. As a
consequence, and composite subtype and its components always belong to a unique
model, no matter how the storage model of the underlying type is declared. 
This allows in particular the following:

.. code-block:: Ada

      type R1 is record
         F1, F2 : Integer;
      end record
      with Storage_Model => Model_1;

      type R2 is record
         F1, F2 : Integer;
      end record
      with Storage_Model => Model_2;

      suybtype R3 is R1 with Storage_Model => Model_3;

      V1 : R1;
      V2 : R2;
      V3 : R3;
      V4 : Integer;
   begin
      V2.F1 := V1.F1; -- Calls copy-in and copy-out between model 2 and model 1
      V3.F1 := V1.F1; -- Calls copy-in and copy-out between model 3 and model 1
      V4 := V1.F1; -- Calls copy-in and copy-out between native model and model 1

Parameters and Storage Models
-----------------------------

It is illegal to pass to a subprogram that is expecting a formal parameter of
a specific storage model an object of a different storage model. This caters
in particular for cases where the object is passed by reference - explicitely
or not. For example:

.. code-block:: Ada

      subtype My_Integer is Integer with Storage_Model => Some_Model;
      procedure P (V : aliased Integer);

      O : My_Integer;
   begin
      P (O); -- error

In these cases, instead, an explicit copy would need to be made, as to make
it clear that there are two object to consider and identify where the copy 
should be made:

.. code-block:: Ada

      subtype My_Integer is Integer with Storage_Model => Some_Model;
      procedure P (V : aliased Integer);

      O1 : My_Integer;
      O2 : Integer;
   begin
      O2 := O1;
      P (O2); -- ok

Note that we could have consider making such restriction apply only on 
by-reference mechanism. However, there are cases where the decision on wether
a given parameter is passed by reference or not is implementation-dependent, 
it's easier to have a general rule that work the same for all cases.

As a consequence, the following example is also illegal:

.. code-block:: Ada

      subtype My_Integer is Integer with Storage_Model => Some_Model;
      procedure P (V : Integer);

      O : My_Integer;
   begin
      P (O); -- error

Generics and Storage Models
---------------------------

Generic expansion will take into account storage model of formal parameters
when expanding code. On top of that, it is possible to explicitely constrain a
storage model when declaring a generic formal parameter and to ensure 
consistency of usage of said storage model, e.g.:

.. code-block:: Ada

   generic
      Model : in Storage_Model_Type;
      type T1 is private with Storage_Model => Model;
      type T2 is private with Storage_Model => Model;
   
Default_Storage_Model
---------------------

Similar to the Ada pragma Default_Storage_Pool, a pragma 
Default_Storage_Section is provided and specifies the Storage_Section to be 
used for all types and subtypes explicitely declared in a given package.


Storage_Model Shortcuts
-----------------------

Since Storage_Model is applied directly on a subtype, it can also be applied
directly at object creation time. For example:

.. code-block:: Ada

   Section_1 : Section_Type with 
      Enclosing_Storage_Model => System.Storage_Model.Native_Model;
   Section_2 : Section_Type with 
      Enclosing_Storage_Model => System.Storage_Model.Native_Model; 

   subtype Acc is new Integer;

   V1 : Integer with Storage_Model => Section_1;

   X : Acc := new (Section_1) Integer;
   
Note that in the case of access types, we're re-using the current subpool
syntax. Compatibilty between subtypes as described before still apply.

In a similar way, Storage_Model can also be applied directly on a type.

.. code-block:: Ada

   type Some_Type is new Integer with Storage_Model => Some_Model;

Legacy Storage Pools
--------------------

Legacy Storage Pools are now a Storage_Model. They are implemented as follows:

.. code-block:: Ada

   type Root_Storage_Pool is abstract
     new Ada.Finalization.Limited_Controlled with private
   with Storage_Model_Type => (      
      Allocate     => Allocate,
      Deallocate   => Deallocate,
      Copy_In      => Copy_In,
      Copy_Out     => Copy_Out,
      Storage_Size => Storage_Size
   );
   pragma Preelaborable_Initialization (Root_Storage_Pool);

   procedure Allocate
     (Pool                     : in out Root_Storage_Pool;
      Storage_Address          : out System.Address;
      Size_In_Storage_Elements : System.Storage_Elements.Storage_Count;
      Alignment                : System.Storage_Elements.Storage_Count)
   is abstract;

   procedure Deallocate
     (Pool                     : in out Root_Storage_Pool;
      Storage_Address          : System.Address;
      Size_In_Storage_Elements : System.Storage_Elements.Storage_Count;
      Alignment                : System.Storage_Elements.Storage_Count)
   is abstract;

   function Storage_Size
     (Pool : Root_Storage_Pool)
      return System.Storage_Elements.Storage_Count
   is abstract;

   procedure Copy_In 
     (Model  : in out Root_Storage_Pool; 
      From   : System.Address;
      To     : System.Address; 
      Offset : Storage_Count;
      Size   : Storage_Count);

   procedure Copy_Out
     (Model  : in out Root_Storage_Pool; 
      From   : System.Address; 
      Offset : Storage_Count;
      To     : System.Address;       
      Size   : Storage_Count);

As an extra capability, they are augmented with the Copy_In / Copy_Out
capabilities.

The legacy notation:

.. code-block:: Ada

   type My_Pools is new Root_Storage_Pool with record [...]

   My_Pool_Instance : Storage_Model_Pool.Storage_Model :=
      My_Pools'(others => <>);

   type Acc is access all Integer_Array with Storage_Pool => My_Pool;

can still be accepted as a shortcut for the previous expression.

Legacy Subpools 
---------------

Legacy subpools capabilities should be acheiveable through storage sections. 
One aspect of subpools that is not carried over by storage sections is the
fact that subpools are finalizing their contents when dealocatted, storage
sections do not. If needed, finalization needs to be done at the object level.

Reference-level explanation
===========================

Nothing specific at this stage.

Rationale and alternatives
==========================

We initially considered using a generic profile instead of a set of aspects, 
which was actually the direction initally proposed under 
https://github.com/AdaCore/ada-spark-rfcs/pull/51/. E.g.:

.. code-block:: Ada

   with System.Storage_Elements; use System.Storage_Elements;

   generic 
      type Storage_Data_Model (<>) is limited private;
      type Address_Type is private;

      with procedure Allocate 
        (Model           : in out Storage_Data_Model; 
         Storage_Address : out Address_Type;
         Size            : Storage_Count; 
         Alignment       : Storage_Count) is <>;

      with procedure Deallocate 
        (Model           : in out Storage_Data_Model; 
         Storage_Address : out Address_Type;
         Size            : Storage_Count;   
         Alignment       : Storage_Count) is <>;    

      with procedure Copy_In 
        (Model : in out Storage_Data_Model; 
         From    : System.Address;
         To      : Address_Type; 
         Offset  : Storage_Count;
         Size    : Storage_Count) is <>;

      with procedure Copy_Out
        (Model : in out Storage_Data_Model; 
         From  : Address_Type; 
         To    : System.Address; 
         Size  : Storage_Count) is <>;

      with function Storage_Size
        (Pool : Storage_Data_Model)
         return Storage_Count is <>;
  
   package System.Storage_Models is      
     
      type Storage_Model is new Storage_Data_Model;
   
   end System.Storage_Models;

This then could have been used e.g. in the following way:

.. code-block:: Ada

   package CUDA_Memory is

      type CUDA_Storage_Data_Model is null record;
      --  We don't need any specific data associated with the model in CUDA

      type CUDA_Address is new System.Address;
      --  We're assuming for now same address size on host and device

      procedure Allocate 
        (Model           : in out CUDA_Storage_Data_Model; 
         Storage_Address : out CUDA_Address;
         Size            : Storage_Count; 
         Alignment       : Storage_Count);

      with procedure Deallocate 
        (Model           : in out CUDA_Storage_Data_Model; 
         Storage_Address : out CUDA_Address;
         Size            : Storage_Count;   
         Alignment       : Storage_Count);    

      with procedure Copy_In 
        (Model  : in out CUDA_Storage_Data_Model; 
         From   : System.Address; 
         To     : CUDA_Address; 
         Offset : Storage_Count;
         Size   : Storage_Count);

      with procedure Copy_Out
        (Model  : in out CUDA_Storage_Data_Model; 
         From   : CUDA_Address; 
         Offset : Storage_Count;
         To     : System.Address; 
         Size   : Storage_Count);

      with function Storage_Size
        (Pool : CUDA_Storage_Data_Model)
         return Storage_Count return Storage_Count'Last;

      package CUDA_Storage_Model is new System.Storage_Models 
        (CUDA_Storage_Data_Model, CUDA_Address);

      CUDA_Memory : CUDA_Storage_Model.Storage_Model;
      --  This CUDA_Memory object is an instance of the Storage_Model declared
      --  in CUDA_Storage_Model, which associates all the functions declared
      --  in the generic when generating code.

   end CUDA_Memory;

This would have had the advantage of having a source-readable profile. However,
when introducing the Storage_Model type which is necessary to map all 
capabilities of pools, this introduced confusions with two types for the data
model, the formal parameter of the generic and the one declared in the generic
itself. The situation gets even more confusing if Storage_Data_Model is a 
tagged type - there's not really a way to accept such tagged type in the 
generic model and derive it. We also tried to make Storage_Model a subtype
instead of a type. However, this still doesn't really works when using e.g. 
Storage_Pools, where Allocate and Deallocate are abstract subprograms that
can't be passed as-is is impossible (they are abstract).

Once may also argue that getting the type to retreive the 
formal parameter of the instantiation is a bit of an exotic mechanism in Ada,
aspects feel more canonical, closer to e.g. user defined iterators.

Another question is wether Storage_Model should be allowed:
   - (1) only for access types (as storage pools)
   - (2) only at type level
   - (3) only for subtype

The rationale for not bounding the model to an access type but rather a type
or subtype is to allow to write code manipulating different model without the
need of explicitely using pointers, allocation and deallocation. This allows in
particular stack-like notation which is overall safer and more readable. One
direct advantage of this is that this also opens the possibilty to developming
heap based pools on native memory used as stack - a common case of this is
the need to declare a large local temporary array.

Once the above is said, it is not possible to use type-level declaration to
specify memory model. In particular, this does not work for OOP, as declaring
tagged types with different memory models would essensially require to create
different hierarchies.

Using subtypes introduces one specific incompatibilty, see the section on 
subtype incompatibilty. Besides this specific aspect, it still allows to 
identify specific places where conversions need to happen.

Drawbacks
=========

TBD

Prior art
=========

TBD

Unresolved questions
====================

TBD

Future possibilities
====================

The memory model described here is providing read and write operations to and
from foreign memory. It would be useful to study to which extent this can be
aligned with the concept of streams - either provide a generic stream
implementation automatically taking advantage of this capability, or consider
a redesign of stream in the same direction as pools. The later however looks
like a more difficult endavor.
