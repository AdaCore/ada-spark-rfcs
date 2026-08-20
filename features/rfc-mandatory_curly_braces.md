- Feature ID: mandatory_curly_braces
- Start Date: 2026-08-13
- Status: Design

# Summary

This RFC makes a curly-brace syntax `{...}` mandatory for record aggregate
construction in pedantic Ada Flare:

1. Record aggregates: `{X => 1, Y => 2}`, `{1, 2}`, `{others => <>}`, and `{}`
   for the empty (null) record aggregate
2. Extension aggregates: `{Base with {X => 1}}`, `{Base with {}}`
3. Record delta aggregates: `{Base with delta {X => 1}}`

In extension and delta aggregates, the components that follow `with` are
themselves wrapped in braces, so what follows `with` always has the shape of a
record aggregate; a null extension is written `{Base with {}}`.

Because braces remove the collision between a record aggregate and a
parenthesised expression, this RFC also lifts the Ada rule that a record
aggregate with a single component association must be written in named notation:
`{42}` is a legal positional record aggregate in pedantic Flare.

# Motivation

## Readability and visual clarity

RFC `mandatory_square_brackets` removed most non-call uses of `()` from pedantic
Flare, but record-shaped aggregates stayed parenthesised, so `()` still carries
three meanings: call actual parameters `Make (X => 1)`, record aggregate
`(X => 1, Y => 2)`, and parenthesised expression `(X)`. A record aggregate is
textually identical to the actual parameter part of a call:

```ada
Draw (Point => (X => 1, Y => 2));   --  aggregate or inner call?
Draw (Point => {X => 1, Y => 2});   --  unambiguously an aggregate
```

| Operation                  | Ada syntax                   | Flare syntax                 |
| -------------------------- | ---------------------------- | ---------------------------- |
| Subprogram call            | `F (X => 1)`                 | `F (X => 1)`                 |
| Array aggregate            | `(1, 2, 3)`                  | `[1, 2, 3]`                  |
| Container aggregate        | `["one" => 1]`               | `["one" => 1]`               |
| Record aggregate           | `(X => 1, Y => 2)`           | `{X => 1, Y => 2}`           |
| Extension aggregate        | `(Base with X => 1)`         | `{Base with {X => 1}}`       |
| Record delta aggregate     | `(Base with delta X => 1)`   | `{Base with delta {X => 1}}` |
| Null record aggregate      | `(null record)`              | `{}`                         |
| Null extension aggregate   | `(Base with null record)`    | `{Base with {}}`             |
| Single-component aggregate | `(F => X)` (named mandatory) | `{X}` or `{F => X}`          |
| Parenthesised expression   | `(A + B)`                    | `(A + B)`                    |

This matches the convention most programmers already know from C, C++, Rust, Go,
C#, and JavaScript, where `{...}` constructs a struct, record, or object value.

## Completing the Flare delimiter policy

After RFC `parentheses_for_parameterless_calls` and RFC
`mandatory_square_brackets`, record aggregates are the last remaining non-call,
non-grouping use of `()` in pedantic Flare. Covering them closes the policy:
`Name (...)` is a call, `[...]` builds or indexes an array or indexable
container (RM 4.1.6), and `{...}` builds a record value.

## Removing the parenthesised-expression collision

In Ada, a record aggregate with a single component association must use named
notation: a positional `(X)` could be indistinguishable from a parenthesised
expression (RM 4.3.1). `{X}` cannot be a parenthesised expression, so the
restriction is lifted. Ada 2022 made the same move when it introduced brackets —
`[X]` is a legal one-element array aggregate while the parenthesised form still
requires two expressions (RM 4.3.3). The restriction is a property of the
delimiter and disappears with it.

## Distinguishing array and container construction from record construction

Array and container aggregates build indexed collections of elements of one
element type; record aggregates bind heterogeneous values to named components.
Distinct delimiters keep both directions readable, in particular when they nest:

```ada
Config : Configuration :=
  {Name    => "prod",
   Retries => 3,
   Servers => ["alpha", "beta"],
   Origin  => {X => 0, Y => 0}};
```

# Guide-level explanation

## Record aggregates

Any record aggregate is written with curly braces; the parenthesised form is a
compile-time error in pedantic mode.

**Ada:**

```ada
P : Point   := (X => 1, Y => 2);
Q : Point   := (1, 2);
R : Point   := (X => 1, others => <>);
N : Nothing := (null record);
```

**Flare:**

```ada
P : Point   := {X => 1, Y => 2};
Q : Point   := {1, 2};
R : Point   := {X => 1, others => <>};
N : Nothing := {};
```

Positional and named associations, choices with `|`, `others`, and the `<>` box
work exactly as in Ada. The one change inside the braces is the empty record:
braces make it directly expressible, so it is written `{}` (mirroring the null
array aggregate `[]`) and the `null record` spelling is not carried over.

## Single-component record aggregates

In Ada, a record aggregate with one component association must use named
notation, because the positional `(X)` already means "the expression `X`,
parenthesised". Braces remove that collision, so for a record type with a single
component `Value`:

```ada
W1 : Wrapped_Counter := {Value => 42};
W2 : Wrapped_Counter := {42};           --  now legal
```

Overloading shows why Ada could not simply allow the parenthesised positional
form — both readings of `(F)` can type-check at once:

```ada
type Wrapper is record
   Flag : Boolean;
end record;

function F return Boolean;
function F return Wrapper;

V : Wrapper := (F);   --  as a parenthesised expression, calls the
                      --  Wrapper-returning F; as an aggregate, it would
                      --  call the Boolean-returning F
```

Braces split the two readings into two spellings: `(F)` stays a parenthesised
expression calling the `Wrapper`-returning `F`, while `{F}` is the aggregate
`{Flag => F}` calling the `Boolean`-returning `F`.

Named notation remains available and is often still the clearer choice; this RFC
only removes the requirement.

## Extension aggregates

Extension aggregates use curly braces around the whole aggregate, and the
components added by the extension are wrapped in braces of their own: what
follows `with` has exactly the shape of a record aggregate, with the null
extension using the empty inner aggregate.

**Ada:**

```ada
D : Derived := (Base_Value with Extra => 5);
E : Derived := (Base_Type with Extra => 5);
F : Derived := (Base_Value with null record);
```

**Flare:**

```ada
D : Derived := {Base_Value with {Extra => 5}};
E : Derived := {Base_Type with {Extra => 5}};
F : Derived := {Base_Value with {}};
```

The inner braces keep the empty forms apart. `{}` is itself a legal record
aggregate and single-component positional aggregates are legal, so a flat
`{Base with {}}` could mean "extend `Base` with nothing" or "extend `Base` with
one component whose value is the empty record". Nesting gives the two cases
different spellings:

```ada
A : T1 := {Base with {}};     --  null extension: nothing added
B : T2 := {Base with {{}}};   --  one positional component, an empty record
```

## Record delta aggregates

Record delta aggregates follow the same shape: the updated components after
`with delta` are wrapped in braces of their own.

```ada
--  Ada: (P with delta X => P.X + 1)
Moved : Point := {P with delta {X => P.X + 1}};

--  Array deltas stay flat and bracketed (mandatory_square_brackets):
Updated : Integer_Array := [A with delta 2 => 99];
```

The outer delimiter matches the shape of the base value — brackets for arrays,
braces for records — and after `with delta`, a record's updated components form
a braced, record-shaped list.

## Qualified expressions

A qualified record aggregate uses the brace form after the apostrophe, just as
Ada 2022 already allows `T'[...]`: Ada's `Point'(X => 1, Y => 2)` becomes
`Point'{X => 1, Y => 2}`. A qualified plain expression keeps parentheses:
`Integer'(A + B)`.

## What still uses parentheses

