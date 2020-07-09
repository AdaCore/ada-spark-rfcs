- Feature Name: Extended Storage Pools
- Start Date: 2020-07-09
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

This features proposes a new way to design storage pools, in particular to deal
with support of platforms with incompatible memory segments such as CUDA.

Motivation
==========

GPU support, for example CUDA, requires to declare object that ultimately reside
on the device memory. In C, allocation conceptually looks like:

.. code-block:: C

  int * hostArray = malloc (sizeof (int) * 100);
  int * deviceArray = cudaMalloc (sizeof (int) * 100);

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

The above sequence is difficult to map in Ada in the context of unconstrained 
arrays, where the initialization sequence requires to allocate memory for the 
boundaries, as well as copy to these boundaries.

Guide-level explanation
=======================

Storage Pools in Ada could be the begining of a solution. However, they suffer 
for several limitations:

- They do not provide provision for initialization of e.g. boundaries.
- They don't allow to model copies in both directions.
- The usage of a controlled type requires complexity and run-time contraints 
that could be avoided.
- They require the usage of pointers, while in a number of cases it would be 
more convenient to declare automatic objects as if they were declared on the 
stack.
- They require the usage of System.Address to handle addresses, while we may
want to represent an address on the target environment differently.

This proposal introduces a new concept as an alternative to a Storage_Pool: a 
Custom_Address. A Custom_Address is a type that models an address in a memory
pool potentially located at a different physical space. At its core, a 
Custom_Address is a definite type (could be scalar or composite) associated 
with 4 aspects, that describe 4 capabilities:

- How to allocate memory on this section
- How to deallocate memory from this section
- How to copy from the main memory to this section
- How to copy from this section to the main memory

The expected profile of the functions designated by the aspect is pre-set. 
Here's a simple example:

.. code-block:: Ada

  type Cuda_Address is mod 2 ** 64 with
    Cutsom_Address (
      Allocate         => Cuda_Allocate,
      Deallocate       => Cuda_Deallocate,
      Copy_To_Target   => Cuda_From_Host_To_Device,
      Copy_From_Target => Cuda_From_Device_To_Host,
      );

  function Allocate (Size : Storage_Count) return Cuda_Address;
  procedure Deallocate (Addr : in out Cuda_Address);
  function Copy_To_Target (From : System.Address; To : Cuda_Address; Size : Storage_Count);
  function Copy_From_Target (From : Cuda_Address; To : System.Address; Size : Storage_Count);

It is then possible to associate an object or a type to this new address, 
using a new Address_Type aspect. The consequence is that:

- allocation is done through the allocate functon
- deallocation is done through the deallocation function
- it is only possible to modify/read values of these types through full copies
from and to a host values

These three rules are only enforced if the custom address is different than 
System.Address. It's also possible to use System.Address straight out, which
can become handy in cases decribed below.

For example:

.. code-block:: Ada

    type Arr_Type is array (Integer range <>) of Integer;

    type Cuda_Arr_Type is new Arr with Address_Type => Cuda_Address;

    Host_Arr : Arr_Type (1 .. 100);

    -- The call below calls allocate function, then copy functions to initialize
    -- bounds. It would also call a copy function for initializer if we had any.
    Device_Arr : Cuda_Arr_Type (1 .. 100);
  begin
     --  work on Host_Arr
     Device_Arr := Cuda_Arr_Type (Host_Arr); -- Ok, calling copy functions

     --  send Device_Arr to some functions expecting this kind of object, then
     --  working on it.

     Host_Arr := Arr_Type (Device_Arr); -- Ok, calling copy function
  end; -- calling deallocation

Note that however, direct references such as:

.. code-block:: Ada

  Device_Arr (1) := 0;

would not be allowed. However, in a typicall program like the above, the device
program would declare Cuda_Address differently:

.. code-block:: Ada

  type Cuda_Address is new System.Address;

It would then be able to manipulate the resulting objects direclty.

Note that the above also works with pointers, so that it's also possible to
write:

.. code-block:: Ada

    type Arr_Type is array (Integer range <>) of Integer;
    type Cuda_Arr_Type is new Arr with Address_Type => Cuda_Address;

    type Host_Access is access all Arr_Type;
    type Device_Access is access all Cuda_Arr_Type;

    Host_Arr : Host_Access := new Arr_Type (1 .. 100);
    Device_Arr : Device_Access := new Cuda_Arr_Type (1 .. 100);
  begin
    Device_Arr.all := Cuda_Arr_Type (Host_Arr.all);

In the above case, Unchecked_Deallocation on the Device_Access type will call 
the specific Cuda deallocation.

Note that the usage of Address_Type also changes the result of 'Address, which
now returns a value of Address_Type instead of System.Address.

Reference-level explanation
===========================

Nothing specific at this stage.

Rationale and alternatives
==========================

TBD

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

While it's primimary driven by the need of GPU / CPU address modeling, this kind
of pattern could conceptulally replace usage of storage pools, or be used for
other cases of distributed data.
