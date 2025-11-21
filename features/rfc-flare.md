- Feature Name:
- Start Date:
- Status:

Summary
=======

Motivation
==========

Guide-level explanation
=======================

Flare Versioning
----------------

The Ada/Flare language is activated at the unit level (spec and body). Flare
can be turned on at the child package level, once that's the case all further
children must also be Ada/Flare. Flare packages may depend on Ada units, the
reverse is not possible. Furthermore, if a specific Flare version is specified,
children unit or dependents must all be at least of that specific version, or
further.

Flare versions implement semantic numbering, Major.Minor. Beside the minor
versions under the major 0 which is considered beta, minor versions are not
allowed to introduce backward-incompatible changes.

The version of Flare described in this document is Flare 0.1.

Outside of specific constraints in the source code, a tool or a compiler
may decide on wether or not a unit is Flare, and what version. This may be
a default, a flag, a file extension or any other indication that said tool
may use.

A unit can be marked Flare introducing the pragma Flare either on its
specification, or implemetation if there's no specification. E.g.:

```ada
pragma Flare;

package P is
   --  This is Flare code
end P;
```

When provided without arguments, the tool is instructed to select the most
recent version available. A developer may also provide specific minimal version
through string parameters. E.g.:

```ada
pragma Flare ("0.1");

package P is
   --  This is Flare code, should be compiled with at least 0.1 version.
end P;
```

Developers may also provide specific maximal version, e.g:

```ada
pragma Flare ("0.1", "0.2");

package P is
   --  This is Flare code, should be compiled for any version between 0.1
   --  and 0.2.
end P;
```

Versions can be provided with only major, or major + minor. When only a major
version is provided, it means:
- The smaller minor version for the lower bound
- The largest mintor version for the upper bound

For example:

- `pragma Flare ("0");`: Must be compliant with at least the `0.1` version of
   the language
- `pragma Flare ("0", "0");`: Must be compliant with any version in the "0"
   branch.

These pragma define not only the subset of the language that is allowed, but
also interpretation of semantics in case of changes.

Alternatively to the Flare language, a user can also request a package to
be written with the Ada compatible subset of Flare, e.g.:

```ada
pragma Flare_Compatible ("0.1");

package P is
   --  This package accepts Ada semantics as well as non-backward incompatible
   --  Flare capabilities, starting with 0.1.
end P;
```

Features Enabled in Flare 0.1
-----------------------------

The following list is the list of feature that will make the cut of the Flare
0.1 version. As a version under the 0.x branch, further change may still
introduce backward-incompatible changes in the pedantic Flare version.

Control Flow
^^^^^^^^^^^^

[Continue](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-continue.md)

[Finally](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-finally.md)

[Predefined Short Circuits Operators](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-finally.mdfeatures/rfc-shortcircuit.md)

[Local Declarations without Blocks](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/features/rfc-local-vars-without-block.md)

Arrays
^^^^^^

[Array Slice Access](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/array_slice_access.md)

[Fixed Lower Bound](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-fixed-lower-bound.rst)

[Import Array from Address](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-import-array-from-address.md)

[Max Array Size]()

[Square Bracket Notation for Array Index]()

[Goto/Return/Raise When](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-conditional-when-constructs.rst)


Object Orientation
^^^^^^^^^^^^^^^^^^

[Max Class Size](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-class-size.md)

[Components](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-oop-fields.rst)

[Protected](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-oop-protected.rst)

[Constructors](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-oop-constructors.rst)

[Destructors](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-oop-destructors.rst)

[Aggregates and Assignments](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-oop-aggregates-and-assignments.rst)

[Dispatching](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-oop-dispatching.rst)

[Primitives](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-oop-primitives.rst)

[Super](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-oop-super.rst)

[Attributes](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-oop-attributes.rst)

Generics
^^^^^^^^

[Expression Functions as Default Formals](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-expression-functions-as-default-for-generic-formal-function-parameters.rst)

[Inference from Formal Dependents](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-inference-of-dependent-types.md)

[Structural Instantiation](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-structural-generic-instantiation.md)

Contract-Based Programming
^^^^^^^^^^^^^^^^^^^^^^^^^^

[Multiple Levels of Ghost](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-multiple_ghost_levels.md)

[Exceptional Contracts](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-spark-exceptional-contracts.md)

[Proven Functions with Out Parameters](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-function-out-parameters.md)

[Deep Delta Aggregates](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-deep-delta-aggregates.md)

Other
^^^^^

[External Initialization](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-external-initialization.rst)

[Range Integer Types](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-range-integer-types.rst)

[String Interpolation](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-string-interpolation.md)

[Aggregate Record Notation]()

[End name; instead of end record](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-mandatory_end_designator.md)

[Parenthesis for Non-Parameter Calls]()

Reference-level explanation
===========================


Rationale and alternatives
==========================

Drawbacks
=========


Prior art
=========


Unresolved questions
====================


Future possibilities
====================

