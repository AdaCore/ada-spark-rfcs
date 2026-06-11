- Feature ID: mandatory_square_brackets
- Start Date: 2026-02-26
- Status: Design

# Summary

This RFC proposes to make the square-bracket syntax `[...]` mandatory for four
related constructs in pedantic Ada Flare:

1. Bracketed aggregate forms, namely array aggregates (including array delta
   aggregates) and Ada 2022 container aggregates: `[1, 2, 3]`, `[others => 0]`,
   `[Base with delta 1 => 99]`
2. Indexing, including array indexing, entry-family indexing (also in indexed
   entry calls), and generalized indexing: `A [I]`, `M [Row, Col]`,
   `Request [Medium]`, `Request [High] (T)`, `Vector [Position]`, `Map [Key]`
3. Array slices: `A [1 .. 3]`
4. The index list of array type definitions, entry family declarations, and
   index constraints in subtype indications:
   `type Foo is array [1 .. 2] of Positive;`,
   `entry Request [Priority] (D : Item);`,
   `subtype Line is String [1 .. 80];`

In Ada 2022, `[...]` is the preferred syntax for array aggregates, and GNAT already warns on the old parenthesised form `(...)`. This RFC extends the Ada 2022 direction to also cover indexing and array slices, making these forms a compile-time requirement in pedantic Flare.

Container aggregates already use square brackets in Ada 2022 and follow the same visual convention. Other aggregate forms, including record aggregates, extension aggregates, and record delta aggregates, are not covered by this RFC.

# Motivation

## Readability and visual clarity

In Ada, parentheses `()` carry several distinct meanings.

In calls, indexing, and other expressions:

- Subprogram call with arguments: `Sort (Buffer, Length)`
- Array indexing: `Buffer (I)`
- Entry-family indexing: `Request (Medium)`
- Indexed entry call: `Request (High) (T)`
- Generalized indexing: `Vector (Position)`, `Map (Key)`
- Array aggregate: `Buffer := (1, 2, 3)`

In declarations:

- Index list of an array type definition: `array (1 .. 2) of Positive`
- Index constraint in a subtype indication: `String (1 .. 80)`
- Family index of an entry declaration: `entry Request (Priority) (D : Item)`

When reading unfamiliar code, a reader cannot determine from syntax alone
whether `F (X)` is a function call, an array index, an entry-family index, or
user-defined indexing. They must consult the declaration of `F`.

Using square brackets for these access and construction forms separates them
from subprogram calls. This RFC does not make every bracketed construct
syntactically distinct from every other bracketed construct. Normal Ada name
resolution still distinguishes array indexing, entry-family indexing,
generalized indexing, slices, and aggregates. The important readability win is
that `()` remains the visual marker for calls, while `[]` marks the family of
indexing, slicing, and bracketed aggregate forms.

| Operation            | Ada syntax          | Flare syntax        |
| -------------------- | ------------------- | ------------------- |
| Subprogram call      | `F (X)`             | `F (X)`             |
| Array index          | `A (I)`             | `A [I]`             |
| Entry-family index   | `Request (Medium)`  | `Request [Medium]`  |
| Indexed entry call   | `Request (High) (T)` | `Request [High] (T)` |
| Generalized indexing | `Vector (Position)` | `Vector [Position]` |
| Generalized indexing | `Map (Key)`         | `Map [Key]`         |
| Array aggregate      | `(1, 2, 3)`         | `[1, 2, 3]`         |
| Array type definition | `array (1 .. 2) of Positive` | `array [1 .. 2] of Positive` |
| Index constraint     | `String (1 .. 80)`  | `String [1 .. 80]`  |

This aligns with the visual convention that most programmers already associate with square brackets from languages such as C, C++, Rust, Python, and Go, where `A[I]` denotes an index operation.

## Declaration and use symmetry

Extending the rule to array type definitions, index constraints, and entry
family declarations makes declarations mirror their use sites. The index list
introduced by `type Foo is array [1 .. 2] of Positive`, constrained by
`subtype Line is String [1 .. 80]`, or declared by
`entry Request [Priority] (D : Item)` is written between the same brackets
that appear at every use site: `Foo_Object [I]`, `Line_Object [I]`, and
`Request [High] (T)`.

## Alignment with Ada 2022

Ada 2022 introduced `[...]` as the preferred aggregate syntax for arrays (RM 4.3.3) and extended the notation to container aggregates more broadly (RM 4.3.5). GNAT already emits a warning when the old parenthesised form `(...)` is used for an array aggregate. This RFC extends the Ada 2022 decision by also using `[...]` for array access, entry-family access, and generalized indexing.