This RFC does not change:

- Discriminant constraints: `Rec (D => 5)` (see Rationale and alternatives)
- Discriminant parts in type declarations: `type Rec (D : Positive) is record`

# Reference-level explanation

## Lexical elements

Curly braces are not delimiters in Ada. RM 2.2 must be extended so that `{` and
`}` are single delimiters, alongside `(`, `)`, `[`, and `]`; no compound
delimiter involving braces is introduced. This is a pure addition: `{` and `}`
occur in legal Ada source only inside string literals, character literals, and
comments, where they remain uninterpreted.

RFC `string_interpolation` gives braces meaning inside interpolated string
literals (`f"..."`). There is no grammar-level conflict but since an
interpolated expression contains a full `expression`, brace aggregates can
appear inside it, as in `f"origin is {Point'{X => 0, Y => 0}}"`.

## Grammar notation

In the grammar fragments below, quoted `'{'` and `'}'` are literal curly braces,
while unquoted `{` `}` retain their RM meaning of a repeated part.

## Record aggregates

RM 4.3.1 `record_aggregate` becomes:

```
record_aggregate ::= '{' [record_component_association_list] '}'

record_component_association_list ::=
  record_component_association {, record_component_association}
```

Two changes are made beyond the delimiters:

- The `null record` alternative of `record_component_association_list` is
  removed. Emptiness is expressed by omitting the list: the empty record
  aggregate is written `{}`, mirroring the null array aggregate `[]`. Exactly as
  `(null record)` in Ada, `{}` is legal only where there are no components to
  give values to.
- The named-notation requirement for single-component aggregates is removed.
  That rule exists only to keep `(X)` unambiguous as a parenthesised expression;
  inside braces there is nothing to disambiguate. Ada 2022 sets the precedent:
  the bracketed `positional_array_aggregate` accepts a single expression
  (`[X]`), while the parenthesised form requires two (RM 4.3.3).

All other name resolution, legality, and dynamic semantics of RM 4.3.1 are
unchanged. The single-component relaxation extends to the inner list of an
extension aggregate: `{Base with {42}}` is legal (the flat Ada form
`(Base with 42)` already was). Record delta aggregates continue to require named
associations, as in Ada.

## Extension aggregates

RM 4.3.2 `extension_aggregate` becomes:

```
extension_aggregate ::=
  '{' ancestor_part with '{' [record_component_association_list] '}' '}'
```

The `ancestor_part` syntax (an expression or a subtype mark) and all static and
dynamic semantics of RM 4.3.2 are unchanged. As in the record aggregate, the
`null record` alternative is removed; the null extension is written with an
empty inner list, `{Base with {}}`.

The inner braces are what keeps the aggregate family unambiguous: with a flat
list, the natural empty form `{Base with {}}` could equally parse as an
extension with a single positional component whose value is the empty record
aggregate. Nested, the two spellings differ — `{Base with {}}` adds nothing,
`{Base with {{}}}` adds one component whose value is `{}`. Nesting also gives
`with` a uniform right-hand side: whatever follows it (after `delta`, if any) is
a braced, record-shaped component list.

## Record delta aggregates

RM 4.3.4 `record_delta_aggregate` becomes:

```
record_delta_aggregate ::=
  '{' base_expression with delta '{' record_component_association_list '}' '}'
```

The inner list is mandatory and named-only, exactly as in Ada: a delta that
changes nothing has no use, so no empty form is provided.

The `array_delta_aggregate` grammar is that of RFC `mandatory_square_brackets`
and remains bracketed and flat (`[A with delta 2 => 99]`): its associations are
index choices rather than a record-shaped component list, and arrays have no
empty-extension form to disambiguate. The delimiter alone now tells the reader
whether a delta aggregate is record-shaped or array-shaped.

If RFC `deep_delta_aggregates` is adopted, its extended association forms
(`A.B => ...`, `C [I].D => ...`) nest inside the inner braces without further
change: that RFC modifies the association list, this one the enclosing
delimiters.

