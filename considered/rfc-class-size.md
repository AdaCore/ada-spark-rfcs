# Class'Size aspect for tagged types

## Summary

The idea is to be able to annotate a tagged type declaration with a `Class'Size`
aspect like so:

```ada
type Foo is tagged abstract null record
with Class'Size => 16 * 8; --  Size is in bits
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

A new aspect, `Class'Size` is added.

### Syntax

No custom syntax

### Static legality rules

* `Class'Size` can be specified only on tagged type definitions. Any use on other
  entities will raise an error.

* `Class'Size` can only be specified on the rootmost type of a tagged type
  hierarchy (excluding interfaces).

* Given a tagged type `A` which has a `Class'Size` aspect, the classwide type
  `A'Class` is a definite constrained type, as well as any classwide type for
  any of the types derived from `A`.

* When defining a type that is derived directly or indirectly from `A`, its
  computed size will be matched against the max-size. If it is bigger than the
  max size, an error will be raised.

### Operational semantics

Objects with a `Class'Size` aspect are stored by value in a memory zone that is
the size of `Class'Size`.

## Unresolved questions

* Whether you can use `Class'Size` on interfaces. In this first iteration of the
  feature, I would say no. Quentin has some arguments for why it should be
  allowed, and I have some arguments as to why it should be disallowed.

* Can you redefine `Class'Size` on subclasses to specify a smaller size ?

* Can you define `Class'Size` on intermediate classes?

## Future possibilities

Manually computing the size is tedious, so the idea would be to leverage
the "final" feature explained here
https://github.com/AdaCore/ada-spark-rfcs/blob/topic/final/considered/final_modifier.md
to allow people that are OK with making the type final to let the compiler
auto-compute the size.

```ada
type Foo is final tagged abstract null record
with Class'Size => Auto;
--  This type can only be derived inside the package it has been declared in.

type Bar is new Foo with record
    A, B : Integer;
end record;

type Baz is new Foo with record
    S : String (1 .. 128)
end record;

-- Size of Foo'Class automatically infered to be Max (Bar'Size, Baz'Size, ...)
```
