- Feature ID: `tuples`
- Start Date: 2026-08-14
- Status: Proposed

Summary
=======

Flare gains *tuples*: anonymous record types, written with braces, whose identity
is structural. A tuple type is a component list without a type name —
`{Integer; Integer}`, or with optional component names for documentation,
`{Quotient, Remainder : Integer}`. A tuple value is a positional brace aggregate,
`{1, 2}`. Tuples are consumed by *decomposing* them into named objects, either into
existing ones (`{C, D} := Divide (X, Y);`) or by declaring them on the spot
(`{Q, R : Integer} := Divide (X, Y);`). Decomposing also works on records, so a
function returning a declared record can be decomposed the same way. A tuple
value may be assigned to any record whose components match positionally, which
makes a tuple a *deferred aggregate* — a composite that has not yet chosen its
nominal type. A tuple type may also be a parameter type, so a tuple can be passed
whole from producer to consumer, and an *decomposition association*
`P (Id => K, {B, C} => F)` spreads one tuple across several formals of a call.
Finally, a *component group* `R.{A, B}` denotes the tuple of two or more components
of one object, readable and writable, giving the imperative counterpart to delta
aggregates.

Because each component of a tuple result is built in place exactly as a single
function result is, a function may return several values whose sizes it chooses
itself — `{String; String}` — which no combination of `out` parameters can express.

Motivation
==========

Returning more than one value from a function is one of the oldest ergonomic
complaints about Ada, and every workaround costs something.

`out` parameters force the operation to be a procedure, which excludes it from
expressions, from contracts, and from `constant` initializations:

```ada
procedure Divide (X, Y : Integer; Quotient, Remainder : out Integer);
--  cannot appear in an expression, an aspect, or a declaration
```

Declaring a record for the result works, but the type is pure overhead when the
value exists only to be taken apart one line later, and it pollutes the package
specification with a name nobody wants to use:

```ada
type Division_Result is record
   Quotient, Remainder : Integer;
end record;

function Divide (X, Y : Integer) return Division_Result;

R : constant Division_Result := Divide (A, B);
Q : constant Integer := R.Quotient;   --  three declarations to get two values
Rem_ : constant Integer := R.Remainder;
```

The result is that Ada programmers systematically choose the worse of the two:
`out` parameters, because at least they do not require a type declaration. That
pushes computations out of expression context, which in turn works against
contract-based programming — a `Post` cannot mention the second result of a
procedure as an expression.

Several results of callee-determined size
-----------------------------------------

The case above is ergonomic: the values could be returned, just not pleasantly.
There is a second case where the cheap workaround stops working altogether.

Ada can already return *one* value whose size the callee chooses, because a
function result is built in place:

```ada
function Head (S : String) return String;   --  length decided by Head
```

It cannot return two. And the workaround Ada programmers reach for first — `out`
parameters — is categorically unable to substitute:

```ada
procedure Split (Line : String; Sep : Character; Key, Value : out String);
```

An `out String` is an already-constrained object supplied by the caller, so the
caller must know both lengths *before* the call — which is precisely what it called
`Split` to find out. For constrained results, `out` parameters are an ugly but
working escape hatch. For results whose size the callee determines, there is no
escape hatch at all.

Everything that remains charges something real:

- **A discriminated record** works, but the lengths become part of a declared
  type, must be computed a second time as discriminant values, and a new such type
  is needed for every shape anyone ever returns:

  ```ada
  type Split_Result (Key_Len, Value_Len : Natural) is record
     Key   : String (1 .. Key_Len);
     Value : String (1 .. Value_Len);
  end record;

  function Split (Line : String; Sep : Character) return Split_Result;
  ```

- **`Unbounded_String`, or `Indefinite_Holders`,** move both results to the heap.
  That rules the operation out of exactly the contexts Flare cares most about —
  bare-metal and certified code, where the heap and the secondary stack are often
  excluded by policy.

- **Two separate functions**, `Key_Of` and `Value_Of`, parse the line twice.

With tuples the callee returns both, and the declaring form gives the caller two
properly sized objects with their own names:

```ada
function Split (Line : String; Sep : Character) return {Key, Value : String};
...
{Key, Value : String} := Split (Line, ':');
```

No type declaration, no discriminants, no heap. Each component is built in place
exactly as a single `String` result is today, and each declared object is
constrained by its initial value exactly as `S : String := F;` already is. Nothing
new is asked of the runtime; the existing mechanism is used twice.

This is also the case where the *declaring* form of the decomposition is not a
convenience but a necessity. An unconstrained object cannot be declared without an
initial value, so without `{Key, Value : String} := Split (…);` there would be
nowhere to put the results — which is why decomposing and multiple unconstrained
returns have to be designed together.

