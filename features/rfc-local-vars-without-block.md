- Feature Name: Local_Vars_Without_Block
- Start Date: 2021-11-02
- Status: Production

Summary
=======

A basic_declarative_item may appear at the place of any statement.  Such declarations are not visible within any exception handler associated
with the enclosing construct.  A goto may not jump into the scope of such a declaration from outside its scope.

Motivation
==========

It is generally good practice to declare local variables (or constants) with as short a lifetime as possible.
However, introducing a declare block to accomplish this is a relatively heavy syntactic load along with a traditional extra level of indentation
This RFC is proposing to support interspersing basic_declarative_items within sequences of statements.  We considered a more limited
mechanism where declarations could only appear at the beginning of a sequence of statements, separated from the statements by a reserved
word such as "in", but we have chosen to go to the more flexible approach.

Guide-level explanation
=======================

We propose to allow any basic_declarative_item to appear at the place of any statement. 

For example:

    if X > 5 then
       X := X + 1;
       
       Squared : constant Integer := X**2;
       
       X := X + Squared;
    else
       X := X - 1;
       
       Cubed : constant Integer := X**3;

       X := X + Cubed;
    end if;
       
If the enclosing construct allows a handler
(such as an accept statement or a subprogram body), declarations that appear at the place of a statement are *not* visible within
the handler.  Only declarations that precede a "begin" would be visible in the corresponding exception handler.

Reference-level explanation
===========================

Syntax:

Include basic_declarative_item as an additional case for a simple_statement in
5.1(4/2):

    simple_statement ::= ... | basic_declarative_item

Semantics:

The scope of an entity declared by a basic_declarative_item that is in the place of
a statement extends to the end of the associated sequence_of_statements, but does *not* include the handler
part of a handled_sequence_of_statements.  From a legality point of view, a goto statement may not go
to a label that is within the scope of such a variable, if the goto statement itself is not also within the
scope of the varaible.

Declarations that are in the place of a statement are equivalent to transforming the remainder of
the sequence_of_statements starting at the basic_declarative_item into a declare block, with the declarative_item and any
declarative_items that
follow it immediately as the declarative_part, and the remainder of the sequence_of_statements (not including the
handler, if any) as the sequence_of_statements of the declare block.  The handler, if any, remains part of the enclosing
construct in this transformation.

Rationale and alternatives
==========================

The main goal is to allow variables and constants to be declared with as short of a lifetime
as possible, to minimize the amount of code that needs to be considered when analyzing whether
a given variable is used properly.

We considered allowing (or requiring) a reserved word such as "in" to act as a separator between declarations and statements.
But since this is not strictly necessary from a syntax point of view, we chose to go with the simpler and more flexible approach.
Note that having such a separator would be useful for cases where the declarations are part of
a handled_sequence_of_statements, as it would separate declarations that are visible in
the handlers, from those that are only visible within the statements.

Drawbacks
=========

Readability is one concern, but it is arguable that the current rules are worse from a readability
point of view, as they tend to lead to overly
indented source code, or perhaps even worse, to local variables being declared with a longer
lifetime than they need, making it harder to understand the role the variable might be playing
in the large amount of code where it is visible.

A project could presumably choose to control use of this feature, either by disallowing its use
altogether, or limiting usage to cases where the declarations appear only at the beginning of the
sequence of statements.

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
a follow-on RFC, though at that time it might be worth allowing the use of a separator such as the
"in" reserved word to demarcate which declarations are visible within the handlers, from the statements
and declarations whose exceptions are being handled.
