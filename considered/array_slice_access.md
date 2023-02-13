- Feature Name: Array Slice Access
- Start Date: 2023-02-13
- RFC PR:
- RFC Issue:

Summary
=======

Add the ability to create an access to a continuous sub part of an array
(a.k.a. a slice):

```ada
   type Arr_Type is array (Natural range <>) of UInt8;
   type Arr_Access is access all Arr_Type;
   Arr : aliased Arr_Type := (1 .. 10 => 42);
   Ptr : Arr_Access;
begin
   Ptr := Arr (4 .. 6)'Access; -- New feature

   pragma assert (Ptr.all'Length = 3);
```

It is possible to make a sub-slice from a slice:
```ada
   Ptr := Ptr(Ptr'First + 1 .. Ptr'Last)'Access;
```

But growing the slice out of its bounds is not allowed as the original bounds
of the underlying array are not know from the slice.

Motivation
==========

As of today, there is no good solution to have an access to a slice of an array
in Ada. There are workarounds, which are covered below in the "Alternative"
section, but none of them provide the safety we can expect from Ada/SPARK. The
ability to work on slices of arrays is very useful in many cases, some of them
presented below. Having this feature built in the language will improve the
quality of software developed in Ada/SPARK.


Zero-Copy parser
----------------

Zero-copy is an optimization technique for parser/deserializers to save time
and memory usage. It can also eliminate the need for dynamic memory which makes
it very interesting for embedded and safety-critical applications. Looking for
example at an IP protocol parser. The parser receives an array that contains a
full IP packet, it will read the meta data and pass the payload to the next
protocol layer (TCP, UDP, etc.). Instead of allocating a new buffer for the
payload and copying the payload from the IP packet to this new buffer, a
zero-copy parser will pass a slice of the original array to the next protocol
layer. Thus saving time and memory. See
[here](https://manishearth.github.io/blog/2022/08/03/zero-copy-1-not-a-yoking-matter/#zero-copy-deserialization-the-basics)
for another example.

Interrupt based data transfer
-----------------------------

In low-level embedded applications and/or operating-systems, incoming data from
will sometimes be automatically written in a memory buffer by a peripheral.
This is known as Direct Memory Access (DMA). The use of DMA can greatly improve
performances by avoiding costly interrupts and CPU usage for every single byte
of a data transfer. One sub-system of the software will be in charge of feeding
buffers to the DMA engine. This means having a queue of slices to be
transferred, or the other ways around a queue of slices to fill with incoming
data. One example of such a sub-system is the
[bbqueue-spark](https://github.com/Fabien-Chouteau/bbqueue-spark) library.

Guide-level explanation
=======================

Reference-level explanation
===========================

Rationale and alternatives
==========================

There are two main ways to workaround the lack of slice access in Ada. First,
some variation of:
```ada
  type Arr is array (Natural range <>) of UInt8;
  type Arr_Access is access all Arr;

   type Slice is record
     A : Arr_Access;
     First : Natural;
     Last : Natural;
   end record;
```

The problem with this approach is that nothing prevents accessing all of the
original array. It's actually fairly easy for a programmer to forget about the
Slice bounds and in good faith do something like:

```ada
S.A (S.A'First) := 0;
```

Instead of:
```ada
S.A (S.First) := 0;
```

The other option is to use System.Address:
```ada
type Slice is record
  Addr : System.Address;
  Size : Natural;
end record;
```
This might be ok for memory chunks, but it is also error prone and doesn't
carry the type of the array.

Drawbacks
=========

These new kinds of accesses will require a new fat-pointer implementation to
carry the bounds of the slice.

Prior art
=========

[Rust has built-in slice
types](https://doc.rust-lang.org/book/ch04-03-slices.html) with similar
features as this proposal, with the added lifetime checks of course.

[Go's definition of slices](https://go.dev/blog/slices-intro) looks similar at
first, but have noticeable differences. The underlying array is not visible to
the user and is implicitly created with the slice. Slices have a length and a
capacity, length is the current size of the slice, and capacity the actual size
of the underlying array. So slices can grow and shrink within the capacity of
the array.

Unresolved questions
====================

Do the elements have to be aliased?
```ada
type Arr_Type is array (Natural range <>) of aliased UInt8;
```

Since this is not needed for an access to the full array so we expect to keep
it the same for access to slices.


