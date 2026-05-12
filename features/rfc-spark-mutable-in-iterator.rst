- Feature ID: spark-mutable-in-iterator
- Start Date: 2026-04-20
- Status: Ready for prototyping

Summary
=======

The Iterable aspect is a GNAT specific aspect that provides user defined
iteration over containers. Currently, it requires, at minimum, `First`, `Next`,
and `Has_Element` functions to iterate over the cursors of the container. An `Element` or `Constant_Reference` function (exclusive) can be added to obtain
iteration over the content container (`for Item of C loop` instead of `for Position in Container loop`). This method allows iterating over the elements of
the container in a read-only fashion, but does not allow any write. For
example, it is not possible to increment all elements of a container without
iterating over cursors.

This issue can be solved by adding an optional `Reference` function returning
an anonymous access-to-variable view of the element instead of a read-only view.

Motivation
==========

The use of `Reference` would allow mutating the content of the container
in-place, without changing the overall container layout. This feature would be
SPARK-friendly, calling `Reference` would be considered a borrow over the
container. This would properly track the updates in the loop body back to the
model of the container.

Guide-level explanation
=======================

The current proposal gives the option to add an extra `Reference` function over
a type that already supports `for ... of` iteration via an Iterable annotation,
with `Element` or `Constant_Reference` specified. `Reference` alone should not
be allowed, as this would not support iteration over constant containers.

For a `Container` type, `Reference` should have the following signature:

```ada
function Reference (C : [aliased] [in out] Container; P : Cursor) return not null access Element_Type;
```

It can be attached to an `Iterable` annotation as follows:

```ada
type Container is private with
   Iterable =>
     (First => First,
      Next => Next,
      Has_Element => Has_Element,
      Constant_Reference => Constant_Reference,
      Reference => Reference);
```
or

```ada
type Container is private with
   Iterable =>
     (First => First,
      Next => Next,
      Has_Element => Has_Element,
      Element => Element,
      Reference => Reference);
```

When `Reference` is specified for an Iterable annotation, and we have a mutable
view `E` of the matching `Container` type, then the following loop

```ada
for E of Container loop
  P (E);
end loop;
```

will be expanded to code corresponding to

```ada
declare
   Position : Cursor := First (Container);
begin
   while Has_Element (Container, Position) loop
      declare
         Ref : constant access Element_Type := Reference (Container, Position);
         E : Element_Type renames Ref.all;
      begin
         P (E);
      end;
      Position := Next (Container, Position);
   end loop;
end;
```


Reference-level explanation
===========================

The main scenario is already explained in the Guide-level explanation section.

When `Reference` is attached to an `Iterable` annotation, exactly one of
`Element` or `Constant_Reference` shall be attached to the same annotation. The
designated subtype of `Reference`'s return type shall statically match the
designated subtype of `Constant_Reference`'s return type, or `Element`'s return
subtype, whichever is provided.

When `Reference` is attached to an `Iterable` annotation, there are two ways to
expand `for ... of` loops, one for mutable views and the other for constant
view. The expansion is chosen according to the same rules as for choosing
between `Variable_Indexing` and `Constant_Indexing` aspects. That is,
`Constant_Reference` (or `Element`) is chosen over `Reference` when:

- `Reference` is not specified for the `Iterable` annotation of the container.
- The container object denotes a constant
- All occurrences of the loop parameter occur within `primaries` where `names`
  denoting constants are permitted.


Rationale and alternatives:
===========================

Essentially the same as for the `Constant_Reference` proposal.

- Procedural iterators with in-out parameters would be applicable, with similar 
pros/cons of limited lifetime/performance.
- the same enhancement of allowing private functions in the prototype of 
Iterable could be considered.

Drawbacks
=========

As E is a renaming and not an object, it would be unusable in certain cases. 
For example, in Global and Depends contracts. That is considered to be a minor 
shortcoming. The given examples would only impact subprograms declared in the 
loop body.

Compatibility
=============

The change does not alter the behaviour of legacy code.

Open questions
==============

None

Prior art
=========

Unresolved questions
====================

Future possibilities
====================

For proof purposes in SPARK, we need a loop invariant that states that the 
layout of the container remains unchanged from element updates. For example, 
updating a vector does not change its length. Since that invariant would be the 
same for all `for ... of` loop, it could be specified it once and for all when 
declaring the container. The current plan is to provide this feature with a 
tool-specific `Annotate`, but it could also be attached directly to the 
`Iterable` annotation.
