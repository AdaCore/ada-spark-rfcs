- Feature Name: SPARK_Mode with static Boolean expressions
- Start Date: 2026-07-31
- Status: Design

Summary
=======

This RFC aims to extend the `SPARK_Mode` aspect and pragma so that, in addition
to the identifiers `On`, `Off` and `Auto`, it accepts static Boolean
expressions. Placement, inheritance and consistency rules are unchanged.

Motivation
==========

Clients of SPARKlib, and more generally clients of SPARK libraries with
generics, usually don't want to prove the code of the generic. But from the
SPARK point of view, the code is part of the unit where it is instantiated, so
it will be proved by gnatprove.

The commonly used solution is to move the private part and package body of the
generic package (or the body of a generic subprogram) behind SPARK_Mode => Off.

But developers of the library in question want to prove the generic using a
sufficiently general instantiation. This proof needs the body of the package
(`Lib` in the example) to be under SPARK_Mode => On. With the SPARK_Mode pragma
as it stands today, this conflict can only be resolved with conditional
compilation that duplicates a lot of code, or preprocessing.

Guide-level explanation
=======================

Wherever `SPARK_Mode => On` or `SPARK_Mode => Off` is allowed, one can also
write a static Boolean expression, with `True` being equivalent to `On` and
`False` being equivalent to `Off`. This notably allows library developers to
condition the SPARK status of an entity, such as the body of a generic package,
on a separate configuration package:

```
package Configuration is
   Prove_Lib : constant Boolean := True;
end Configuration;

generic
   ...
package Lib with SPARK_Mode => True is

   ...

private
   pragma SPARK_Mode (Configuration.Prove_Lib);
   ...
end Lib;

package body Lib with SPARK_Mode => Configuration.Prove_Lib is
   ...
end Lib;
```

In the above case, the configuration package sets the Boolean `Prove_Lib` to
`True`, which means the package spec, private part and body are all in SPARK.
Via conditional compilation, e.g. using scenario variables, a different body can
be provided for the `Configuration` package, setting `Prove_Lib` to `False`.

In practice this feature allows users to enable or disable SPARK_Mode for
certain sections of the code without duplicating them.

Reference-level explanation
===========================

```
  pragma SPARK_Mode [(On | Off | Auto | static_boolean_EXPRESSION)];
```

Placement, inheritance and consistency rules are unchanged. The identifiers
`On`, `Off` and `Auto` remain identifiers specific to the pragma/aspect, and
keep their current meaning. Any other argument must be a static Boolean
expression; `True` is equivalent to `On` and `False` is equivalent to `Off`.

The names `On`, `Off` and `Auto` are resolved as follows, mirroring the rule
that the ARM already uses for the `Default_Storage_Pool` aspect (ARM 13.11.3):
an argument that is one of these identifiers is illegal if a declaration with
that defining identifier is directly visible at that point (13.11.3(4.1/4)
and 13.11.3(5.1/4) for `Standard`); any other argument is resolved normally
(13.11.3(5.2/5)).

Rationale and alternatives
==========================

Without this new feature, the workaround is either preprocessing (SPARKlib does
that), or duplicating, via conditional compilation, the entire spec and body of
package `Lib` in the example. This is inconvenient if the package is large, if
there are many packages that require similar treatment, or both.

Note that the rule is stated in terms of direct visibility, which covers both
immediate visibility and use-visibility, whereas the ARM rule for `Standard`
only needs to mention immediate visibility: a declaration named `Standard`
cannot become use-visible, since package `Standard` always hides it. For `On`,
`Off` and `Auto` there is no such protection, and use-visibility is in fact the
most likely way for such a declaration to become directly visible; the potential
for confusion is the same in that case, so both forms of visibility make the
argument illegal.

The main alternative we considered was to introduce a separate aspect and
pragma, `SPARK_Mode_Enabled`, with the same placement, inheritance and
consistency rules as `SPARK_Mode`, but taking a mandatory static Boolean
expression and giving no special meaning to `On`, `Off` and `Auto`. The
motivation for that alternative was the concern that, in an extended
`SPARK_Mode`, the names `On`, `Off` and `Auto` could also denote user-declared
static Booleans, making the argument ambiguous. We rejected it because it adds
a second aspect and pragma that duplicates an existing one, and because the
ambiguity concern is already solved in Ada.

Regarding the ambiguity concern, the ARM already addresses this for
[Default_Storage_Pool](https://docs.adacore.com/live/wave/arm22/html/arm22/arm22-13-11-3.html).
`Standard` is an identifier specific to the pragma/aspect, and it is illegal if
a declaration with that defining identifier is immediately visible at that point
(see 4.1/4 and 5.1/4); anything else is resolved normally (5.2/5). The same rule
can be transposed directly to `SPARK_Mode` for `On`, `Off` and `Auto`, using
direct visibility instead of immediate visibility.

Two other ways of resolving the ambiguity were considered:

- Make `On`, `Off` and `Auto` always denote the mode, regardless of whether a
  declaration with that identifier is visible at that point. This silently
  hides the user's declaration instead of flagging the conflict, and it
  diverges from the rule Ada already uses in the same situation. The chosen
  solution is superior on both counts.
- Add a configuration pragma that switches `SPARK_Mode` between two modes, one
  accepting only `On`/`Off`/`Auto` and the other accepting only static Boolean
  expressions. This introduces yet another pragma, and it is potentially
  inflexible, as the two forms could no longer be mixed within the scope of the
  configuration pragma.

Drawbacks
=========

It changes the meaning of a program that declares a directly visible object named
`On`, `Off` or `Auto` and uses it as the argument of `SPARK_Mode`: such a use
becomes illegal instead of denoting the mode. This is expected to be rare, and is
the same trade-off the ARM already accepts for
`Default_Storage_Pool`. Where it does occur, `True` and `False` are available as
replacements for `On` and `Off`.

Prior art
=========

`Default_Storage_Pool` (ARM 13.11.3) combines an identifier specific to the
aspect (`Standard`) with an argument that is otherwise resolved normally, and
provides the visibility rule that removes the ambiguity.
