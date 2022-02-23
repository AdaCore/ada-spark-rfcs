- Feature Name: SPARK function out parameters
- Start Date: 2022-02-23
- RFC PR: #89
- RFC Issue: (leave this empty)

Summary
=======

Functions with out and in-out parameters (but no other side-effects through
global variables) would be allowed in SPARK, but calls to these functions would
only be allowed as the expression of an assignment statement.

Motivation
==========

Functions with side-effects are not allowed in SPARK, so that they can have a
direct interpretation as mathematical functions and be called inside
expressions without having to worry about order of side-effects. Thus, Ada
functions with out or in-out parameters:

```ada
function Update_And_Return (X : in out T) return Status;
```

need to be rewritten into SPARK procedures:

```ada
procedure Update_And_Return (X : in out T; Result : out Status);
```

This requires rewriting function calls:

```ada
S : Status := Update_And_Return (X);
```

into procedure calls:

```ada
declare
  S : Status;
begin
  Update_And_Return (X, S);
end;
```

This evolution would allow functions with out and in-out parameters in SPARK,
provided they are called directly as the expression of an assignment statement,
like above, but not in more complex expressions (and certainly not in
assertions as a result).

Guide-level explanation
=======================

Functions with side-effects are allowed in SPARK, subject to restrictions on
calls to these functions. Such functions can have out or in-out parameters, but
cannot write (directly or indirectly) into variables from enclosing scopes,
meaning that their Global contract in SPARK is ``null``.

Calls to such functions are only allowed as the expression of an assignment
statement. This ensures that there cannot be different side-effects resulting
from the choice of order of evaluation of expressions.

In terms of implementation in GNATprove, calls to such functions should be
treated like procedure calls.

Reference-level explanation
===========================

The changes are located in chapter 6 of the SPARK Reference Manual.

After this sentence in 6.1:
> Rules are imposed in SPARK to ensure that the execution of a function call
> does not modify any variables declared outside of the function. It follows as
> a consequence of these rules that the evaluation of any SPARK expression is
> side-effect free.
add:
> Rules are imposed in SPARK to ensure that the execution of a function call
> does not modify any variables declared outside of the function.
> Functions with out and in-out parameters are treated like procedures,
> and calls to these functions are restricted to the expression inside
> an assignment statement. Such a function is said to be a procedural function.
> Outside of this special case, it follows as a consequence of these rules
> that the evaluation of any SPARK expression is side-effect free.

Change legality rule 6.1(6):
> A function declaration shall not have a parameter_specification with a mode
> of out or in out. This rule also applies to a subprogram_body for a function
> for which no explicit declaration is given. A function shall have no outputs
> other than its result.
into:
> A function shall have no outputs other than its result and its parameters of
> mode out or in out. [Function parameters of mode in (including of access type)
> are not outputs. Note that access parameters are of mode in too.]

Change static semantics rule 6.1.5(21):
> A function without an explicit Depends aspect specification has the default
> dependency_relation that its result is dependent on all of its
> inputs. [Generally an explicit Depends aspect is not required for a function
> declaration.]
to:
> A function without an explicit Depends aspect specification has the default
> dependency_relation that its outputs (its result and its parameters of mode
> out and in out) are dependent on all of its inputs. [Generally an explicit
> Depends aspect is not required for a nonprocedural function declaration,
> as its only output is the function result.]

Change this sentence in 6.4.2:
> A function is not allowed to have side-effects and cannot update an actual
> parameter or global variable. Therefore, function calls cannot introduce
> aliasing and are excluded from the anti-aliasing rules given below for
> procedure or entry calls.
into:
> A nonprocedural function is not allowed to have side-effects and cannot
> update an actual parameter or global variable. Therefore, nonprocedural
> function calls cannot introduce aliasing and are excluded from the
> anti-aliasing rules given below for procedural function, procedure or entry
> calls.

Add a verification rule in 6.4.2, similar to the existing one for procedure and
entry calls in 6.4.2(3):
> A procedural function call shall only pass two actual parameters which
> potentially introduce aliasing via parameter passing when either:
>  - both of the corresponding formal parameters are of mode in; or
>  - at least one of the corresponding formal parameters is immutable and is of
>    a by-copy type. [Note that this includes parameters of named
>    access-to-constant and (named or anonymous) access-to-subprograms
>    types. Ownership rules prevent other problematic aliasing, see section
>    Access Types.]

Add a verification rule in 6.4.2, similar to the existing one for procedure and
entry calls in 6.4.2(4):
> If an actual parameter in a procedural function call and a global_item
> referenced by the called procedural function potentially introduce aliasing
> via parameter passing, then the corresponding formal parameter shall be
> of mode in.

Add a legality rule in 6.8 regarding expression functions:
> An expression function should not be also a procedural function. [An expression
> function should not have parameters of mode out or in out.]

Rationale and alternatives
==========================

Allowing functions to have out and in out parameters allows for more natural
translation / bindings from C, rather than introducing a procedure. This is also
the only way to write a subprogram having more than one output, one of which has
indefinite type (e.g. type ``String``), without introducing access types.

Drawbacks
=========

On the one side, introducing procedural functions means that not all functions
in SPARK are free of side-effects. On the other side, SPARK already supports
volatile functions (with aspect ``Volatile_Function``) which have side-effects
through reading effectively volatile objects (but still cannot have outputs
other than their result).

Prior art
=========

Volatile functions are another special-case for functions with some
side-effects that was previously introduced in SPARK.

Other verification-oriented programming languages do not have the same
distinction between procedures and functions that exists in SPARK, so did not
have to come up with procedural functions.

Unresolved questions
====================

- Are all consequences of the introduction of procedural functions described in
  the reference-level explanation?

Future possibilities
====================

It could be possible in the future to accept side-effects on variables in the
enclosing scope of a procedural function, i.e., that a procedural function
could have a Global contract different from ``null``.
