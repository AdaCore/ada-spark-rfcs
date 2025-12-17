- Feature Name: To_String
- Start Date:
- Status: Production

Summary
=======


Motivation
==========

The current type-to-string mechanism in Ada has a few shortcomings:
- Integers values are provided with a heading space
- The new Ada 2022 Put_Image attribute is not dispatching, and confusing when
  using with class wide view (which will be a more visible problem with the
  new dispatching semantics)
- The new Ada 2022 Put_Image attribute provide some limited formating (notably
  through the identation functions of the Buffer) but doesn't go as far as
  allowing to format the output to standards such as JSON or YAML.

The need to be able to output formatted format is particularly important for
application that need to log data for e.g. debuging or other external purposes.

Guide-level explanation
=======================

To_String Attribute
-------------------

'To_String (with its _Wide_String and _Wide_Wide_String counterpart) is provided
in replacement of 'Image (and 'Img in GNAT specific extension).
This attribute is used directly on a value, and by default operates like
'Image, (with the exception that no leading space is present for
numeric values) e.g.:

```ada
I : Integer := 42;
J : String := I'To_String;
```

will print:

```
42
```

To_String attribute can take an optional parameter of type
`Flare.Strings.Text_Buffers.Root_Formatter_Type'Class`.
A few derivations are provided by default, such as JSON_Formatter and
YAML_Formatter. For example:

```ada
type Rec is record
   A, B : Integer;
end record;

V : Rec := (1, 2);

Put_Line (V'To_String (JSON_Structured_Formatter));
```

will print:

```json
{
   "A": 1,
   "B": 2
}
```

To_String can be used direclty as a procedure. In this case it needs to be
provided with an instance of a new buffer type,
Flare.Strings.Text_Buffers.Root_Buffer_Type, and an optional formatter.
Similar to Ada,there are predefined buffer types provided by the language.
E.g.:

```ada
type Rec is record
   A, B : Integer;
end record;

V : Rec := (1, 2);

Buffer : Flare.Strings.Text_Buffers.Unbounded;

V'To_String (Buffer, JSON_Structured_Formatter);
```

`Flare.Strings.Text_Buffers.Root_Buffer_Type` is similar to
`Ada.Strings.Text_Buffers.Root_Buffer_Type` except that it relies on a
formatter to structure the output, as opposed to the indent primitives. E.g.:

