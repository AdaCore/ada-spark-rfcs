- Feature Name: loop_index_attribute
- Start Date: (2025-02-27
- Status: Planning

Summary
=======

This RFC introduces a new ghost attribute, called ``Loop_Index``,
that can be applied to the loop parameter of a generalized iterator to get the
underlying index or cursor.

Motivation
==========

Currently, it is often not possible to use array component iterators and
container element iterators in loops in SPARK as loop invariants generally need
to refer to the underlying loop index or cursor.
It would be possible to use the ghost attribute Loop_Index inside the pragma
``Loop_Invariant`` or ``Loop_Variant`` of loops with array component iterators
or container element iterators, making it possible to use this pattern in SPARK.
This feature should work both for array component iterators and for container
element iterators based on the ``Iterable`` aspect.
It should be executable when ghost code is enabled.

Guide-level explanation
=======================

The ghost attribute ``Loop_Index`` can be used on the loop parameter of array
component iterators to access the index associated with the loop parameter in
the array. It allows users to more easily express loop invariant over loops with
array component iterators. Here is an example of a loop that increments elements
of an array. It uses the ``Loop_Index`` attribute in its loop invariant to
express that all elements up to the current index have been updated:

```ada
procedure Do_Loop_1 (A : in out My_Array) is
begin
   for E of A loop
      E := E + 1;
      pragma Loop_Invariant
        (for all I in A'First .. E'Loop_Index => A (I) = A'Loop_Entry (I) + 1);
   end loop;
end Do_Loop_1;
```

``Loop_Index`` can also be used on the loop parameter of container element
iterators based on the ``Iterable`` aspect to access the underlying cursor in
the container. As an example, the following procedure loops over a functional
sequence to count the number of zeros. As big integers serve as cursors in
functional sequences, the ``Loop_Index`` attribute can be used to bound the
number of occurrences encountered so far in the loop invariant:

```ada
procedure Do_Loop_2 (S : in out My_Sequence) is
   C : Big_Natural := 0;
begin
   for E of S loop
      if E = 0 then
        C := C + 1;
      end if;
      pragma Loop_Invariant (C <= E'Loop_Index);
   end loop;
end Do_Loop_2;
```

Reference-level explanation
===========================

The ghost attribute ``Loop_Index`` can be applied to the loop parameter of array
component iterators and container element iterators whose container type is
annotated with the ``Iterable`` aspect. Occurrences of this
attribute are only allowed in the body of a loop with such an iterator.

During the execution of the body of a loop with an array component iterator,
references to the ``Loop_Index`` attribute stand for the index of the component
of the array designated by the loop parameter. Here is an equivalent formulation
of the loop from ``Do_Loop_1`` presented in the previous section:


```ada
procedure Do_Loop_1 (A : in out My_Array) is
begin
   for E_Loop_Index in A'Range loop
      declare
        E : Element_Type renames A (E_Loop_Index);
      begin
        E := E + 1;
        pragma Loop_Invariant
          (for all I in A'First .. E_Loop_Index => A (I) = A'Loop_Entry (I) + 1);
      end;
   end loop;
end Do_Loop_1;
```

During the execution of the body of a loop with a container element iterators,
references to the ``Loop_Index`` attribute stand for the cursor variable
introduced in the canonical expansion of loops based on the ``Iterable`` aspect.
Here is the expansion of the loop from ``Do_Loop_2`` presented in the previous
section:

```ada
procedure Do_Loop_2 (S : in out My_Sequence) is
   C : Big_Natural := 0;
begin
   declare
     E_Loop_Index : Big_Natural := First (S);
   begin
     while Has_Element (S,  E_Loop_Index) loop
      declare
        E : constant Element_Type := Element (S,  E_Loop_Index);
      begin
        if E = 0 then
          C := C + 1;
        end if;

        E_Loop_Index := Next (S, E_Loop_Index);

        pragma Loop_Invariant (C <= E_Loop_Index);
      end;
   end loop;
end Do_Loop_2;
```

Rationale and alternatives
==========================

Making the ``Loop_Index`` attribute ghost does not serve any actual need except
for ensuring that array component iterators and container element iterators
remain reserved to loops where the loop body does not depend on the loop index.

We could decide to disallow references to ``Loop_Index`` outside of pragmas
``Loop_Invariant`` and ``Loop_Variant`` like references to the ``Loop_Entry``
attribute, but we know from experience with ``Loop_Entry`` that it sometimes
makes it more complicated to debug proof attempts by copying the invariant
inside intermediate assertions.

An alternative to the ``Loop_Index`` attribute would be to directly use a tuple
in the definition of the iterator:

```ada
for (Cursor, Element) in Collection.Iterate loop
```

This seems more complicated to implement and relatively orthogonal though. The
use case here is to support loops in which the executable code does not need to
refer to the loop index or cursor, and only the ghost code (the loop invariant)
requires it.

Drawbacks
=========


Prior art
=========


Unresolved questions
====================

For array content iterators over multi-dimensional arrays, it might make sense
to define ``Loop_Index (I)`` attributes for each dimension. Another possibility
is to disallow the feature on multi-dimensional arrays for now.

Future possibilities
====================

After this change, it would make sense to extend the ``Iterable`` aspect to take
as parameters ``Reference`` and ``Constant_Reference`` functions providing
direct access inside the container to make iteration more efficient. In SPARK,
absence of tampering would be provided by ownership.