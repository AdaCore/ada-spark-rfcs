# Size'Class aspect for tagged types

## Summary

The idea is to be able to annotate a tagged type declaration with a `Size'Class`
aspect like so:

```ada
type Foo is tagged abstract null record
with Size'Class => 16 * 8; --  Size is in bits
```

Then, any time a descendent would be declared, the compiler would verify that
it satisfies the size constraints

```ada
type Bar is new Foo with record
   S : String (1 .. 128);
end record; --  ERROR: Record doesn't fit in 16 bytes
```

The usefulness of this is that the classwide type for `Foo` would be of a
definite and known size, which would allow the users to use classwide instances
as definite sized objects:

```ada
Inst : Foo'Class;
type Foo_Array is array (Positive range <>) of Foo'Class;
```

## Motivation

* Being able to use classwide types where definite types are required in Ada,
  which in turns allows to either use tagged types where they couldn't be used
  before, or remove a lot of dynamic allocations if tagged types were used
  already.

* The above will make tagged types much more usable in embedded contexts where
  dynamic allocation is prohibited, or discouraged.

## Reference level explanation

A new aspect, Size'Class, is defined.

The Size'Class representation aspect may be specified for a
non-derived non-interface specific tagged type T.
The expected type for the Aspect_Definition is Universal_Integer; the
specified value shall be static.

If the Size'Class aspect is specified for a type T, then every
specific descendant of T [redundant: (including T)]

- shall have a Size that does not exceed the specified value; and

- shall be undiscriminated; and

- shall have no composite subcomponent whose subtype is subject to a
  dynamic constraint; and

- shall have no interface progenitors; and

- shall not have a tagged partial view other than a private extension; and

- shall not have a statically deeper accessibility level than that of T.

In addition to the places where Legality Rules normally apply (see 12.3),
these legality rules apply also in the private part and in the body of an
instance of a generic unit.

For any subtype S that is a subtype of a descendant of T, S'Class'Size is
defined to yield the specified value [redundant:,  although S'Class'Size is
not a static expression].

A class-wide descendant of a type with a specified Size'Class aspect
is defined to be a "mutably tagged" type. Any subtype of a mutably tagged
type is, by definition, a definite subtype (RM 3.3 notwithstanding). Default
initialization of an object of such a definite subtype proceeds as for the
corresponding specific type, except that Program_Error is raised if the
specific type is abstract. [In particular, the initial tag of the object
is that of the corresponding specific type.]

An object of a tagged type is defined to be "tag-constrained" if it is

- an object whose type is not mutably tagged; or

- a constant object; or

- a view conversion of a tag-constrained object; or

- a formal "in out" or "out" parameter whose corresponding
  actual parameter is tag-constrained.

[Redundant: A variable of a specific type is always tag-constrained. An
allocator of an access-to-mutably-tagged-variable type never creates a
tag-constrained object; the object designated by a value of such an
access type is not tag-constrained.]

In the case of an assignment to a tagged variable that
is not tag-constrained, no check is performed that the tag of the value of
the expression is the same as that of the target (RM 5.2 notwithstanding).
Instead, the tag of the target object becomes that of the source object of
the assignment. [Redundant: The tag of an object of a mutably-tagged
type MT will always be the tag of some specific type that is covered by MT.]
An assignment to a composite object similarly copies the tags of any
subcomponents of the source object that have a mutably-tagged type.

The Constrained attribute is defined for any name denoting an object of a
mutably tagged type (RM 3.7.2 notwithstanding). In this case, the Constrained
attribute yields the value True if the object is tag-constrained and False
otherwise.

Renaming is not allowed (see 8.5.1) for a type conversion having an operand
of a mutably tagged type MT and a target type TT such that TT'Class does not
cover MT [redundant: (sometimes called a "downward" conversion)], nor for
any part of such an object, nor for any slice of such an object. This
rule also applies in any context where a name is required to be one for
which "renaming is allowed" (for example, see RM 12.4).

A name denoting a view of a variable of a mutably tagged type shall not
occur as an operative constituent of the prefix of a name denoting a
prefixed view of a callable entity, except as the callee name in a call to
the callable entity. [Redundant: This disallows, for example, renaming
such a prefixed view, passing the prefixed view name as a generic actual
parameter, or using the prefixed view name as the prefix of an attribute.]

For a type conversion between two general access types, either both
or neither of the designated types shall be mutably tagged. For an
Access (or Unchecked_Access) attribute reference, the designated type
of the type of the attribute reference and the type of the prefix of
the attribute shall either both or neither be mutably tagged.

The execution of a construct is erroneous if the construct has a constituent
that is a name denoting a subcomponent of a tagged object and the object's
tag is changed by this execution between evaluating the name and the last use
(within this execution) of the subcomponent denoted by the name.

If the type of a formal parameter is a specific tagged type then the
execution of the call is erroneous if the tag of the actual is changed
while the formal parameter exists (that is, before leaving the
corresponding callable construct).

## Future possibilities

It may be possible to relax some of the restrictions regarding interface types and derived types.
The erroneous execution rules (which are patterned after existing RM rules for discriminated types)
might also be made more permissive.
It would be possible to have a compile-time check instead of a run-time check to prevent
"X : Some_Abstract_Type'Class;".
These have all been deferred in order to simplify the initial version of this feature.

Manually computing the size is tedious, so the idea would be to leverage
the "final" feature explained here
https://github.com/AdaCore/ada-spark-rfcs/blob/topic/final/considered/final_modifier.md
to allow people that are OK with making the type final to let the compiler
auto-compute the size.

```ada
type Foo is final tagged abstract null record
with Size'Class => Auto;
--  This type can only be derived inside the package it has been declared in.

type Bar is new Foo with record
    A, B : Integer;
end record;

type Baz is new Foo with record
    S : String (1 .. 128)
end record;

-- Size of Foo'Class automatically infered to be Max (Bar'Size, Baz'Size, ...)
```
