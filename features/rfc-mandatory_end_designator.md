- Feature ID: mandatory_end_designator
- Start Date: 2025-11-06
- Status: Proposed

Summary
=======

This RFC proposes to standardize and mandate the use of the designator name in the end statement for all block-like constructs. Currently, the repetition of the designator (e.g., `end My_Procedure;`) is optional for subprograms, packages, tasks, and protected types. This proposal makes this end designator mandatory in all such cases. As a key part of this standardization, this RFC also proposes to replace the inconsistent end record terminator for record type declarations. This construct will be deprecated in favor of the now-mandatory `end <designator>;` syntax (e.g., `end My_Record_Type;`).

Motivation
==========

The primary motivation for this change is to improve language consistency and code readability in long or nested code blocks, by explicitly linking the end of a block to its beginning.

The current `end record` syntax is inconsistent with other block terminators. This proposal aligns record declarations with the termination syntax used by subprograms, packages, tasks, and protected types. This change would establish a clear rule: "If a construct has a name in its declaration, that name must be repeated at its end". This rule also finds precedent in Ada's named loops, where a loop's name must be repeated at its `end loop` termination.

In addition, the proposal is particularly well-suited for upcoming language features, such as `class record`s. In such a construct, the `class record body` could be substantially longer, containing the implementations of various methods.

Guide-level explanation
=======================

For subprograms, packages, tasks, protected types, record types, class record types and named loops, their name must be repeated at the end. The old syntax, where the name was optional or a different keyword was used (like `end record`), is illegal.

```ada
-- Old syntax, now illegal
procedure My_Procedure is
begin
    null;
end; -- No designator

-- New syntax, mandatory
procedure My_Procedure is
begin
    null;
end My_Procedure; -- Designator is mandatory
```

The most significant change is to record declarations. The special `end record;` syntax has been removed from the language and replaced by the same universal `end <designator>;` rule.

```ada
-- Old syntax, now illegal
type My_Record is record
    Foo : Unbounded_String;
    Bar : Natural;
end My_Record;

-- New syntax, mandatory
type My_Record is record
   Foo : Unbounded_String;
   Bar : Natural;
end My_Record; -- Designator is mandatory
```


Reference-level explanation
===========================

Nothing specific at this stage.

Rationale and alternatives
==========================

An alternative was to only deprecate `end record;` in favor of an optional `end <record_name>;`. This was deemed a missed opportunity. While it would fix the end record inconsistency, it would not bring the benefits of making the designator mandatory everywhere.

Drawbacks
=========

The primary drawbacks are related to backward compatibility and verbosity.

For backward compatibility, see the Compatibility section below.

Mandating the designator makes the code more verbose, as it will be required to type the designator at the end of every block. This is a trade-off and the benefit of improved readability and consistency is argued to outweigh the inconvenience of extra typing.

Compatibility
=============

This is a significant breaking change. All existing Ada code that currently uses the optional designator (or `end record`) would become non-compliant.

Open questions
==============

None at this stage.

Prior art
=========

Ada itself has named loops, (e.g., `Outer_Loop: loop ... end loop Outer_Loop;`) which already enforce the proposed pattern.

Unresolved questions
====================

None at this stage.

Future possibilities
====================

Nothing specific at this stage.