Nor is the gain confined to strings. Any indefinite subtype qualifies:
unconstrained arrays, class-wide types (`{Shape'Class; Shape'Class}`), and Flare's
own `Definite` arrays — which, being definite, make the enclosing tuple definite
and therefore storable as well as returnable.

Three further gaps motivate the rest of this proposal:

- **Swapping and rotating.** `A, B := B, A` has no Ada spelling. Every Ada
  programmer writes a temporary, and AI22-0164-2 is currently proposing dedicated
  `=<` and `>=<` operators for move and swap in Ada 202y.

- **Updating several components of one object.** Flare already provides the
  functional form via deep delta aggregates,
  `R2 := (R with delta A => 1, B => 2);`, but there is no imperative form: you
  write two assignment statements, and nothing states that they belong together.

- **Groups of components have no type.** There is no record type for "just `A` and
  `B` of `R`", and there cannot be one, because such a type would have to be
  declared for every group anyone ever wants. This is the case that *requires*
  anonymous product types: multiple results can always be expressed with a declared
  record, at the costs set out above, but a component group cannot be expressed at
  all.

Guide-level explanation
=======================

A tuple type
------------

A tuple type is a component list in braces. It has no name:

```ada
{Integer; Integer}
{Float; Float; Boolean}
```

Components may be given names, which serve the same purpose as formal parameter
names — they document the result and appear in the specification, but they are
*not* part of the type:

```ada
function Divide (X, Y : Integer) return {Quotient, Remainder : Integer};
function Split  (S : String)     return {Name : String; Age : Natural};
```

`{Quotient, Remainder : Integer}` and `{Integer; Integer}` are the same type.

Both separators appear in a tuple type, with the same two roles they have in a
record component list:

- `;` separates **component declarations**, and is therefore what you need
  whenever the components have different subtypes: `{Integer; Float}`,
  `{Name : String; Age : Natural}`.
- `,` separates **identifiers within one declaration**, which share a subtype:
  `{A, B : Integer}`.

So a two-component tuple of `Integer` is written `{Integer; Integer}` when the
components are unnamed and `{A, B : Integer}` when they are named.
`{Integer, Integer}` is not a tuple type — a comma may only separate identifiers,
and `Integer` there would be read as an identifier being declared, not as a
subtype mark.

A tuple value
-------------

A tuple value is a positional brace aggregate:

```ada
function Divide (X, Y : Integer) return {Quotient, Remainder : Integer} is
begin
   return {X / Y, X rem Y};
end Divide;

function Split (S : String) return {Name : String; Age : Natural} is
begin
   return {Field (S, 1), Natural'Value (Field (S, 2))};
end Split;
```

A value is always comma-separated, whatever the type looks like, because it is an
aggregate rather than a declaration: components are being *listed*, not
*declared*. So `{Name : String; Age : Natural}` — semicolon, because the subtypes
differ — takes the value `{"Ada", 36}`, with a comma. This is exactly the relation
a record component list has to a record aggregate; the brace notation changes
nothing about it.

The one place the two lists can look alike is a decomposition, which comes in both
flavours (see below): `{C, D} := X;` lists existing objects, so commas, while
`{A : Integer; B : Float} := X;` declares them, so semicolons.

Decomposing
-----------

A tuple is consumed by *decomposing* it. If the objects already exist, a decomposition is
an assignment statement:

```ada
Q, R : Integer;
...
{Q, R} := Divide (A, B);
```

If they do not, the decomposition declares them — and the syntax of the declaration is
simply the tuple type, so what you write on the left is what you would have
written as the result type:

```ada
{Q, R : Integer} := Divide (A, B);
```

Because Flare allows a basic declarative item wherever a statement may appear, this
needs no enclosing block. Add `constant` where you want it:

```ada
{Q, R : constant Integer} := Divide (A, B);
```

Use `<>` to discard a component you do not need, in either form:

```ada
{Q, <>} := Divide (A, B);              --  Q already declared
{Q : Integer; <>} := Divide (A, B);    --  declaring Q, discarding the rest
```

Decomposing reads components; there is no other way to read part of a tuple. There
is no `.1`, no `.Quotient`, no selection of any kind — a tuple is either decomposed,
assigned whole, or compared. If you want to name and keep one field out of many,
that is what records are for.

Records decompose too
---------------------

The same notation decomposes a record, so the declared-record style keeps working
and gets shorter:

```ada
type Division_Result is record
   Quotient, Remainder : Integer;
end record;

function Divide (X, Y : Integer) return Division_Result;

{Q, R : Integer} := Divide (A, B);   --  positional decomposition of a record
```

Several results of callee-determined size
-----------------------------------------

Because a tuple component is built in place just as a single function result is, a
function may return several values whose sizes it chooses itself — which no
combination of `out` parameters can express:

