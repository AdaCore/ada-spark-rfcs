- Feature Name: (string_interpolation)
- Start Date: (2021-06-01)
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

Provide a new string literal syntax which supports the use 
of "string interpolation," where the names of variables or
expressions can be used directly within the string literal, such that
the value of the variable or the expression is "interpolated" directly
into the value of the enclosing string upon use at run-time.  In addition,
an escape character ('\\') is provided for inserting certain standard control
characters (such as newline) or unicode characters within
the string literal.

Motivation
==========

For certain kinds of programs, a significant proportion of the code can be
devoted to string manipulation, producing strings to be used for output.
In such programs, the need to concatenate literal strings and strings
produced by 'Image or equivalent can produce verbose, hard-to-read source
code.  String interpolation is an alternative which makes the program
shorter, easier to read and understand, easier to maintain, etc.  Having to
explicitly write concatenations of string literals, special characters,
and the results of 'Image, is tedious, error prone, and obfuscates what the
program is trying to accomplish.

Guide-level explanation
=======================

We propose a new string literal syntax, for an "interpolated" string literal, using the following syntax

- {" ... "}

Within an interpolated string literal, the simple name of an object,
or an expression, when enclosed in { ... }, is expanded at run-time
into the result of calling 'Image on the object or expression (trimmed of a leading space if the second character is a digit).
In addition, control/special characters (or character sequences) such as newline or
tab can be included in the string literal using an escape sequence, where
the first character is the backslash ('\\'), and the next character or characters
identifies the special character or character sequence of interest.

A simple example of string interpolation would be:

.. code-block:: ada

   {"The name is {Name} and the sum is {X + Y}."}
   
Now that Ada 2022 will have a general 'Image function, this becomes much more straightforward.
Expressions that are of a string type or a character type would be interpolated directly 
into the resulting string, while anything else would have the '*_Image attribute applied.
Because Ada established the convention of putting a space in front of the 'Image of
non-negative integers, we drop a leading blank if it is followed immediately by a digit.

As exemplified, the value of simple identifiers, more complex names, or expressions can all be inserted with { ... }.

For example:

.. code-block:: ada

  Put_Line
    ({"X = {X} and Y = {Y} and X+Y = {X+Y};\n"} &
     {" an open brace = \{ and"} &
     {" quote is either "" or \" though \" would be preferred."});


One question is how these new kinds of string literals would interact with the Ada 2022 String_Literal
aspect, which allows a user-defined type to support the use of string literals for values
of types other than a string type.
Our proposal would be for all string interpolation and character escaping to occur first,
to produce a Wide_Wide_String, which is then handed off to the user's String_Literal function,
to be converted into a value of the user-defined type.

Reference-level explanation
===========================

TBD

Rationale and alternatives
==========================

As indicated in the motivation section, the main goal is to provide a clearer,
easier to read, less error-prone approach to creating strings for output.

We propose using {" ... "} to bracket the string literal as a whole, and { ... } for each internal interpolation.
Other alternatives considered were starting with $" and using $(...) as the interpolation indicator, or
starting with F" and using { ... } internally.  In the case using $", we
also considered using "$ to end an interpolated string literal, to maintain the
normal mirroring of bracketing notations in Ada (such as << ... >> and ( ... )).

We ultimately chose the {" ... "} as the syntax for an interpolated string literal is that it would preserve
the mirroring, and means that { ... } become the general indicators of the use of string interpolation.

The alternative F" ... " syntax is the same as or similar to what some other languages do, but is a bit
unusual for Ada in its use of a delimiter starting with a normal letter.  This syntax probably originated
in C's use of modifiers on the syntax of literals to give indications of their type (e.g. in C/C++, 26L is
a long integer, L'z' is a wide character literal, u8"..." is a UTF8 string literal, etc.).  Ada has chosen
to use context to determine type, while distinct syntax based on special-character delimiters or reserved
words is used to
convey syntactically and semantically distinct
constructs.

If we want to consider more formatting options, it would seem we could allow additional parameters
within {...}, such as {X+Y, Width => 13}, but without changing the rules for the Put_Image
aspect, they would need to control simple "postprocessing" on the result of 'Image.  An alternative
would be to allow 'Image itself to take multiple parameters.  That would essentially mean that
the Put_Image "aspect" could be provided by a procedure that had additional, defaulted parameters,
which would become available for the 'Image attributes derived from Put_Image.

We originally included a multi-line string literal possibility.  One complexity with multi-line string literals
is whether or not spaces at the beginning of the literal are included within the resulting string.  The proposed {" ... "} syntax can provide
a nice solution to this, where a multi-line string literal would simply have a single set of braces, but multiple quoted strings.  E.g.:

.. code-block:: ada

   {"This is a multi-line"
    "string literal"
    "There is no ambiguity about how many"
    "spaces are included in each line"}

with the ultimate string value being the strings on each line concatenated with a standard newline indicator between them.

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

- It is still not completely resolved how to combine the Ada convention of preceding the 'Image of a nonnegative numeric literal with a space.  Here we propose to recognize the case of the result of 'Image starting with <blank><digit> and remove the <blank>.  We base it on the result of 'Image, because "big" numbers and other "private" types that are intended to be used as numbers (such as types that provide saturation semantics) might very well continue the tradition of inserting a space in the beginning of their 'Image when the value is nonnegative.

- A somewhat simpler rule is to trim both leading and trailing spaces, with the argument that the extra spaces were probably included in 'Image for stand-alone formatting concerns, but are not helpful when the result of 'Image is being interpolated into a surrounding context.

- Whether to use doubling rather than an escape character within these strings to allow the nested use of {, }, and ".  One argument in favor of backslash is that it supports common control characters such as tab and newline without reverting to the potentially more obscure and somewhat dated {ASCII.HT} or {ASCII.LF}. It also allows the user to not worry about which characters are supposed to be doubled and which are not -- e.g. should we double "}" -- not strictly necessary, and what about single quote.

- Whether to support a multi-line syntax.  With the current {" ... "} syntax there is a somewhat obvious generalization that would support multi-line strings, as proposed above.

Future possibilities
====================

TBD
