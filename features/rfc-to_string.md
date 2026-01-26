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

Put_Line (I);
```

will print:

```
42
```

To_String attribute can take an optional parameter of type
`Flare.Strings.Text_Buffers.Root_Formatter_Type'Class`. By default, this
parameter will be valuated by `Flare.Strings.Text_Formatters.Default_Formatter`
(defined later). A few other derivations are provided, such as JSON_Formatter
and YAML_Formatter. For example:

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

To_String can also accept an extra parameter, `Format`, which may contain
values indicating to the formatter additional parameters or condition default
generation of formatting for e.g. elementary types. This string is here to
prepare for additional extensions of the model but its format requires design
on its own - which is outside of the scope of this proposal. E.g.:

```ada
--  The following is not part of the proposal but demonstrate future extension
--  possiblities

X : Float;
V : String := X'To_String (Format => Root_Formatter_Parameter'Make (".2f"));
--  assuming we include a format similar to python, asks for 2 decimals

V : String := f"{X:.2f}"
--  same as above, using formatted strings
```

By default, this received an empty string.

`Flare.Strings.Text_Buffers.Root_Buffer_Type` is similar to
`Ada.Strings.Text_Buffers.Root_Buffer_Type` except that it relies on a
formatter to structure the output, as opposed to the indent primitives. E.g.:

```ada
package Flare.Strings.Text_Formatters is

   type Ada_Type is
      (Access_Type,
       Enumeration_Type,
       Signed_Type,
       Modular_Type,
       Float_Type,
       Decimal_Type,
       Ordinary_Fixed_Point_Type
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

   type Root_Formatter_Parameters is abstract class record
      --  Provided for future extensions - should contain various formating
      --  parameters necessary for default formating.

      procedure Root_Formatter_Parameters'Constructor
         (Self   : in out Root_Formatter_Parameters;
          Format : String);
      --  Will support default formating format, for example ".2f" may mean
      --  2 decimals for floating points if following Python formatting
   end Root_Formatter_Parameters;

   type Root_Formatter_Type is abstract class record
      procedure Put (
         Self   : in out Root_Formatter_Type;
         Buffer : in out Root_Buffer_Type;
         Item   : in     String;
         Format : Root_Formatter_Parameters) is abstract;

      procedure Wide_Put (
         Self   : in out Root_Formatter_Type;
         Buffer : in out Root_Buffer_Type;
         Item   : in     Wide_String;
         Format : Root_Formatter_Parameters) is abstract;

      procedure Wide_Wide_Put (
         Self   : in out Root_Formatter_Type;
         Buffer : in out Root_Buffer_Type;
         Item   : in     Wide_Wide_String;
         Format : Root_Formatter_Parameters) is abstract;

      procedure Put_UTF_8 (
         Self   : in out Root_Formatter_Type;
         Buffer : in out Root_Buffer_Type;
         Item   : in     UTF_Encoding.UTF_8_String;
         Format : Root_Formatter_Parameters) is abstract;

      procedure Wide_Put_UTF_16 (
         Self   : in out Root_Formatter_Type;
         Buffer : in out Root_Buffer_Type;
         Item   : in     UTF_Encoding.UTF_16_Wide_String;
         Format : Root_Formatter_Parameters) is abstract;

      procedure New_Line (
         Self   : in out Root_Formatter_Type;
         Buffer : in out Root_Buffer_Type;
         Format : Root_Formatter_Parameters) is abstract;

      procedure Start
         (Self   : in out Root_Formatter_Type;
          Buffer : in out Root_Buffer_Type;
          Format : Root_Formatter_Parameters);

      procedure Finish
         (Self   : in out Root_Formatter_Type;
          Buffer : in out Root_Buffer_Type);

      procedure Open (
         Self      : in out Root_Formatter_Type;
         Buffer    : in out Root_Buffer_Type;
         Type_Kind : Ada_Type;
         Type_Name : UTF_Encoding.UTF_8_String;
         Format    : Root_Formatter_Parameters;
      );

      procedure List_Element (
         Self          : in out Root_Formatter_Type;
         Buffer        : in out Root_Buffer_Type;
         Name          : UTF_Encoding.UTF_8_String := "";
         Is_Constraint : Boolean;
         Format        : Root_Formatter_Parameters
      );

      procedure Close (
         Self   : in out Root_Buffer_Type;
         Buffer : in out Root_Buffer_Type;
      );
   end Root_Formatter_Type with private;

   type Default_Formatter_Type is new Root_Formatter_Type with class record
      -- Implementation-Defined
   end Default_Formatter_Type;

   Default_Formatter : Default_Formatter_Type;

private
   ... -- not specified by the language
end Flare.Strings.Text_Buffers;
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
    Buffer    : in out Flare.Strings.Text_Buffers.Root_Buffer_Type;
    Formatter : in out Flare.Strings.Text_Buffers.Root_Formatter_Type;
    Format    : Root_Formatter_Parameters)
is
begin
   Formatter.Open (Buffer, Record_Type, "P.Rec", Format);

   Formatter.List_Element (Buffer, "D", True, Format);
   Self.D'To_String (Buffer, Formatter, Format);

   Formatter.List_Element (Buffer, "A", False, Format);
   Self.A'To_String (Buffer, Formatter, Format);

   Formatter.List_Element (Buffer, "B", False, Format);
   Self.B'To_String (Buffer, Formatter, Format);

   if Self.D then
      Formatter.List_Element (Buffer, "C", False, Format);
      Self.C'To_String (Buffer, Formatter, Format);
   else
      Formatter.List_Element (Buffer, "E", False, Format);
      Self.E'To_String (Buffer, Formatter, Format);
   end if;

   Formatter.Close (Buffer);
end Rec'To_String;
```