```ada
function Split (Line : String; Sep : Character) return {Key, Value : String};
...
{Key, Value : String} := Split (Line, ':');
Put_Line (Key & " = " & Value);
```

`Key` and `Value` are ordinary `String` objects, each constrained by its initial
value, with no discriminants, no holder type and no heap. The declaring form of the
decomposition is what makes this work: an unconstrained object cannot be declared without
an initial value, so this is the only place the results can land.

Tuple parameters
----------------

A tuple type may be a parameter type, which is what lets a tuple travel from the
subprogram that produced it to the one that consumes it without being taken apart
and put back together:

```ada
function  Divide (X, Y : Integer) return {Quotient, Remainder : Integer};
procedure Report (Result : {Integer; Integer});

Report (Divide (A, B));            --  passed straight through
```

Without tuple parameters that call would have to be written as a decomposition followed
by a recompose:

```ada
{Q, R : Integer} := Divide (A, B);
Report ({Q, R});                   --  two statements, two names nobody wanted
```

The formal's component names need not match the actual's — `Report` names nothing,
`Divide` names its components `Quotient` and `Remainder`, and they are the same
type — because names are not part of a tuple type.

Decomposing into a call
-----------------------

Sometimes the consumer does not take a pair; it takes two separate parameters. An
*decomposition association* spreads one tuple across several formals of a call:

```ada
procedure Store (Id : Key_Type; Quotient, Remainder : Integer);
...
Store (Id => K, {Quotient, Remainder} => Divide (A, B));
```

The braces group formal parameter names, and the tuple's components are matched to
them positionally, left to right. This is what a call looks like when a producer
and a consumer agree on the values but not on how they are packaged, and it saves
the same compose/decompose round trip:

```ada
--  without the decomposition association
{Q, R : Integer} := Divide (A, B);
Store (Id => K, Quotient => Q, Remainder => R);
```

A decomposition association is a form of named notation, so it goes with the other named
associations, and the formals it names may appear in any order:

```ada
Store ({Remainder, Quotient} => Swap_Halves (A, B), Id => K);
```

A whole call can be supplied this way when the arity matches:

```ada
Store ({Id, Quotient, Remainder} => Compute_Everything (A, B));
```

The distinction between the two features is worth keeping in view: a **tuple
parameter** passes the tuple *whole* to a formal that expects a tuple, while an
**decomposition association** *spreads* it across formals that expect ordinary values.

Tuples assign to records
------------------------

A tuple value may be assigned to a record whose components match, so an anonymous
result can be captured in a named type without an intermediate:

```ada
function Divide (X, Y : Integer) return {Integer; Integer};

Result : Division_Result;
...
Result := Divide (A, B);
```

A tuple is therefore best understood as a *deferred aggregate*: a composite value
that has not yet been told which nominal type it belongs to. `{1, 2}` against a
record target is already an aggregate of that record; this rule extends the same
courtesy to a value whose type happens to be a tuple.

Swapping
--------

Swap and rotate fall out, because the right-hand side is evaluated before anything
is written:

```ada
{A, B} := {B, A};
{A, B, C} := {C, A, B};
```

Component groups
----------------

`R.{A, B}` denotes the tuple of components `A` and `B` of the object `R`. It is a
view: it can be read and written.

```ada
R.{X, Y} := {1, 2};          --  assign two components at once
R.{X, Y} := R.{Y, X};        --  swap two components of one object
{H, W : Integer} := R.{Height, Width};
```

This is the imperative counterpart to the delta aggregate. Where you would write

```ada
R2 := (R with delta X => 1, Y => 2);
```

to produce a new value, you now write

```ada
R.{X, Y} := {1, 2};
```

to update in place, and the grouping is visible to the reader and to the compiler
rather than being implied by two adjacent statements.

Reference-level explanation
===========================

Syntax
------

Note on notation: the Ada reference manual's grammar metasyntax already uses `{`
and `}` for "zero or more". The wording will therefore need a convention for
literal braces; below, literal braces are shown in bold as **{** and **}**.

```
tuple_definition ::= **{** tuple_component_list **}**

tuple_component_list ::= tuple_component {; tuple_component}

tuple_component ::= [defining_identifier_list :] subtype_indication
```

A `tuple_definition` may appear anywhere a `subtype_mark` may appear: function
result types, parameter subtypes, object subtypes, record and array component
subtypes, and generic actual parameters. Component names are optional per
component; they may be mixed with unnamed components, though a specification is
clearer if it names all or none.

A `tuple_definition` is **not** a `type_definition`, so

```ada
type Pair is {Integer; Integer};   --  illegal in this proposal
```

