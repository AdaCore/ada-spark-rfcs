- Feature Name: Storage_Model (2)
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

It is a simplification to the second design iteration on 
https://github.com/AdaCore/ada-spark-rfcs/pull/67.

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

Under this proposal, the current storage pool APIs should become a specific use 
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
to an access type. Under this aspect, allocations and deallocations
will come from the specified memory model instead of the standard ones. In 
addition, if write operations are needed for initialization, or if there is a 
copy of the target object from and to a standard memory area, the Copy_In and 
Copy_Out functions will be called. When used in conjunction with access types,
it allows to encompass the capabilities of storage pools, e.g.:

.. code-block:: Ada

   procedure Main is
      type Integer_Array is array (Integer range <>) of Integer;

      type Host_Array_Access is access all Integer_Array;
      type Device_Array_Access is access all Integer_Array
         with Storage_Model => CUDA_Memory;;
      
      procedure Free is new Unchecked_Deallocation 
         (Host_Array_Type, Host_Array_Access);
      procedure Free is new Unchecked_Deallocation 
         (Device_Array_Type, Device_Array_Access);

      Host_Array : Host_Array_Access := new Integer_Array (1 .. 10);

      Device_Array : Device_Array_Access := new Host_Array (1 .. 10);
      --  Calls CUDA_Storage_Model.Allocate to allocate the fat pointers and
      --  the bounds, then CUDA_Storage_Model.Copy_In to copy the values of the
      --  boundaries.
   begin
      Host_Array.all := (others => 0);

      Device_Array.all := Host_Array.all; 
      --  Calls CUDA_Storage_Model.Copy_In to write to the device array from the
      --  native memory.

      Host_Array.all := Device_Array.all;
      --  Calls CUDA_Storage_Model.Copy_Out to read from the device array and 
      --  write to native memory.

      Free (Host_Array);

      Free (Device_Array);
      --  Calls CUDA_Storage_Model.Deallocate;
   end;

Taking 'Address of an object with a specific memory model returns an object of 
the type of the address for that memory category, which may be different from 
System.Address.   

When copy are performed between two specific data models, the native memory
is used as a temporary between the two. E.g.:

.. code-block:: Ada

  type Foo_I is access Integer with Storage_Model => Foo;
  type Bar_I is access Integer with Storage_Model => Bar;

    X : Foo_I := new Integer;
    Y : Bar_I := new Integer;
  begin
    X.all := Y.all;

conceptually becomes:

.. code-block:: Ada

    X : Foo_I := new Integer;
    T : Integer;
    Y : Bar_I := new Integer;
  begin
    T := Y.all;
    X.all := T;

System.Storage_Model.Native_Model
---------------------------------

A new package is created, System.Native_Storage_Model. It declares in particular 
a model "Native_Model" that refers to the default native memory. When applied
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

      type R_A is access all R with Storage_Model => Some_Model;;

      V : R_A := new R;
      X : Integer := 98;
   begin
      V.B := X; -- Will call Copy_In with offset 4 assuming 32 bits integer.

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

Reference-level explanation
===========================

Nothing specific at this stage.

Rationale and alternatives
==========================

See https://github.com/AdaCore/ada-spark-rfcs/pull/51/ and 
https://github.com/AdaCore/ada-spark-rfcs/pull/67 for alternative designs.

We also investigated the possibility of providing a purely library based
approach to this problem, and not provide new language features. For example,
we could have:

.. code-block:: Ada

   generic
      type Foreign_Address is private;
      type Copy_Options is private;
      Default_Copy_Options : Copy_Options;

      with function Allocate (Size : Natural) return Foreign_Address;
      with procedure Deallocate (Address : Foreign_Address);
      with procedure Copy_To_Foreign (Dst : Foreign_Address; Src : System.Address; Bytes : Natural; Options : Copy_Options);
      with procedure Copy_To_Native (Dst : System.Address; Src : Foreign_Address; Bytes : Natural; Options : Copy_Options);
      with function Offset (Address : Foreign_Address; Bytes : Natural) return Foreign_Address;
   package Storage_Models is

   end Storage_Models;

As a way to describe the model, then generic to map specific type mapping, e.g.
for arrays:

.. code-block:: Ada

   generic
      type Typ is private;
      type Index_Typ is (<>);
      type Array_Typ is array (Index_Typ range <>) of Typ;
      type Array_Access is access all Array_Typ;
   package Storage_Models.Arrays is

      type Foreign_Array_Access is record
         Data   : Foreign_Address;
         Bounds : Foreign_Address;
      end record;

      function Allocate (First, Last : Index_Typ) return Foreign_Array_Access;
      function Allocate_And_Init (Src : Array_Typ) return Foreign_Array_Access;

      procedure Assign
        (Dst : Foreign_Array_Access; Src : Array_Typ; Options : Copy_Options := Default_Copy_Options);
      procedure Assign
        (Dst : Foreign_Array_Access; First, Last : Index_Typ; Src : Array_Typ; Options : Copy_Options := Default_Copy_Options);
      procedure Assign
        (Dst : Foreign_Array_Access; Src : Typ; Options : Copy_Options := Default_Copy_Options);
      procedure Assign
        (Dst : Foreign_Array_Access; First, Last : Index_Typ; Src : Typ; Options : Copy_Options := Default_Copy_Options);
      procedure Assign
        (Dst : in out Array_Typ; Src : Foreign_Array_Access; Options : Copy_Options := Default_Copy_Options);
      procedure Assign
        (Dst : in out Array_Typ; Src : Foreign_Array_Access; First, Last : Index_Typ; Options : Copy_Options := Default_Copy_Options);

      procedure Deallocate (Src : in out Foreign_Array_Access);
   
      function Uncheck_Convert (Src : Foreign_Array_Access) return Array_Access;

      type Array_Typ_Bounds is record
         First, Last : Index_Typ;
      end record;

      function Bounds (Src : Foreign_Array_Access) return Array_Typ_Bounds;

   end Storage_Models.Arrays;

However, this design has several flaws. First, it requires a lot of sub-generics
to be written. For arrays, considering the newly introduct fixed lower boundaries
arrays, that's 3 different generics for arrays of 1 dimension, but e.g. 81
different generic (3 ^ 4 = 81) for arrays of 4 dimensions. This also requires to
have knoweldge of the underlying representation for arrays, in particular on 
GNAT the so-called fat pointers as well as boundary representation, which turns
out not to be a trivial task. The above model also makes a number of things
difficult to express, such as aggregate initializations. 

Another alternative would be to avoid introducing Storage_Models altogether, 
and only look at legacy storage pools with the added Copy_In and Copy_Out
primitives. The rest of the design could then stay untouched.

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

TBD