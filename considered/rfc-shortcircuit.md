- Feature Name: short circuit
- Start Date: 2022-08-12
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

This RFC aims to make binary operator `and` and `or` shortcircuit by default,
deprecating their `and then` and `or else` forms.

Motivation
==========

Boolean operators `and` and `or` are most useful in their short circuit form.
While there are some cases where it's useful to inconditionally evaluate both
operands, most of the time the right operand only needs to be evaluated if
the left is already done. Forcing shorcircuit to be written `and then` and
`or else` is adding unecessary verbosity to the language. Moreover, mistakes
can lead to either inefficient code, or be cause of bugs if the right handside
evaluation is guarded by the left handside, for example:

```Ada
   if I in Some_Array'Range and A (I) = 0 then -- Error, should be and then
```

Guide-level explanation
=======================

Overall Concept
---------------

We introduce a new pragma `Shortcircuit_Operators` which is a library-level
pragma governing the semantic of boolean operator in the unit where the pragma
is used. For code compiled until Ada 2022, the value of this pragma is False,
On afterwards.

When the pragma is in effect and has a true value, non-overriden `and` and `or`
operators are now shortcircuit. More specifically:
- `and` does not evaluate its right-handside operator if the left handside is
  false.
- `or` does not evaluate its right-handside operator if the left handside is
  true.

`and then` and `or else` are not available anymore, using them leads to a
compilation error.

Users that want non-shortcircuit behavior can explicitely compute operands,
for example through separate statements.

This shortcircuit behavior is only implemented for built-in default operators.
Overriden operators will evaluate both operands before being called.

Unit consistency
----------------

The pragma `Shortcircuit_Operators` needs to be consistent between the
specification and the implementation of a library unit. In the case where
there's no specification (e.g. a library unit subprogram body), then the
value of the pragma in the body is the one of the unit.

An the body of a unit may have an explicit value `Shortcircuit_Operators` as
long as it's the same (explicit or implicit) of its specification.

Static and Dynamic Semantics
----------------------------

`Shortcircuit_Operators` impact both dynamic semantics and static semantics.
For example, in Ada, the following is illegal:

```ada
X : constant := Boolean'Pos (False and ((1/0) /= 23));
```

as we know statically that the static expression will be divided by 0. However,
under `Shortcircuit_Operators (True)`, it becomes valid as the right-end side of
the expression will not be computed.

Renamings
---------

Renamins preserve the semantics of the renamed operators. In particular,
if a shortcircuit operator is renamed, it shortcircuit semantics are preserved.

Generic Formal Parameters
-------------------------

General formal parameters may be compatible with short-circuit operators, e.g.:

```ada
generic
   with function F (L, R : Boolean) return Boolean;
package P is

   A : Boolean := F (False, 1 / 0 > 1);

end P;

package My_P is new P (Standard."and");
```

In order to maximise consistency, a boolean operator passed as a generic formal
acts as if it were a wrapper function to that operator, systematically
evaluating both operands when used within the generic implementation.
In otherwords, it does not short-circuit. This avoid situations where, in the
body of the generic unit, the compiler would behave differently depending on
wether "F" is shortcircuit or not.

Note that even in the case of a rename, the semantic of the F function in this
example remains consistent, and this non-shortcircuit. In other words:

```ada
generic
   with function F (L, R : Boolean) return Boolean;
package P is

   function F_Exp (L, R : Boolean) return Boolean renames F;

end P;

package My_P is new P (Standard."and");

A : Boolean := Standard."and" (V1, V2); -- shortcicuit
B : Boolean := My_P.F_Exp (V1, V2); -- non-shortcicuit
```

Implicit inheritance of default expressions
-------------------------------------------

When developping an application mixing different mode of
``Shortcircuit_Operators``, for example when including legacy software, the
operator behavior is fixed at the time of writing. This has an impact for
example in the case of default expressions. E.g.:

```ada

package P1 is
  pragma Shortcircuit_Operators (True);

  G : Integer;

  type T1 is null record;

  function F (A : T1; B : Boolean := G /= 0 and G / 10 > 5);

end P1;

with P1;

package P2 is
  pragma Shortcircuit_Operators (False);

  G : Integer;

  type T2 is new T1 with null record;

end P2;
```

T2 has an implicitely declared primitive F, which has a default expression
using a and operator. As this is written under à ``Shortcircuit_Operators (True)``
package, the operator is still shortcircuit in the implicitely inherited
subprogram. However, if the developper write in P2:

```ada
function F (A : T2; B : Boolean := G /= 0 and G / 10 > 5);
```

In that case, the operator will follow the semantic of the unit where it's
written and will not be shortcircuit.


Reference-level explanation
===========================


Rationale and alternatives
==========================


Drawbacks
=========

It introduces a backward incompatble change to Ada. However, as it's a local
change, it can be deactivated on legacy code.

Prior art
=========

Most programming languages implement shortcircuit operators.