is not permitted. Naming a tuple type would immediately raise whether the name is
a synonym or a distinct nominal type, which is a different feature — see *Future
possibilities*. A subtype declaration is allowed, because a subtype never
introduces a type and the synonym cannot disturb structural identity:

```ada
subtype Pair is {Integer; Integer};   --  legal: a synonym, same type
```

The aggregate form reuses the brace aggregate; a tuple aggregate is always
positional (see *Resolution* below).

Decomposing adds one statement form and one declaration form:

```
decomposition_assignment ::= **{** decomposition_target {, decomposition_target} **}** := expression;

decomposition_target ::= name | <>

decomposition_declaration ::= **{** decomposition_declared_item {; decomposition_declared_item} **}**
                         := expression;

decomposition_declared_item ::= defining_identifier_list : [constant] subtype_indication
                       | <>
```

`decomposition_declared_item` is deliberately `tuple_component` plus `constant` and `<>`:
the left-hand side of a declaring decomposition is the tuple type you would have written
as the result type. The separators therefore behave identically — `{A, B : Integer}`
is one declared item introducing two objects, `{A : Integer; B : Float}` is two —
and `{Q : Integer; <>}` discards the second component.

The two forms are distinguished by the presence of a subtype indication:
`{C, D} := X;` assigns to existing objects, `{C, D : Integer} := X;` declares new
ones. A decomposition whose targets are not declared and which supplies no subtype is
illegal — there is no implicit declaration.

Component groups extend `selected_component`:

```
component_group ::= prefix . **{** selector_name {, selector_name} **}**
```

Calls gain one form of `parameter_association`:

```
decomposition_association ::= **{** formal_parameter_selector_name
                             {, formal_parameter_selector_name} **}**
                       => explicit_actual_parameter
```

Type identity and predefined operations
---------------------------------------

The type of a `tuple_definition` is determined by the ordered list of component
subtypes. Two tuple definitions with the same component subtypes in the same order
denote the same type; component names play no part. This is Flare's second
structural construct, after structural generic instantiation.

Predefined `=`, `/=`, assignment and `'Image` are compiler-generated
component-wise, exactly as they are for record types. There is no library type
behind a tuple: a tuple type is anonymous in the same sense an anonymous access
type is, and in particular it is **not** an instantiation of any `Ada.Tuples_N`.
Two independent reasons make the library route impossible rather than merely
unattractive: a generic cannot take component *names* as parameters, so
`{Quotient, Remainder : Integer}` has no rendering as an instantiation; and a
generic instance would have to be a record, which cannot have unconstrained array
components, so `{String; String}` could not be expressed at all.

One consequence must be stated plainly: because Ada generics are not variadic,
**no user-written generic can range over tuple arity**. Any operation that must
work for tuples of every arity has to be compiler-generated. This is why `=` and
`'Image` are predefined rather than library-provided, and it bears on the
`To_String` framework (see *Open questions*).

Where a tuple type may appear
-----------------------------

Anywhere a subtype mark may appear: function result types, parameter types,
object declarations, record and array components, generic actuals. No new
categories are needed, because a tuple inherits its properties from its
components:

- A tuple type is **definite** if and only if every component subtype is definite.
  `{Integer; Integer}` is definite and may be a record component. `{String;
  String}` is indefinite and therefore carries exactly the restrictions `String`
  already carries: legal as a function result type, legal as an object subtype
  when an initial value constrains it, illegal as a record component.
- A tuple type is **limited** if any component is limited, **controlled** if any
  component is controlled, and by-reference if any component is by-reference.
- `'Size`, `'Alignment` and representation are implementation-defined as for an
  equivalent record type. No representation clauses may be given, since the type
  has no name; a program that needs to control layout should declare a record.

Because decomposing is the only way to read part of a tuple, a tuple object is
useful chiefly for passing a group of values along. That is a deliberate
consequence, not an oversight.

Resolution
----------

A brace aggregate classifies itself, which keeps resolution to a single rule:

- An aggregate containing **any named association** requires a nominal expected
  type. It is never a tuple. This follows from component names not being part of
  a tuple type: there is nothing for `A => 1` to name.
- A **purely positional** aggregate resolves to the expected type if there is
  one, and to a tuple otherwise.

A qualified expression forces the nominal reading where an aggregate would
otherwise be a tuple: `Division_Result'{1, 2}`.

The tuple always exists as a fallback, so there is no context in which a
positional brace aggregate has no meaning. This is deliberately unlike
AI22-0158-1, which gives range notation a record meaning derived solely from the
expected type: because a range has no canonical value type to fall back on, that
rule makes `Size => 10 .. 20` legal and meaningless. Here both readings are
sensible, and the reader can always see the nominal type because it is named at
the target.

Decomposition
-------------

For `{T1, ..., Tn} := E;`:

1. `E` is evaluated in full before any target is modified. `E` may be of a tuple
   type, or of a record type whose full view is visible at the point of the
   decomposition.
2. `E` must have exactly `n` components. Each target is matched positionally.
   `<>` targets are matched and discarded; the corresponding component of `E` is
   still evaluated.
3. Each non-discarded component is assigned to its target in positional order,
   which for a controlled or class-record target means a call to `'Assign`.
   Subtype conformance is checked per component as in any assignment.

Because `'Assign` is implicitly `No_Raise` in Flare, a decomposition cannot be left
half-applied by a propagating exception from an assignment operation; this is what
makes multiple-target assignment safe to specify at all.

For the declaration form, the declared objects are elaborated in positional order
and each is initialized from the corresponding component. The declaration is a
basic declarative item, so it may appear wherever a statement may appear; its
scope extends to the end of the enclosing sequence of statements, per the existing
Flare rule for local declarations without blocks. **That rule's enumeration of
permitted declarative items must be extended to include the decomposition declaration.**

Tuple parameters
----------------

A tuple type may be the subtype of a formal parameter of any mode; nothing special
is required, since the tuple inherits its passing properties component-wise like
any composite. Two points follow from names not being part of the type:

- the component names of the formal's tuple type and of the actual's need not
  agree, and either may name none;
- a tuple parameter cannot be given a named actual for one of its components.
  `Report (Result => {1, 2})` supplies the whole tuple positionally, as an
  aggregate; there is no `Report (Result.Quotient => 1)`.

Decomposition associations in calls
-----------------------------------

For an `decomposition_association` `{F1, ..., Fn} => A` in a call:

1. Each `Fi` must denote a distinct formal parameter of the callee, of mode `in`,
   not named or covered by any other association in the call. Modes `out` and
   `in out` are excluded because they would require writing results back into the
   components of `A` — the opposite direction, and not proposed here (see *Future
   possibilities*).
2. `A` must be of a tuple type, or of a record type whose full view is visible at
   the point of the call, with exactly `n` components — the same set of sources an
   decomposition accepts.
3. Components of `A` are matched to `F1 .. Fn` positionally in the order written,
   which need not be the formals' declaration order. Each must satisfy its
   formal's subtype exactly as an ordinary actual does.
4. `A` is evaluated once.
5. An `decomposition_association` is a named association. The existing rule that all
   positional associations precede all named ones therefore applies to it, and it
   may appear in any position among the named associations.
6. The existing parameter-coverage rules are unchanged, counting a formal named
   inside a decomposition association as supplied. Formals not supplied by any
   association take their defaults as usual.
7. `decomposition_association` is permitted in subprogram calls and entry calls, including
   prefixed-view calls. It is **not** permitted in generic instantiations: a
   `generic_association` binds a type or a static entity rather than passing a
   run-time value, so there is nothing for a tuple to distribute.

Assignment from a tuple to a record
-----------------------------------

An expression of a tuple type is acceptable where a record type `R` is expected —
in an assignment, an object initialization, or an `in` parameter — when:

1. the number of components is equal;
2. each tuple component type is *the same type* as the corresponding component of
   `R`, matched positionally. Convertibility is deliberately not enough:
   positional matching is precisely the context in which a silent numeric
   conversion is most dangerous;
3. the **full view of `R` is visible** at the point of the assignment. Without
   this restriction a client of a private type could learn its component
   structure by writing `Obj := F;`, which would be a hole in privacy rather than
   a convenience. This is the same restriction record aggregates already carry;
4. `R` has no discriminants and no variant part, and is not a class record. These
   are excluded in this proposal rather than forbidden in principle; see *Future
   possibilities*.

Subtype constraints are checked at run time as in any assignment.

Component groups
----------------

`P.{S1, ..., Sn}` where `P` is a prefix denoting an object of a record type:

- each `Si` must be a distinct component of that type, visible at that point.
  Repeating a component is illegal, as repeating a choice in an aggregate is.
- The group denotes a value of the tuple type formed from the components' subtypes
  in the order written — which need not be declaration order.
- As a target, the right-hand side is evaluated in full before any component is
  written, then components are written in the order listed. This is what makes
  `R.{X, Y} := R.{Y, X};` a swap.
- The group is a variable view if the prefix is a variable, a constant view
  otherwise.
- A component group may not be renamed or have `'Access` taken of it: it is not a
  single object.

Rationale and alternatives
==========================

Why braces
----------

`{` and `}` are not delimiters in Ada — RM 2.1 classifies them as
`special_character`, legal inside string literals and comments and nowhere else.
The notation is therefore free in every position at once: type, aggregate, decomposition
target, and component group.

