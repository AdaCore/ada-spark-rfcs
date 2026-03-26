- Feature Name: To_String
- Start Date:
- Status: Production

# Summary


# Motivation

The current type-to-string mechanism in Ada has a few shortcomings:
- Integer values are provided with a leading space
- The new Ada 2022 Put_Image attribute is non-dispatching and confusing when
  used with a class-wide view (which will be a more visible problem with the
  new dispatching semantics)
- The new Ada 2022 Put_Image attribute provides some limited formatting (notably
  through the indentation functions of the Buffer) but doesn't go as far as
  allowing to format the output to standards such as JSON or YAML.

The need to output formatted data is particularly important for
applications that need to log data for e.g. debugging or other external purposes.

# Guide-level explanation

## To_String Attribute

'To_String (with its _Wide_String and _Wide_Wide_String counterparts) is provided
as a replacement for 'Image (and 'Img in GNAT-specific extensions).
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
parameter will be set to `Flare.Strings.Text_Formatters.Default_Formatter`
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

To_String can be used directly as a procedure. In this case it needs to be
provided with an instance of a new buffer type,
Flare.Strings.Text_Buffers.Root_Buffer_Type, and an optional formatter.
Similar to Ada, there are predefined buffer types provided by the language.
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
values indicating to the formatter additional parameters or controlling the default
generation of formatting for e.g. elementary types. This string is here to
prepare for additional extensions of the model but its format requires design
on its own - which is outside of the scope of this proposal. E.g.:

```ada
--  The following is not part of the proposal but demonstrate future extension
--  possibilities

X : Float;
V : String := X'To_String (Format => Root_Formatter_Parameter'Make (".2f"));
--  assuming we include a format similar to python, asks for 2 decimals

V : String := f"{X:.2f}"
--  same as above, using formatted strings
```

By default, this receives an empty string.

`Flare.Strings.Text_Buffers.Root_Buffer_Type` is similar to
`Ada.Strings.Text_Buffers.Root_Buffer_Type` except that it relies on a
formatter to structure the output, as opposed to the indent primitives. E.g.:

```ada
package Flare.Strings.Text_Formatters is

   type Root_Formatter_Parameters is abstract class record
      --  Provided for future extensions - should contain various formatting
      --  parameters necessary for default formatting.

      procedure Root_Formatter_Parameters'Constructor
         (Self   : in out Root_Formatter_Parameters;
          Format : String);
      --  Will support default formatting format, for example ".2f" may mean
      --  2 decimals for floating points if following Python formatting
   end Root_Formatter_Parameters with private;

   type Root_Formatter_Type is abstract class record

      --  Elementary Types Support  --

      procedure Put_Address (
         Self      : in out Root_Formatter_Type;
         Buffer    : in out Root_Buffer_Type;
         Type_Name : UTF_Encoding.UTF_8_String;
         Item      : System.Address;
         Format    : Root_Formatter_Parameters)
      is abstract;

      procedure Put_Access (
         Self      : in out Root_Formatter_Type;
         Buffer    : in out Root_Buffer_Type;
         Type_Name : UTF_Encoding.UTF_8_String;
         Item      : System.Storage_Elements.Storage_Array;
         Format    : Root_Formatter_Parameters)
      is abstract;
      --  Ada Access types may be a single address - they may also contain
      --  more information depending on the implementation (e.g. bounds for
      --  arrays), so we need to provide a byte array as input

      procedure Put_Enumeration (
         Self       : in out Root_Formatter_Type;
         Buffer     : in out Root_Buffer_Type;
         Type_Name  : UTF_Encoding.UTF_8_String;
         Value_Name : UTF_Encoding.UTF_8_String;
         Value_Rep  : Interfaces.Integer_64;
         Format     : Root_Formatter_Parameters)
      is abstract;

      procedure Put_Boolean (
         Self   : in out Root_Formatter_Type;
         Buffer : in out Root_Buffer_Type;
         Value  : Boolean;
         Format : Root_Formatter_Parameters)
      is abstract;

      procedure Put_Integer_8 (
         Self      : in out Root_Formatter_Type;
         Buffer    : in out Root_Buffer_Type;
         Type_Name : UTF_Encoding.UTF_8_String;
         Item      : Interfaces.Integer_8;
         Format    : Root_Formatter_Parameters)
      is abstract;

      procedure Put_Integer_16 (
         Self      : in out Root_Formatter_Type;
         Buffer    : in out Root_Buffer_Type;
         Type_Name : UTF_Encoding.UTF_8_String;
         Item      : Interfaces.Integer_16;
         Format    : Root_Formatter_Parameters)
      is abstract;

      procedure Put_Integer_32 (
         Self      : in out Root_Formatter_Type;
         Buffer    : in out Root_Buffer_Type;
         Type_Name : UTF_Encoding.UTF_8_String;
         Item      : Interfaces.Integer_32;
         Format    : Root_Formatter_Parameters)
      is abstract;

      procedure Put_Integer_64 (
         Self      : in out Root_Formatter_Type;
         Buffer    : in out Root_Buffer_Type;
         Type_Name : UTF_Encoding.UTF_8_String;
         Item      : Interfaces.Integer_64;
         Format    : Root_Formatter_Parameters)
      is abstract;

      procedure Put_Unsigned_8 (
         Self      : in out Root_Formatter_Type;
         Buffer    : in out Root_Buffer_Type;
         Type_Name : UTF_Encoding.UTF_8_String;
         Item      : Interfaces.Unsigned_8;
         Format    : Root_Formatter_Parameters)
      is abstract;

      procedure Put_Unsigned_16 (
         Self      : in out Root_Formatter_Type;
         Buffer    : in out Root_Buffer_Type;
         Type_Name : UTF_Encoding.UTF_8_String;
         Item      : Interfaces.Unsigned_16;
         Format    : Root_Formatter_Parameters)
      is abstract;

      procedure Put_Unsigned_32 (
         Self      : in out Root_Formatter_Type;
         Buffer    : in out Root_Buffer_Type;
         Type_Name : UTF_Encoding.UTF_8_String;
         Item      : Interfaces.Unsigned_32;
         Format    : Root_Formatter_Parameters)
      is abstract;

      procedure Put_Unsigned_64 (
         Self      : in out Root_Formatter_Type;
         Buffer    : in out Root_Buffer_Type;
         Type_Name : UTF_Encoding.UTF_8_String;
         Item      : Interfaces.Unsigned_64;
         Format    : Root_Formatter_Parameters)
      is abstract;

      procedure Put_Unsigned_128 (
         Self      : in out Root_Formatter_Type;
         Buffer    : in out Root_Buffer_Type;
         Type_Name : UTF_Encoding.UTF_8_String;
         Item      : Interfaces.Unsigned_128;
         Format    : Root_Formatter_Parameters)
      is abstract;

      procedure Put_Big_Integer (
         Self      : in out Root_Formatter_Type;
         Buffer    : in out Root_Buffer_Type;
         Type_Name : UTF_Encoding.UTF_8_String;
         Item      : Ada.Numerics.Big_Numbers.Big_Integers.Big_Integer;
         Format    : Root_Formatter_Parameters)
      is abstract;

      procedure Put_Float_32 (
         Self      : in out Root_Formatter_Type;
         Buffer    : in out Root_Buffer_Type;
         Type_Name : UTF_Encoding.UTF_8_String;
         Item      : Interfaces.IEEE_Float_32;
         Format    : Root_Formatter_Parameters)
      is abstract;

      procedure Put_Float_64 (
         Self      : in out Root_Formatter_Type;
         Buffer    : in out Root_Buffer_Type;
         Type_Name : UTF_Encoding.UTF_8_String;
         Item      : Interfaces.IEEE_Float_64;
         Format    : Root_Formatter_Parameters)
      is abstract;

      procedure Put_Big_Real (
         Self      : in out Root_Formatter_Type;
         Buffer    : in out Root_Buffer_Type;
         Type_Name : UTF_Encoding.UTF_8_String;
         Item      : Ada.Numerics.Big_Numbers.Big_Reals.Big_Real;
         Format    : Root_Formatter_Parameters)
      is abstract;

      procedure Put_Fixed_Point_8 (
         Self              : in out Root_Formatter_Type;
         Buffer            : in out Root_Buffer_Type;
         Type_Name         : UTF_Encoding.UTF_8_String;
         Value             : Interfaces.Integer_8;
         Scope_Numerator   : Interfaces.Integer_8;
         Scope_Denominator : Interfaces.Integer_8;
         Format            : Root_Formatter_Parameters)
      is abstract;

      procedure Put_Fixed_Point_16 (
         Self              : in out Root_Formatter_Type;
         Buffer            : in out Root_Buffer_Type;
         Type_Name         : UTF_Encoding.UTF_8_String;
         Value             : Interfaces.Integer_16;
         Scope_Numerator   : Interfaces.Integer_16;
         Scope_Denominator : Interfaces.Integer_16;
         Format            : Root_Formatter_Parameters)
      is abstract;

      procedure Put_Fixed_Point_32 (
         Self              : in out Root_Formatter_Type;
         Buffer            : in out Root_Buffer_Type;
         Type_Name         : UTF_Encoding.UTF_8_String;
         Value             : Interfaces.Integer_32;
         Scope_Numerator   : Interfaces.Integer_32;
         Scope_Denominator : Interfaces.Integer_32;
         Format            : Root_Formatter_Parameters)
      is abstract;

      procedure Put_Fixed_Point_64 (
         Self              : in out Root_Formatter_Type;
         Buffer            : in out Root_Buffer_Type;
         Type_Name         : UTF_Encoding.UTF_8_String;
         Value             : Interfaces.Integer_64;
         Scope_Numerator   : Interfaces.Integer_64;
         Scope_Denominator : Interfaces.Integer_64;
         Format            : Root_Formatter_Parameters)
      is abstract;

      procedure Put_Fixed_Point_128 (
         Self              : in out Root_Formatter_Type;
         Buffer            : in out Root_Buffer_Type;
         Type_Name         : UTF_Encoding.UTF_8_String;
         Value             : Interfaces.Integer_128;
         Scope_Numerator   : Interfaces.Integer_128;
         Scope_Denominator : Interfaces.Integer_128;
         Format            : Root_Formatter_Parameters)
      is abstract;

      --  Array Support  --

      procedure Open_Array (
         Self           : in out Root_Formatter_Type;
         Buffer         : in out Root_Buffer_Type;
         Type_Name      : UTF_Encoding.UTF_8_String;
         Format         : Root_Formatter_Parameters)
      is abstract;

      procedure List_First (
         Self           : in out Root_Formatter_Type;
         Buffer         : in out Root_Buffer_Type;
         Dimension      : Integer;
         Format         : Root_Formatter_Parameters)
      is abstract;

      procedure List_Last (
         Self           : in out Root_Formatter_Type;
         Buffer         : in out Root_Buffer_Type;
         Dimension      : Integer;
         Format         : Root_Formatter_Parameters)
      is abstract;

      procedure List_Components (
         Self          : in out Root_Formatter_Type;
         Buffer        : in out Root_Buffer_Type;
         Format        : Root_Formatter_Parameters)
      is abstract;

      procedure List_Indexes_Components (
         Self          : in out Root_Formatter_Type;
         Buffer        : in out Root_Buffer_Type;
         Format        : Root_Formatter_Parameters)
      is abstract;
      --  Following this, the formatter expect to receive a sequence of
      -- {index(es), component value}

      --  Common for composite types  --

      --  Record Support  --

      procedure Open_Record (
         Self      : in out Root_Formatter_Type;
         Buffer    : in out Root_Buffer_Type;
         Type_Name : UTF_Encoding.UTF_8_String;
         Format    : Root_Formatter_Parameters)
      is abstract;

      procedure List_Discriminant (
         Self   : in out Root_Formatter_Type;
         Buffer : in out Root_Buffer_Type;
         Name   : UTF_Encoding.UTF_8_String;
         Format : Root_Formatter_Parameters)
      is abstract;

      procedure List_Component (
         Self   : in out Root_Formatter_Type;
         Buffer : in out Root_Buffer_Type;
         Name   : UTF_Encoding.UTF_8_String;
         Format : Root_Formatter_Parameters)
      is abstract;

      --  Protected Support  --

      procedure Open_Protected (
         Self      : in out Root_Formatter_Type;
         Buffer    : in out Root_Buffer_Type;
         Type_Name : UTF_Encoding.UTF_8_String;
         Format    : Root_Formatter_Parameters)
      is abstract;

      --  Also calls List_Discriminant and List_Component

      --  Task Support  --

      procedure Open_Task (
         Self      : in out Root_Formatter_Type;
         Buffer    : in out Root_Buffer_Type;
         Type_Name : UTF_Encoding.UTF_8_String;
         Format    : Root_Formatter_Parameters)
      is abstract;

      --  Also calls List_Discriminant

      --  String printing support  --

      procedure Put (
         Self   : in out Root_Formatter_Type;
         Buffer : in out Root_Buffer_Type;
         Item   : in     String;
         Format : Root_Formatter_Parameters)
      is abstract;

      procedure Wide_Put (
         Self   : in out Root_Formatter_Type;
         Buffer : in out Root_Buffer_Type;
         Item   : in     Wide_String;
         Format : Root_Formatter_Parameters)
      is abstract;

      procedure Wide_Wide_Put (
         Self   : in out Root_Formatter_Type;
         Buffer : in out Root_Buffer_Type;
         Item   : in     Wide_Wide_String;
         Format : Root_Formatter_Parameters)
      is abstract;

      procedure Put_UTF_8 (
         Self   : in out Root_Formatter_Type;
         Buffer : in out Root_Buffer_Type;
         Item   : in     UTF_Encoding.UTF_8_String;
         Format : Root_Formatter_Parameters)
      is abstract;

      procedure Wide_Put_UTF_16 (
         Self   : in out Root_Formatter_Type;
         Buffer : in out Root_Buffer_Type;
         Item   : in     UTF_Encoding.UTF_16_Wide_String;
         Format : Root_Formatter_Parameters)
      is abstract;

      procedure New_Line (
         Self   : in out Root_Formatter_Type;
         Buffer : in out Root_Buffer_Type;
         Format : Root_Formatter_Parameters)
      is abstract;

      --  Other flow indications --

      procedure Open
         (Self   : in out Root_Formatter_Type;
          Buffer : in out Root_Buffer_Type;
          Format : Root_Formatter_Parameters)
      is abstract;

      procedure Close (
         Self   : in out Root_Formatter_Type;
         Buffer : in out Root_Buffer_Type)
      is abstract;
   end Root_Formatter_Type with private;

   Default_Formatter : constant Root_Formatter_Type'Class;

private
   ... -- not specified by the language
end Flare.Strings.Text_Buffers;
```

