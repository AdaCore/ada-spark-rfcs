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

We introduce a new pragma Shorcircuit_Operators which is a library-level pragma
governing the semantic of boolean operator in the unit where the pragma is used.
For code compiled until Ada 2022, the value of this pragma is False, True
afterwards.

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
