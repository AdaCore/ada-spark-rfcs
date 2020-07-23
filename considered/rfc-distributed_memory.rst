- Feature Name: Distibuted Memory
- Start Date: 2020-07-09
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

This features proposes a way to support Distributed Memory, an architecture where various components of a system have separate memory components that are (at least conceptually) addressed independently from each other and where special actions are needed to copy between the memory components.  That latter can't be supported by storage pools.  An example of such an architecture is CUDA, where each "device" (the GPU) has memory distinct from that of the host.

Motivation
==========

We need to be able state what distributed memory an object is to reside in.  For example, in CUDA we need the ability to declare an object as residing in device memory. Using CUDA as an example, what we do in C to allocate objects in both host and device memory and copy between them conceptually looks like this:

.. code-block:: C

  int *hostArray = malloc (sizeof (int) * 100);
  int *deviceArray = cudaMalloc (sizeof (int) * 100);

  // some initialization to deviceArray

  // copy the memory from host to device
  cudaCopy (deviceArray, hostArray);

  // work on device Array on the GPU working on the device

  // copy the memory from device to the host
  cudaCopy (hostArray, deviceArray);

  // free the host
  free (hostArray)

  // free the Array
  cudaFree (deviceArray)

If we try to directly map this to Ada using unconstrained arrays, we must initialize the bounds of the array, but those will also be in device memory and we need to tell the compiler how to copy data into that memory.

Guide-level explanation
=======================

If we tried to implement this in Ada using Storage Pools, we run into several limitations:

- They don't provide provision for initializations.
- They don't model copies in both directions.
- The usage of a controlled type requires complexity and run-time contraints that could be avoided.
- They require the usage of access types, while in a number of cases it would be more convenient to declare automatic objects as if they were declared normally.
- They assume that all addresses are of type System.Address, but there's no guarantee that each memory has the same address range.

This proposal introduces a new concept as an alternative to Storage_Pools: Distributed_Memory.  We provide the ability to create different memories, each with its own address type and functions that manipulate that memory.  Objects in different memories will normally be located on different physical components in the system architecture.

The following capabilities need to be specified for each memory:

- How to allocate memory
- How to deallocate memory
- How to copy from main (default) memory
- How to copy to main (default) memory

A temporary of default memory is used to perform a copy between two different distributed memory models, e.g.:

.. code-block:: Ada
  type Foo_I is new Integer with Distributed_Memory => Foo;
  type Bar_I is new Integer with Distributed_Memory => Bar;

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

Each memory is created as an instantiation of a generic package:

.. code-block:: Ada
  generic 
    type Address_Type is private;
    function Allocate (Size : Storage_Count) return Address_Type;
    procedure Free (Addr : in out Address_Type);
    procedure Copy_Out (From : System.Address; To : Address_Type; Size : Storage_Count);
    procedure Copy_In (From : Address_Type; To : System.Address; Size : Storage_Count);
  package System.Distributed_Memory is
    type Memory is private;
  private
    [...]
  end System.Distributed_Memory;

The intent is that the type of System.Distributed_Memory.Memory be a record that contains accesses to each of the defined subprograms.

An example of an instantiation for CUDA device memory is:

.. code-block:: Ada

  type CUDA_Address is mod 2 ** 64;

  package CUDA_Memory is
    new System.Distributed_Memory
      (Address_Type => CUDA_Address,
       Allocate     => CUDA_Allocate,
       Free         => CUDA_Free,
       Copy_Out     => CUDA_From_Host_To_Device,   
       Copy_In      => CUDA_From_Device_To_Host);

  function Allocate (Size : Storage_Count) return Cuda_Address;
  procedure Deallocate (Addr : in out Cuda_Address);
  procedure Copy_To_Target (From : System.Address; To : Cuda_Address; Size : Storage_Count);
  procedure Copy_From_Target (From : Cuda_Address; To : System.Address; Size : Storage_Count);

We indicate that an object or a type is in this memory using a new Distributed_Memory aspect. This means that:

- allocation is done via the allocate functon
- deallocation is done via the deallocation procedure
- all access to that memory is done via the copy in and copy out procedures