Parentheses were considered and rejected. `(A, B)` is already a positional record
aggregate, so a parenthesized tuple literal could only be resolved by expected
type, with no canonical fallback — the AI22-0158-1 failure mode. And `(A)` cannot
be distinguished from a parenthesized expression, so one-element tuples would be
unreachable; Rust has to write `(x,)` for exactly this reason.

Braces also complete a bracket story Flare has already begun: `()` for grouping
and calls, `[]` for arrays and containers, `{}` for aggregates — of which a tuple
is the anonymous case.

Why no component selection
--------------------------

Every other statically typed language with tuples provides a positional selector:
`.0` in Rust and Swift, `._1` in Scala, `std::get<0>` in C++, `fst`/`snd` in ML.
Flare does not, because in this design a tuple exists in order to be decomposed, and
a selector would create a second, worse way to do the same thing — worse because
`T.2` carries no information about what the component means. The cost is that
`Divide (A, B).Remainder` must be written as a decomposition on the preceding line. The
benefit is that a tuple has exactly one consumption form and the type stays
genuinely anonymous: with no names in the type, a named selector would have to
depend on the declared subtype rather than the type, so two expressions of the
same type would admit different selectors.

Why names are not part of the type
----------------------------------

If the names were part of the type, `{Quotient, Remainder : Integer}` and
`{Integer; Integer}` would be different types and every consumer would have to
spell the names to interoperate — reintroducing exactly the nominal-declaration
burden the feature exists to remove. Treating them as formal-parameter-like
documentation keeps the type structural while letting a specification say what it
returns. Swift makes labels participate and pays for it with intricate
label-matching conversion rules; C# erases them and had to add mismatch
diagnostics anyway. Both directions have a known wart; this one is at least
simple to state.

Why `A2, B2 : Integer := X;` is not the decomposition syntax
------------------------------------------------------------

An attractive-looking alternative is to let a multiple-object declaration
decompose:

```ada
A2, B2 : Integer := X;   --  proposed meaning: decomposition X into A2 and B2
```

This must be rejected. RM 3.3.1(7) already makes a multiple-object declaration
equivalent to a series of single declarations, so this text has a meaning today:
`X` is evaluated **once per object**, twice in total. Under the decomposition reading it
would be evaluated once and split. Same source text, two different behaviours,
both legal, with nothing in the syntax to indicate which is in force — the answer
would depend on the result type of `X`, possibly through overload resolution. That
is the worst class of incompatibility: silent, and invisible at the point of use.
Braces are therefore mandatory on every decomposition. The cost is two characters.

Why `R.{A, B}` and not `R {A, B}`
---------------------------------

Juxtaposition without the dot would put `R {A, B}` one apostrophe away from
`R'{A, B}`, and the two mean opposite things: a group of components *of an object*
versus an aggregate *of a type*. The selection dot states the intent — reach into
this object — composes with paths (`R.Inner.{A, B}`), and cannot be confused with
the qualified form.

Alternatives to the whole proposal
----------------------------------

**Destructuring over records only, with no anonymous types.** This is the Java
answer (record patterns, tuples explicitly refused on the grounds that a tuple is
a record that lost its name) and, in effect, the C++ answer (structured bindings
work on any aggregate, so `std::tuple` is not needed for multiple returns). It
would deliver the headline ergonomic win with no structural typing, no resolution
rule, and no indefinite-component question. It is rejected here for one reason:
component groups. `R.{A, B}` has no nominal type and cannot be given one, so an
anonymous product type is not a convenience in that case but a requirement. Since
tuple types must exist for component groups, using them for results as well costs
nothing further.

**Multiple return values that are not a type**, as in Go. Smallest possible
change, but a pair cannot then be stored, passed on, or put in a container, and
the restriction would have to be justified by fiat rather than falling out of
existing rules.

**A library type, `Ada.Tuples_N`.** Impossible as discussed under
*Reference-level explanation*: names cannot be generic parameters, and a record
instance cannot have unconstrained components. It would also reproduce the arity
wall every language that took this route has hit — Scala's `Tuple1`…`Tuple22`,
C#'s `ValueTuple<T1..T7>` plus `TRest`.

Fit with the philosophy of the language
---------------------------------------

The proposal is deliberately conservative in shape: the tuple type notation is a
record component list with the name removed, the value notation is a record
aggregate, the definite/indefinite and limited properties are inherited
component-wise from existing rules, and predefined operations are generated as they
already are for records. Nothing is introduced that Ada does not already have,
except the removal of the name.

The one genuine departure is structural typing, and it is confined: tuples are
anonymous, so there is no nominal type whose identity could be subverted, and
anything that persists can be given a record type, into which a tuple assigns
directly.

Drawbacks
=========