```ada
package Flare.Strings.Text_Buffers is

   type Ada_Type is
      (Access_Type,
       Enumeration_Type,
       Signed_Type,
       Modular_Type,
       Float_Type,
       Decimal_Type,
       Ordinary_Type
       Array_Type,
       Record_Type,
       Protected_Type,
       Task_Type);

   type Elementary_Type is Ada_Type range Access_Type .. Ordinary_Type;
   type Scalar_Type is Elementary_Type range Enumeration_Type .. Ordinary_Type;
   type Discrete_Type is Scalar_Type range Enumeration_Type .. Modular_Type;
   type Integer_Type is Discrete_Type range Signed_Type .. Modular_Type;
   type Real_Type is Scalar_Type range Float_Type .. Ordinary_Type;
   Type Fixed_Type is Scalar_Type range Decimal_Type .. Ordinary_Type;
   type Composite_Type is Ada_Type range Array_Type .. Task_Type;

   type Root_Buffer_Type is abstract class record;

   type Root_Formatter_Type is abstract class record
      procedure Put (
         Self   : in out Root_Formatter_Type;
         Buffer : in out Root_Buffer_Type;
         Item   : in     String) is abstract;

      procedure Wide_Put (
         Self   : in out Root_Formatter_Type;
         Buffer : in out Root_Buffer_Type;
         Item   : in     Wide_String) is abstract;

      procedure Wide_Wide_Put (
         Self   : in out Root_Formatter_Type;
         Buffer : in out Root_Buffer_Type;
         Item   : in     Wide_Wide_String) is abstract;

      procedure Put_UTF_8 (
         Self   : in out Root_Formatter_Type;
         Buffer : in out Root_Buffer_Type;
         Item   : in     UTF_Encoding.UTF_8_String) is abstract;

      procedure Wide_Put_UTF_16 (
         Self   : in out Root_Formatter_Type;
         Buffer : in out Root_Buffer_Type;
         Item   : in     UTF_Encoding.UTF_16_Wide_String) is abstract;

      procedure New_Line (
         Self   : in out Root_Formatter_Type;
         Buffer : in out Root_Buffer_Type) is abstract;

      procedure Start
         (Self   : in out Root_Formatter_Type;
          Buffer : in out Root_Buffer_Type);

      procedure Finish
         (Self : in out Root_Formatter_Type;
          Buffer : in out Root_Buffer_Type);

      procedure Open (
         Self      : in out Root_Formatter_Type;
         Buffer    : in out Flare.Strings.Text_Buffers.Root_Buffer_Type'Class;
         Type_Kind : Ada_Type;
         Type_Name : String
      );

      procedure Open (
         Self           : in out Root_Formatter_Type;
         Buffer         : in out Flare.Strings.Text_Buffers.Root_Buffer_Type'Class;
         Type_Kind      : Ada_Type;
         Type_Name      : String;
         Index_Kind     : Ada_Type;
         Index_Name     : String;
         Component_Kind : Ada_Type;
         Component_Name : String
      );

      procedure List_Element (
         Self         : in out Root_Formatter_Type;
         Buffer       : in out Root_Buffer_Type;
         Name         : String := "";
         Is_Constrain : Boolean
      );

      procedure Close (
         Self   : in out Root_Buffer_Type;
         Buffer : in out Flare.Strings.Text_Buffers.Root_Buffer_Type'Class;
      );
   end Root_Formatter_Type with private;

   type Root_Buffer_Type is abstract class record

      --  The following function will use the underlying formatter

      procedure Put (
         Self : in out Root_Buffer_Type;
         Item : in     String) is abstract;

      procedure Wide_Put (
         Self : in out Root_Buffer_Type;
         Item : in     Wide_String) is abstract;

      procedure Wide_Wide_Put (
         Self : in out Root_Buffer_Type;
         Item : in     Wide_Wide_String) is abstract;

      procedure Put_UTF_8 (
         Self : in out Root_Buffer_Type;
         Item : in     UTF_Encoding.UTF_8_String) is abstract;

      procedure Wide_Put_UTF_16 (
         Self : in out Root_Buffer_Type;
         Item : in     UTF_Encoding.UTF_16_Wide_String) is abstract;

      procedure New_Line (Self : in out Root_Buffer_Type) is abstract;

   end Root_Buffer with private;

private
   ... -- not specified by the language
end Ada.Strings.Text_Buffers;
```

`To_String` can be overriden by an attribute that takes a value and a buffer.
Default To_String for records are using scoping to follow formatting.

The overriden To_String is primitive of the type. When used on a tagged or class
record, it will dispatch. Calling to string on a class wide view will dispatch
to the actual call. E.g.:

```ada
   type Root is class record ...

   type Child is new Root with class record ...

   X : Root'Class := Child'(others => <>);
begin
   Put_Line (X'To_String); -- Will dispatch to Child'To_String.
```

Certain formatter require to do certain things at the start and the end of the
buffer operation (for example prepend a size), which can be done in the Start
and Finish primivites. Specific formatter may need to contain states and
be instanciated (as opposed to the global objects demonstrated here).

Default To_String for Records
-----------------------------

The default implementation of To_String for records (and other heteregeneous
types will be as follows):

- First call Formatter.Open on the type
- Then Call Formatter.List element followed by To_String on each discriminant.
- Then Call Formatter.List element followed by To_String on each component.
- Last call Formatter.Close

For example:

```ada
type Rec (D : Boolean) is record
   A, B : Integer;

   case D is
      when True =>
         C : Integer;

      when False =>
         E : Integer;
   end case;
end record;

procedure Rec'To_String
   (Self      : Rec;
    Buffer    : Flare.Strings.Text_Buffers.Root_Buffer_Type;
    Formatter : Flare.Strings.Text_Buffers.Root_Formatter_Type)
is
begin
   Formatter.Open (Buffer, Record_Type, "P.Rec");

   Formatter.List_Element (Buffer, "D", True);

   Formatter.List_Element (Buffer, "A", False);
   Self.A'To_String (Buffer, Formatter);

   Formatter.List_Element (Buffer, "B", False);
   Self.B'To_String (Buffer, Formatter);

   if Self.D then
      Formatter.List_Element (Buffer, "C", False);
      Self.B'To_String (Buffer, Formatter);
   else
      Formatter.List_Element (Buffer, "D", False);
      Self.B'To_String (Buffer, Formatter);
   end if;

   Formatter.Close (Buffer);
end Rec'To_String;
```