## Improving the result of RFC `parentheses_for_parameterless_calls`

RFC `parentheses_for_parameterless_calls` requires that all parameterless subprogram calls carry empty parentheses `()`. That migration is safe on its own, but this RFC makes the resulting code clearer. In Ada, the expression `Z (1)` can mean either "call the parameterless function `Z` and index the result at position `1`" or "index the array or container object `Z` at position `1`", depending on which declaration `Z` resolves to. Requiring `[...]` for indexing makes the two interpretations syntactically distinct in the migrated code. The shadowing case that might appear to permit such a remapping is discussed in RFC `parentheses_for_parameterless_calls` (Additional analysis section, example 2).

# Guide-level explanation

## Bracketed aggregate forms

In Flare, any array aggregate must be written with square brackets. The parenthesised form is a compile-time error in pedantic mode.

**Ada:**

```ada
V : Integer_Array := (1, 2, 3);
W : Integer_Array := (1 => 10, 2 => 20);
Z : Integer_Array := (others => 0);
U : Integer_Array := (V with delta 2 => 99);
```

**Flare:**

```ada
V : Integer_Array := [1, 2, 3];
W : Integer_Array := [1 => 10, 2 => 20];
Z : Integer_Array := [others => 0];
U : Integer_Array := [V with delta 2 => 99];
```

Container aggregates already use square brackets in Ada 2022. This RFC keeps
them aligned with the same visual rule, but does not otherwise change their
syntax or semantics.

The same bracketed literal can resolve to an array aggregate or to a container
aggregate depending on the expected type:

```ada
Array_Value  : Integer_Array       := [1, 2, 3];
Vector_Value : Int_Vectors.Vector  := [1, 2, 3];
Map_Value    : String_Integer_Maps.Map := ["one" => 1, "two" => 2];
```

Other aggregate forms keep their Ada delimiter syntax. In particular, record
aggregates, extension aggregates, and record delta aggregates are still written
with parentheses.

## Indexing and array slices

In Flare, indexing into an array, indexing an entry family, and taking an array
slice must also use square brackets.

**Ada:**

```ada
Element := Buffer (I);
Matrix (Row, Col) := 0;
Sub := Buffer (1 .. 3);
Request (Medium);
Request (High) (T);
```

**Flare:**

```ada
Element := Buffer [I];
Matrix [Row, Col] := 0;
Sub := Buffer [1 .. 3];
Request [Medium];
Request [High] (T);
```

In an indexed entry call, the family index is written between square brackets
while the actual parameters keep parentheses, so the two roles are
syntactically distinct.

The same rule applies to generalized indexing, where a tagged type provides
indexing through the `Constant_Indexing` or `Variable_Indexing` aspect.

**Ada:**

```ada
Element := Vector (Position);
Value := Map (Key);
Field := Table (Row, Column);
```

**Flare:**

```ada
Element := Vector [Position];
Value := Map [Key];
Field := Table [Row, Column];
```

This RFC only changes the delimiter used for existing generalized indexing. It does not introduce user-defined slicing for arbitrary containers.

## Array type declarations, index constraints, and entry families

The index list of an array type definition, the index constraint of a subtype
indication, and the family index of an entry declaration also use square
brackets, so that declarations mirror their use sites.

**Ada:**

```ada
type Foo is array (1 .. 2) of Positive;
type Buffer_Type is array (Positive range <>) of Byte;

subtype Line is String (1 .. 80);
Buffer : String (1 .. 80);

entry Request (Priority) (D : Item);
...
accept Request (P) (D : Item) do
```

**Flare:**

```ada
type Foo is array [1 .. 2] of Positive;
type Buffer_Type is array [Positive range <>] of Byte;

subtype Line is String [1 .. 80];
Buffer : String [1 .. 80];

entry Request [Priority] (D : Item);
...
accept Request [P] (D : Item) do
```

## Functions returning an indexable object

With both this RFC and RFC `parentheses_for_parameterless_calls` active, chained access becomes syntactically distinct by construction:

```ada
-- Ada: overloaded notation -- is Z a function call or an indexable object?
Y := Z (1);

-- Flare: distinct notation
Y := Z () [1];  -- Z is called as a parameterless function; result is indexed
Y := Z [1];     -- Z is an array or container object; indexed directly
```

# Reference-level explanation

The following grammar changes and clarifications are required.

## Aggregate forms

RM 4.3 defines `aggregate` as covering record aggregates, extension aggregates,
array aggregates, delta aggregates, and container aggregates. This RFC changes
only the array-shaped aggregate forms that can currently use parentheses:

- RM 4.3.3 `array_aggregate`
- RM 4.3.4 `array_delta_aggregate`

Container aggregates are also in scope as part of the bracketed aggregate
convention, but RM 4.3.5 already defines them with square brackets only. Record
aggregates, extension aggregates, and record delta aggregates are unchanged and
continue to use parentheses.

## Array aggregates

RM 4.3.3 `array_aggregate` becomes:

```
array_aggregate ::=
    positional_array_aggregate
  | null_array_aggregate
  | named_array_aggregate

positional_array_aggregate ::=
    '[' expression {, expression} [, others => expression] ']'
  | '[' expression {, expression}, others => <> ']'

null_array_aggregate ::= '[' ']'

named_array_aggregate ::= '[' array_component_association_list ']'
```

The enclosing delimiters for every array aggregate form are square brackets.
The internal component association syntax, including choices, iterated component
associations, `others`, and `<>`, is otherwise unchanged.

## Array delta aggregates

RM 4.3.4 `array_delta_aggregate` becomes:

```
array_delta_aggregate ::=
  '[' base_expression with delta array_component_association_list ']'
```

The `record_delta_aggregate` grammar is unchanged and remains parenthesized.

## Container aggregates

RM 4.3.5 `container_aggregate` is unchanged:

```
container_aggregate ::=
    null_container_aggregate
  | positional_container_aggregate
  | named_container_aggregate

null_container_aggregate ::= '[' ']'

positional_container_aggregate ::= '[' expression {, expression} ']'

named_container_aggregate ::= '[' container_element_association_list ']'
```

Container aggregate name resolution, legality, and dynamic semantics remain
those defined by Ada 2022 and the `Aggregate` aspect. This RFC includes
container aggregates only to make the bracketed aggregate convention explicit.

## Indexed components

RM 4.1.1 `indexed_component` becomes:

```
indexed_component ::= prefix '[' expression {, expression} ']'
```

The expression list syntax and all existing name resolution and legality rules
are unchanged. Since RM 4.1.1 covers both array components and entries in entry
families, both forms use square brackets in Flare:

```ada
Element := Buffer [I];
Request [Medium];
```

## Generalized indexing

RM 4.1.6 `generalized_indexing` becomes:

```
generalized_indexing ::=
  indexable_container_object_prefix square_bracket_actual_parameter_part

square_bracket_actual_parameter_part ::=
  '[' parameter_association {, parameter_association} ']'
```

The parameter association syntax is unchanged; only the delimiters change from
`(` ... `)` to `[` ... `]`. The existing rules for choosing
`Constant_Indexing` or `Variable_Indexing` continue to apply.

When a generalized indexing is interpreted as constant or variable indexing,
`Container [Args]` is equivalent to a call on the corresponding prefixed view,
with `Args` passed as the normal actual parameters:

```ada
Container [Args]
-- equivalent to:
Container.Indexing (Args)
```

where `Indexing` is the name specified by the `Constant_Indexing` or
`Variable_Indexing` aspect.

## Slices

RM 4.1.2 `slice` becomes:

```
slice ::= prefix '[' discrete_range ']'
```

The existing slice semantics are unchanged: after any implicit dereference, the
prefix still has to resolve to a one-dimensional array type. This RFC does not
introduce user-defined slicing or container slicing.

## Array type definitions

RM 3.6 `unconstrained_array_definition` and `constrained_array_definition`
become:

```
unconstrained_array_definition ::=
  array '[' index_subtype_definition {, index_subtype_definition} ']'
    of component_definition

constrained_array_definition ::=
  array '[' discrete_subtype_definition {, discrete_subtype_definition} ']'
    of component_definition
```

Only the delimiters around the index list change. The
`index_subtype_definition`, `discrete_subtype_definition`, and
`component_definition` syntax, and all static and dynamic semantics of RM 3.6,
are unchanged.

## Index constraints

RM 3.6.1 `index_constraint` becomes:

```
index_constraint ::= '[' discrete_range {, discrete_range} ']'
```

The discrete range syntax and all static and dynamic semantics of RM 3.6.1 are
unchanged.

## Entry families

In the grammar fragments below, quoted `'['` and `']'` are literal square
brackets, while unquoted `[` `]` retain their RM meaning of an optional part.

RM 9.5.2 `entry_declaration` becomes:

```
entry_declaration ::=
  [overriding_indicator]
  entry defining_identifier ['[' discrete_subtype_definition ']']
    parameter_profile
    [aspect_specification];
```

RM 9.5.2 `accept_statement` becomes:

```
accept_statement ::=
  accept entry_direct_name ['[' entry_index ']'] parameter_profile [do
    handled_sequence_of_statements
  end [entry_identifier]];
```

RM 9.5.3 `entry_call_statement` is unchanged:

```
entry_call_statement ::= entry_name [actual_parameter_part];
```

When the entry name denotes an entry of an entry family, the name is an
`indexed_component` and therefore uses square brackets under this RFC (RM 4.1.1
above), while the `actual_parameter_part` keeps parentheses:

```ada
Request [High] (T);
```

## Disambiguation summary

After applying both this RFC and RFC `parentheses_for_parameterless_calls`, the following table holds:

| Expression               | Meaning in Flare                                |
| ------------------------ | ----------------------------------------------- |
| `F ()`                   | Call to parameterless subprogram `F`            |
| `F (X)`                  | Call to subprogram `F` with argument `X`        |
| `A [I]`                  | Index array `A` at position `I`                 |
| `Request [Medium]`       | Index entry family `Request`                    |
| `Request [High] (T)`     | Call entry `High` of family `Request` with `T`  |
| `Vector [Position]`      | Generalized indexing on container `Vector`      |
| `Map [Key]`              | Generalized indexing on container `Map`         |
| `A [1 .. 3]`             | Slice of array `A`                              |
| `F () [I]`               | Call `F`, then index the returned object at `I` |
| `[1, 2, 3]`              | Array or positional container aggregate         |
| `[others => 0]`          | Array aggregate with `others` choice            |
| `[V with delta 2 => 99]` | Delta array aggregate                           |

Bracketed forms still require normal Ada resolution to determine their exact construct.

# Rationale and alternatives

The repeated use of `()` in Ada for calls, indexing, and array aggregates imposes a cognitive load that square brackets eliminate for the forms covered by this RFC.

The design chosen here gives calls and bracketed forms distinct visual markers:

- `()` remains for subprogram and entry calls
- `[]` marks the family of indexing, array slicing, and bracketed aggregate forms

The contents of square brackets are not assumed to have a single type or a
single semantic role. For example, in a multidimensional array index such as
`Matrix [Row, Column]`, `Row` and `Column` may have different index types.
The justification for `[]` is the visual distinction between calls and the
family of bracketed access and construction forms.

This is a complete and consistent bracketing policy for the forms covered by
this RFC. Applying it to bracketed aggregate forms alone without indexing would
leave the most common overloaded notation (`Z (1)` as call-then-index vs. plain
index) unresolved. Applying it only to array indexing would leave entry-family
indexing and user-defined indexing visually indistinguishable from a call.

## Alternative: apply to bracketed aggregate forms only

Covering bracketed aggregate forms but not indexing is insufficient because
`Z (1)` would still be ambiguous. Requiring `[...]` for indexing makes the two
forms distinct.

## Alternative: apply to arrays only

Covering array indexing but not entry-family indexing or generalized indexing
would create a new split: arrays would use `A [I]`, while entry families and
user-defined containers would still use `Entry (I)` and `Container (I)`. This
would weaken the rule that `[]` means indexing and would continue to require
declaration lookup to distinguish generalized indexing from a subprogram call.

# Drawbacks

## Migration effort

All existing Ada code using `(...)` for array aggregates, `A (I)` for array
indexing, entry-family indexing, or generalized indexing, or `A (L .. R)` for
array slices must be updated before it compiles in pedantic Flare, as must
array type definitions, index constraints, and entry family declarations using
parenthesised index lists.

# Compatibility

Code already using `[...]` for array or container aggregates is valid Ada 2022 and requires no changes when migrating to pedantic Flare.

Code using `(...)` for array aggregates must be updated. In non-pedantic Flare, both forms are accepted for backward compatibility.

Code written with `A [I]` for array indexing, entry-family indexing, or
generalized indexing, or with bracketed index lists in array type definitions,
index constraints, and entry family declarations, is not valid Ada 2022 and
will not compile with a standard Ada 2022 compiler. In non-pedantic Flare, the
parenthesised Ada 2022 forms continue to be accepted.

# Open questions

None at this stage.

# Prior art

## Ada 2022 array aggregates

Ada 2022 introduced `[...]` as the preferred form for array aggregates (RM 4.3.3) and extended the notation to container aggregates (RM 4.3.5). This was a decision to improve readability and reduce the overloading of `()`. This RFC extends this decision with a natural complement: indexing and slicing.

## Other languages

The convention of using `[I]` for array and container indexing is common across languages. Examples include C, C++, Rust, Go, Python, Swift, JavaScript, TypeScript.
