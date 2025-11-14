- Feature Name: Standard OOP model
- Start Date:
- Status: Design

Summary
=======

This RFC introduces a shorthand notation to declare subprogram-valued aspects.

Motivation
==========

Currently, to specify a subprogram-valued aspect for a type, one needs to first
declare a subprogram, that most of the times is never referred elsewhere, and
then link it to the type via an aspect specification or attribute definition
clause. This pattern creates unnecessary boilerplate code, disconnects the
aspect specification from the denoted subprogram, and introduces potential name
resolution issues.

Guide-level explanation
=======================

Subprogram-valued Aspect Declaration
------------------------------------

Currently, specifying a subprogram-valued aspect for a type requires to first
declare the subprogram and then apply the corresponding aspect specification or
attribute definition clause. For example:

.. code-block:: ada

   type T is null record;

   for T'Write use My_Write;

   procedure My_Write
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Item : in T);

Or via an aspect specification:

.. code-block:: ada

   type T is null record with Write => My_Write;

   procedure My_Write
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Item : in T);

This proposal introduces **subprogram-valued aspect declarations** that allow
to specify a subprogram as an aspect value directly within the subprogram
declaration.
For example, the above can be rewritten as:

.. code-block:: ada

   type T is null record;

   procedure T'Write
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Item : in T);

Under the hood, the compiler expands this subprogram declaration into an
*internal* subprogram declaration and corresponding aspect specification. The
internal subprogram is not visible in the source code, and thus cannot be
called directly. The name of the internal subprogram is determined solely by
the aspect name, meaning that the internal subprogram denoted by
``T'Write`` will have the same name of another declaration like ``U'Write``.

Reducing the Gap Between Aspect Call and Denoted Subprogram
-----------------------------------------------------------

For an Ada programmer, this shorthand helps connecting the aspect to its
denoted subprogram. Even though an aspect call (e.g., ``T'Write (...)``) is not
*strictly speaking*
a subprogram call, under the hood the compiler transparently resolves it to the
specified subprogram.
With this shorthand notation, there is no indirection from the aspect call
``T'Write (...)`` to
which actual subprogram is being called, as it is declared right there as
``T'Write``.

Note that, even though not a problem, this proposal doesn't completely
unify aspect calls with their subprograms, some mismatches may still be
present.
Consider the following example:

.. code-block:: ada

   type Custom is limited private record;

   procedure Custom'Put_Image
     (Buffer : in out Ada.Strings.Text_Buffers.Root_Buffer_Type'Class;
      Item : Custom);

Here, a call to ``Custom'Put_Line (...)`` calls the aspect
``Custom'Put_Image (...)`` which eventually calls the denoted subprogram.
Therefore, the procedure ``Custom'Put_Image`` is called via the aspect
``Put_Image``, and thus the mismatch between names.

Primitive or Nonprimitive?
--------------------------

Subprogram-valued aspect declarations can be used to define both primitive and
nonprimitive operations of a type.
For instance, we could define a container type as:

.. code-block:: ada

   type Container is tagged record
      ...
   end record;
   type Cursor is new Positive;

   function Container'First (C : Container) return Cursor;
   function Container'Next (C : Container; Pos : Cursor) return Cursor;
   function Container'Has_Element (C : Container; Pos : Cursor) return Boolean;
   function Container'Element (C : Container; Pos : Cursor) return Integer;

All the subprogram-valued aspect
declarations of ``Container`` are primitive operations.
Whether a subprogram-valued aspect declaration is primitive or not
depends on the usual rules of primitive operations applied to the denoted
internal subprogram.

Name Resolution
---------------

This proposal helps in reducing name resolution issues when declaring the
aspect's temporary subprogram since it will hardly conflict with anything else.
Nevertheless, it is possible
to define overloadings of the same aspect declaration, for example this container has
two overloadings of the ``Constant_Indexing`` aspect:

.. code-block:: ada

   type Indexable_Container is tagged null record;

   function Indexable_Container'Constant_Indexing -- first overloading
     (Container : aliased Indexable_Container;
      Position  : Offset) return Constant_Reference_Type;

   function Indexable_Container'Constant_Indexing -- second overloading
     (Container : aliased Indexable_Container;
      Position  : Custom_Offset) return Constant_Reference_Type;

   function Indexable_Container'Variable_Indexing
     (Container : aliased in out Indexable_Container;
      Position  : Offset) return Reference_Type;

However, it is very unlikely to have name resolution issues since
``Indexable_Container'Constant_Indexing`` can only appear in its declarative
region, and cannot be mistaken for anything else.

Inheritance
-----------

Subprogram-valued aspect declarations creates inherited subprograms in derived
types accordingly to the usual rules of inheritance applied to the denoted
internal subprogram. For instance, in the following code:

.. code-block:: ada

   type T is tagged record;

   procedure T'Write
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Item : in T);

   type U is new T with null record;

   overriding -- optional
   procedure U'Write
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Item : in U);

The internal subprogram denoted by ``T'Write`` is inherited by ``U``, and
overridden by the internal subprogram of ``U'Write``.

In case of nonoverridable aspects, since the denoted internal subprogram
shares the same name, the overridden internal subprogram is *comfirming* and
thus accepted by the compiler. For example, the following code should be
accepted:

.. code-block:: ada

   type Vector is tagged null record;

   procedure Vector'Default_Iterator (Container : Vector);

   type Fixed_Vector is new Vector with null record;

   procedure Fixed_Vector'Default_Iterator (Container : Fixed_Vector);

Scoped Records
--------------

In relation to the scoped records and class types proposed in the *RFC OOP
primitives*,
subprogram-valued aspect declarations can be used accordingly:

.. code-block:: ada

   type T is tagged record

      procedure T'Write
        (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
         Item : in T);

   end T;

This provide a seamless solution in particular to scope oop primitives:

.. code-block:: ada

   type T is class record
      procedure T'Constructor (Self : in out T);
      procedure T'Destructor (Self : in out T);

      procedure T'Write
        (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
         Item : in T);
   end record;

Unfortunately, the direct attribute definitions inside a scoped record clashes
with the class type rules where each subprogram is required to be primitive and
following the rules of First_Controlling_Parameter (e.g., see ``T'Write`` above
where ``Item`` is the second formal, not the first). The rule's motivation
comes, for instance,
from the fact that class primitives are called with the prefix notation, and
that no primitive operation should be defined afterwards.

To resolve this clash, we could relax the rules for class types to allow
subprogram-valued aspect declarations to be nonprimitive inside scoped records
and to not adhere to the First_Controlling_Parameter rule.

Hierarchy with Write, Read, Output, and Put_Image
-------------------------------------------------

Here it follows an example of usage of subprogram-valued aspect declarations
with a simple hierarchy involving a combination of ``Write``, ``Read``,
``Output``, and
``Put_Image`` aspects.

.. code-block:: ada

   with Ada.Strings.Text_Buffers; use Ada.Strings.Text_Buffers;
   with Ada.Streams; use Ada.Streams;

   package Geometry is
      type Shape is tagged record
         X, Y : Integer;
      end record;

      procedure Shape'Read
        (Stream : not null access Root_Stream_Type'Class;
         Item   : out Shape);
      procedure Shape'Output
        (Stream : not null access Root_Stream_Type'Class;
         Item   : in Shape);
      procedure Shape'Put_Image
        (Buffer : in out Root_Buffer_Type'Class;
         Item   : Shape);

      type Circle is new Shape with record
         Radius : Integer;
      end record;

      overriding
      procedure Circle'Read
        (Stream : not null access Root_Stream_Type'Class;
         Item   : out Circle);
      procedure Circle'Write
        (Stream : not null access Root_Stream_Type'Class;
         Item   : in Circle);
      overriding
      procedure Circle'Put_Image
        (Buffer : in out Root_Buffer_Type'Class;
         Item   : Circle);
   end Geometry;

   ...

   with Ada.Strings.Text_Buffers; use Ada.Strings.Text_Buffers;
   with Ada.Streams; use Ada.Streams;
   with Ada.Text_IO; use Ada.Text_IO;

   package body Geometry is
      procedure Shape'Read
        (Stream : not null access Root_Stream_Type'Class;
         Item   : out Shape) is
      begin
         Put_Line ("Shape'Read called");
         Integer'Read (Stream, Item.X);
         Integer'Read (Stream, Item.Y);
      end Shape'Read;

      procedure Shape'Output
        (Stream : not null access Root_Stream_Type'Class;
         Item   : in Shape) is
      begin
         Put_Line ("Shape'Output called");
         Integer'Output (Stream, Item.X);
         Integer'Output (Stream, Item.Y);
      end Shape'Output;

      procedure Shape'Put_Image
        (Buffer : in out Root_Buffer_Type'Class;
         Item   : Shape) is
      begin
         Put_Line ("Shape'Put_Image called");
         Integer'Put_Image (Buffer, Item.X);
         Integer'Put_Image (Buffer, Item.Y);
      end Shape'Put_Image;

      overriding
      procedure Circle'Read
        (Stream : not null access Root_Stream_Type'Class;
         Item   : out Circle) is
      begin
         Put_Line ("Circle'Read called");
         Integer'Read (Stream, Item.Radius);
         Shape'Read (Stream, Shape (Item));
      end Circle'Read;

      procedure Circle'Write
        (Stream : not null access Root_Stream_Type'Class;
         Item   : in Circle) is
      begin
         Put_Line ("Circle'Write called");
         Integer'Write (Stream, Item.Radius);
         Shape'Output (Stream, Shape (Item)); -- Mixing Write and Output here
      end Circle'Write;

      overriding
      procedure Circle'Put_Image
        (Buffer : in out Root_Buffer_Type'Class;
         Item   : Circle) is
      begin
         Put_Line (Shape(Item)'Image);
         Put_Line ("Circle'Put_Image called");
         Integer'Put_Image (Buffer, Item.Radius);
      end Circle'Put_Image;
   end Geometry;

Reference-level explanation
===========================

This proposal introduces syntactic sugar for the declaration and specification
of subprogram-valued aspects. It is fully backward compatible with existing Ada
code and does not introduce any new semantic rule.

Rationale and alternatives
==========================

The notation introduced here could be shortened further by ``@'Aspect`` since
``@`` could be resolved to the enclosing record name similarly to the shorthand
for the left hand side of assignments. The big advantage is when the record
name is long. We could rewrite the container example as:

.. code-block:: ada

   type Indexable_Container_With_A_Long_Name is tagged record
      function @'Constant_Indexing
        (Container : aliased @;
         Position  : Offset) return Constant_Reference_Type;
      function @'Constant_Indexing
        (Container : aliased @;
         Position  : Custom_Offset) return Constant_Reference_Type;
      function @'Variable_Indexing
        (Container : aliased in out @;
         Position  : Offset) return Reference_Type;
   end record;

This use of ``@`` transcends the current proposal and should be discussed in a
separate RFC.

Drawbacks
=========

The IDE support for this shorthand notation might be complex as it would need
to connect aspect calls with their (potential) declarations.

Prior art
=========

Unresolved questions
====================

Future possibilities
====================

