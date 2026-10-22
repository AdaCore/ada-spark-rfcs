- Feature ID: mandatory_curly_braces
- Start Date: 2026-08-13
- Status: Design

# Summary

This RFC makes a curly-brace syntax `{...}` mandatory for record aggregate
construction in pedantic Ada Flare:

1. Record aggregates: `{X => 1, Y => 2}`, `{1, 2}`, `{others => <>}`, and
   `{null record}` for the empty (null) record aggregate
2. Extension aggregates: `{Base with X => 1}`, `{Base with null record}`
3. Record delta aggregates: `{Base with delta X => 1}`

Extension and delta aggregates retain Ada's flat component lists after `with`;
only the enclosing delimiters change. The explicit `null record` spelling is
retained for empty records and null extensions.

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

| Operation                  | Ada syntax                   | Flare syntax               |
| -------------------------- | ---------------------------- | -------------------------- |
| Subprogram call            | `F (X => 1)`                 | `F (X => 1)`               |
| Array aggregate            | `(1, 2, 3)`                  | `[1, 2, 3]`                |
| Container aggregate        | `["one" => 1]`               | `["one" => 1]`             |
| Record aggregate           | `(X => 1, Y => 2)`           | `{X => 1, Y => 2}`         |
| Extension aggregate        | `(Base with X => 1)`         | `{Base with X => 1}`       |
| Record delta aggregate     | `(Base with delta X => 1)`   | `{Base with delta X => 1}` |
| Null record aggregate      | `(null record)`              | `{null record}`            |
| Null extension aggregate   | `(Base with null record)`    | `{Base with null record}`  |
| Single-component aggregate | `(F => X)` (named mandatory) | `{X}` or `{F => X}`        |
| Parenthesised expression   | `(A + B)`                    | `(A + B)`                  |

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
N : Nothing := {null record};
```

Positional and named associations, choices with `|`, `others`, the `<>` box, and
the `null record` spelling work exactly as in Ada. An empty record aggregate is
written `{null record}`; empty braces `{}` are not an aggregate syntax.

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

Extension aggregates use curly braces around the whole aggregate. The component
list after `with` remains flat, and a null extension retains `null record`.

**Ada:**

```ada
D : Derived := (Base_Value with Extra => 5);
E : Derived := (Base_Type with Extra => 5);
F : Derived := (Base_Value with null record);
```

**Flare:**

```ada
D : Derived := {Base_Value with Extra => 5};
E : Derived := {Base_Type with Extra => 5};
F : Derived := {Base_Value with null record};
```

The explicit `null record` spelling distinguishes a null extension from an
extension with one positional component whose value is an empty record:

```ada
A : T1 := {Base with null record};     --  null extension: nothing added
B : T2 := {Base with {null record}};   --  one positional component, an empty record
```

## Record delta aggregates

Record delta aggregates use curly braces around the whole aggregate, with a flat
list of named component updates after `with delta`.

```ada
--  Ada: (P with delta X => P.X + 1)
Moved : Point := {P with delta X => P.X + 1};

--  Array deltas stay flat and bracketed (mandatory_square_brackets):
Updated : Integer_Array := [A with delta 2 => 99];
```

The outer delimiter matches the shape of the base value — brackets for arrays,
braces for records. Both delta forms keep their association lists flat.

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
literals (`f"..."`). The proposed grammar allows brace aggregates inside an
interpolated expression, as in `f"origin is {Point'{X => 0, Y => 0}}"`.
Supporting this nesting requires changes to interpolation handling in both GNAT
and Libadalang.

## Grammar notation

In the grammar fragments below, quoted `'{'` and `'}'` are literal curly braces,
while unquoted `{` `}` retain their RM meaning of a repeated part.

## Record aggregates

RM 4.3.1 `record_aggregate` becomes:

```
record_aggregate ::= '{' record_component_association_list '}'

record_component_association_list ::=
  record_component_association {, record_component_association}
  | null record
```

The `null record` alternative is retained, so the empty record aggregate is
written `{null record}`. Exactly as `(null record)` in Ada, it is legal only
where there are no components to give values to.

The named-notation requirement for single-component aggregates is removed. That
rule exists only to keep `(X)` unambiguous as a parenthesised expression; inside
braces there is nothing to disambiguate. Ada 2022 sets the precedent: the
bracketed `positional_array_aggregate` accepts a single expression (`[X]`),
while the parenthesised form requires two (RM 4.3.3).

All other name resolution, legality, and dynamic semantics of RM 4.3.1 are
unchanged. Extension aggregates retain their existing permission for a single
positional component: `{Base with 42}` is legal, just as `(Base with 42)` was in
Ada. Record delta aggregates continue to require named associations, as in Ada.

## Extension aggregates

RM 4.3.2 `extension_aggregate` becomes:

```
extension_aggregate ::=
  '{' ancestor_part with record_component_association_list '}'
