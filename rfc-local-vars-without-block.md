- Feature Name: Local_Vars_Without_Block
- Start Date: 2021-11-02
- RFC PR:
- RFC Issue:

Summary
=======

Local variables may be declared within a part of a compound statement without introducing a full declare block.
The declarations may, but need not, be separated from the statements with an "in" reserved word.  In the absence
of the "in" separator, the declarations may be interspersed arbitrarily with the statements.

Motivation
==========

It is generally good practice to declare local variables (or constants) with as short a lifetime as possible.
However, introducing a declare block to accomplish this is a relatively heavy syntactic load along with a traditional extra level of indentation
This RFC is proposing to support local variable declarations without this extra syntactic load, by eliminating the "declare" and "end" reserved words
(and the extra level of indentation) and optionally use the reserved word "in" as a separator
between the declarations and the statements.  We would expect that in a typical
source-code format, the "in" would be outdented somewhat, but not necessarily all the way to the level of the enclosing compound statement,
so the "in" would, say, line up with, or be close to the indentation of, the "if" and the "end if", while the local declarations and statements
would be indented just one level relative to the "if" and "end if."

Guide-level explanation
=======================

In any arm of a compound statement, such an if/then/elsif statement, or a case/when statement, or a for/loop statement
one or more local declarations may be introduced, followed by "in" followed by the sequence of statements.

For example:

    if X > 5 then
       Squared : constant Integer := X**2;
     in
       X := X + Squared;
    else
       Cubed : constant Integer := X**3;
     in
       X := X + Cubed;
    end if;
       
Syntactically, this would mean that most places where the language currently allows a sequence_of_statements,
we would now allow an optional non-empty list of basic_declarative_item followed by "begin", followed by the
(non-optional) sequence_of_statements.  This option would not be provided in constructs where the sequence_of_statements
is already preceded by "begin", such as the sequence_of_statements of a subprogram body or a declare block.

Reference-level explanation
===========================

Syntax:

Replace "sequence_of_statements" with:

      [local_declarative_part
    in]
       sequence_of_statements
      
in the following constructs:

     abortable_part 9.7.4
     accept_alternative 9.7.1
     case_statement_alternative 5.4
     conditional_entry_call 9.7.3
     delay_alternative 9.7.1
     entry_call_alternative 9.7.2
     exception_handler 11.2
     if_statement 5.3
     loop_statement 5.5
     parallel_block_statement 5.6.1
     selective_accept 9.7.1
     triggering_alternative 9.7.4

Replace "handled_sequence_of_statements" with

      [local_declarative_part
    in]
       handled_sequence_of_statements
       
in accept_statement 9.5.2

local_declarative_part would be defined as follows:

    local_declarative_part ::= basic_declarative_item {basic_declarative_item}

Semantics:

From a static semantics point of view, the scope of an entity declared in a local_declarative_part
extends from the beginning of its declaration to the end of the associated sequence_of_statements
(or handled_sequence_of_statements in the accept_statement case).

From a dynamic semantics point of view, providing a local_declarative_part is entirely equivalent to introducing a
declare block as the only statement in the original (handled_)sequence_of_statements,
with a corresponding declarative_part and (handled_)sequence_of_statements.

Rationale and alternatives
==========================

The main goal is to allow variables and constants to be declared with as short of a lifetime
as possible, to minimize the amount of code that needs to be considered when analyzing whether
a given variable is used properly.

We have chosen to allow an "in" reserved word as a separator between declarations and statements.
That is not strictly necessary from a syntax point of view, but we felt it was useful from
a readability point of view.

Drawbacks
=========

Readability is one concern, but it is arguable that the current rules are worse from a readability
point of view, as they tend to lead to overly
indented source code, or perhaps even worse, to local variables being declared with a longer
lifetime than they need, making it harder to understand the role the variable might be playing
in the large amount of code where it is visible.

Prior art
=========

Many C-inspired languages these days allow declarations immediately following the open
brace, and some allow interspersing declarations and statements freely.  Very few require
any sort of heavy syntax to introduce a "very local" declaration.

Unresolved questions
====================

Currently we are proposing to allow only "basic" declarative
items in these contexts, so nested bodies are not allowed.  Subprogram declarations are allowed, but
only if they are defined by an expression function, an import, or an instantiation.
One could argue that arbitrary
declarations and bodies should be permitted.
Alternatively, we could restrict it to only object declarations and use clauses, and no type declarations
and no subprogram declarations.
We have selected "basic_declarative_item" as this is already a well defined subset of all kinds of
declarations that is used for package specs, and so is familiar to the programmer and doesn't require
a newly selected subset.

Clearly, the programmer can always fall back to using a local declare block for more complex requirements,
though of course this is pushing more levels of indendatation on the more complex cases.

Future possibilities
====================

Obvious extensions would be to allow exception handlers in all these contexts, and to allow arbitrary
declarations.  We discuss the issue of arbitrary declarations above.  As far as exception handlers,
there seems no particular reason to disallow them, and they should perhaps be considered as part of
this RFC, or an immediate follow-on RFC.