Default To_String for Arrays
----------------------------

The default implementation of To_String for records (and other heteregeneous
types will be as follows):

- First call Formatter.Open on the type, also giving index and component types
- Then Call Formatter.List element followed by To_String on each low then high bound.
- Then for each component, call Formatter.List element followed by To_String on the Index then Component
- Last call Formatter.Close

for example:

```ada
type Arr is array (Integer range <>) of Integer;

procedure Arr'To_String
   (Self      : Arr;
    Buffer    : Flare.Strings.Text_Buffers.Root_Buffer_Type;
    Formatter : Flare.Strings.Text_Buffers.Root_Formatter_Type)
is
begin
   Formatter.Open
     (Buffer, Record_Type, "P.Arr",
      Signed_Type, "Standard.Integer",
      Signed_Type, "Standard.Integer");

   Formatter.List_Element (Buffer, "First", True);
   Self'First'To_String (Buffer, Formatter);

   Formatter.List_Element (Buffer, "Last", True);
   Self'Last'To_String (Buffer, Formatter);

   for I in Self'Range loop
      Formatter.List_Element (Buffer, "", False);

      I'To_String (Buffer, Formatter, False);
      Self (I)'To_String (Buffer, Formatter, False);
   end loop;

   Formatter.Close (Buffer);
end Arr'To_String;
```

In case of multi dimensional arrays, boundaries are passed in sequence,
then both indexes are pushed to the buffer, e.g.:

```ada
type Arr is array (Integer range <>; Integer range <>) of Integer;

procedure Arr'To_String
   (Self      : Arr;
    Buffer    : Flare.Strings.Text_Buffers.Root_Buffer_Type;
    Formatter : Flare.Strings.Text_Buffers.Root_Formatter_Type)
is
begin
   Formatter.Open
     (Buffer, Record_Type, "P.Arr",
      Signed_Type, "Standard.Integer",
      Signed_Type, "Standard.Integer");

   Formatter.List_Element (Buffer, "First", True);
   Self'First (1)'To_String (Buffer, Formatter);

   Formatter.List_Element (Buffer, "Last", True);
   Self'Last (1)'To_String (Buffer, Formatter);

   Formatter.List_Element (Buffer, "First", True);
   Self'First (2)'To_String (Buffer, Formatter);

   Formatter.List_Element (Buffer, "Last", True);
   Self'Last (2)'To_String (Buffer, Formatter);

   for I in Self'Range (1) loop
      for J in Self'Range (2) loop
         Formatter.List_Element (Buffer, "", False);

         I'To_String (Buffer, Formatter, False);
         J'To_String (Buffer, Formatter, False);
         Self (I, J)'To_String (Buffer, Formatter, False);
      end loop;
   end loop;

   Formatter.Close (Buffer);
end Arr'To_String;
```

Default To_String for Arrays of Characters
------------------------------------------

One-dimention array of character have a special default To_String method - they
don't output element by element with indices but instead output directly the
entire value, e.g.:

```ada
procedure String'To_String
   (Self      : String;
    Buffer    : Flare.Strings.Text_Buffers.Root_Buffer_Type;
    Formatter : Flare.Strings.Text_Buffers.Root_Formatter_Type)
is
begin
   Formatter.Open
     (Buffer, Record_Type, "Standard.String",
      Signed_Type,         "Standard.Integer",
      Enumeration_Type,    "Standard.Character");

   Formatter.List_Element (Buffer, "First", True);
   Self'First'To_String (Buffer, Formatter);

   Formatter.List_Element (Buffer, "Last", True);
   Self'Last'To_String (Buffer, Formatter);

   Formatter.Put (Buffer, Self);

   Formatter.Close (Buffer);
end String'To_String;
```

Default To_String for Elementary Types
--------------------------------------

