- Feature Name: Standard OOP model
- Start Date:
- Status: Design

Summary
=======

This RFC introduces a shorthand notation to declare subprogram-valued aspects.

Motivation
==========

Currently, to specify a subprogram-valued aspect for a type, one needs to first
declare a subprogram, that most of the times is never referred to elsewhere,
and then link it to the type via an aspect specification or attribute
definition clause. This pattern creates unnecessary boilerplate code,
disconnects the aspect specification from the denoted subprogram declaration,
and introduces potential name resolution issues.

Guide-level explanation
=======================

Subprogram-valued Aspect Declarations
-------------------------------------

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

The code above both declares the subprogram ``T'Write`` and specifies it as the
``Write`` aspect of type ``T``.
Intuitively, this shorthand notation translates to the following aspect
specification:

.. code-block:: ada

   type T is null record with Write => @'Write;

Where "@" denotes the enclosing type name, cf. ``T`` in this case. When such
subprogram is inherited, "@" will also denote the derived type name.

A Derived Map Example
^^^^^^^^^^^^^^^^^^^^^

With the subprogram-valued aspect declarations, we could write a hierarchy of a
map as follows:

.. code-block:: ada

   package P is
      type T is tagged null record;

      --  T has exactly two keys: Natural and Boolean
      function T'Constant_Indexing (X : T; I : Natural) return Natural;
      function T'Constant_Indexing (X : T; B : Boolean) return Natural;
   end P;

.. code-block:: ada

   with P;

   package Q is
      type T2 is new P.T with null record;

      --  The behavior of the Natural key is overridden
      overriding -- Optional
      function T2'Constant_Indexing (X : T2; I : Natural) return Natural;

      --  The Boolean key is implicitly inherited from P.T
      --  function T2'Constant_Indexing (X : T2; B : Boolean) return Natural;

      --  Additionally, T2 supports a Float key
      function T2'Constant_Indexing (X : T2; F : Float) return Float;
   end Q;

The aspect specification on ``T`` is ``... => @'Constant_Indexing``, where "@"
denotes both ``T`` and ``T2``.
As you can see from the example above, the usual rules of inheritance apply.

There is no clash between subprogram-valued aspect declarations for the same
aspect name, in the same scope *but* for different types, since the aspect
specification is qualified by "@", which denotes the enclosing type name.

.. code-block:: ada

   type A is tagged null record;
   procedure A'Constant_Indexing (X : A; I : Natural) return Natural;

   type B is tagged null record;
   procedure B'Constant_Indexing (X : B; I : Natural) return Natural;

Which intuitively translates to:

- ``type A ... with Constant_Indexing => @'Constant_Indexing``
  where "@" denotes only ``A``, and

- ``type B ... with Constant_Indexing => @'Constant_Indexing``
  where "@" denotes only ``B``.

As expected, ``A'Constant_Indexing`` and ``B'Constant_Indexing`` are not
homonyms.

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
The usual rules of primitive operations apply.

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

This approach is quite natural and consistent with the rest of the proposal:
all aspect specifications are gathered together within the scoped environment.

Unfortunately, the subprogram-valued aspect declarations inside a scoped class
may clash with the class type rules where each subprogram is required to be
primitive and following the rules of First_Controlling_Parameter
(e.g., see ``T'Write`` above
where ``Item`` is the second formal, not the first). The rule's motivation
comes, for instance,
from the fact that class primitives are called with the prefix notation, and
that no primitive operation should be defined afterwards.

To solve this issue, we allow (only) subprogram-valued aspect declarations
inside scoped environments to be nonprimitive and not following the
First_Controlling_Parameter rule. Since, these subprograms are never called
with the prefix notation, this relaxation is safe.

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
code.

When a subprogram-valued aspect declaration is encountered, it is equivalent
to an aspect specification where the aspect value is "@'<Aspect_Name>", where
"@" denotes the the name of the enclosing type and any of its derived types.

Rationale and alternatives
==========================

While the notation "@'<Aspect_Name>" is not a syntactic Ada construct and it is
used above in this proposal at an intuitive level for the aspect
specifications, a syntactic ``@'<Aspect_Name>`` used in the subprogram name
could further shorten our notation. This second use of ``@`` denotes the
enclosing type name; no need to account for derived types here.
The big advantage is when the type name is long; for instance, we could write:

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