`To_String` can be overridden by an attribute that takes a value and a buffer.
The default To_String for records uses scoping to follow formatting.

The overridden To_String is a primitive of the type. When used on a tagged or class
record, it will dispatch. Calling To_String on a class-wide view will dispatch
to the actual call. E.g.:

```ada
   type Root is class record ...

   type Child is new Root with class record ...

   X : Root'Class := Child'(others => <>);
begin
   Put_Line (X'To_String); -- Will dispatch to Child'To_String.
```

## Protocol

When generating a call to the To_String attribute function, the compiler is
responsible for:

- Creating an instance of Root_Buffer_Type
- Calling Open on the formatter, buffer, and parameters (either default values
  or the ones explicitly provided).
- Calling To_String procedure on the element
- Calling Close on the formatter, buffer and parameters
- Using the buffer to convert to a string and returning that string.

The To_String procedure attribute is directly calling the attribute as defined
by the user, there's no specific instrumentation inserted by the compiler in
this case.

Each data type has a pre-defined protocol which governs the default generation
for To_String attributes - user may override this default implementation (for
example, hiding certain fields, or generating an array-like representation for
a record). Not respecting the protocol is likely to cause failures in the formatter,
but there are no specific checks (contracts could be added to help with this).

### To_String for Elementary Types

