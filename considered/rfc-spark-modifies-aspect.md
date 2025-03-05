- Feature Name: spark_modifies_aspect
- Start Date: 2025-02-28
- RFC PR:
- RFC Issue:

Summary
=======

We propose a new contract to express precisely which parts of a mutable formal
parameter or a global object might be modified by a subprogram.

Motivation
==========

As SPARK performs modular verification on a per subprogram basis, it is
necessary to specify in the contract of subprogram not only what they modify,
but also what they preserve. This can be done currently in a coarse grain
maner using the parameter mode or the global mode. But it is imprecise, as
mutable parameters and global objects are considered to possibly be entirely
modified on every call of the subprogram. We want an easy way to specify that
only some components of an output of the subprogram are potentially modified, or
that some outputs can only be modified if a guard evaluates to True.

Guide-level explanation
=======================

It is possible to annotate subprograms with side-effects with a ``Modifies``
aspect. This aspect splits the input space in a number of disjoint cases, and,
for each case, lists the parts of objects that are both inputs and outputs of
the subprogram that are modified by the subprogram. Other objects are
necessarily left unchanged.

This allows users to easily specify that some of their outputs are left
unchanged on some paths. Here is an example. The global variable ``G`` is only
written by ``Write_G_If_B`` if its parameter ``B`` evaluates to True. Its
``Modifies`` aspect states that ``Write_G_If_B`` does not modify anything if
``B`` is False:

```ada
   G : Integer;

   procedure Write_G_If_B (B : Boolean) with
     Global => (In_Out => G),
     Modifies => (not B => null);

   procedure Write_G_If_B (B : Boolean) is
   begin
      if B then
         G := 0;
      end if;
   end Write_G_If_B;
```

Note that the guard here should be read as a precondition. It is evaluated once
and for all at the beginning of the subprogram and the corresponding case is
considered to be enabled if it evaluates to True.

The ``Modifies`` aspect supports listing only parts of an object. It can be
a record component, an array index, a dereference, or a sequence of them.
Components which are not listed are considered to be preserved by the
subprogram. As an example, ``Write_G1_F1`` only modifies the ``F1``
component of its ``G1`` field of ``X``. The components ``X.G2`` and ``X.G1.F2``
are preserved by the call:

```ada
   type R is record
      F1, F2 : Boolean;
   end record;
   type RR is record
      G1, G2 : R;
   end record;

   procedure Write_G1_F1 (X : in out RR) with
     Modifies => (others => X.G1.F1);

   procedure Write_G1_F1 (X : in out RR) is
   begin
      X.G1.F1 := False;
   end Write_G1_F1;
```

When an array index is used, the expression of the index is always evaluated
at the beginning of the call. As an example, in the following example, the
index of the preserved element is computed at the beginning of the call, so it
will be the input value of ``I`` and not its output value.

```ada
   type A is array (1 .. 10) of Boolean;
   type AR is record
      G1, G2 : A;
   end record;

   procedure Write_G1_I (X : in out AR; I : in out Positive) with
     Modifies => (others => X.G1.F1 (I));

   procedure Write_G1_I (X : in out AR; I : in out Positive) is
   begin
      X.G1 (I) := False;
      I := 42;
   end Write_G1_I;
```

Reference-level explanation
===========================

The ``Modifies`` aspect is introduced by an aspect_specification where the
aspect_mark is ``Modifies`` and the aspect_definition must follow the grammar of
``MODIFIES_SPECIFICATION``:

```
MODIFIES_SPECIFICATION ::= (MODIFIES_ALTERNATIVE {, MODIFIES_ALTERNATIVE});

MODIFIES_ALTERNATIVE ::= GUARD => MODIFIED_OBJECTS

GUARD ::= boolean_EXPRESSION | others

MODIFIED_OBJECTS ::= null | (MODIFIED_OBJECT {, MODIFIED_OBJECT})

MODIFIED_OBJECT ::=
    name
  | MODIFIED_OBJECT . all
  | MODIFIED_OBJECT . component_selector_name
  | MODIFIED_OBJECT (expression [, expression])
```

This aspect contains a list of alternatives made of a guard, and a list
of names designating parts of mutable parameters or global objects. The
alternatives should be disjoint, so that at most one guard evaluates to True at
the beginning of a given call. The ``others`` modifier can be used as the guard
of the last alternative. For a set of input, the alternative whose guard
evaluates to True is said to be *enabled*. If no guard evaluates to True, the
alternative with ``others`` as a guard is enabled if there is one.

We say that an object is *unchanged* by a subprogram if its input and its output
values match in the following way:

- For discrete and fixed point objects, their values shall be equal.
- For floating point objects, they shall have the same bitwise representation.
- For composite object, matching components shall be unchanged and:
  - if the object is tagged, its tag shall be the same, and
  - for array objects, the bounds shall be equal.
- For access-to-object objects, they shall either be both null or designate
  unchanged values.
- For access-to-subprogram objects, they shall either be both null or designate
  the same subprogram.

For now, we propose to not support unchanged concurrent objects. Therefore,
if a concurrent object is modified by a subprogram with a ``Modifies`` aspect,
the object should always occur alone in all alternatives of the ``Modifies``
aspect. The implicit self reference of protected operation is always omitted.