The default implementation for elementary types is to first call open on that
type, then translate the value into a string as is currently done with 'Image
(without heading space for integers), then call close, e.g.:

```ada
procedure Integer'To_String
   (Self      : Integer;
    Buffer    : Flare.Strings.Text_Buffers.Root_Buffer_Type;
    Formatter : Flare.Strings.Text_Buffers.Root_Formatter_Type)
is
begin
   Formatter.Open (Buffer, Signed_Type, "Standard.Integer");
   Formatter.Put (Buffer, <code transforming Self to string>);
   Formatter.Close (Buffer);
end Integer'To_String;
```

One of the potential use case for providing this level of information on the
elementary types is to allow the formatter to "reformat" number, for example,
formating "1234" into "1,234".

Default Formatters
------------------

Flare.Strings.Text_Formatters provides a number of default formatters for users:

```ada
package Flare.Strings.Text_Formatters is

   type Default_Formatter_Type is new Root_Formatter_Type with class record
      -- Implementation-Defined
   end Default_Formatter_Type;

   Default_Formatter : Default_Formatter_Type;

   type JSON_Formatter_Type is new Root_Formatter_Type with class record
      -- Implementation-Defined
   end JSON_Formatter_Type;

   JSON_Formatter : JSON_Formatter_Type;

   type YAML_Formatter_Type is new Root_Formatter_Type with class record
      -- Implementation-Defined
   end YAML_Formatter_Type;

   YAML_Formatter : YAML_Formatter_Type;

end Flare.Strings.Text_Formatters;
```

To complete the specification, we will provide schema when relevant (e.g. JSON
schema)

Ada Compatibilty Mode
---------------------

`To_String` will be made available in Ada compatibility mode. For this,
Ada.Strings.Text_Buffers will be augmented with the necessary tagged types,
and Ada.Strings.Text_Formatters will be introduced with default implementations.

Compatibilty with 'Img and 'Value
---------------------------------

The Ada 'Img, 'Image and 'Value attributes are deprecated (kept in
compatibility mode) to favor the attributes, 'To_String and 'From_String
(with their _Wide_String and _Wide_Wide_String counterparts).
These attributes are used directly on a value, and by default operate like
'Value and 'Image, (with the exception that no leading space is present for
numeric values) e.g.:

Formatted string (strings that start with an f) will exclusively use To_String
(they already are doing something special to some extent as integers don't
have heading space there).

Reference-level explanation
===========================


Rationale and alternatives
==========================

Two v.s. one argument for formatter and buffer
----------------------------------------------

An alternative design could be to have To_String only take one argument, a
formatter that would contain a buffer, e.g.:

```ada
type Rec is record
   A, B : Integer;
end record;

procedure Rec'To_String
   (Self      : Rec;
    Formatter : Flare.Strings.Text_Buffers.Root_Formatter_Type)
is
begin
   Formatter.Open (Record_Type, "P.Rec");

   Formatter.List_Element ("D", True);

   Formatter.List_Element ("A", False);
   Self.A'To_String (Formatter);

   Formatter.List_Element ("B", False);
   Self.B'To_String (Formatter);

   Formatter.Close;
end Rec'To_String;
```

However, this simplification on the implementer side increases complexity
on the user side as one now needs to instanciate a formatter with a new
object containing the buffer, e.g.:

```ada
type Rec is record
   A, B : Integer;
end record;

V : Rec := (1, 2);

Put_Line (V'To_String (Create_JSON_Structured_Formatter (Create_Buffer)));
```

In the current version, by default, the compiler is responsible for creating
the buffer.

Both designs can be worked with - it seemed however that the feature would
be more commonly used on the user side than the implementer.

Drawbacks
=========

Performance Considerations
--------------------------

There is a trade-off in this proposal in terms of complexity / efficiency.
Notably, refering to types and components through strings as opposed to more
complex data structure may lead to less efficient code when needed for e.g.
comparisons. However, given the main use cases for this kind of construction
(e.g. logging purposes), this trade-off seems adequate.

Prior art
=========

Future possibilities
====================

A new attribute 'From_String associated with a Root_Parser_Type could be
introduced. Parsing is more complicated than just formatting values, may deserve
some additional design work.