The default implementation for elementary types is to call the appropriate
Put_ procedure that corresponds to this type. In the case of floats and integers,
if no matching procedure exists, Big_Int and Big_Float will be used instead. For example:

```ada
procedure Integer'To_String
   (Self      : Integer;
    Buffer    : in out Flare.Strings.Text_Buffers.Root_Buffer_Type;
    Formatter : in out Flare.Strings.Text_Buffers.Root_Formatter_Type;
    Format    : Root_Formatter_Parameters)
is
begin
   Formatter.Put_Integer_32 (Buffer, "Standard.Integer", Integer_32 (Self), Format);
end Integer'To_String;
```
### To_String for Arrays

The default implementation of To_String for arrays:

- Call Formatter.Open_Array on the type
- Call Formatter.List_First and Formatter.List_Last on each bound
- If the array is indexed by integer types:
   - Call List_Components
   - For each component, call To_String on that component
- If the array is indexed by enumerations:
   - Call List_Indexes_And_Components
   - For each component, call To_String on the index then on the component
- Call Formatter.Close

For example:

```ada
type Arr is array (Integer range <>) of Integer;

procedure Arr'To_String
   (Self      : Arr;
    Buffer    : in out Flare.Strings.Text_Buffers.Root_Buffer_Type;
    Formatter : in out Flare.Strings.Text_Buffers.Root_Formatter_Type;
    Format    : Root_Formatter_Parameters)
is
begin
   Formatter.Open_Array (Buffer, "P.Arr", Format);

   Formatter.List_First (Buffer, 1, Format);
   Self'First'To_String (Buffer, Formatter, Format);

   Formatter.List_Last (Buffer, 1, Format);
   Self'Last'To_String (Buffer, Formatter, Format);

   Formatter.List_Components (Buffer, Format);

   for E of Self loop
      E'To_String (Buffer, Formatter, False, Format);
   end loop;

   Formatter.Close (Buffer);
end Arr'To_String;
```

In the case of multidimensional arrays, boundaries are passed in sequence,
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
   Formatter.Open_Array (Buffer, "P.Arr", Format);

   Formatter.List_First (Buffer, 1, Format);
   Self'First (1)'To_String (Buffer, Formatter, Format);

   Formatter.List_Last (Buffer, 1, Format);
   Self'Last (1)'To_String (Buffer, Formatter, Format);

   Formatter.List_First (Buffer, 2, Format);
   Self'First (2)'To_String (Buffer, Formatter, Format);

   Formatter.List_Last (Buffer, 2, Format);
   Self'Last (2)'To_String (Buffer, Formatter, Format);

   Formatter.List_Components (Buffer, Format);

   for I in Self'Range (1) loop
      for J in Self'Range (2) loop
         Self (I, J)'To_String (Buffer, Formatter, Format);
      end loop;
   end loop;

   Formatter.Close (Buffer);
