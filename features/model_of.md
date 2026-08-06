- Feature Name: model_of
- Start Date: 2026-04-02
- Status: Design

Summary
=======

This RFC proposes a mechanism for attaching analysis-oriented contracts,
consisting of aspects that do not affect execution with assertsions
disbled (such as `Pre`, `Post`, `Global`, and `Test_Case`), to subprograms
without modifying the package's original source.

The RFC only addresses aspects attached to sub-programs.

The envisaged workflow is as follows:

* The developer creates a sidecar unit containing the selected model
declarations and other code fragments that matching **main specification**
or **main body**.

* A **model decorator** step merges the main unit and sidecar unit into a
**decorated unit** where code blocks are annotated to show their origin.

* The decorated unit is used instead of the original **main unit** when
compiling or analyzing the code.

Technically, the proposal relies on five related components:

(1) Syntax for the sidecar unit.

(2) Implementation of the **model decorator** step.

(3) A workflow for integrating the model step with the rest of the
toolchain.

(4) Syntax for code annotations in the **decorated unit**.

(5) Compiler modifications to take code annotations into account when displaying
diagnostic messages.

Step (3) is outside the scope of this proposal as it depends on the implementation choices of step (2).
The alternatives for step (2) are either to implement it as a separate preprocessing tool or an integrated
step inside the compiler. 

Motivation
==========

It may not always be possible or reasonable to include a formal contract in the specification of the subprograms. Some examples of scenarios where formal contracts in source code may not be feasible:

* When analyzing legacy code, one may want to avoid unnecessary changes to the original source code.

* Formal contracts may be long and complex. Mixing them with functional code may reduce the readability and maintainability of both.

* In the case of certified code, one needs to prove that all code is either fully verified or is completely isolated from the certified functionality. Removing the sidecar files is significantly simpler than proving the contracts are fully removed during compilation.

The workflow presented in the summary aims to minimize the impact on the compilation process.
The only envisaged changes are to ignore the syntax of the sidecar unit (to avoid including it
in the compilation chain by accident) and to support annotations that denote the original location
of the source code fragments.
Generating the decorated unit may happens outside the compiler.

Guide-level explanation
=======================

### (1) The sidecar unit

Consider an existing package specification that must not be modified:

```ada
--  my_math.ads  (main specification, not modified)
package My_Math is
 function Sqrt (X : Float) return Float;
 function Log (X : Float) return Float;
private
 function Hidden (X : Float) return Float;
end My_Math;
```

A developer wishing to supply contracts for formal analysis creates a companion
sidecar specification:

```ada
--  my_math_models.ads  (sidecar specification, not compiled by the regular build)
model package My_Math is
 model function Sqrt (X : Float) return Float
 with
 Pre  => X >= 0.0,
 Post => Sqrt'Result >= 0.0;

 model function Hidden (X : Float) return Float
 with
 Pre  => X >= 0.0;
end My_Math;
```

A sidecar specification begins with `model package <package-name> is` instead
of `package <package-name> is`. The `model` keyword signals to the tool that
this file supplies additional specification information and is never compiled
as a stand-alone unit.

Inside a sidecar package, each decorated subprogram declaration begins with
`model` (for example, `model function` or `model procedure`). In sidecar
specifications, model entries may target any declaration in the public or
private part of the corresponding package.

For a sidecar body, the same processing applies, but `model` entries may only
apply to the specifications of subprograms declared in the body. Any other
code fragments in the sidecar unit that are not introduced by the `model`
entries are copied unchanged into the decorated output.

Consider a package body with a local subprogram and a helper function:

```ada
--  my_math.adb  (main body, not modified)
package body My_Math is
 function Pow (X, Y : Float) return Float is
 begin
 return X ** Y;
 end Pow;

 function Sqrt (X : Float) return Float is
 begin
 return Pow (X, 0.5);
 end Sqrt;
end My_Math;
```

A companion sidecar body may provide contracts for `Pow` instead of `Sqrt`
and define a helper function in the model package:

```ada
--  my_math_models.adb  (sidecar body, not compiled by the regular build)

--  additional included packages
with Helper_Package; use Helper_Package;

model package My_Math is
 --  helper function to express the contract
 function Greater_Than (X, Y : Float) return Boolean is
 begin
 return X > Y;
 end Greater_Than;

 model function Pow (X, Y : Float) return Float
 with
 Pre  => Greater_Than (X, 0.0),
 Post => Greater_Than (Pow'Result, 0.0);
end My_Math;
```

