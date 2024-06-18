- Feature Name: (string_interpolation)
- Start Date: (2021-06-01)
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

## Summary

Provide a new string literal syntax which supports the use
of "string interpolation," where the names of variables or
expressions can be used directly within the string literal, such that
the value of the variable or the expression is "interpolated" directly
into the value of the enclosing string upon use at run-time.  In addition,
an escape character (`\\`) is provided for inserting certain standard control
characters (such as newline) or to escape characters with special significance
to the interpolated string syntax, namely `"`,`{`, `}`,and `\\` itself.
Finally, a syntax is provided for creating multi-line string literals, without
having to explicitly use an escape sequence such as `\\n`.

## Motivation

For certain kinds of programs, a significant proportion of the code can be
devoted to string manipulation, producing strings to be used for output. In
such programs, the need to concatenate literal strings and strings produced by
`'Image` or equivalent can produce verbose, hard-to-read source code.

String interpolation is an alternative which makes the program shorter, easier
to read and understand, easier to maintain, etc.  Having to explicitly write
concatenations of string literals, special characters, and the results of
`'Image`, is tedious, error prone, and obfuscates what the program is trying to
accomplish.

## Guide-level explanation

We propose a new string literal syntax, for an "interpolated" string literal,
using the following syntax

```ada
f" ... "
```

Within an interpolated string literal, an arbitrary expression, when enclosed
in `{ ... }`, is expanded at run-time into the result of calling `'Image` on
the result of evaluating the expression (trimmed of a leading space if the type
is numeric-ish -- see below), unless it is already a string or a single
character.

In addition, control/special characters (or character sequences) such as
newline or tab can be included in the string literal using an escape sequence,
where the first character is the backslash (`\\`), and the next character or
characters identifies the special character or character sequence of interest.

Note that unlike normal string literals, doubled characters have no special
significance.  So to include a double-quote or a brace character in an
interpolated string, they must be preceded by a `\\`.

A simple example of string interpolation would be:

```ada
f"The name is {Name} and the sum is {X + Y}."
```

Now that Ada 2022 will have a general `'Image` function, this becomes much more
straightforward.

Expressions that are of a string type or a character type, but without a
user-specified `Put_Image` aspect, would be interpolated directly into the
resulting string, while anything else would have the `'*_Image` attribute
applied.

Because Ada established the convention of putting a space in front of the
`'Image` of non-negative integers, we drop a leading blank if the type is
numeric, or has an `Integer_Literal` or `Real_Literal` aspect.

As exemplified, values defined by simple identifiers, more complex names, or
expressions can all be inserted with { ... }.

For example:

```ada
Put_Line
  (f"X = {X} and Y = {Y} and X+Y = {X+Y};\n" &
   f" a double quote is \" and" &
   f" an open brace is \{");
```

One issue is how these new kinds of string literals would interact with the Ada
2022 `String_Literal` aspect, which allows a user-defined type to support the use
of string literals for values of types other than a string type.

Our proposal is that all string interpolation, line concatenation, and
character escaping occurs first, to produce a `Wide_Wide_String`, which is then
handed off to the user's `String_Literal` function, to be converted into a
value of the user-defined type.

## Reference-level explanation

Syntax:

```bnf
interpolated_string_literal ::=
   'f' "{interpolated_string_element}"

interpolated_string_element ::=
    escaped_character | interpolated_expression
  | non_quotation_mark_non_left_brace-graphic_character

escaped_character ::= '\graphic_character'

interpolated_expression ::= '{' expression '}'
```

### Name resolution

The expected type for an `interpolated_string_literal` shall be a single string
type or a type with a specified `String_Literal` aspect (see 4.2.1). In either
case, the `interpolated_string_literal` is interpreted to be of its expected
type. The expression of an `interpolated_expression` can be of any type.

### Legality rules

The graphic character of an `escaped_character` shall be one of the following
characters:

```
'a', 'b', 'f', 'n', 'r', 't', 'v', '0', '\\', '"', '{', '}'
```

### Static semantics

An `escaped_character` either represents the given `graphic_character`, or, in
the following cases, it represents a control character determined by the
`graphic_character`:

| escaped_character | meaning               |
| ----------------- | --------------------- |
| `'\\a'`           |  ALERT                |
| `'\\b'`           |  BACKSPACE            |
| `'\\f'`           |  FORM FEED            |
| `'\\n'`           |  LINE FEED            |
| `'\\r'`           |  CARRIAGE RETURN      |
| `'\\t'`           |  CHARACTER TABULATION |
| `'\\v'`           |  LINE TABULATION      |
| `'\\0'`           |  NUL                  |
| ----------------- | --------------------- |
| `'\\\\'`          |  `'\\'`               |
| `'\\"'`           |  `'"'`                |
| `'\\{'`           |  `'{'`                |
| `'\\}'`           |  `'}'`                |
| ================= | ===================== |

### Legality Rules

If the expected type is a single string type, then each of the
`graphic_characters`, other than escaped characters that are interpreted as
control characters, shall correspond to character literals of the component
type of the string type.

If any escaped characters interpreted as control characters appear in the
string, then the expected type shall be a type with a specified
`String_Literal` aspect, or have a component type that is descended from one of
the character types declared in package Standard (since these are the only
character types that permit control characters).

### Dynamic semantics

The evaluation of an `interpolated_string_literal` begins with the creation of
a text buffer of a type descended from `Strings.Text_Buffers.Root_Buffer_Type`
(see A.4.12), followed by a sequence of procedure invocations as determined by
the sequence of `interpolated_string_elements` appearing in the
`interpolated_string_literal`, as follows:

- When one or more elements that are not `interpolated_expressions` are
  encountered in the sequence: A `Wide_Wide_String` formed from the
  corresponding `Wide_Wide_Characters` is added to the text buffer using
  `Wide_Wide_Put`;

- When an `interpolated_expression` is encountered, the expression is
  evaluated, and then:

   * If the type of the expression has a user-specified `Put_Image` aspect, or
     if the type is not itself a string or character type none of whose
         enumeration literals are identifiers, then the `Put_Image` attribute
         procedure of the type is invoked, with actual parameters being the
         buffer created earlier and the result of evaluating the expression;

   * If the type is numeric or has a specified `Integer_Literal` or
     `Real_Literal` aspect, then prior to invoking `Put_Image`, the
     `Trim_White_Space` flag (see below) is set on the text buffer;

   * If the type of the expression is a string or character type none of whose
     enumeration literals are identifiers, then the individual characters of
     the result of evaluating the expression are converted to the corresponding
     `Wide_Wide_Character`, and added to the text buffer using `Wide_Wide_Put`;

- Once all pieces have been processed, the `Wide_Wide_Get` function of the text
  buffer is invoked which returns a `Wide_Wide_String`, which is used as
  follows:

   - If the expected type is `Wide_Wide_String`, then this is the result.

   - If the expected type has a `String_Literal` aspect, then this result is
     passed to the function identified by the `String_Literal` aspect, to
     produce the value of the expected type.

   - Otherwise, the result of calling the `Wide_Wide_Get` function is mapped
     character by character to a value of the expected string type, checking
     that each mapped character belongs to the component subtype of the string
     type, with the low bound of the resulting string being the low bound of
     the index subtype of the string type, and checking that the high bound of
     the result is within the index subtype of the string type.

Universal Text Buffers are updated to include a `Trim_White_Space` flag which
can be set prior to calling any of the Put operations, which will cause white
space characters to be discarded by any Put operation until a non-white-space
character is encountered, at which point the flag will be reset.

Rationale and alternatives
==========================

> NOTE: This documents the rationale for the legacy syntax choice, that has now
> been subsumed. Keeping that here for history.
>
> The f"syntax" has been chosen, originally to avoid possible clashes with the
> use of `{` and `}` for data structure literals (like sets and maps in Python,
> or struct literals in C/C++)
>
> The multi-line feature has been removed, because what was unforeseen at the
> time is that this adds context sensitive lexing being a requirement, so old
> style strings containing {} are not wrongly interpreted as containing
> interpolated expressions.

As indicated in the motivation section, the main goal is to provide a clearer,
easier to read, less error-prone approach to creating strings for output.

We propose using {" ... "} to bracket the string literal as a whole, and { ...
} for each internal interpolation. Other alternatives considered were starting
with $" and using $(...) as the interpolation indicator, or starting with F"
and using { ... } internally.  In the case using $", we also considered using
"$ to end an interpolated string literal, to maintain the normal mirroring of
bracketing notations in Ada (such as << ... >> and ( ... )).

We ultimately chose the {" ... "} as the syntax for an interpolated string
literal is that it would preserve the mirroring, and means that the brace
characters '{' and '}' become the general indicators of the use of string
interpolation.

The alternative F" ... " syntax is the same as or similar to what some other
languages do, but is a bit unusual for Ada in its use of a delimiter starting
with a normal letter.  This syntax probably originated in C's use of modifiers
on the syntax of literals to give indications of their type (e.g. in C/C++, 26L
is a long integer, L'z' is a wide character literal, u8"..." is a UTF8 string
literal, etc.).  Ada has chosen to use context to determine type, while
distinct syntax based on special-character delimiters or reserved words is used
to convey syntactically and semantically distinct constructs.

If we want to consider more formatting options, it would seem we could allow
additional parameters within {...}, such as {X+Y, Width => 13}, but without
changing the rules for the Put_Image aspect, they would need to control simple
"postprocessing" on the result of 'Image.  An alternative would be to allow
'Image itself to take multiple parameters.  That would essentially mean that
the Put_Image "aspect" could be provided by a procedure that had additional,
defaulted parameters, which would become available for the 'Image attributes
derived from Put_Image.

We debated whether to include a multi-line string literal possibility, and
ultimately decided to include it, because the {"..."} syntax provided a natural
mechanism for doing so.  We avoid one complexity associated with multi-line
string literals where it is not always clear how many spaces at the beginning
of each line of the literal are included within the resulting string. The {"
... "} syntax provides a nice solution to this, since a multi-line string
literal would simply have a single set of braces, but multiple quoted strings.

Drawbacks
=========

Hopefully the semantics will be fairly intuitive, but this is certainly
adding complexity to string literals.  Programmers who get used to the features
of this extended syntax may find themselves using the features in the "normal"
string literal which could lead to surprises.

Prior art
=========

String interpolation has begun to show up in many languages.  Python has a number
of string literal syntaxes, chosen by a prefix letter, but our sense is that
the string interpolation syntax has emerged as the favorite.

We do not want
to have lots of different syntaxes, so we have included the more general
escape mechanism
as part of this new string literal syntax.  We have chosen '\\' as the
escape character, which has been embraced as the standard escape character
in C and most C-inspired languages, and more widely in Unix and Unix-like systems.

Unresolved questions
====================

We have not discussed how best to represent arbitrary unicode characters.

Future possibilities
====================

The '\\' escape character might also be used to introduce arbitrary unicode
characters.  In C, '\\u####' is used for characters in the 16-bit unicode BMP,
and '\\U########' is used for arbitrary unicode characters.