end Arr'To_String;
```

### To_String for Arrays of Characters

One-dimensional arrays of characters have a special default To_String method - they
don't output element by element with indices but instead output the
entire value directly, e.g.:

```ada
procedure String'To_String
   (Self      : String;
    Buffer    : in out Flare.Strings.Text_Buffers.Root_Buffer_Type;
    Formatter : in out Flare.Strings.Text_Buffers.Root_Formatter_Type;
    Format    : Root_Formatter_Parameters)
is
begin
   Formatter.Open_Array (Buffer, "Standard.String", Format);

   Formatter.List_First (Buffer, 1, Format);
   Self'First'To_String (Buffer, Formatter, Format);

   Formatter.List_Last (Buffer, 1, Format);
   Self'Last'To_String (Buffer, Formatter, Format);

   Formatter.Put (Buffer, Self, Format);

   Formatter.Close (Buffer);
end String'To_String;
```

## To_String for Records

The default implementation of To_String for records:

- Call Formatter.Open_Record on the type
- For each discriminant, call Formatter.List_Discriminant followed by To_String
  on the discriminant value
- For each component, call Formatter.List_Component followed by To_String
  on the component value
- Call Formatter.Close

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
   Formatter.Open_Record (Buffer, "P.Rec", Format);

   Formatter.List_Discriminant (Buffer, "D", Format);
   Self.D'To_String (Buffer, Formatter, Format);

   Formatter.List_Component (Buffer, "A", Format);
   Self.A'To_String (Buffer, Formatter, Format);

   Formatter.List_Component (Buffer, "B", Format);
   Self.B'To_String (Buffer, Formatter, Format);

   if Self.D then
      Formatter.List_Component (Buffer, "C", Format);
      Self.C'To_String (Buffer, Formatter, Format);
   else
      Formatter.List_Component (Buffer, "E", Format);
      Self.E'To_String (Buffer, Formatter, Format);
   end if;

   Formatter.Close (Buffer);
end Rec'To_String;
```

## To_String for Tagged Records and Classes

For tagged records and classes, To_String will first open the child scope, then
call its parent To_String, then add any constraints or components. For example:

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
   Formatter.Open_Record (Buffer, "P.Root", Format);

   Formatter.List_Component (Buffer, "A", Format);
   Self.A'To_String (Buffer, Formatter, Format);

   Formatter.List_Component (Buffer, "B", Format);
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
   Formatter.Open_Record (Buffer, "P.Child", Format);

   --  Static call to the parent
   Self'Super'To_String (Buffer, Formatter, Format);

   --  Now prints components

   Formatter.List_Component (Buffer, "C", Format);
   Self.A'To_String (Buffer, Formatter, Format);

   Formatter.List_Component (Buffer, "D", Format);
   Self.B'To_String (Buffer, Formatter, Format);

   Formatter.Close (Buffer);
end Child'To_String;
```

Child may be overridden; the implementer may decide not to call the parent if needed.

For the formatter, by default, components are provided in order. The formatter
also has the possibility of detecting which components belong to which type
by tracking the Open/Close calls in a stack.

## To_String for Tasks and Protected Types

Tasks will first display task ids, followed by discriminants if any:

```ada
procedure Some_Task_Type'To_String
   (Self      : Some_Task_Type;
    Buffer    : in out Flare.Strings.Text_Buffers.Root_Buffer_Type;
    Formatter : in out Flare.Strings.Text_Buffers.Root_Formatter_Type;
    Format    : Root_Formatter_Parameters)
is
begin
   Formatter.Open_Task (Buffer, "P.Some_Task_Type", Format);
   Formatter.Put (Buffer, <code providing task id>);

   --  Add here sequence of list / put

   Formatter.Close (Buffer);