In this example, the `model function` entry is resolved against the body
specification for `Pow` in the main body, the helper function `Greater_Than`
is defined in the sidecar model package, and the pragma is copied verbatim
into the decorated output.

### Validity rules for sidecar units

Only the aspects that do not affect execution when `Assertion_Policy` is
set to `Ignore` or `Disable` may be specified in the model — for example,
`Pre`, `Post`, `Global`, `Depends`, `Contract_Cases`, `Test_Case`,
`Subprogram_Variant`, `Ghost`, and `Annotate`. 
Such an aspect is accepted in the model when the same aspect doesn't
yet exist in the actual subprogram specification.
Overriding or changing an existing aspect specification is not permitted.

Annotation can be applied to a generic instance, but not to a generic.

The fragments of the sidecar unit that are not marked with the keyword `model`
and are thus copied as-is shall have a valid Ada syntax. The model decorator
step does not check them, assuming that, in the event of conflicts with other
elements of the program, the compilation step will discover them.

An annotation can be applied to a child unit using the unit's qualified name.

### (2) The model decorator step

The model decorator step reads both the main unit and the sidecar unit, and produces the decorated unit.

For specifications, the step merges the package specification with the sidecar model declarations.
It injects contracts into the corresponding source declarations.
For bodies, the step performs the same merge on the body: it reads the actual package body and the sidecar body, resolves `model` declarations against body specifications, and injects contract aspects into the matched declarations.

In both cases, non-`model` fragments from the sidecar are copied through unchanged, and the decorated output preserves origin information using linemarkers.

```ada
pragma Source_Annotations (On)

--  my_math_decorated.ads  (decorated specification, consumed by analysis tools)
--# @Source_Reference@ 1 "my_math.ads" 1
package My_Math is
 function Sqrt (X : Float) return Float
--# @Source_Reference@ 3 "my_math_models.ads" 1
 with
--# @Source_Reference@ 5 "my_math_models.ads"
 Pre  => X >= 0.0,
 Post => Sqrt'Result >= 0.0;
--# @Source_Reference@ 3 "my_math.ads" 2
 function Log (X : Float) return Float;
end My_Math;
```

For a body, the decorated output is produced in the same way.
The model contracts are merged into the actual body declaration, and the
origin linemarkers preserve their relationship to both the original body and
the sidecar body.

```ada
pragma Source_Annotations (On)

--  my_math_decorated.adb  (decorated body, consumed by analysis tools)
--# @Source_Reference@ 1 "my_math_models.adb" 1
--  additional included packages
with Helper_Package; use Helper_Package;

--# @Source_Reference@ 1 "my_math.adb" 1
package body My_Math is
--# @Source_Reference@ 5 "my_math_models.adb" 1
 --  helper function to express the contract
 function Greater_Than (X, Y : Float) return Boolean is
 begin
 return X > Y;
 end Greater_Than;

--# @Source_Reference@ 3 "my_math.adb" 1
 function Pow (X, Y : Float) return Float
--# @Source_Reference@ 12 "my_math_models.adb" 1
 with
 Pre  => Greater_Than (X, 0.0),
 Post => Greater_Than (Pow'Result, 0.0);
--# @Source_Reference@ 4 "my_math.adb" 1
 is
 begin
 return X ** Y;
 end Pow;

 function Sqrt (X : Float) return Float is
 begin
 return Pow (X, 0.5);
 end Sqrt;
end My_Math;
```

The decorated unit is valid Ada 2022 (with contract aspects) and will be passed to
the analysis tools instead of the original main unit.

`pragma Source_Annotations (On)` instructs the compiler to apply special processing
to annotations representing code locations.

A given subprogram may carry each aspect in at most one of the main unit and the
sidecar unit. If both files supply the same aspect for the same subprogram, the
model decorator tool reports an error indicating the conflicting line in each file.

If a sidecar unit exists for a package without a corresponding main source
file, the tool may create the missing unit during decoration so that the sidecar
can still participate in the analysis. An example of such a scenario would be 
a contract that uses ghost code and this ghost code requires a body.

### (3) Toolchain integration

Integrating the model decorator step with the rest of the toolchain is outside
the scope of this proposal.

### (4) Code annotations in the decorated unit

Special syntax for code annotations is activated by `pragma Source_Annotations (On)`.

Each linemarker embedded in the decorated unit is an Ada line comment of the
form:

```
--# @Source_Reference@ linenum "filename" [flags]
```