## Qualified expressions and other contexts

RM 4.7 `qualified_expression` is unchanged: its second alternative references
`aggregate`, so the brace form flows through automatically.
`Point'{X => 1, Y => 2}` is a qualified record aggregate; `Integer'(A + B)`
keeps the parenthesised expression form, matching the Ada 2022 treatment of
`T'[...]`. Constructs defined in terms of `aggregate` or `record_aggregate`
(default expressions, generic actuals, aspect definitions, etc.) likewise
inherit the brace form without individual changes.

## Default `Put_Image` output for record types

Ada 2022 aligned the default image of composite types with aggregate notation
(RM 4.10, AI12-0020-1): arrays render with brackets, records with parentheses
(`(X =>  1, Y =>  2)`, `(NULL RECORD)`). Flare keeps that alignment: the
default `Put_Image` of a record type emits braces — `{X =>  1, Y =>  2}`, and
`{}` for a null record — so runtime images stay consistent with Flare source.
Note the seam: the default `Put_Image` is determined by the unit declaring the
type, so a type declared in a regular Ada unit keeps the parenthesised image
even when used from Flare code.

## Disambiguation summary

With all three delimiter RFCs applied:

| Expression                | Meaning in Flare                              |
| ------------------------- | --------------------------------------------- |
| `F ()`                    | Call to parameterless subprogram `F`          |
| `F (X => 1)`              | Call to subprogram `F` with named association |
| `(A + B)`                 | Parenthesised expression                      |
| `A [I]`                   | Index array or container `A`                  |
| `[1, 2, 3]`               | Array or positional container aggregate       |
| `["one" => 1]`            | Named container aggregate                     |
| `[V with delta 2 => 99]`  | Array delta aggregate                         |
| `{X => 1, Y => 2}`        | Record aggregate                              |
| `{42}`                    | Single-component positional record aggregate  |
| `{}`                      | Empty (null) record aggregate                 |
| `{Base with {X => 1}}`    | Extension aggregate                           |
| `{Base with {}}`          | Null extension aggregate                      |
| `{P with delta {X => 1}}` | Record delta aggregate                        |
| `Point'{X => 1, Y => 2}`  | Qualified record aggregate                    |

Braced forms still require normal Ada resolution to distinguish a record
aggregate from an extension aggregate and to resolve component names, but the
construct family is determined by the delimiter alone.

# Rationale and alternatives

Curly braces are the natural choice for record construction:

- They carry exactly the intended meaning in the languages most programmers come
  from: struct and object construction in C, C++, Rust, Go, C#, Java,
  JavaScript, and Zig.
- They complete a three-way visual split — call `()`, array or container `[]`,
  record `{}` — that lets a reader classify any construct without consulting
  declarations.

## The empty record aggregate is `{}`

Ada spells the empty aggregate `(null record)` because a parenthesised empty
form `()` was not available. Braces have no such constraint: `{}` is directly
expressible and mirrors the null array aggregate `[]`. Keeping `{null record}`
as a second spelling was considered and dropped since it reads as a leftover of
the parenthesised syntax.

## Nested component lists after `with`

The flat transliteration `{Base with A => 1, B => 2}` of Ada's extension
aggregate was this RFC's starting point. Two problems pushed toward the nested
form:

- Consistency of the empty forms. With `{}` adopted, the flat null extension
  would either keep `null record` (`{Base with null record}`), reintroducing the
  spelling plain aggregates just dropped, or be written `{Base with {}}`. This
  last case would be ambiguous in a flat grammar, because `{}` is also a legal
  positional component value (an empty record).
- Uniformity. In the nested form, `with` is always followed by a braced,
  record-shaped component list, and the empty and non-empty cases look alike:
  `{Base with {}}`, `{Base with {A => 1, B => 2}}`.

