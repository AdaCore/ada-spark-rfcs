- Feature Name: External initialization aspect

Summary
=======

This RFC proposes a new language construct for the embedding of binary resources much like `C's #embed <https://www.open-std.org/jtc1/sc22/wg14/www/docs/n3017.htm#appendix>`_ or `Rust's include_bytes!() <https://doc.rust-lang.org/std/macro.include_bytes.html>`_. The feature allows for the direct inclusion of arbitrary binary as data:

.. code-block:: ada

    package body Some_Package is
     type Byte is mod 256;
     type Byte_Array is (Integer range <>) of Byte;
     Some_File_Data : Byte_Array
       with External_initialization => "/some/file/data.raw";

     type Some_Record is record
       X : Integer;
       Y : Char;
     end record;
     Some_Other_Data : Some_Record
       with External_Initialization => "/some/data.raw";

Motivation
==========

Embedding binary data in an application currently involves the preprocessing,
usually implemented in the build system by custom scripts, of the resources data
to translate it in Ada source code as an array of litteral values. This solution
has several issues:

- no code reuse: every project has to craft a bespoke implementation and jump
  though hoops to handle portability, tools requirements, possible constraint on
  the data (e.g. alignement, maximum size), …
- performance impact on the compiler: parsing and analysing such arrays can have
  huge impact on compilation times and resources. Tools are not expecting
  litteral arrays with millions of elements, which is quite common when
  embedding resources of few megabytes.

.. code-block:: ada

   type Byte is mod 256;
   type Byte_Array is (Integer range <>) of Byte
      with Alignment => 128;
   Some_File_Data : Byte_Array
     with External_Initialization => "/some/file/data.raw";

.. code-block:: ada

   type Some_Record is record
     <various fields>
   end record
      with Alignment => 128;
   Some_File_Data : Some_Record
     with External_Initialization => "/some/file/data.raw";

Reference level explanation
===========================

A new ``External_Initialization`` aspect is added with the following parameters:

- mandatory ``Path``: the path the compiler uses to access the binary resource;
- optional ``Maximum_Size``: the maximum number of bytes the compiler reads from
  the resource;
- optional ``If_Empty``: an expression used in place of read data in case
  the resource is empty;

The aspect can only be applied to an object declaration at library level.

Syntax
------

No custom syntax.

Static legality rules
---------------------

- The number of bytes read from the resource (given by the minimum of
  ``Maximum_Size`` (if provided) and actual resource size) must be compatible with
  the expected data size:

  - for constrained type, the number of bytes must match exactly the type size;
  - for unconstrained type, the number of bytes should probably be checked for
    compatibility, if possible.

.. code-block:: ada

   type Byte is mod 256;
   type Byte_Array is (Integer range <>) of Byte;
   Some_File_Data : Byte_Array
     with External_Initialization => (Path =>"/some/file/data.raw",
                                      Maximum_Size => 128);

Operational semantics
---------------------

On array of scalar type, the ``External_Initialization`` aspect has the same
observable behavior as if the following transformation is used:

.. code-block:: ada

   type Byte is mod 256;
   type Byte_Array is (Integer range <>) of Byte;
   --  Some_File_Data : Byte_Array
   --    with External_Initialization => "/some/file/data.raw";
   Some_File_Data : Byte_Array := Byte_Array'(123, 100, 223);
   pragma Assert (Some_File_Data'Valid);

On other type, the aspect has the same observable behavior as in:

.. code-block:: ada

   type Some_Rec_Type is record
     F1: Integer;
     F2: Some_Other_Record_Type;
   end record;
   --  Some_File_Data : Some_Rec_Type
   --    with External_Initialization => "/some/file/data.raw";
   type Byte is mod 256;
   type Byte_Array is (Integer range <>) of Byte;
   function Byte_To_Some_Rec_Type is
     new Ada.Unchecked_Conversion (Source => Byte_Array,
                                   Target => Some_Rec_Type);
   Some_File_Data : Byte_Array := Byte_To_Some_Rec_Type(Byte_Array'(123, 100, 223));
   pragma Assert (Some_File_Data'Valid);

Questions
=========

- The above code shows ``Unchecked_Conversion`` from ``Byte_Array`` to arbitrary type. Should this be

  - dropped and left as something the user has to explicitely write
  - made more explicit with an extra parameter e.g. ``Unchecked => True``.
  - kept hidden (listed here, but probably not a good idea at all)

Caveats and alternatives
========================

Rust
----

.. code-block :: rust

  #[repr(C)]
  pub struct MyStuff {
      i1: i32,
      i2: i32,
  }

  pub fn nada() -> &'static [MyStuff] {
      let a = include_bytes!("data");

      let num = unsafe {
          std::mem::transmute::<&[u8], &[MyStuff]>(a)
      };
      num

     //   let (head, body, _tail) =  unsafe { a.align_to::<&[MyStuff]>() };
     //   assert!(head.is_empty(), "Not correctly aligned");
     //   &body[0]
  }

See https://rust.godbolt.org/z/4Kxo6dvjs .

The ``rustc`` compiler seems to be treating the ``include_bytes!()`` specifically,
with a dedicated AST node kind for performance reason. It seems to be also very
close to string handling (URL are willingly in backquotes to avoid pinging
rust-lang github project):

- ``https://github.com/rust-lang/rust/issues/65818``
- ``https://github.com/rust-lang/rust/issues/65818``
- ``https://github.com/rust-lang/rust/pull/103812#issuecomment-1299087888``

C
-

The C proposal has several optional parameters and is designed to be extensible
(e.g. vendor specific):

- ``__has_embed()``: cpp macro to check for the resource availability
- ``prefix`` / ``suffix``: optional parameters to add sequences of token inserted
  before/after the given resource binary data.
- ``if_empty``: a sequence of tokens used in place of the loaded data when the
  resource is empty.
- ``limit``: a limit on the number of bytes read from the resource.

.. code-block:: c

  #include <inttypes.h>

  struct MyStuff {
      int32_t i1;
      int32_t i2;
  };

  int main () {
      const struct MyStuff some[] = {
  #embed </dev/urandom> is_empty (1) limit(10)
      };
  }

See https://godbolt.org/z/rr1z7T87T .