If a ``MODIFIED_OBJECT`` is a name, it shall denote an entire object or a
state abstraction that is an output of the subprogram. For example, it would not
make sense to mention ``B`` in the ``Modifies`` aspect of ``Write_G_If_B``, as
``B`` is one of its inputs but not one of its outputs.

If an alternative of a ``Modifies`` aspect is enabled for a subprogram call,
then the index expressions of its ``MODIFIED_OBJECTS`` are evaluated once and
for all at the beginning of the call. This is examplified by ``Write_G1_I`` in
the previous section. The handling here is similar to what is done for loops in
Ada, where bounds and container objects are evaluated one and for all at the
beginning of the loop.

If an alternative of a ``Modifies`` aspect is enabled for a subprogram call,
then each element of the ``MODIFIED_OBJECTS`` shall denote an object both at
the beginning and at the end of the call. In particular, discriminant-dependent
components shall be present, and dereferenced pointers shall not be null.

If an alternative of a ``Modifies`` aspect is enabled for a subprogram call,
then, when the subprogram returns normally, all subcomponents reachable from
objects that are outputs of the subprogram shall be unchanged but for thos
e reachable from the evalutation of elements of the ``MODIFIED_OBJECTS`` list of
the enabled clause.
This means in particular that we do not require anything when no alternatives
are enabled. It is the case for ``Write_G_If_B``. If ``B`` evaluates to True,
there is no enabled alternative and all outputs of ``Write_G_If_B``, here ``G``
only, might be modified by the call.

When a subprogram propagates an exception, its parameter that are not known to
be passed by reference are exempted from the check. All subcomponents reachable
from objects that are outputs of the subprogram except its parameters that might
be passed by copy shall be unchanged but for those reachable from the
evalutation of elements of the ``MODIFIED_OBJECTS`` list of the enabled clause.

Rationale and alternatives
==========================

We could propose a dual ``Preserves`` contract instead, but it seems less
ideal as the size of the contract could blow up with the number of components
in the structure while ``Modifies`` contracts should stay proportional to the
size of the code. Also, it would not work as well with tagged extensions.

Another alternative would be to rather list objects in the ``Modifies`` aspect
with an optional ``when`` condition. However, this would only make sense if
objects can only be mentionned once. This is something that might depend on
the value of the subprogram's inputs if the object contains index components.

As a pathological exemple, let's consider a function that only sets elements I
and J of an array A if they are not equal to 0:

```ada
procedure Set_If_Not_Zero (A : Int_Array; I, J : Index) with
  Modifies =>
    (A (I) /= 0 and A (J) /= 0 => (A (I), A (J)),
     A (I) /= 0 and A (J) = 0 => A (I),
     A (J) /= 0 and A (I) = 0 => A (J),
     A (J) = 0 and A (I) = 0 => null);
```

Obviously this is painful. An alternative would be to rather list objects in the
``Modifies`` aspect with an optional ``when`` condition.

```ada
procedure Set_If_Not_Zero (A : Int_Array; I, J : Index) with
  Modifies =>
    (A (I) when A (I) /= 0,
     A (J) when A (J) /= 0);
```

In this version, we might be tempted to require that a single object can only
occur once in the ``Modifies`` aspect, but they might not be practical, as can
be seen on the example above, when index components are present.

A possibility could be to allow duplication in this alternative version when
there are indexed components (similarly to what is done for deep delta
aggregates). This would allow harder to read forms with duplications that
hopefully people would not write.

Drawbacks
=========

Prior art
=========

In ACSL, they can provide separate behaviors based on a partition of the input
space. For each behavior, they can supply an `assign clause` providing a set of
modified source locations. The language of source locations is quite
expressive, including dereferences, component accesses, ranges of arrays, and
even set operations and comprehension:

```
@ assigns { q->hd | struct list *q ; reachable(p,q) } ;
```

This quite different from what we propose because they are modelling the memory,
which we do not need to do in SPARK.

In WhyMl, `writes` contracts can include separate mutable fields. As far as I
know they cannot have different contracts for a partition of the input. It is
less useful in WhyMl as specifying the preservation in contracts can be done
easily using the builtin logical equality symbol.

Unresolved questions
====================

This annotation could stay non executable for now as it is mostly needed for
formal verification.

Future possibilities
====================

It would be nice to be able to use iterated components for arrays, ideally
with a guard, like:

```ada
  Modifies => (for I in A'Range => A (I).F when I mod 2 = 0);
```

It might be too complex for a first iteration though.

It would be good to be able to use the ``Modifies`` aspect on private types.
The design for that might rely on a set of special primitives that could be
mentioned in the clause and that would be considered to be preserved if not
mentioned.

Think about what the natural extension and evolution of your proposal would
be and how it would affect the language and project as a whole in a holistic
way. Try to use this section as a tool to more fully consider all possible
interactions with the project and language in your proposal.
Also consider how the this all fits into the roadmap for the project
and of the relevant sub-team.

This is also a good place to "dump ideas", if they are out of scope for the
RFC you are writing 