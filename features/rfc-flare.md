- Feature Name: flare-pragma
- Start Date: 2026-02-26
- Status: Ready for prototyping

# Summary

# Motivation

# Guide-level explanation

## Flare Versioning

The Flare language is activated at the compilation unit level (spec or
body). A unit to which no Flare pragma applies is *regular Ada*; a unit in Flare
mode is either *pedantic Flare* (pragma `Flare`) or *extensions* mode (pragma
`Flare_Extensions`). Flare mode can be turned on at the child package level.
Once that's the case all further children must also be in Flare mode. Flare
packages may depend on regular Ada units, the reverse is not possible.

Flare allows for specific versioning. Flare versions implement semantic
numbering, Major.Minor. Beside the minor versions under the major 0 which is
considered beta, minor versions are not allowed to introduce
backward-incompatible changes.

The version of Flare described in this document is Flare 0.1.

Outside of specific constraints in the source code, a tool or a compiler
may decide on whether or not a unit is Flare, and what version. This may be
a default, a flag, a file extension or any other indication that said tool
may use.

If a specific Flare version is specified, child and dependent units must all
be at least of that specific version, or further. A body, by contrast, must
match the version of its specification exactly (see [Pragma
Scope](#pragma-scope)).

### Pragma Flare

A unit can be marked Flare introducing a configuration pragma Flare either on
its specification, or implementation. E.g.:

```ada
pragma Flare;

package P is
   --  This is Flare code
end P;
```

### Pragma Scope

The pragma Flare only applies to the compilation unit it is placed on. Like
other configuration pragmas placed before a library level package
specification, it is not propagated to the corresponding package body. The
body must therefore repeat the pragma to be Flare as well.

```ada
-- p.ads
pragma Flare;
package P is
   --  This is Flare code
end P;

-- p.adb
package body P is -- ERROR: Spec is in Flare mode whereas the body is not
   --  This is regular Ada code
end P;
```

The reverse is not allowed either: a body may not be Flare unless its spec is
also Flare. A spec and its body must have the same Flare status.

```ada
-- p.ads
package P is
   --  This is regular Ada code
end P;

-- p.adb
pragma Flare;
package body P is -- ERROR: Body is Flare whereas the spec is not
   --  This is Flare code
end P;
```

When provided without a version, the tool is instructed to select the most
recent version available. A developer may also provide a version with specific
version-aware flare pragmas, e.g.:

```ada
pragma Flare_0_1;

package P is
   --  This Flare code is compatible with Flare 0.1
end P;
```

Since configuration pragmas are not propagated from the spec to the body, the
body must repeat the pragma, and it must request the same version as the spec:

```ada
--  p.ads
pragma Flare_0_1;
package P is
   --  This is Flare 0.1 code
end P;

--  p.adb
pragma Flare_0_2;
package body P is -- ERROR: Body is Flare 0.2 whereas the spec is Flare 0.1
   --  This is Flare code
end P;
```

Versions can be provided with only major version numbers, e.g. `pragma
Flare_1;`. A major-only pragma selects the most recent available minor version
of that major, so `pragma Flare_1;` requests the newest `1.x`. An exception is
the 0 major version, where a minor version must also be provided, e.g. `pragma
Flare_0_1;`. Version numbers are written in canonical form, without leading
zeros: `Flare_01` and `Flare_1_00` are illegal spellings of `Flare_1` and
`Flare_1_0`.

At most one Flare or Flare_Extensions pragma may apply to a given compilation
unit.

These pragmas define not only the subset of the language that is allowed, but
also interpretation of semantics in case of changes.

#### Child Packages

Flare can be turned on at the child package level even when the parent is
regular Ada. Once a unit is in Flare mode, all further children must also be in
Flare mode.

```ada
--  p.ads
package P is
   --  This is regular Ada code
end P;

--  p-c.ads
pragma Flare;
package P.C is
   --  This is Flare code, turned on at the child level
end P.C;

--  p-c-g.ads
package P.C.G is -- ERROR: Parent P.C is Flare, so P.C.G must also be Flare
   --  This must be in Flare mode
end P.C.G;
```

Furthermore, when a specific version is requested, children must be at least
of that version:

```ada
--  p-c.ads
pragma Flare_0_2;
package P.C is
   --  This is Flare 0.2 code
end P.C;

--  p-c-g.ads
pragma Flare_0_1; -- ERROR: Parent P.C requires at least Flare 0.2
package P.C.G is
   --  This is Flare code
end P.C.G;
```

#### Dependencies

An extensions-mode unit is technically an Ada unit, so for dependency purposes
there are only two kinds of unit: Ada units (regular Ada or extensions) and
pedantic Flare units. Ada units may depend on one another freely, in either
direction. A pedantic Flare unit may depend on Ada units, but the reverse is not
possible: an Ada unit may not depend on a pedantic Flare unit.

```ada
--  a.ads
package A is
   --  This is regular Ada code
end A;

--  f.ads
pragma Flare;
with A; -- OK: a pedantic Flare unit may depend on an Ada unit
package F is
   --  This is Flare code
end F;

--  b.ads
with F; -- ERROR: an Ada unit may not depend on a pedantic Flare unit
package B is
   --  This is regular Ada code
end B;
```

As with children, when a specific version is requested, dependents must be at
least of that version:

```ada
--  f.ads
pragma Flare_0_2;
package F is
   --  This is Flare 0.2 code
end F;

--  g.ads
pragma Flare_0_1;
with F; -- ERROR: F requires at least Flare 0.2
package G is
   --  This is Flare code
end G;
```

### Pragma Flare_Extensions

Alternatively to the Flare language, a user can also request a package to
be written with the Ada compatible subset of Flare, e.g.:

```ada
pragma Flare_Extensions_0_1;

package P is
   --  This package accepts Ada semantics as well as non-backward incompatible
   --  Flare capabilities, starting with 0.1.
end P;
```

As with pragma Flare, the version follows the same scheme: a version may be
given with only a major number (`pragma Flare_Extensions_1;`), and, when no
version is provided at all, the tool selects the most recent version available:

```ada
pragma Flare_Extensions;

package P is
   --  Ada semantics plus the most recent backward-compatible Flare capabilities
end P;
```

The sibling RFCs refer to the pedantic Flare mode as "pedantic Ada Flare" and to
the extensions mode as "non-pedantic Ada Flare"; the latter is the
`Flare_Extensions` mode described here. Pedantic mode will activate additional capabilities, but may fail in compiling legacy Ada code.

Notably, new reserved words (``continue``, ``finally`` and ``class``) may not
be considered reserved in Ada compatibility mode, but are in Flare pedantic.

The two Flare modes are not mixed within a unit: a spec and its body, and a
Flare unit and its Flare children, must use the same mode. Dependencies are
looser: an extensions-mode unit is technically an Ada unit, so Ada units and
extensions units may depend on one another freely, and a pedantic unit may
depend on either.

Note that the use of pragma Flare_Extensions is close to GNAT's
[`pragma Extensions_Allowed`](#gnat-pragma-extensions_allowed): both accept
Ada semantics and add capabilities on top, the difference being that
Flare_Extensions is versioned and limited to backward-compatible Flare
features.

Flare language is based on the Ada 2022 language subset supported by GNAT
(consult the GNAT Reference Manual for the list of supported Ada 2022 features).

## Features Enabled in Flare 0.1

The following list is the list of features that will make the cut of the Flare
0.1 version. As a version under the 0.x branch, further changes may still
introduce backward-incompatible changes in the pedantic Flare version.

### Control Flow

[Continue](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-continue.md)

[Finally](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-finally.md)

[Predefined Short Circuits Operators](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-shortcircuit.md)

[Local Declarations without Blocks](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-local-vars-without-block.md)

### Arrays

[Array Slice Access](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/array_slice_access.md)

[Fixed Lower Bound](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-fixed-lower-bound.rst)

[Import Array from Address](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-import-array-from-address.md)

[Max Array Size]()

[Square Bracket Notation for Array Index]()

[Goto/Return/Raise When](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-conditional-when-constructs.rst)


### Object Orientation

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

### Generics

[Expression Functions as Default Formals](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-expression-functions-as-default-for-generic-formal-function-parameters.rst)

[Inference from Formal Dependents](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-inference-of-dependent-types.md)

[Structural Instantiation](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-structural-generic-instantiation.md)

### Contract-Based Programming

[Multiple Levels of Ghost](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-multiple_ghost_levels.md)

[Exceptional Contracts](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-spark-exceptional-contracts.md)

[Proven Functions with Out Parameters](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-function-out-parameters.md)

[Deep Delta Aggregates](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-deep-delta-aggregates.md)

[Modifies Aspect](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-spark-modifies-aspect.md)

[Values at Labels ('At)](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-spark-values-at-labels.md)

[No_Raise Aspect](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-noraise.md)

### Other

[External Initialization](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-external-initialization.rst)

[Range Integer Types](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-range-integer-types.rst)

[String Interpolation](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-string-interpolation.md)

[To_String](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-to_string.md)

[Aggregate Record Notation]()

[End name; instead of end record](https://github.com/AdaCore/ada-spark-rfcs/blob/master/features/rfc-mandatory_end_designator.md)

[Parenthesis for Non-Parameter Calls]()

## Reference-level explanation

### Syntax

Flare mode is selected by one of two families of configuration pragmas. Both
families carry an optional version embedded in the pragma identifier:

```
flare_pragma ::= pragma flare_pragma_identifier;

flare_pragma_identifier ::=
     Flare
   | Flare _ version
   | Flare_Extensions
   | Flare_Extensions _ version

version ::=
     major_version
   | major_version _ minor_version

major_version ::= numeral
minor_version ::= numeral
```

`numeral` is a sequence of decimal digits, written in canonical form: no
leading zeros, except for the single digit `0` itself. `Flare_01` and
`Flare_1_00` are therefore illegal spellings; the legal spellings are `Flare_1`
and `Flare_1_0`.

Examples of legal pragmas:

```ada
pragma Flare;                --  pedantic Flare, most recent version
pragma Flare_0_1;            --  pedantic Flare, version 0.1
pragma Flare_1;              --  pedantic Flare, major version 1
pragma Flare_1_1;            --  pedantic Flare, version 1.1
pragma Flare_Extensions;     --  Flare extensions, most recent version
pragma Flare_Extensions_0_1; --  Flare extensions, version 0.1
```

These are configuration pragmas. Each applies to the single compilation unit it
immediately precedes, following the usual placement rules for configuration
pragmas given before a library unit. Placing one of these pragmas anywhere a
configuration pragma is not permitted is illegal.

At most one pragma from either family may apply to a given compilation unit. A
compilation unit to which no such pragma applies is *regular Ada*; a unit to
which a `Flare` pragma applies is in *pedantic Flare* mode; a unit to which a
`Flare_Extensions` pragma applies is in *extensions* mode. The pedantic and
extensions modes are together referred to as *Flare mode*.

### Legality Rules — the version

A `version` denotes a Major.Minor pair with the following semantics:

* If a `minor_version` is omitted, the pragma denotes the most recent available
  minor version of major version `major_version` (so `pragma Flare_1;` selects
  the newest `1.x`).

* If the whole `version` is omitted (`pragma Flare;`,
  `pragma Flare_Extensions;`), the pragma denotes the most recent version
  available to the tool.

* It is illegal to omit the `minor_version` when the `major_version` is `0`
  (e.g. `pragma Flare_0;` is illegal). Under the `0` major version, every minor
  version is a beta that may introduce backward-incompatible changes, so a
  minor version must always be pinned. For every major version greater than
  `0`, minor versions may only add backward-compatible capabilities.

Each pragma resolves to a concrete *effective version*, a Major.Minor pair. It
is illegal if no version satisfying the pragma is available to the tool. In the
absence of any of these pragmas, whether a unit is regular Ada or in Flare mode,
and at what version, is determined by the tool (a default, a flag, a file
extension, or any other tool-defined indication).

Versions are totally ordered: `(M1, N1) <= (M2, N2)` iff `M1 < M2`, or
`M1 = M2` and `N1 <= N2`. This order underlies every "at least of that version"
rule below.

### Legality Rules — placement and consistency

The pragma applies only to the compilation unit it is placed on. Like other
configuration pragmas placed before a library unit specification, it is not
propagated to the corresponding body.

Within a unit and its subtree the two Flare modes are not mixed: a spec and its
body, and a Flare unit and its Flare children, must all use the same mode.
Dependencies between separate units are looser — see **Dependencies** below.

* **Spec to body.** If the specification of a library unit is in Flare mode
  with effective version *V*, then its body, if any, must be in the same mode
  (pedantic or extensions) and repeat a pragma resolving to the same effective
  version *V*. It is illegal for the body to be regular Ada, to be in the other
  mode, or to resolve to a different effective version.

* **Regular Ada spec.** If the specification is regular Ada, the body must also
  be regular Ada. A spec and its body always have the same Flare status: it is
  illegal for a body to be in Flare mode unless its specification is in Flare
  mode as well.

* **Children.** A child unit of a unit that is in Flare mode must itself be in
  the same Flare mode (pedantic or extensions). Once a unit is in Flare mode, all
  of its descendants must be in that same mode. A child unit may be in Flare mode
  even when its parent is regular Ada. Where the parent is in Flare mode with
  effective version *V*, the child's effective version must be `>= V`.

* **Dependencies.** For the purpose of dependencies an extensions-mode unit is
  technically an Ada unit: extensions mode only adds backward-compatible
  features and so places no requirement on units that depend on it. There are
  therefore only two kinds of unit to consider: *Ada units* (regular Ada or
  extensions) and pedantic Flare units.

  * Ada units may depend on (`with`) one another freely, in either direction.
  * A pedantic Flare unit may depend on any Ada unit (regular Ada or extensions)
    and on other pedantic units.
  * An Ada unit may not depend on a pedantic Flare unit, since a pedantic
    interface may expose Flare constructs the depending unit does not support.

  Where a pedantic Flare unit with effective version *V* is depended upon by
  another pedantic unit, the depending unit's effective version must be `>= V`.

* **Subunits.** The Flare pragmas behave like any other configuration pragma
  with respect to subunits: a subunit inherits the configuration pragmas that
  apply to its parent, and is therefore in the same Flare mode and version as
  the body it belongs to. A subunit may carry its own set of configuration
  pragmas, but any Flare pragma it specifies must match the Flare mode and
  version of its parent.

### Static Semantics

The mode and effective version selected for a compilation unit determine two
things:

* the subset (pedantic Flare) or superset (extensions) of the language that is
  legal within the unit, and

* the interpretation of any construct whose semantics differ between versions.

In pedantic Flare mode the unit is restricted to the Flare subset of the base
Ada language for the effective version; constructs outside that subset are
illegal. In extensions mode the unit accepts the full base Ada language of the
effective version and additionally enables the backward-compatible Flare
capabilities of that version. The base language for the Flare versions described
in this document is a subset of Ada 2022.

## Rationale and alternatives

## Drawbacks

## Prior art

### GNAT Ada Version Pragmas

The Flare pragmas closely resemble the Ada language version pragmas that GNAT
already provides, such as `pragma Ada_83`, `pragma Ada_95`, `pragma Ada_2005`,
`pragma Ada_2012` and [`pragma Ada_2022`][gnat-ada-2022]. Like Flare, these are
configuration pragmas that select the language version applied to a compilation
unit. They share the same scoping behavior: a version pragma placed before a
library level package specification is not propagated to the corresponding
package body and must be repeated there.

The main difference is that the GNAT pragmas select an edition of standard Ada,
whereas the Flare pragmas select the Flare language and its version.

[gnat-ada-2022]: https://docs.adacore.com/live/wave/gnat_rm/html/gnat_rm/gnat_rm/implementation_defined_pragmas.html#pragma-ada-2022

### GNAT Pragma Extensions_Allowed

GNAT also provides the
[`pragma Extensions_Allowed`][gnat-extensions-allowed], which enables language
features beyond standard Ada. It takes one of `Off`, `On` or `All_Extensions`:
`On` enables a curated set of GNAT-specific extensions on top of the latest Ada
version, while `All_Extensions` additionally enables the
[experimental extensions][gnat-experimental-extensions]. It corresponds to the
`-gnatX` and `-gnatX0` command-line switches, over which it takes precedence.

Many of the features slated for Flare 0.1 are already available through this
mechanism, including for example the conditional `when` constructs, the
`continue` and `finally` statements, fixed lower bounds, constructors and
destructors, structural generic instantiation, inference of dependent types,
the `External_Initialization` aspect and string interpolation.

This makes pragma `Extensions_Allowed` very close to the [`pragma
Flare_Extensions`](#pragma-flare_extensions). Both accept standard Ada and layer
additional features on top, rather than defining a new language subset.
`Extensions_Allowed(All_Extensions)` activates curated and experimental
GNAT-specific extensions. `Flare_Extensions` adds additional Flare features in
their backward-compatible form. Unlike Extensions_Allowed, `Flare_Extensions`
allows to specify the version of the Flare language.

The pedantic `pragma Flare`, by contrast, has no direct GNAT equivalent: it
defines a specific, versioned subset of the language. It rejects code outside
that subset, whereas `Extensions_Allowed` only ever adds to standard Ada.

[gnat-extensions-allowed]: https://docs.adacore.com/live/wave/gnat_rm/html/gnat_rm/gnat_rm/implementation_defined_pragmas.html#pragma-extensions-allowed
[gnat-experimental-extensions]: https://docs.adacore.com/live/wave/gnat_rm/html/gnat_rm/gnat_rm/gnat_language_extensions.html#experimental-language-extensions

## Unresolved questions

## Future possibilities

### Sticky Flare Pragma

Currently, the pragma Flare applies only to the compilation unit it is placed
on and, like other configuration pragmas, is not propagated from a
specification to its body. A future extension could make the pragma "sticky",
so that a pragma Flare placed on a spec automatically applies to the
corresponding body as well. This would remove the need to repeat the pragma on
the body, at the cost of making a unit's Flare status less locally explicit.


