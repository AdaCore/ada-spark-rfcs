- Feature Name: empty_parentheses_for_function_call
- Start Date: 2019-01-09
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

Function calls with no arguments in Ada are not syntactically distinguishable
from reads of a variable, which impairs readability. We propose to allow using
the empty parentheses "()" after the name of a function without parameters to
denote a call without arguments.

Motivation
==========

Because a function call can have side-effects, including the possibility to
fail for various reasons, it's important to be able to distinguish a function
call from a read of a variable.

For example, we'd like to distinguish these cases on the following example:

   X := Var + Func;

For symmetry between procedure calls and function calls without arguments, Ada
mandates that function calls without arguments are represented syntactically by
the function name without parentheses.

We propose to allow the empty parentheses "()" after the function name in a
call without arguments, as in:

   X := Var + Func();

As additional benefit, this makes Ada syntax easier to understand for the
majority of programmers, as it is much more common to have empty parentheses to
denote function calls without arguments.

Guide-level explanation
=======================

The proposed change is a minor syntactic addition whose only effect is to
increase readability of code.

Reference-level explanation
===========================

There are no expected interactions with other features of Ada.

The implementation would simply consist in changes to the parser to allow the
new syntax.

Rationale and alternatives
==========================

This proposal goes in the direction of increased readability, which is a main
goal in Ada.

The impact is minimal.

Drawbacks
=========

- This alternative syntax for function calls makes it different to call a
  procedure without parameters (where no parentheses would be used) or to call
  a function without parameters (where the empty parenthese would be allowed).

Prior art
=========

Most languages use empty parentheses to denote an empty list of arguments.

Unresolved questions
====================

- Is this proposed syntax extension important enough to be implemented?

- Should we allow empty parentheses also for procedure calls without
  parameters?

Future possibilities
====================

In the same spirit of increased readability, it could be possible to
distinguish array accesses, function calls and type conversions, which are
displayed similarly in Ada, as in:

   X := Arr(1) + Func(1) + Conv(1);