Default To_String for Tagged Records and Classes
------------------------------------------------

For tagged records and classes, To_String will first open the child scope, then
call its parent To_String, then add any constraints or components. For example:

For example:

```ada
type Root is class record
   A, B : Integer;
end record;

type Child is new Root with class record
   C, D : Integer;
end record;

procedure Root'To_String
   (Self      : Root;
    Buffer    : in out Flare.Strings.Text_Buffers.Root_Buffer_Type;
    Formatter : in out Flare.Strings.Text_Buffers.Root_Formatter_Type;
    Format    : Root_Formatter_Parameters)
is
begin
   Formatter.Open (Buffer, Record_Type, "P.Root", Format);

   Formatter.List_Element (Buffer, "A", False, Format);
   Self.A'To_String (Buffer, Formatter, Format);

   Formatter.List_Element (Buffer, "B", False, Format);
   Self.B'To_String (Buffer, Formatter, Format);

   Formatter.Close (Buffer);
end Root'To_String

procedure Child'To_String
   (Self      : Child;
    Buffer    : in out Flare.Strings.Text_Buffers.Root_Buffer_Type;
    Formatter : in out Flare.Strings.Text_Buffers.Root_Formatter_Type;
    Format    : Root_Formatter_Parameters)
is
begin
   Formatter.Open (Buffer, Record_Type, "P.Child", Format);

   --  Static call to the parent
   Self'Super'To_String (Buffer, Formatter, Format);

   --  Now prints components

   Formatter.List_Element (Buffer, "C", False, Format);
   Self.A'To_String (Buffer, Formatter, Format);

   Formatter.List_Element (Buffer, "D", False, Format);
   Self.B'To_String (Buffer, Formatter, Format);

   Formatter.Close (Buffer);
end Child'To_String;
```

Child may be overriden, the implementer may decide to not call parent if needed.

For the formatter, by default, components are provided in order. The formater
also has the possibility of detecting whcih components belong to which type
by tracking the Open/Close calls in a stack.

Default To_String for Arrays
----------------------------

The default implementation of To_String for arrays:

- First call Formatter.Open on the type, also giving index and component types
- Then call Formatter.List element followed by To_String on each low then high bound.
- Then for each component, call Formatter.List element followed by To_String on the Index then Component
- Last call Formatter.Close

for example:

```ada
type Arr is array (Integer range <>) of Integer;

procedure Arr'To_String
   (Self      : Arr;
    Buffer    : in out Flare.Strings.Text_Buffers.Root_Buffer_Type;
    Formatter : in out Flare.Strings.Text_Buffers.Root_Formatter_Type;
    Format    : Root_Formatter_Parameters)
is
begin
   Formatter.Open (Buffer, Array_Type, "P.Arr", Format);

   Formatter.List_Element (Buffer, "First", True, Format);
   Self'First'To_String (Buffer, Formatter, Format);

   Formatter.List_Element (Buffer, "Last", True, Format);
   Self'Last'To_String (Buffer, Formatter, Format);

   for I in Self'Range loop
      Formatter.List_Element (Buffer, "", False, Format);

      I'To_String (Buffer, Formatter, False, Format);
      Self (I)'To_String (Buffer, Formatter, False, Format);
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
    Buffer    : in out Flare.Strings.Text_Buffers.Root_Buffer_Type;
    Formatter : in out Flare.Strings.Text_Buffers.Root_Formatter_Type;
    Format    : Root_Formatter_Parameters)
is
begin
   Formatter.Open (Buffer, Array_Type, "P.Arr", Format);

   Formatter.List_Element (Buffer, "First", True, Format);
   Self'First (1)'To_String (Buffer, Formatter, Format);

   Formatter.List_Element (Buffer, "Last", True, Format);
   Self'Last (1)'To_String (Buffer, Formatter, Format);

   Formatter.List_Element (Buffer, "First", True, Format);
   Self'First (2)'To_String (Buffer, Formatter, Format);

   Formatter.List_Element (Buffer, "Last", True, Format);
   Self'Last (2)'To_String (Buffer, Formatter, Format);

   for I in Self'Range (1) loop
      for J in Self'Range (2) loop
         Formatter.List_Element (Buffer, "", False, Format);

         I'To_String (Buffer, Formatter, False, Format);
         J'To_String (Buffer, Formatter, False, Format);
         Self (I, J)'To_String (Buffer, Formatter, False, Format);
      end loop;
   end loop;

   Formatter.Close (Buffer);
end Arr'To_String;
```

Note that in the To_String calls to individual constriants, the formatter
will receive the exact type of each bound (through their own Open call), so
it is possible to reproduce exactly the shape of the array by capturing
constraints first up until the first non constrain element is retreived.

Default To_String for Arrays of Characters
------------------------------------------

One-dimention array of character have a special default To_String method - they
don't output element by element with indices but instead output directly the
entire value, e.g.:

```ada
procedure String'To_String
   (Self      : String;
    Buffer    : in out Flare.Strings.Text_Buffers.Root_Buffer_Type;
    Formatter : in out Flare.Strings.Text_Buffers.Root_Formatter_Type;
    Format    : Root_Formatter_Parameters)
is
begin
   Formatter.Open
     (Buffer, Record_Type, "Standard.String",
      Signed_Type,         "Standard.Integer",
      Enumeration_Type,    "Standard.Character",
      Format);

   Formatter.List_Element (Buffer, "First", True, Format);
   Self'First'To_String (Buffer, Formatter, Format);

   Formatter.List_Element (Buffer, "Last", True, Format);
   Self'Last'To_String (Buffer, Formatter, Format);

   Formatter.Put (Buffer, Self, Format);

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
    Buffer    : in out Flare.Strings.Text_Buffers.Root_Buffer_Type;
    Formatter : in out Flare.Strings.Text_Buffers.Root_Formatter_Type;
    Format    : Root_Formatter_Parameters)
is
begin
   Formatter.Open (Buffer, Signed_Type, "Standard.Integer", Format);
   Formatter.Put (Buffer, <code transforming Self to string>);
   Formatter.Close (Buffer);
end Integer'To_String;
```

One of the potential use case for providing this level of information on the
elementary types is to allow the formatter to "reformat" number, for example,
formating "1234" into "1,234".

Default To_String for Tasks and Protected Types
-----------------------------------------------

Tasks will first display task ids, followed by discriminants if any:

```ada
procedure Some_Task_Type'To_String
   (Self      : Some_Task_Type;
    Buffer    : in out Flare.Strings.Text_Buffers.Root_Buffer_Type;
    Formatter : in out Flare.Strings.Text_Buffers.Root_Formatter_Type;
    Format    : Root_Formatter_Parameters)
is
begin
   Formatter.Open (Buffer, Task_Type, "P.Some_Task_Type", Format);
   Formatter.Put (Buffer, <code providing task id>);

   --  Add here sequence of list / put

   Formatter.Close (Buffer);
end Some_Task_Type'To_String;
```

In the case of a protected type T, a call to the default implementation of
T'To_String begins only one protected (read-only) action (similar to Put_Image).

