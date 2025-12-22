- Feature ID: mandatory_end_designator
- Start Date: 2025-11-06
- Status: Ready for Prototyping

# Summary

This RFC proposes to standardize the use of a single `end[ designator]` terminator for all declaration constructs that use an end designator, in pedantic Ada Flare.

Currently, the repetition of the designator (for example, `end My_Procedure`) is optional for subprograms, packages, tasks, and protected types. Record type declarations, however, use a distinct and inconsistent terminator: `end record[ designator]`.

This RFC proposes to deprecate the special `end record[ designator]` syntax for record type declarations and replace it with the uniform `end[ designator];` syntax (for example, `end My_Record_Type;`).

For backwards compatibility reasons, non-pedantic Ada Flare continues to accept the Ada 2022 syntax.

# Motivation

The primary motivation for this change is to improve language consistency and code readability in long or nested code blocks, by explicitly and uniformily linking the end of a construct to its beginning.

The current `end record[ designator]` syntax is inconsistent with other declaration terminators. This proposal aligns record declarations with the termination syntax used by subprograms, packages, tasks, and protected types.

# Guide-level explanation

The special `end record[ designator];` syntax is removed in pedantic Ada Flare and replaced by the generic `end[ designator];` syntax.

**Ada Syntax:**

```ada
type My_Record_1 is record
    Foo : Unbounded_String;
    Bar : Natural;
end record; -- mandatory 'record'

type My_Record_2 is record
    Foo : Unbounded_String;
    Bar : Natural;
end record My_Record_2; -- mandatory 'record' and optional designator
```

**Flare Syntax:**

```ada
type My_Record_1 is record
   Foo : Unbounded_String;
   Bar : Natural;
end; -- No designator

type My_Record_2 is record
   Foo : Unbounded_String;
   Bar : Natural;
end My_Record_2; -- With optional designator
```

# Reference-level explanation

The grammar for record_definition (ARM 3.8) is changed to:

```
record_definition ::=
  record
    component_list
  end[ record_identifier]
  | null record
```

# Rationale and alternatives

An alternative approach would be to require the designator for all end terminators. This was considered in ealier drafts but rejected in order to preserve the existing Ada philosophy of optional designators for declaration constructs.

# Drawbacks

The primary drawbacks are related to compatibility. See the Compatibility section below.

# Compatibility

Code using the new `end[ designator]` syntax for record type declarations will not compile with standard Ada 2022 compilers.

In pedantic Ada Flare, the `end record[ designator]` form is rejected and only the generic terminator is accepted.

In non-pedantic Ada Flare, both the Ada 2022 and the Ada Flare syntax remain valid to preserve backward compatibility.

# Open questions

None at this stage.

# Prior art

None at this stage.

# Unresolved questions

None at this stage.

# Future possibilities

Nothing specific at this stage.
