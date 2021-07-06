- Feature Name: (string_interpolation)
- Start Date: (2021-06-01)
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

Provide two new string literal syntaxes which support the use 
of "string interpolation," where the names of variables or parenthesized 
expressions can be used directly within the string literal, such that
the value of the variable or the expression is "interpolated" directly
into the value of the enclosing string upon use at run-time.  In addition,
an escape character ('\\') is provided for inserting certain standard control
characters (such as newline) or unicode characters within
the string literal.  The two string-literal syntaxes differ in that one is designed
for creating a string literal all on one line, while the other is designed
for producing multi-line string literals.

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

We propose two new string literal syntaxes:

- Single-line interpolated string literal using $" ... "$

- Multi-line interpolated string literal using $"" ... ""$

Within an interpolated string literal, the simple name of an object,
or a parenthesized expression, when preceded by $, is expanded at run-time
into the result of calling 'Image on the object or expression (trimmed of any leading or trailing whitespace).
In addition, control/special characters (or character sequences) such as newline or
tab can be included in the string literal using an escape sequence, where
the first character is the backslash ('\'), and the next character or characters
identifies the special character or character sequence of interest.

A simple example of string interpolation would be:

.. code-block:: ada

   $"The name is $Name and the sum is $(X + Y)."$
   
Now that Ada 2022 will have a general 'Image function, this becomes much more straightforward.
Expressions that are of type *_String or *_Character would be interpolated directly 
into the resulting string, while anything else would have the '*_Image attribute applied
(with any leading and trailing whitespace trimmed).

As exemplified, the value of simple identifiers can be inserted with $identifier,
while $(...) is used for expressions or more complex names.

For example:

.. code-block:: ada

  Put_Line
    ($"X = $X and Y = $Y and X+Y = $(X+Y);\n"$ &
     $" a dollar sign = \$ and"$ &
     $" quote is either "" or \" though \" would be preferred."$);

In some cases, the string will want to represent multiple lines of
text.  The use of "\n" and explicit concatenation can become tedious
and less readable when creating such a multi-line string.  For
such a situation, we propose the multi-line string literal notation,
using $"" at the end of a line to start the string and ""$ to terminate.  Unless escaped,
each newline separating two lines of the multi-line literal is included in the string represented
by the multi-line string literal.

For example:

.. code-block:: ada

  Put_Line
    ($""
     X = $X and Y = $Y and X+Y = $(X+Y);
      a dollar sign = \$ and quote is either "" or \" though \" would be preferred.
     ""$)

The multi-line string literal begins with a $"" at the end of a line.
The multi-line string literal ends upon encountering the sequence ""$, whether
it happens at the beginning of a line, or somewhere in the middle of a line.
In the latter case, the value of the string does not end with a newline character.

Note that multi-line string literals introduce the question of whether spaces at the 
beginning of a line of such a literal are significant.

Proposed approach:
Ignore spaces that appear at the beginning of every line of the multi-line literal.
Use an escaped space on at least one of the lines if every line is supposed
to start with one or more spaces.  So for example:

.. code-block:: ada

  Put_Line ($""
      This is indented relative to
    this line.  These lines are at
    the same level of indentation.
      And here we are indented again
    but again this line is not indented.
    ""$);

The above multi-line string literal represents a string that
has two spaces at the beginning of the first and fourth
lines, but no spaces at the beginning of the other three lines.  The last character of
the string represented by the above literal is a newline, because the same rule about
ignoring leading spaces applies to the terminating ""$.

If we want to consider more formatting options, it would seem we could allow additional parameters
within $(...), such as $(X+Y, Width => 13), but without changing the rules for the Put_Image
aspect, they would need to control simple "postprocessing" on the result of 'Image.  An alternative
would be to allow 'Image itself to take multiple parameters.  That would essentially mean that
the Put_Image "aspect" could be provided by a procedure that had additional, defaulted parameters,
which would become available for the 'Image attributes derived from Put_Image.

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

We have chosen to make the starting and ending sequences mirrors of each other
($" ... "$ and $"" ... ""$).  This seemed to match the mirror aspects of other
bracketing notations in Ada, such as (), <>, <<...>>, etc.

We have used '$' as both the indicator of the new string literal syntax, and
as the character inside the string to indicate the interpolation of a run-time value.
This seemed the most straightforward choice.

We have allowed the use of "$identifer" directly, and only require parentheses when
the name is more complex than a single identifier, or when there is an expression
to be displayed.  An alternative would be to allow "$X.Y.Z" but our concern is that
the period is a common punctuation mark, and it would be better to avoid any
possible confusion by requiring () for cases like $(X.Y.Z).

We have proposed to ignore spaces at the beginning of multi-line string literals,
so that the usual indentating conventions of the language can be obeyed,
rather than forcing multi-line string literals to be crowded against the left
margin.  Originally we had thought the first line of the multi-line literal
would establish the number of spaces to ignore on each line, but it didn't seem
appropriate to treat the first line specially.  So it is easy enough to look
at all of the lines of the string literal, and only ignore spaces that occur at
the beginning of all of them.

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
the string interpolation syntax has emerged as the favorite.  We do not want
to have lots of different syntaxes, so we have included the escape mechanism
as part of both of the new string literal syntaxes.  We have chosen '\\' as the
escape character, which has been embraced as the standard escape character
since C introduced it back in the early 70's.

Unresolved questions
====================

TBD

Future possibilities
====================

TBD