- **Structural typing does not type meaning.** A function returning
  `{Integer; Integer}` as (quotient, remainder) is interchangeable with one
  returning (x, y), and that type-checks. This is inherent to anonymity. It is
  mitigated, not solved, by the optional component names in specifications and by
  the fact that anything worth storing can be given a record type.
- **No selection** means `Divide (A, B).Remainder` needs a preceding decomposition. Every
  comparable language chose otherwise.
- **Positional decompositions do not scale.** At arity two a decomposition is clear; at arity
  six, with several components of the same type, a transposition is silent. See
  *Open questions* on a named decomposition form.
- **Another bracket pair.** Flare would use all three, and braces already mean
  interpolation inside `f"..."` strings.
- **A second way to write a call.** A decomposition association gives a call two
  spellings for the same effect, since the caller can always decomposition first and pass
  the results individually. That is the price of not forcing a compose/decompose
  round trip when producer and consumer disagree only about packaging.
- **No representation control.** A tuple type cannot carry representation clauses,
  since it has no name.
- **Compiler-generated operations only.** Anything generic over arity is out of
  reach without variadic generics.

Compatibility
=============

**Lexically additive, and therefore backward compatible.** `{` and `}` are not
tokens in Ada; they can appear today only inside string literals and comments,
which this proposal does not touch. No existing legal Ada program contains a brace
in a position this proposal gives meaning to, so no existing program changes
meaning.

The new syntactic forms — decomposition assignment, decomposition declaration, component group,
decomposition association — all occupy grammar slots that are currently empty. An Ada
assignment target is a `name`, and no name may begin with `{`; no
`selected_component` may have a brace after the dot; and a `parameter_association`
is either an expression, which cannot begin with `{`, or a `selector_name`
followed by `=>`, which cannot either.

`A2, B2 : Integer := X;` retains its current Ada meaning exactly, which is the
reason it is not used as the decomposition syntax.

The decomposition *declaration* depends on Flare's local declarations without blocks; in
a strict-Ada mode it would be legal only in a declarative part.

**Dependency.** This proposal assumes `{...}` is Flare's brace aggregate notation.
Whether `(...)` continues to be accepted for record aggregates is a separate and
much larger compatibility question, settled by the brace-aggregate proposal rather
than this one. This RFC is compatible with either answer: it needs only that a
positional brace aggregate exists and that named brace associations require a
nominal type.

**Feature set.** Additive, and should be part of the Flare feature set rather than
requiring an individual switch.

Open questions
==============

1. **A named decomposition form.** Should the component names in a specification be
   usable to decomposition order-independently?

   ```ada
   {Zip => Z, City => C} := Parse (Line);
   ```

   The value grows with arity, and it is the only available defence against
   transposing two same-typed components. The cost is that the names become part
   of the contract, so renaming one breaks callers — the status parameter names
   already have in Ada. Note that this is *not* a named aggregate: it is a named
   decomposition, on the left of `:=`, so it does not conflict with the rule that named
   brace associations require a nominal type.
2. **`To_String` for tuples.** Chapter 9's formatter framework is user-extensible
   Ada generic code, and no such code can range over arity. Either the compiler
   synthesizes `To_String` for tuples as it does `'Image`, or tuples are not
   printable through the framework. This needs deciding with the `To_String`
   owner.
3. **Deep paths in component groups.** Flare's deep delta aggregates already allow
   `A.B` on the left of an association, so `R.{A.B, C}` is a natural extension.
   Not proposed here.
4. **Array component groups.** `Arr.{1, 3} := {X, Y}` is conceivable but wants
   reconciling with slice notation first. Not proposed here.
5. **Arity 0 and 1.** `{X}` is unambiguous with braces and `{}` falls out of the
   resolution rule, but neither has a use case absent variadic generics. Allow for
   uniformity, or forbid?
6. **Mixed named and unnamed components** in one tuple type are permitted by the
   grammar above. Should they be?
7. **Interaction with the generalized case statement** (AI22-0153-1), which
   proposes aggregate choices with binding. If Flare pursues pattern matching,
   decomposing is a degenerate case of it and the two should share a syntax.

Prior art
=========

A note on terminology, since this proposal uses a different word from most of the
literature. What is called **decomposition** here is called *destructuring* in
Rust, Swift, Kotlin and JavaScript, *deconstruction* in C# (which provides
`Deconstruct` methods for it), *unpacking* in Python (both `a, b = t` and the
argument form `f(*t)`), *structured bindings* in C++, and falls under *pattern
matching* in ML and Erlang. "Decomposition" is preferred here because Ada already
defines **composite type** as a formal category and an aggregate *composes* a
value, so decomposition is the inverse operation named in the language's own
vocabulary; "unfold" was rejected because it already means the anamorphism in
recursion schemes, inlining in compilers, and the exposure of a recursive type in
type theory — the last of which AI22-0169-1 could make live in Ada.

