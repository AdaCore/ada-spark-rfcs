- Feature Name: ghost fields
- Start Date: 2022-02-22
- RFC PR: #88
- RFC Issue: (leave this empty)

Summary
=======

Motivation
==========

Guide-level explanation
=======================

Ghost Fields
------------

The Ghost aspect can be specified for a record component. An assignment
statement to such a component (in full or part) is a ghost statement. The rules
for referencing a ghost component are the same as for any other ghost
entity. Ghost entities should now be allowed inside the expression
corresponding to a ghost component inside an aggregate. Here is an example of
use of a ghost component:

```Ada
type Pair is record
   X, Y : Integer;
   Area : Integer with Ghost;  --  ghost component
end record;

function Compute_Area (X, Y : Integer) return Integer is (X * Y)
   with Ghost;

function Create (X, Y : Integer) return Pair is
   (X => X, Y => Y, Area => Compute_Area (X, Y));  --  ghost reference

procedure Assign (P : out Pair; X, Y : Integer) is
begin
   P.X := X;
   P.Y := Y;
   P.Area := Compute_Area (X, Y);  --  ghost statement
end Assign;
```

Ghost fields may or may not be present at compile-time. As a consequence, the
size and layout of a data structure may differ depending on wether or not
ghost code is activated. In order to control this duality, a new set of
attributes "Ghost_Size", "Ghost_Value_Size" and "Ghost_Object_Size" are added
to refer to the size of the ghost objects when compiled whereas "Size",
"Value_Size" and "Object_Size" refer to the value of the objects as compiled.
As a consequence, Size, Value_Size and Object_Size may vary depending on
wether ghost code is active or not:

Note that as a consequence, "Size", "Value_Size" and "Object_Size" can't be
specified on a record type that has ghost fields as this size is not constant.
Instead, one would use "Concrete_Size", "Concrete_Value_Size"
and "Concrete_Object_Size" which refers to the object without its ghost
components. These could also be turned into attributes. For example:

```Ada
type Pair is record
   X, Y : Integer;
   Area : Integer with Ghost;  --  ghost component
end record
   with Ghost_Size    => 12 * 8,
      Concrete_Size => 8 * 8;

S1 : Integer := Pair'Size;          -- 8 or 12 bytes
S2 : Integer := Pair'Ghost_Size;    -- 12 bytes
S3 : Integer := Pair'Concrete_Size; -- 8 bytes
```

When representation is necessary, it has to describe both concrete and ghost
fields, the compiler will check consistency of both cases. For example:

```Ada
for Pair'Ghost_Size    => 12 * 8,
for Pair'Concrete_Size => 8 * 8,

for Pair use record
   X    at 0 range 0 .. 31;
   Y    at 4 range 0 .. 31;
   Area at 8 range 0 .. 31;
end record;
```

Ghost components do not participate in the default equality, so that two
``Pair`` objects which only differ in their ``Area`` component should be
equal:

```Ada
P1 := (X => 1, Y => 2, Area => 8);
P2 := (X => 1, Y => 2, Area => 12);
pragma Assert (P1 = P2);  --  true assertion
```

Note that subtype predicates cannot refer to ghost entities, including ghost
components, as they are evaluated in type membership tests. Type invariants can
refer to ghost entities, including ghost components.

Ghost Parameters
----------------

The Ghost aspect can be specified for a parameters. E.g.:

```Ada
procedure Some_Procedure (X : Integer; Y : Integer with Ghost);
```

Ghost parameters need to be valuated at call time (unless they have default
values), and can be with expression containing ghost entities. E.g.:

```Ada
   V1 : Integer;
   V2 : Integer with Ghost;

   Some_Procedure (V1, V1 + V2);
```

When Ghost code is not compiled, the expression valuating ghost parameter is
not evaluated and no parameters is passed.

Inside the body of a procedure or a function, ghost parameters behave like
Ghost variable and can only be used in the context of ghost code.


Reference-level explanation
===========================

TDB

Rationale and alternatives
==========================


Drawbacks
=========

Alternate layout for ghost and non-ghost record may create additional
difficulties when developping application that heavily depends on reprentations.
Some of these applications may as a consequence not be able to rely on run-time
ghost fields. The [Multiple Ghost fields proposal](https://github.com/QuentinOchem/ada-spark-rfcs/blob/multiple_ghost/considered/rfc-multiple_ghost_levels.md)
would allow to cater for these cases.

Prior art
=========

Other programming languages that target formal program verification include
ghost fields: [Why3](http://why3.lri.fr/doc/syntaxref.html#modules),
[Dafny](https://dafny-lang.github.io/dafny/DafnyRef/DafnyRef.html#33-declaration-modifiers).

Ghost code is not executable in these languages, so the above discussion
regarding alternatives for ghost components is not relevant for them.

Unresolved questions
====================


Future possibilities
====================
