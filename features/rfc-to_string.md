- Feature Name: To_String
- Start Date:
- Status: Production

Summary
=======


Motivation
==========

The current type-to-string mechanism in Ada has a few shortcomings:
- Integers values are provided with a heading space
- The new Ada 2022 Put_Image attribute is not discpatching, and confusing when
  using with class wide view (which will be a more visible problem with the
  new dispatching semantics)
- The new Ada 2022 Put_Image attribute provide some limited formating (notably
  through the identation functions of the Buffer) but doesn't go as far as
  allowing to format the output to standards such as JSON or YAML.
- Ada 'Image is a bit awkward, called on a types, as opposed to GNAT-Specicif
  'Img.

The need to be able to output formatted format is particularly important for
application that need to log data for e.g. debuging or other external purposes.

Guide-level explanation
=======================

To_String Attribute
-------------------

'To_String (with its _Wide_String and _Wide_Wide_String counterpart) is provided
in replacement of 'Image (and 'Img in GNAT specific extension).
This attribute is used directly on a value, and by default operate like
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
provider with an instance of a new buffer type,
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

   type Root_Buffer_Type is abstract class;

   type Root_Formatter_Type is abstract class
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

      procedure New_Line (Self : in out Root_Buffer_Type) is abstract;

      procedure Open (
         Self   : in out Root_Formatter_Type;
         Buffer : in out Flare.Strings.Text_Buffers.Root_Buffer_Type'Class;
         Name   : String;
         Kind   : Ada_Type;
      );

      procedure List_Element (
         Self   : in out Root_Formatter_Type;
         Buffer : in out Root_Buffer_Type;
         Name   : String := "";
      );

      procedure Close (
         Self   : in out Root_Buffer_Type;
         Buffer : in out Flare.Strings.Text_Buffers.Root_Buffer_Type'Class;
      );
   end Root_Formatter_Type with private;

   type Root_Buffer_Type is abstract class

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
Default To_String for records are using scoping to follow formatting. For
example, this is the default implementation for Rec, assuming Rec is contained
in a package P:

```ada
procedure Rec'To_String
   (Self      : Rec;
    Buffer    : Flare.Strings.Text_Buffers.Root_Buffer_Type;
    Formatter : Flare.Strings.Text_Buffers.Root_Formatter_Type)
is
begin
   Formatter.Open (Buffer, Record_Type, "P.Rec");

   Formatter.List_Element (Buffer, "A");
   Self.A'To_String (Buffer, Formatter);

   Formatter.List_Element (Buffer, "B");
   Self.B'To_String (Buffer, Formatter);

   Formatter.Close (Buffer);
end Rec'To_String;
```

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

From_String Attribute
---------------------

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

Drawbacks
=========


Prior art
=========