| Language | Tuple type | Names in type | Selection | Decomposition | Arity limit |
|---|---|---|---|---|---|
| Go | no — multiple returns only | n/a | n/a | `q, r := div(a,b)` | none (not a type) |
| OCaml / Haskell | structural | no | `fst`/`snd` | pattern match | GHC instances stop ~15 |
| Rust | structural | no | `.0` | `let (q, r) = …` | std trait impls stop at 12 |
| C++ | `std::tuple` | no | `std::get<0>` | `auto [q, r] = …` | unbounded (parameter packs) |
| Scala | structural | no | `._1` | pattern match | `Tuple22` for years |
| Swift | structural | yes, optional | `.name`, `.0` | `let (q, r) = …` | unbounded since 5.9 |
| C# | structural | yes, erased | `.name` | `var (q, r) = …` | `ValueTuple<T1..T7>` + `TRest` |
| Java | refused | — | — | record patterns | n/a |

Lessons taken:

- **Arbitrary arity is free in the type system and expensive in a library.** Scala
  capped at 22, Rust's standard trait implementations stop at 12 so a 13-tuple
  silently loses its derived behaviour, GHC's instances stop around 15, and C#
  nests pairs past 7. Every one of these is a library artefact. Compiler-generated
  operations, as proposed here, have no such wall.
- **Name erasure leaks.** C# treats tuple element names as compile-time
  decoration, then had to add diagnostics for mismatched names on assignment,
  because programmers treat them as meaningful. This is evidence for the named
  decomposition in *Open questions*: the names end up load-bearing whether or not the
  language admits it.
- **Java's refusal is a real position, not an oversight.** "A tuple is a record
  that lost its name" is the strongest argument against this proposal, and the
  answer is component groups, which have no name to lose.
- **Rust's tuple structs** (`struct Bounds(u32, u32)`: nominal identity, positional
  unnamed components) are a middle road worth remembering — pair ergonomics with a
  name that stops it being confused with every other pair. See *Future
  possibilities*.
- **Destructuring need not imply tuples.** C++ structured bindings and Kotlin's
  `componentN()` convention destructure ordinary nominal types. This proposal takes
  that lesson by making decomposing work on records too.

Unresolved questions
====================

To resolve through the RFC process: the named decomposition form (question 1), whose
answer changes the syntax; and the `To_String` decision (question 2), which
depends on another feature's owner.

To resolve through implementation: the representation and calling convention of a
tuple result, in particular whether a tuple of two scalars is returned in
registers as a small record would be, and how a tuple with indefinite components
is built in place. Neither affects the language definition.

Out of scope, addressable independently: whether `(...)` survives for record
aggregates; deep and array component groups (questions 3 and 4); pattern matching
(question 7); relaxing the no-discriminant and no-variant restriction on
tuple-to-record assignment.

Future possibilities
====================

- **Pattern matching.** Decomposition is pattern matching with a single alternative that always matches. If Flare
  adopts a generalized case statement in the spirit of AI22-0153-1 — aggregate
  choices with identifier binding — decomposing should become the single-alternative
  case of it rather than a parallel mechanism. Designing the decomposition syntax with
  that in mind is cheap now and expensive later.
- **Tuple structs.** A record type with positional, unnamed components
  (`type Bounds is {Positive; Natural};` as a *named* type) would give nominal
  identity with tuple ergonomics, answering the structural-aliasing drawback
  directly. It is a small addition once tuple types exist.
- **Composition associations.** The mirror of the decomposition association: collecting several
  `out` parameters of one call into a single tuple object, `P (Id => K, T =< {B, C})`
  or similar. It is the natural completion of the feature, but it needs a direction
  marker in the syntax — `{B, C} => T` cannot mean both "spread `T` into `B` and
  `C`" and "collect `B` and `C` into `T`" — and it interacts with the move
  operators below. Deliberately left out here.
- **Move and swap.** AI22-0164-2 proposes `=<` and `>=<` for move and swap in Ada
  202y. `{A, B} := {B, A};` already covers the common swap case; if Flare pursues
  ownership and moves, the interaction should be examined before adopting new
  operators.
- **Variadic generics** would allow user code to range over arity, and are the
  only route to a library-provided operation over all tuples. Large, independent,
  and not required by anything here.
- **Discriminants and variants** in tuple-to-record assignment, excluded above,
  could be admitted once the matching rules for variant parts are worked out.
- **Container aggregates.** AI22-0134-1 proposes allowing both `Add_Named` and
  `Add_Unnamed` in one `Aggregate` aspect, motivated by JSON-shaped heterogeneous
  objects. That is the same pressure an anonymous aggregate relieves, and the two
  designs should be checked against each other.