For example:

.. code-block:: Ada

    type Arr_Type is array (Integer range <>) of Integer;

    type Cuda_Arr_Type is new Arr with Distributed_Memory => CUDA_Memory.Memory;

    Host_Arr : Arr_Type (1 .. 100);

    -- The call below calls allocate function, then the copy procedure to initialize
    -- bounds. It would also call a copy procedure for the initializer if we had any.
    Device_Arr : Cuda_Arr_Type (1 .. 100);
  begin
     --  work on Host_Arr
     Device_Arr := Cuda_Arr_Type (Host_Arr); -- Ok, calling copy procedure

     --  send Device_Arr to some procedure expecting this kind of object, then
     --  working on it.

     Host_Arr := Arr_Type (Device_Arr); -- Ok, calling copy procedure
  end; -- calling deallocation procedure

Partial read and write are also allowed, for example:

.. code-block:: Ada

  Device_Arr (1) := Device_Arr (1) + 1;

Note that the above code may be expensive in some models (it is for CUDA), so coding standards may provide restrictions. 

To enable explicit specification of the default memory, a package called System.Distributed_Memory.Standard is provided.  It can be used to provide alternative specification selected at compilation time. For example you could have a file for host compilation that looks like the CUDA_Memory instantiation above, and a version for the device that looks like:

.. code-block:: Ada

  package CUDA_Memory renames System.Distributed_Memory_Standard.Memory;

This way, you can use the same value of the Distributed_Memory aspect throughout and select whether it's device or host memory by selecting the desired file (or directory) during the build process.

Moves between two objects in different memories, neither of which is the default memory, generates an intermediate copy to the default memory.

We can also use this feature with access types, so we can write:

.. code-block:: Ada

    type Arr_Type is array (Integer range <>) of Integer;
    type Cuda_Arr_Type is new Arr with Distributed_Memory => CUDA_Memory.Memory;

    type Host_Access is access all Arr_Type;
    type Device_Access is access all Cuda_Arr_Type;

    Host_Arr : Host_Access := new Arr_Type (1 .. 100);
    Device_Arr : Device_Access := new Cuda_Arr_Type (1 .. 100);
  begin
    Device_Arr.all := Cuda_Arr_Type (Host_Arr.all);

In the above case, Unchecked_Deallocation on the Device_Access type will call the specific CUDA deallocation.

Taking 'Address of an object with a Distributed_Memory aspect returns an object of the type of the address for that memory category, which may be different from System.Address.

Reference-level explanation
===========================

Nothing specific at this stage.

Rationale and alternatives
==========================

We initially considered using an aspect-based syntax instead of a generic, e.g.:

.. code-block:: Ada

  type Cuda_Address is mod 2 ** 64 with
    Cutsom_Address (
      Allocate         => Cuda_Allocate,
      Deallocate       => Cuda_Deallocate,
      Copy_To_Target   => Cuda_From_Host_To_Device,
      Copy_From_Target => Cuda_From_Device_To_Host,
      );

However, it turns out that there no clear advantage of the aspect v.s. the generic, and that the generic has the clear advantage of having a source-readable profile.

Drawbacks
=========

TBD

Prior art
=========

TBD

Unresolved questions
====================

This proposal doesn't fully replace the Storage_Pool abstraction. While the various allocate / deallocate functions can work with a global object, it's not straightforward to create a pool that would be deallocated.

There is a way to emulate this that might be close enough if the instantiation of Distributed_Memory is local and parametrized with local subprograms, e.g.:

.. code-block:: Ada

  procedure Some_Procedure is
    --  Some data for the pool

    function Allocate is [...]
    --  other functions

    package Local_Memory is new System.Distributed_Memory ([...]);

And of course, this could be further generalized though a generic to provide re-usable local memory models:

.. code-block:: Ada
  generic

  package Memory_Model is
   --  Some data for the pool

    function Allocate is [...]
    --  other functions

    package DSA is new System.Distributed_Memory ([...]);
  
  procedure Some_Procedure is
    package Local_Model is new Memory_Model;

But we'd still need code generation assistance in handling copies.

Future possibilities
====================

TBD