The fixed token `@Source_Reference@` marks the comment as a source-reference
linemarker rather than an ordinary comment.

The `#` must immediately follow `--`, with no intervening space. This is
deliberate: GNAT's style check `c` (part of the default style-checking set)
requires two spaces after `--` in a full-line comment, but explicitly exempts
a comment whose first character is a special character immediately following
`--` — the same exemption that already covers `gnatprep`'s `--!` and the
legacy SPARK annotation language's `--#`. Writing `-- #` (with a space before
the `#`) would fall outside that exemption and be flagged as a style
violation under the default checks; `--#` is not.

The semantics follow the C preprocessor convention (GCC manual §9.7):

| Field      | Meaning |
|------------|---------|
| `linenum` | Line number in `filename` that the **immediately following** source line originated from. |
| `filename` | Quoted path to the original file. |
| `1` | First occurrence of this file (entering a new file). |
| `2` | Returning to the `filename` after lines were imported from another file. |
| *(absent)* | Continuation within the same file at a non-sequential line number. |

A new linemarker is emitted only when the origin file changes or when the next
line number is not the direct successor of the previous one (i.e., lines were
skipped — for instance, because a sidecar declaration is a resolved reference
and does not appear in the output).

Using these rules, any tool processing the decorated unit can reconstruct the
exact origin of each line by tracking the current `(filename, linenum)` pair
and incrementing `linenum` for each non-comment source line between markers.

### (5) Compiler support for code annotations

When the compiler encounters a linemarker comment in a decorated unit, it uses
the embedded `(filename, linenum)` pair to attribute any diagnostics to the
originating source location rather than to the decorated unit. This ensures
that the error and warning messages refer to lines in the main unit or the sidecar
unit, as appropriate.

Reference-level explanation
===========================

### (1) Sidecar unit grammar

```
decoration_unit ::=
 "model" "package" package_name "is"
 { decorated_subprogram_declaration }
 "end" package_name ";"

decorated_subprogram_declaration ::=
 "model" subprogram_specification
 "with" decoration_aspect_list ";"

decoration_aspect_list ::=
 decoration_aspect { "," decoration_aspect }

decoration_aspect ::=
 pre_aspect | post_aspect | contract_cases_aspect
 | global_aspect | depends_aspect | test_case_aspect
 | subprogram_variant_aspect | ghost_aspect | annotate_aspect
 | <any other aspect with no effect on execution>
```

Every `decorated_subprogram_declaration` must begin with `model` and must
contain only aspects that do not affect execution (see the aspect
list above). A sidecar unit may also contain ordinary source text and
declarations that the `model` entries do not introduce; those fragments
are copied through unchanged into the decorated output.

### (2) Model decorator step: resolution and synthesis

**Resolution rules for decorated subprogram declarations**

A `model` subprogram declaration must name a subprogram declared in the
package named by the enclosing `model package` clause. The `model package`
clause may name a child package using its qualified name (for example,
`model package My_Math.Extra is`), in which case the declaration is resolved
against that child package's own specification or body, not against its
parent. Overloaded names are disambiguated by matching the parameter profile
of the decorated declaration against the candidates in the target package.
If no candidate matches, or more than one candidate matches, the model
decorator tool reports an error.

In a sidecar specification, `model` entries may target any declaration in the
public or private part of the corresponding package. In a sidecar body,
`model` entries may target only subprogram specifications.

**Synthesis algorithm**

1. Parse the main unit and collect all relevant declarations with their
 source locations.
2. Parse the sidecar unit; for each `decorated_subprogram_declaration`, resolve
 it against the main source declarations.
3. Conflict check: if a main source declaration already carries any of the
 aspects present in the sidecar entry for the same subprogram, then emit an error.
4. Build the decorated unit by iterating over the main source in source order,
 inserting linemarkers before each run of lines that share the same origin,
 and injecting the `with` clause from the sidecar immediately after the
 closing parenthesis of the subprogram profile (and before the semicolon that
 would otherwise terminate it).
5. Copy any sidecar code fragments that the `model` entries do not introduce into the
 decorated output unchanged.
6. If the sidecar exists but the corresponding main unit does not, create the
 missing main unit and use it as the basis for the decorated output.
7. The `model` declaration is a synthesis directive and is **not** emitted in the
 decorated unit.

### (4) Linemarker emission rules (normative)

Let `(file, line)` be the origin of the most recently emitted non-comment
source line. Before emitting the next source line with origin `(file', line')`:

* If `file' ≠ file`:
  * If `file'` has not been seen before in the current decorated unit, emit
    `--# @Source_Reference@ line' "file'" 1`.
  * Otherwise emit `--# @Source_Reference@ line' "file'" 2`.
* Else if `line' ≠ line + 1`:
  * Emit `--# @Source_Reference@ line' "file'"` (no flag).
* Otherwise, no marker is needed.

Rationale and alternatives
==========================

**Why a separate sidecar unit rather than a pragma or pragma-based approach?**

Pragmas are compiled by `gprbuild` and visible to all tools. The intent here
is to keep decoration completely out of the production compilation pipeline.
A separate sidecar unit with `model package` syntax makes this separation
syntactically unambiguous: build systems can exclude sidecar model files without
any special configuration by recognizing the `model package` keyword.

**Why `model package` syntax rather than a library-level pragma?**

A pragma-based approach (e.g., `pragma Decorate (My_Math, ...);`) would be
structurally flat and would offer no natural place to write a full subprogram
profile, including aspects. Mirroring the package declaration provides a
familiar, IDE-navigable structure and reuses Ada's existing aspect syntax
without any new grammar for individual contracts.

**Why linemarkers in comments rather than a separate source-map file?**

A separate source-map file risks going out of sync with the decorated unit if
the decorated unit is post-processed. Embedding linemarkers as comments keeps
provenance co-located with the text, survives most transformations, and follows
a well-understood convention already used by GCC, Clang, and the Ada
preprocessor.

Drawbacks
=========

* Introduces a sidecar unit artifact and a model decorator step not part of
 standard Ada.
* The meaning of `model` declarations is entirely tool-defined; the syntax has no
 runtime semantics and is rejected by a standard compiler unless hidden behind
 a configuration pragma.
* Tool vendors must implement the conflict-detection rule independently, risking
 divergent interpretations.
* Decorated packages that model large third-party libraries may grow complex and
 require their own maintenance discipline.

Compatibility
=============

The feature is fully backward compatible: existing specifications and bodies are
unaffected. The GNAT front-end never sees sidecar units in a
regular build. If they are still included in the compilation chain, the
compiler rightfully rejects them.

Decorated units are derived artifacts produced by the model decorator
tool; they use the same extension as the original unit and are valid Ada 2022.
Analysis tools opt in by invoking the model decorator tool before compilation.

Decorated units are not guaranteed to be safe input to `gnatdoc`. `gnatdoc`
attaches a documentation comment block to a declaration purely by adjacency
(no intervening blank line) and matching indentation, with no special
handling for other comment forms. The model decorator step injects a
linemarker exactly at the boundaries where a subprogram's origin changes —
which coincides with where `gnatdoc` looks for a leading-style (preceding) or
trailing/`gnat`-style (following, the default) doc comment. A linemarker
spliced between a subprogram declaration and a pre-existing `gnatdoc` comment
on it can, therefore, break that association when the decorated unit, rather
than the main unit, is fed to `gnatdoc`. Decorated units should be treated as
input to compilation and analysis tools only, not to documentation
generators.

Open questions
==============

* **Overloading**: Should the profile in the sidecar declaration be
 required to be identical to the one in the main declaration (same parameter
 names, modes, and types), or only conformant (matching types and modes but
 allowing different names)?
* **`with` clauses in sidecar units**: what context clauses are permitted?
 Are they inherited from the main unit's context, or must they be repeated
 explicitly?

Prior art
=========

**C preprocessor linemarkers** (GCC manual §9.7): The `# linenum "file" flags`
convention for tracking source provenance through a preprocessing pipeline is
the direct inspiration for the decorated unit linemarker format.

**Frama-C ACSL annotations**: The ACSL specification language for C uses
`/*@ ... */` comment blocks to attach contracts to C functions without
modifying the source. The present proposal differs in that it uses a separate
file rather than inline comments, but shares the goal of non-invasive contract
attachment.

**SPARK ghost code and model packages**: SPARK already distinguishes between
executable code and ghost code. Model packages written with `pragma
Annotate (GNATprove, External_Axiomatization, ...)` serve a similar purpose to
sidecar units. However, they are package-body replacements rather than
specification overlays, and they are visible to the GNAT front-end.

**JML (Java Modeling Language)**: JML attaches formal contracts to Java methods
via specially formatted comments. Like this RFC, it keeps contracts out of
the executable source; unlike this RFC, it does not introduce a separate file
or a provenance-tracking output format.
