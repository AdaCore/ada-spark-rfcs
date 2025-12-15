- Feature Name: Standard OOP model
- Start Date:
- Status: Ready for prototyping

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

This shorthand notation declares a subprogram and specifies it as the value of
the ``Write`` aspect of the type ``T``.


Only subprogram-valued aspects are allowed in this shorthand notation.
In a subprogram-valued aspect declaration, the subprogram name shall be in the
form of an attribute reference, where the prefix denotes the first subtype of a
type, and the aspect declaration shall occur immediately within the same
declarative region as the type.
The body of a subprogram declared via a subprogram-value aspect declaration
must have a specification.

A Derived Map Example
^^^^^^^^^^^^^^^^^^^^^

With the subprogram-valued aspect declarations, we could write a hierarchy of a
map as follows:

.. code-block:: ada

   package P is
      type Root is tagged null record;

      --  Root has exactly two keys: Natural and Boolean
      function Root'Constant_Indexing (X : Root; I : Natural) return Natural;
      function Root'Constant_Indexing (X : Root; B : Boolean) return Natural;
   end P;

.. code-block:: ada

   with P;

   package Q is
      type Child is new P.Root with null record;

      --  The behavior of the Natural key is overridden
      overriding -- Optional
      function Child'Constant_Indexing (X : Child; I : Natural) return Natural;

      --  The Boolean key is implicitly inherited from P.Root
      --  function Child'Constant_Indexing (X : Child; B : Boolean)

      --  Additionally, Child supports a Float key
      function Child'Constant_Indexing (X : Child; F : Float) return Float;
   end Q;

Furthermore, we could have also declared two different maps in the same
package:

.. code-block:: ada

   type A is tagged null record;
   function A'Constant_Indexing (X : A; I : Natural) return Natural;

   type B is tagged null record;
   function B'Constant_Indexing (X : B; I : Natural) return Natural;

The rules of overloading resolution and inheritance that apply to subprograms
apply similarly here as expected.

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

In the example above, all the subprogram-valued aspect
declarations of ``Container`` are primitive operations.
The usual rules of primitive operations apply, except that subprograms declared
via this shorthand notation cannot be called via prefix notation: e.g.,
``... := Obj.Container'First;`` is forbidden.

Scoped Records
--------------

In relation to the scoped records proposed in the *RFC OOP primitives*,
subprogram-valued aspect declarations work accordingly:

.. code-block:: ada

   type T is class record
      procedure T'Write
        (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
         Item : in T);
   end record;

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

To solve this issue, subprogram-valued aspect declarations
inside scoped environments are allowed to be nonprimitive and to not follow the
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
As long as they don't share the same aspect name, a mix of the regular aspect
specifications and subprogram-valued aspect
declarations is permitted.

Some changes are required:

- RM 6.3(3); the designator of end labels in a subprogram body shall match the
  name of the subprogram-valued aspect declaration:

  .. code-block:: ada

     procedure T'Some_Aspect (...) is
     begin
        ...
     end T'Some_Aspect;

- RM 3.9(10); ``Ada.Tags.Wide_Wide_Expanded_Name`` needs to take into account
  this new syntax:

  .. code-block:: ada

    package body Pkg is
       procedure T'Some_Aspect (...) is
          type My_Tagged_Type is tagged null record;
       begin
          Put_Line (Ada.Tags.Wide_Wide_Expanded_Name (My_Tagged_Type'Tag));
          --  "PKG.T'SOME_ATTRIBUTE.MY_TAGGED_TYPE"
       end T'Some_Aspect;

- RM 4.1.3 (4); the prefix of expanded names allows such names to scope
  visibility inside the body of a subprogram-valued aspect declaration.
  The following is legal:

  .. code-block:: ada

     procedure T'Some_Aspect (...) is
        X : Integer;
     begin
        T'Some_Aspect.X := 123; -- Legal
     end T'Some_Aspect;

- RM 10.1.1(21); analogously to operators, the defining name of a function that
  is a compilation unit cannot use this shorthand notation.

- RM 10.1.3; bodies of subprogram-valued aspect declarations cannot have a
  body_stub.

Rationale and alternatives
==========================

Inside scoped environments, a syntactic ``@'<Aspect_Name>`` used in the
subprogram name
could further shorten our notation.
The big advantage is when the type name is long; for instance, we could write:

.. code-block:: ada

   type Indexable_Container_With_A_Long_Name is class record
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

- The IDE support for this shorthand notation might be complex as it would need
  to connect aspect calls with their (potential) declarations.

- To not degrade user experience, also the debugger must allow breakpoints on
  the shorthand notation instead of their internal naming counterpart;
  e.g., ``b T'Write`` should be accepted in ``gdb``.

Prior art
=========

Unresolved questions
====================

Future possibilities
====================