The known cost is visual: two levels of braces can make a flat value look
nested. `{Base with {A => 1, B => 2}}` builds one flat record, not a record
containing a record. Also allowing the flat list when it is non-empty
(`{Base with A => 1, B => 2}`), reserving the nested form for the empty case
that needs it, was considered and rejected: it would give the same aggregate two
spellings and make the empty and non-empty cases look different for no gain.
There is one syntax for every extension aggregate.

## Alternative: `{Base}` for the null extension

Rejected: it collides with the single-component positional record aggregate. For
a null extension `T` of a parent with a single component `C`, `{X}` could read
as the extension aggregate `{X with {}}` or as the record aggregate `{C => X}`
(record aggregates may list inherited components). Expected-type resolution
settles most cases, but an overloaded `X` becomes genuinely ambiguous. The
reserved word `with` also tells the reader the value is an extension of an
ancestor, not a wrapping of a component; Rust, the closest precedent, likewise
requires an explicit marker for functional update (`T { ..base }`, never
`T { base }`).

## Alternative: brace-delimited discriminant parts and constraints

RFC `mandatory_square_brackets` extended `[...]` to index constraints
(`String [1 .. 80]`) for declaration/use symmetry; the analogue here would be
`type Buffer {Size : Positive} is record ...` and
`subtype Small is Buffer {Size => 16};`. Rejected: discriminant parentheses
serve more roles than the aggregate symmetry covers (discriminant parts, subtype
constraints, per-object constraints), and a reader of `Buffer {Size => 16}`
would expect the braces to introduce component values, not discriminants.
Discriminant parts and constraints keep parentheses.

## Alternative: keep parentheses for record aggregates

The status quo of RFC `mandatory_square_brackets`. It leaves the delimiter
policy incomplete: `(X => 1, Y => 2)` still reads like a call's actual parameter
part, and single-component aggregates must stay named-only.

## Alternative: one delimiter for all aggregates

A single delimiter — `[...]` or `{...}` — for every aggregate would be simpler
to specify, but it erases the distinction between building an array or container
and building a record, and either direction contradicts Ada 2022, which
deliberately introduced `[]` for array and container aggregates while keeping
records parenthesised. It would also make the two delta forms visually identical
again.

# Drawbacks

- Migration effort: all existing Ada code using `(...)` for record-shaped
  aggregates must be updated before it compiles in pedantic Flare. The rewrite
  is purely syntactic and can be automated with the same tooling as RFC
  `mandatory_square_brackets`.
- A third delimiter family: readers must learn that Flare distinguishes three
  bracket pairs. We consider this a net win. The delimiter now carries
  information that previously required declaration lookup but it is a real
  difference from Ada tradition.

# Compatibility

Code using `{...}` for record-shaped aggregates is not valid Ada 2022. Code
using `(...)` for them must be updated to compile in pedantic Flare; in
non-pedantic Flare, both forms are accepted for backward compatibility.

Every legal Ada record-shaped aggregate maps to the brace form mechanically: the
delimiters change, `(null record)` becomes `{}`, `(Base with null record)`
becomes `{Base with {}}`, and the component lists of extension and delta
aggregates gain their inner braces. In the other direction, a single-component
positional aggregate such as `{42}` has no direct Ada equivalent and must be
rewritten in named notation, `(Value => 42)`.

# Prior art

Ada 2022 introduced `[...]` for array and container aggregates precisely to
reduce the overloading of `()` and improve readability (RM 4.3.3, RM 4.3.5).
Elsewhere, curly braces are the dominant record/struct construction syntax:

- C and C++: `struct Point p = {1, 2};`, `Point{.x = 1, .y = 2}`
- Rust: `Point { x: 1, y: 2 }`, delta analogue `Point { x: 5, ..base }`
- Go: `Point{X: 1, Y: 2}`
- C#: `new Point { X = 1, Y = 2 }`
- JavaScript/TypeScript: `{x: 1, y: 2}`, delta analogue `{...base, x: 5}`