Ada Compatibilty Mode
---------------------

`To_String` will be made available in Ada compatibility mode. For this,
Ada.Strings.Text_Formatters will be introduced with the necessary tagged types,
and default implementations

The packages provided for Ada will look as follow:

```ada
package Ada.Strings.Text_Formatters is

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

   type Root_Formatter_Parameters is abstract tagged record
      --  Provided for future extensions - should contain various formating
      --  parameters necessary for default formating.

      null;
   end record;

   function Create
      (Self   : in out Root_Formatter_Parameters;
       Format : String) return Root_Formatter_Parameters

   type Root_Formatter_Type is abstract tagged record
      null;
   end record;

   procedure Put (
      Self   : in out Root_Formatter_Type;
      Buffer : in out Root_Buffer_Type'Class;
      Item   : in     String;
      Format : Root_Formatter_Parameters'Class) is abstract;

   procedure Wide_Put (
      Self   : in out Root_Formatter_Type;
      Buffer : in out Root_Buffer_Type'Class;
      Item   : in     Wide_String;
      Format : Root_Formatter_Parameters'Class) is abstract;

   procedure Wide_Wide_Put (
      Self   : in out Root_Formatter_Type;
      Buffer : in out Root_Buffer_Type'Class;
      Item   : in     Wide_Wide_String;
      Format : Root_Formatter_Parameters'Class) is abstract;

   procedure Put_UTF_8 (
      Self   : in out Root_Formatter_Type;
      Buffer : in out Root_Buffer_Type'Class;
      Item   : in     UTF_Encoding.UTF_8_String;
      Format : Root_Formatter_Parameters'Class) is abstract;

   procedure Wide_Put_UTF_16 (
      Self   : in out Root_Formatter_Type;
      Buffer : in out Root_Buffer_Type'Class;
      Item   : in     UTF_Encoding.UTF_16_Wide_String;
      Format : Root_Formatter_Parameters'Class) is abstract;

   procedure New_Line (
      Self   : in out Root_Formatter_Type;
      Buffer : in out Root_Buffer_Type'Class;
      Format : Root_Formatter_Parameters'Class) is abstract;

   procedure Start
      (Self   : in out Root_Formatter_Type;
       Buffer : in out Root_Buffer_Type'Class;
       Format : Root_Formatter_Parameters'Class);

   procedure Finish
      (Self   : in out Root_Formatter_Type;
       Buffer : in out Root_Buffer_Type'Class);

   procedure Open (
      Self      : in out Root_Formatter_Type;
      Buffer    : in out Flare.Strings.Text_Buffers.Root_Buffer_Type'Class;
      Type_Kind : Ada_Type;
      Type_Name : UTF_Encoding.UTF_8_String;
      Format    : Root_Formatter_Parameters'Class
   );

   procedure List_Element (
      Self          : in out Root_Formatter_Type;
      Buffer        : in out Root_Buffer_Type;
      Name          : UTF_Encoding.UTF_8_String := "";
      Is_Constraint : Boolean;
      Format        : Root_Formatter_Parameters'Class
   );

   procedure Close (
      Self   : in out Root_Buffer_Type;
      Buffer : in out Flare.Strings.Text_Buffers.Root_Buffer_Type'Class;
   );

   type Default_Formatter_Type is new Root_Formatter_Type with record
      -- Implementation-Defined
   end record;

   Default_Formatter : Default_Formatter_Type;

end Ada.Strings.Text_Formatters;
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

Mixed Tagged Type Hierarchies
-----------------------------

In mixed compatibilty mode, units compiled with extensions may be mixed with
units not compiled with the extensions. If that's the case, only units with
the extension do get To_String generated for them. In the case of hierarchy
of classes, it is legal to have To_String introduced this way at any point
in the hiearchy. All children of a type that support To_String also supports
To_String.

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

- A new attribute 'From_String associated with a Root_Parser_Type could be
  introduced. Parsing is more complicated than just formatting values, may"
  deserve some additional design work.

- Format parameter has been introduce to prepare for future extension - its
  default semantics need to be defined.

- Interpolated strings (f"") should provides way to easily associate a formatter
  and format parameters.

- Formatters for formats such as YAML, JSON and others can be provided to
  additional libraries.