end Some_Task_Type'To_String;
```

In the case of a protected type T, a call to the default implementation of
T'To_String begins only one protected (read-only) action (similar to Put_Image).

## Ada Compatibility Mode

`To_String` will be made available in Ada compatibility mode. For this,
Ada.Strings.Text_Formatters will be introduced with the necessary tagged types
and default implementations.

The package provided for Ada will look as follows:

```ada
package Ada.Strings.Text_Formatters is

   type Root_Formatter_Parameters is abstract tagged record
      --  Provided for future extensions - should contain various formatting
      --  parameters necessary for default formatting.

      null;
   end record;

   function Create
      (Self   : in out Root_Formatter_Parameters;
       Format : String) return Root_Formatter_Parameters is abstract;

   type Root_Formatter_Type is abstract tagged record
      null;
   end record;

   --  Elementary Types Support  --

   procedure Put_Address
      (Self      : in out Root_Formatter_Type;
       Buffer    : in out Root_Buffer_Type'Class;
       Type_Name : UTF_Encoding.UTF_8_String;
       Item      : System.Address;
       Format    : Root_Formatter_Parameters'Class)
   is abstract;

   procedure Put_Access
      (Self      : in out Root_Formatter_Type;
       Buffer    : in out Root_Buffer_Type'Class;
       Type_Name : UTF_Encoding.UTF_8_String;
       Item      : System.Storage_Elements.Storage_Array;
       Format    : Root_Formatter_Parameters'Class)
   is abstract;
   --  Ada Access types may be a single address - they may also contain
   --  more information depending on the implementation (e.g. bounds for
   --  arrays), so we need to provide a byte array as input

   procedure Put_Enumeration
      (Self       : in out Root_Formatter_Type;
       Buffer     : in out Root_Buffer_Type'Class;
       Type_Name  : UTF_Encoding.UTF_8_String;
       Value_Name : UTF_Encoding.UTF_8_String;
       Value_Rep  : Interfaces.Integer_64;
       Format     : Root_Formatter_Parameters'Class)
   is abstract;

   procedure Put_Boolean
      (Self   : in out Root_Formatter_Type;
       Buffer : in out Root_Buffer_Type'Class;
       Value  : Boolean;
       Format : Root_Formatter_Parameters'Class)
   is abstract;

   procedure Put_Integer_8
      (Self      : in out Root_Formatter_Type;
       Buffer    : in out Root_Buffer_Type'Class;
       Type_Name : UTF_Encoding.UTF_8_String;
       Item      : Interfaces.Integer_8;
       Format    : Root_Formatter_Parameters'Class)
   is abstract;

   procedure Put_Integer_16
      (Self      : in out Root_Formatter_Type;
       Buffer    : in out Root_Buffer_Type'Class;
       Type_Name : UTF_Encoding.UTF_8_String;
       Item      : Interfaces.Integer_16;
       Format    : Root_Formatter_Parameters'Class)
   is abstract;

   procedure Put_Integer_32
      (Self      : in out Root_Formatter_Type;
       Buffer    : in out Root_Buffer_Type'Class;
       Type_Name : UTF_Encoding.UTF_8_String;
       Item      : Interfaces.Integer_32;
       Format    : Root_Formatter_Parameters'Class)
   is abstract;

   procedure Put_Integer_64
      (Self      : in out Root_Formatter_Type;
       Buffer    : in out Root_Buffer_Type'Class;
       Type_Name : UTF_Encoding.UTF_8_String;
       Item      : Interfaces.Integer_64;
       Format    : Root_Formatter_Parameters'Class)
   is abstract;

   procedure Put_Unsigned_8
      (Self      : in out Root_Formatter_Type;
       Buffer    : in out Root_Buffer_Type'Class;
       Type_Name : UTF_Encoding.UTF_8_String;
       Item      : Interfaces.Unsigned_8;
       Format    : Root_Formatter_Parameters'Class)
   is abstract;

   procedure Put_Unsigned_16
      (Self      : in out Root_Formatter_Type;
       Buffer    : in out Root_Buffer_Type'Class;
       Type_Name : UTF_Encoding.UTF_8_String;
       Item      : Interfaces.Unsigned_16;
       Format    : Root_Formatter_Parameters'Class)
   is abstract;

   procedure Put_Unsigned_32
      (Self      : in out Root_Formatter_Type;
       Buffer    : in out Root_Buffer_Type'Class;
       Type_Name : UTF_Encoding.UTF_8_String;
       Item      : Interfaces.Unsigned_32;
       Format    : Root_Formatter_Parameters'Class)
   is abstract;

   procedure Put_Unsigned_64
      (Self      : in out Root_Formatter_Type;
       Buffer    : in out Root_Buffer_Type'Class;
       Type_Name : UTF_Encoding.UTF_8_String;
       Item      : Interfaces.Unsigned_64;
       Format    : Root_Formatter_Parameters'Class)
   is abstract;

   procedure Put_Unsigned_128
      (Self      : in out Root_Formatter_Type;
       Buffer    : in out Root_Buffer_Type'Class;
       Type_Name : UTF_Encoding.UTF_8_String;
       Item      : Interfaces.Unsigned_128;
       Format    : Root_Formatter_Parameters'Class)
   is abstract;

   procedure Put_Big_Integer
      (Self      : in out Root_Formatter_Type;
       Buffer    : in out Root_Buffer_Type'Class;
       Type_Name : UTF_Encoding.UTF_8_String;
       Item      : Ada.Numerics.Big_Numbers.Big_Integers.Big_Integer;
       Format    : Root_Formatter_Parameters'Class)
   is abstract;

   procedure Put_Float_32
      (Self      : in out Root_Formatter_Type;
       Buffer    : in out Root_Buffer_Type'Class;
       Type_Name : UTF_Encoding.UTF_8_String;
       Item      : Interfaces.IEEE_Float_32;
       Format    : Root_Formatter_Parameters'Class)
   is abstract;

   procedure Put_Float_64
      (Self      : in out Root_Formatter_Type;
       Buffer    : in out Root_Buffer_Type'Class;
       Type_Name : UTF_Encoding.UTF_8_String;
       Item      : Interfaces.IEEE_Float_64;
       Format    : Root_Formatter_Parameters'Class)
   is abstract;

   procedure Put_Big_Real
      (Self      : in out Root_Formatter_Type;
       Buffer    : in out Root_Buffer_Type'Class;
       Type_Name : UTF_Encoding.UTF_8_String;
       Item      : Ada.Numerics.Big_Numbers.Big_Reals.Big_Real;
       Format    : Root_Formatter_Parameters'Class)
   is abstract;

   procedure Put_Fixed_Point_8
      (Self              : in out Root_Formatter_Type;
       Buffer            : in out Root_Buffer_Type'Class;
       Type_Name         : UTF_Encoding.UTF_8_String;
       Value             : Interfaces.Integer_8;
       Scope_Numerator   : Interfaces.Integer_8;
       Scope_Denominator : Interfaces.Integer_8;
       Format            : Root_Formatter_Parameters'Class)
   is abstract;

   procedure Put_Fixed_Point_16
      (Self              : in out Root_Formatter_Type;
       Buffer            : in out Root_Buffer_Type'Class;
       Type_Name         : UTF_Encoding.UTF_8_String;
       Value             : Interfaces.Integer_16;
       Scope_Numerator   : Interfaces.Integer_16;
       Scope_Denominator : Interfaces.Integer_16;
       Format            : Root_Formatter_Parameters'Class)
   is abstract;

   procedure Put_Fixed_Point_32
      (Self              : in out Root_Formatter_Type;
       Buffer            : in out Root_Buffer_Type'Class;
       Type_Name         : UTF_Encoding.UTF_8_String;
       Value             : Interfaces.Integer_32;
       Scope_Numerator   : Interfaces.Integer_32;
       Scope_Denominator : Interfaces.Integer_32;
       Format            : Root_Formatter_Parameters'Class)
   is abstract;

   procedure Put_Fixed_Point_64
      (Self              : in out Root_Formatter_Type;
       Buffer            : in out Root_Buffer_Type'Class;
       Type_Name         : UTF_Encoding.UTF_8_String;
       Value             : Interfaces.Integer_64;
       Scope_Numerator   : Interfaces.Integer_64;
       Scope_Denominator : Interfaces.Integer_64;
       Format            : Root_Formatter_Parameters'Class)
   is abstract;

   procedure Put_Fixed_Point_128
      (Self              : in out Root_Formatter_Type;
       Buffer            : in out Root_Buffer_Type'Class;
       Type_Name         : UTF_Encoding.UTF_8_String;
       Value             : Interfaces.Integer_128;
       Scope_Numerator   : Interfaces.Integer_128;
       Scope_Denominator : Interfaces.Integer_128;
       Format            : Root_Formatter_Parameters'Class)
   is abstract;


   --  Array Support  --

   procedure Open_Array
      (Self      : in out Root_Formatter_Type;
       Buffer    : in out Root_Buffer_Type'Class;
       Type_Name : UTF_Encoding.UTF_8_String;
       Format    : Root_Formatter_Parameters'Class)
   is abstract;

   procedure List_First
      (Self      : in out Root_Formatter_Type;
       Buffer    : in out Root_Buffer_Type'Class;
       Dimension : Integer;
       Format    : Root_Formatter_Parameters'Class)
   is abstract;

   procedure List_Last
      (Self      : in out Root_Formatter_Type;
       Buffer    : in out Root_Buffer_Type'Class;
       Dimension : Integer;
       Format    : Root_Formatter_Parameters'Class)
   is abstract;

   procedure List_Components
      (Self   : in out Root_Formatter_Type;
       Buffer : in out Root_Buffer_Type'Class;
       Format : Root_Formatter_Parameters'Class)
   is abstract;

   procedure List_Indexes_Components
      (Self   : in out Root_Formatter_Type;
       Buffer : in out Root_Buffer_Type'Class;
       Format : Root_Formatter_Parameters'Class)
   is abstract;
   --  Following this, the formatter expect to receive a sequence of
   --  {index(es), component value}

   --  Common for composite types  --

   --  Record Support  --

   procedure Open_Record
      (Self      : in out Root_Formatter_Type;
       Buffer    : in out Root_Buffer_Type'Class;
       Type_Name : UTF_Encoding.UTF_8_String;
       Format    : Root_Formatter_Parameters'Class)
   is abstract;

   procedure List_Discriminant
      (Self   : in out Root_Formatter_Type;
       Buffer : in out Root_Buffer_Type'Class;
       Name   : UTF_Encoding.UTF_8_String;
       Format : Root_Formatter_Parameters'Class)
   is abstract;

   procedure List_Component
      (Self   : in out Root_Formatter_Type;
       Buffer : in out Root_Buffer_Type'Class;
       Name   : UTF_Encoding.UTF_8_String;
       Format : Root_Formatter_Parameters'Class)
   is abstract;

   --  Protected Support  --

   procedure Open_Protected
      (Self      : in out Root_Formatter_Type;
       Buffer    : in out Root_Buffer_Type'Class;
       Type_Name : UTF_Encoding.UTF_8_String;
       Format    : Root_Formatter_Parameters'Class)
   is abstract;

   --  Also calls List_Discriminant and List_Component

   --  Task Support  --

   procedure Open_Task
      (Self      : in out Root_Formatter_Type;
       Buffer    : in out Root_Buffer_Type'Class;
       Type_Name : UTF_Encoding.UTF_8_String;
       Format    : Root_Formatter_Parameters'Class)
   is abstract;

   --  Also calls List_Discriminant

   --  String printing support  --

   procedure Put
      (Self   : in out Root_Formatter_Type;
       Buffer : in out Root_Buffer_Type'Class;
       Item   : in     String;
       Format : Root_Formatter_Parameters'Class)
   is abstract;

   procedure Wide_Put
      (Self   : in out Root_Formatter_Type;
       Buffer : in out Root_Buffer_Type'Class;
       Item   : in     Wide_String;
       Format : Root_Formatter_Parameters'Class)
   is abstract;

   procedure Wide_Wide_Put
      (Self   : in out Root_Formatter_Type;
       Buffer : in out Root_Buffer_Type'Class;
       Item   : in     Wide_Wide_String;
       Format : Root_Formatter_Parameters'Class)
   is abstract;

   procedure Put_UTF_8
      (Self   : in out Root_Formatter_Type;
       Buffer : in out Root_Buffer_Type'Class;
       Item   : in     UTF_Encoding.UTF_8_String;
       Format : Root_Formatter_Parameters'Class)
   is abstract;

   procedure Wide_Put_UTF_16
      (Self   : in out Root_Formatter_Type;
       Buffer : in out Root_Buffer_Type'Class;
       Item   : in     UTF_Encoding.UTF_16_Wide_String;
       Format : Root_Formatter_Parameters'Class)
   is abstract;

   procedure New_Line
      (Self   : in out Root_Formatter_Type;
       Buffer : in out Root_Buffer_Type'Class;
       Format : Root_Formatter_Parameters'Class)
   is abstract;

   --  Other flow indications --

   procedure Open
      (Self   : in out Root_Formatter_Type;
       Buffer : in out Root_Buffer_Type'Class;
       Format : Root_Formatter_Parameters'Class)
   is abstract;

   procedure Close
      (Self   : in out Root_Formatter_Type;
       Buffer : in out Root_Buffer_Type'Class)
   is abstract;

   Default_Formatter : constant Root_Formatter_Type'Class;

end Ada.Strings.Text_Formatters;
```

## Compatibility with 'Img and 'Value

The Ada 'Img, 'Image and 'Value attributes are deprecated (kept in
compatibility mode) to favor the attributes, 'To_String and 'From_String
(with their _Wide_String and _Wide_Wide_String counterparts).
These attributes are used directly on a value, and by default operate like
'Value and 'Image, (with the exception that no leading space is present for
numeric values) e.g.:

Formatted string (strings that start with an f) will exclusively use To_String
(they already are doing something special to some extent as integers don't
have a leading space there).

## Mixed Tagged Type Hierarchies

In mixed compatibility mode, units compiled with extensions may be mixed with
units not compiled with the extensions. If that's the case, only units with
the extension get To_String generated for them. In the case of a hierarchy
of classes, it is legal to have To_String introduced this way at any point
in the hierarchy. All children of a type that support To_String also support
To_String.

# Reference-level explanation


# Rationale and alternatives

## Two vs. one argument for formatter and buffer

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
   Formatter.Open ("P.Rec");

   Formatter.List_Element ("D", True);

   Formatter.List_Element ("A", False);
   Self.A'To_String (Formatter);

   Formatter.List_Element ("B", False);
   Self.B'To_String (Formatter);

   Formatter.Close;
end Rec'To_String;
```

However, this simplification on the implementer side increases complexity
on the user side as one now needs to instantiate a formatter with a new
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

# Drawbacks

## Performance Considerations

There is a trade-off in this proposal in terms of complexity / efficiency.
Notably, referring to types and components through strings as opposed to more
complex data structures may lead to less efficient code when needed for e.g.
comparisons. However, given the main use cases for this kind of construction
(e.g. logging purposes), this trade-off seems adequate.

# Prior art

# Future possibilities

- A new attribute 'From_String associated with a Root_Parser_Type could be
  introduced. Parsing is more complicated than just formatting values, and may
  deserve some additional design work.

- The Format parameter has been introduced to prepare for future extensions - its
  default semantics need to be defined.

- Interpolated strings (f"") should provide a way to easily associate a formatter
  and format parameters.

- Formatters for formats such as YAML, JSON and others can be provided to
  additional libraries.