```

The `ancestor_part` syntax (an expression or a subtype mark) and all static and
dynamic semantics of RM 4.3.2 are unchanged. The component list remains flat,
including the `null record` alternative: `{Base with null record}` adds nothing,
while `{Base with {null record}}` adds one positional component whose value is
an empty record aggregate.

## Record delta aggregates

RM 4.3.4 `record_delta_aggregate` becomes:

```
record_delta_aggregate ::=
  '{' base_expression with delta record_component_association_list '}'
```

The component list is mandatory, nonempty, and named-only, exactly as in Ada;
the `null record` alternative is not permitted in a record delta aggregate.
These restrictions remove any need for additional braces around the list.

The `array_delta_aggregate` grammar is that of RFC `mandatory_square_brackets`
and remains bracketed and flat (`[A with delta 2 => 99]`). Record and array
delta aggregates therefore share the same flat structure, with the delimiter
alone telling the reader whether the base value is record-shaped or
array-shaped.

If RFC `deep_delta_aggregates` is adopted, its extended association forms
(`A.B => ...`, `C [I].D => ...`) appear in the flat association list without
further change: that RFC modifies the association list, this one the enclosing
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
(`(X =>  1, Y =>  2)`, `(NULL RECORD)`). Flare keeps that alignment: the default
`Put_Image` of a record type emits braces — `{X =>  1, Y =>  2}`, and
`{NULL RECORD}` for a null record — so runtime images stay consistent with Flare
source. Note the seam: the default `Put_Image` is determined by the unit
declaring the type, so a type declared in a regular Ada unit keeps the
parenthesised image even when used from Flare code.

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
| `{null record}`           | Empty (null) record aggregate                 |
| `{Base with X => 1}`      | Extension aggregate                           |
| `{Base with null record}` | Null extension aggregate                      |
| `{P with delta X => 1}`   | Record delta aggregate                        |
| `Point'{X => 1, Y => 2}`  | Qualified record aggregate                    |

Braced forms still require normal Ada resolution to distinguish a record
aggregate from an extension aggregate and to resolve component names, but the
construct family is determined by the delimiter alone.

# Rationale and alternatives

Curly braces are the natural choice for record construction:

- They carry exactly the intended meaning in the languages most programmers come
  from: struct and object construction in C, C++, Rust, Go, C#, JavaScript, and
  Zig.
- They complete a three-way visual split — call `()`, array or container `[]`,
  record `{...}` — that lets a reader classify any construct without consulting
  declarations.

## The empty record aggregate is `{null record}`

Retaining Ada's explicit `null record` spelling makes empty record values easier
to read, especially when nested. It also distinguishes a null extension
`{Base with null record}` from an extension with one empty-record component
`{Base with {null record}}`, without additional braces around the component
list.

The shorter `{}` spelling would mirror the null array aggregate `[]`, but using
`{Base with {}}` for a null extension would collide with an extension whose
single positional component is an empty record. Avoiding that ambiguity by
nesting all extension component lists adds visual complexity. The explicit
spelling is preferred, and `{}` is not provided as an alternative.

## Flat component lists after `with`

Extension aggregates retain Ada's flat component list because `null record`
already distinguishes the empty case from an empty-record component value.
Additional braces would make a flat extension look like a nested record value.

Record delta aggregates also retain flat lists. Their associations are named and
nonempty, so there is no empty-form ambiguity to resolve. This keeps their
structure consistent with array delta aggregates and the shared association
forms proposed by RFC `deep_delta_aggregates`. Consistency between the two delta
forms is a stronger reason than giving extension and delta lists extra braces.

## Alternative: `{Base}` for the null extension

Rejected: it collides with the single-component positional record aggregate. For
a null extension `T` of a parent with a single component `C`, `{X}` could read
as the extension aggregate `{X with null record}` or as the record aggregate
`{C => X}` (record aggregates may list inherited components). Expected-type
resolution settles most cases, but an overloaded `X` becomes genuinely
ambiguous. The reserved word `with` also tells the reader the value is an
extension of an ancestor, not a wrapping of a component; Rust, the closest
precedent, likewise requires an explicit marker for functional update
(`T { ..base }`, never `T { base }`).

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
enclosing delimiters change, while component lists and `null record` retain
their Ada spelling. In the other direction, a single-component positional
aggregate such as `{42}` has no direct Ada equivalent and must be rewritten in
named notation, `(Value => 42)`.

# Prior art

Ada 2022 introduced `[...]` for array and container aggregates precisely to
reduce the overloading of `()` and improve readability (RM 4.3.3, RM 4.3.5).
Elsewhere, curly braces are the dominant record/struct construction syntax:

- C and C++: `struct Point p = {1, 2};`, `Point{.x = 1, .y = 2}`
- Rust: `Point { x: 1, y: 2 }`, delta analogue `Point { x: 5, ..base }`
- Go: `Point{X: 1, Y: 2}`
- C#: `new Point { X = 1, Y = 2 }`
- JavaScript/TypeScript: `{x: 1, y: 2}`, delta analogue `{...base, x: 5}`
