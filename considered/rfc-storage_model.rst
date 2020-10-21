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
     (Model : in out Storage_Data_Model; 
      From  : System.Address;
      To    : Address_Type; 
      Size  : Storage_Count);

   procedure Copy_Out
     (Model : in out Storage_Data_Model; 
      From  : Address_Type; 
      To    : System.Address; 
      Size  : Storage_Count);

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

      with procedure CUDA_Deallocate 
        (Model           : in out CUDA_Storage_Data_Model; 
         Storage_Address : out CUDA_Address;
         Size            : Storage_Count;   
         Alignment       : Storage_Count);    

      with procedure CUDA_Copy_In 
        (Model : in out CUDA_Storage_Data_Model; 
         From  : System.Address; 
         To    : CUDA_Address; 
         Size  : Storage_Count);

      with procedure CUDA_Copy_Out
        (Model : in out CUDA_Storage_Data_Model; 
         From  : CUDA_Address; 
         To    : System.Address; 
         Size  : Storage_Count);

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

      Device_Array : Host_Array_Type (1 .. 10);
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
     (Model : in out Root_Storage_Pool; 
      From  : System.Address;
      To    : System.Address; 
      Size  : Storage_Count);

   procedure Copy_Out
     (Model : in out Root_Storage_Pool; 
      From  : System.Address; 
      To    : System.Address; 
      Size  : Storage_Count);

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

To be studied

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
         From  : System.Address;
         To    : Address_Type; 
         Size  : Storage_Count) is <>;

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
        (Model : in out CUDA_Storage_Data_Model; 
         From  : System.Address; 
         To    : CUDA_Address; 
         Size  : Storage_Count);

      with procedure Copy_Out
        (Model : in out CUDA_Storage_Data_Model; 
         From  : CUDA_Address; 
         To    : System.Address; 
         Size  : Storage_Count);

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
