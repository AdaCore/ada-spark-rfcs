- Feature ID: mandatory_square_bracket_array_aggregates
- Start Date: 2026-02-26
- Status: Design

# Summary

This RFC proposes to make the square-bracket syntax `[...]` mandatory for array aggregates in pedantic Ada Flare. In Ada 2022, `[...]` is the preferred syntax for array aggregates, but the old-style parenthesised aggregate `(...)` is still accepted. For instance, the GNAT compiler issues a warning when it's used. Flare enforces `[...]` strictly, turning such warnings into compile-time errors.

# Motivation

The main motivation for mandatory square brackets is to unblock RFC 'parentheses_for_parameterless_calls'. This RFC would help eliminating name resolution ambiguity caused by Ada's Uniform Addressing Principle (UAP). In Ada, parentheses () are used both for array indexing and for subprogram parameters. When a parameterless function returns an array, the syntax for "calling the function then indexing the result" is identical to "indexing an array variable."

Consider the following precarious Ada scenario:

```
Z : Integer_Array := (others => 0);  -- outer scope: array variable

declare
   function Z return Integer_Array is (1 .. 10 => 99);  -- inner scope: parameterless function, shadows outer Z
begin
   Y := Z (1);  -- Ada: UAP allows calling Z without (), then indexing with (1) → Y = 99
end;
```

In the Flare version of the code above, with both this RFC and RGC 'parentheses_for_parameterless_calls', `Y := Z () [1]` would strictly imply a function call, while `Y := Z [1]` would imply an indexing operation.


# Guide-level explanation

In Flare, any array aggregate (including array delta aggregate) must be written using `[...]`. The old parenthesised form is rejected in pedantic mode.

**Ada Syntax (still accepted in non-pedantic Flare):**

```ada
V : Integer_Array := (1, 2, 3);  -- Ada 2022 accepts with warning
```

**Flare Syntax (required in pedantic Flare):**

```ada

V : Integer_Array := [1, 2, 3];  -- mandatory [] in Flare
```

# Reference-level explanation

The following Reference Manual changes are required:

- RM 4.3.3(4/5):

```
named_array_aggregate ::= '[' array_component_association_list ']'
```

- RM 4.3.4(4/5):

```
array_delta_aggregate ::= '[' base_expression with delta array_component_association_list ']'
```

# Rationale and alternatives

Allow both (status quo): it maintains the ambiguity between array aggregates and function calls.

# Drawbacks

The primary drawbacks are related to compatibility. See the Compatibility section below.

# Compatibility

Code already using `[...]` for array aggregates is valid Ada 2022 and requires no changes when migrating to Flare.

Code using `(...)` for array aggregates must be updated to use `[...]` before it will compile in pedantic Flare.


# Open questions

None at this stage.

# Prior art

None at this stage.

# Unresolved questions

None at this stage.

# Future possibilities

Nothing specific at this stage.
