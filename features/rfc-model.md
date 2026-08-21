- Feature Name: model
- Start Date: 2026-04-02
- Status: Design

Summary
=======

This RFC proposes a mechanism for attaching analysis-oriented contracts,
consisting of aspects that do not affect execution with assertions
disabled (such as `Pre`, `Post`, `Global`, and `Test_Case`), to subprograms
without modifying the package's original source.

The RFC only addresses aspects attached to sub-programs.

Note, that the content of the RFC is somewhat exceptional. Normally, the 
RFC's in this repository address language modificaitons. In this case, the
design team concluded, that the language-oriented proposal can be mostly
solved by additional tooling. The only change in the language is the
dedicated syntax for annotation. To cover the original problem, we describe
the full workflow including the tooling advice.

The envisaged workflow is as follows:

* The developer creates a sidecar unit containing the selected model
declarations and other code fragments that matching **main specification**
or **main body**.

* A **model decorator** step merges the main unit and sidecar unit into a
**decorated unit** where code blocks are annotated to show their origin.

* The decorated unit is used instead of the original **main unit** when
compiling or analyzing the code.

Technically, the proposal relies on five related components:

(1) The `Model` aspect and the structure of the sidecar unit.

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
The only envisaged change is to support annotations that denote the original location
of the source code fragments. The `Model` aspect itself is consumed by the model decorator
step and never reaches the compiler: it does not appear in the decorated unit, and sidecar
units are excluded from the regular build.
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
--  my_math.ams  (sidecar specification, not compiled by the regular build)
package My_Math is
 function Sqrt (X : Float) return Float
 with
 Model,
 Pre  => X >= 0.0,
 Post => Sqrt'Result >= 0.0;

 function Hidden (X : Float) return Float
 with
 Model,
 Pre  => X >= 0.0;
end My_Math;
```

A sidecar specification is an ordinary package declaration that repeats the
name of the package it decorates. It is not identified as a sidecar by its
syntax, but by its file extension: sidecar units use the dedicated extensions
**`.ams`** (sidecar specification) and **`.amb`** (sidecar body), in place of
the `.ads` and `.adb` of the main unit. A sidecar file therefore sits next to
the unit it decorates under the same base name — `my_math.ams` beside
`my_math.ads` — and is invisible to a build that only looks for Ada sources.

Inside a sidecar package, each decorated subprogram declaration carries the
Boolean aspect `Model`. `Model` marks the declaration as a model entry: it
does not introduce a new subprogram, but names an existing one in the main
unit and supplies the remaining aspects for it. In sidecar specifications,
model entries may target any declaration in the public or private part of the
corresponding package: in the example above, `Hidden` is declared in the
private part of `my_math.ads`, but its model entry needs no `private` part of
its own — the sidecar does not have to mirror the structure of the unit it
decorates.

For a sidecar body, the same processing applies, but entries marked with
`Model` may only apply to the specifications of subprograms declared in the
body. Any other code fragments in the sidecar unit that do not carry the
`Model` aspect are copied unchanged into the decorated output.

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
and define a helper function in the sidecar package:

```ada
--  my_math.amb  (sidecar body, not compiled by the regular build)

--  additional included packages
with Helper_Package; use Helper_Package;

package body My_Math is
 --  helper function to express the contract
 function Greater_Than (X, Y : Float) return Boolean is
 begin
 return X > Y;
 end Greater_Than;

 function Pow (X, Y : Float) return Float
 with
 Model,
 Pre  => Greater_Than (X, 0.0),
 Post => Greater_Than (Pow'Result, 0.0);
end My_Math;
```

In this example, the entry marked with `Model` is resolved against the body
specification for `Pow` in the main body, the helper function `Greater_Than`
carries no `Model` aspect and is therefore copied verbatim into the decorated
output, together with the context clause that precedes the package.

### Validity rules for sidecar units

`Model` is a Boolean aspect. It may only be specified on a subprogram
declaration in a sidecar unit, and only with the value `True` — the
abbreviated form `Model` is therefore the expected spelling. A subprogram
declaration carrying `Model` must specify at least one further aspect;
otherwise, the entry contributes nothing.

Apart from `Model` itself, only the aspects that do not affect execution when
`Assertion_Policy` is set to `Ignore` or `Disable` may be specified on a model
entry — for example, `Pre`, `Post`, `Global`, `Depends`, `Contract_Cases`,
`Test_Case`, `Subprogram_Variant`, `Ghost`, and `Annotate`.
Such an aspect is accepted in the model when the same aspect doesn't
yet exist in the actual subprogram specification.
Overriding or changing an existing aspect specification is not permitted.

Annotation can be applied to a generic instance, but not to a generic.

The fragments of the sidecar unit that do not carry the `Model` aspect
and are thus copied as-is shall have a valid Ada syntax. The model decorator
step does not check them, assuming that, in the event of conflicts with other
elements of the program, the compilation step will discover them.

An annotation can be applied to a child unit using the unit's qualified name.

The decoration step shall stop with an error when it cannot find a subprogram
matching a model entry.

### (2) The model decorator step

The model decorator step reads both the main unit and the sidecar unit, and produces the decorated unit.

For specifications, the step merges the package specification with the sidecar model declarations.
It injects contracts into the corresponding source declarations.
For bodies, the step performs the same merge on the body: it reads the actual package body and the sidecar body, resolves declarations carrying `Model` against body specifications, and injects the remaining aspects into the matched declarations.

In both cases, fragments of the sidecar that do not carry the `Model` aspect are copied through unchanged, and the decorated output preserves origin information using linemarkers. The `Model` aspect itself is never emitted.

```ada
pragma Source_Annotations (On);

--  my_math_decorated.ads  (decorated specification, consumed by analysis tools)
--# @Source_Reference@ 1 "my_math.ads" 1
package My_Math is
 function Sqrt (X : Float) return Float
--# @Source_Reference@ 3 "my_math.ams" 1
 with
--# @Source_Reference@ 5 "my_math.ams"
 Pre  => X >= 0.0,
 Post => Sqrt'Result >= 0.0;
--# @Source_Reference@ 3 "my_math.ads" 2
 function Log (X : Float) return Float;
private
 function Hidden (X : Float) return Float
--# @Source_Reference@ 9 "my_math.ams" 2
 with
--# @Source_Reference@ 11 "my_math.ams"
 Pre  => X >= 0.0;
--# @Source_Reference@ 6 "my_math.ads" 2
end My_Math;
```

The private part is decorated exactly like the visible part. Note that no
linemarker precedes `private` or the declaration of `Hidden`: both continue
the run of lines that started at `my_math.ads` line 3, so their origin is
already implied by the preceding marker.

For a body, the decorated output is produced in the same way.
The model contracts are merged into the actual body declaration, and the
origin linemarkers preserve their relationship to both the original body and
the sidecar body.

```ada
pragma Source_Annotations (On);

--  my_math_decorated.adb  (decorated body, consumed by analysis tools)
--# @Source_Reference@ 1 "my_math.amb" 1
--  additional included packages
with Helper_Package; use Helper_Package;

--# @Source_Reference@ 1 "my_math.adb" 1
package body My_Math is
--# @Source_Reference@ 5 "my_math.amb" 2
 --  helper function to express the contract
 function Greater_Than (X, Y : Float) return Boolean is
 begin
 return X > Y;
 end Greater_Than;

--# @Source_Reference@ 3 "my_math.adb" 2
 function Pow (X, Y : Float) return Float
--# @Source_Reference@ 12 "my_math.amb" 2
 with
--# @Source_Reference@ 14 "my_math.amb"
 Pre  => Greater_Than (X, 0.0),
 Post => Greater_Than (Pow'Result, 0.0);
--# @Source_Reference@ 4 "my_math.adb" 2
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
file, the tool shall create the missing unit during decoration so that the sidecar
can still participate in the analysis. An example of such a scenario would be 
a contract that uses ghost code and this ghost code requires a body. Model 
entries are not accepted in this case as there isn't anything to annotate.

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

### (1) The `Model` aspect

The sidecar unit introduces no new grammar: it is an ordinary Ada compilation
unit whose unit name is the name of the package it decorates, held in a file
with the extension `.ams` (specification) or `.amb` (body). The only addition
to the language is the aspect `Model`:

```
decorated_subprogram_declaration ::=
 subprogram_specification
 "with" "Model" [ "=>" "True" ] "," decoration_aspect_list ";"

decoration_aspect_list ::=
 decoration_aspect { "," decoration_aspect }

decoration_aspect ::=
 pre_aspect | post_aspect | contract_cases_aspect
 | global_aspect | depends_aspect | test_case_aspect
 | subprogram_variant_aspect | ghost_aspect | annotate_aspect
 | <any other aspect with no effect on execution>
```

`Model` is a Boolean aspect that may be specified only on a subprogram
declaration, and only in a sidecar unit. Its aspect definition, if given,
shall be the static expression `True`; the abbreviated form `Model` is
equivalent and is the expected spelling. `Model` shall not be inherited, and
shall not be specified on a subprogram body, a body stub, a renaming, or a
generic declaration.

A `decorated_subprogram_declaration` shall specify at least one aspect besides
`Model`, and only aspects that do not affect execution (see the aspect
list above). A sidecar unit may also contain ordinary source text and
declarations that carry no `Model` aspect; those fragments are copied through
unchanged into the decorated output.

### (2) Model decorator step: resolution and synthesis

**Resolution rules for decorated subprogram declarations**

A subprogram declaration carrying `Model` must name a subprogram declared in
the package named by the enclosing package declaration. That package may be a
child package named by its qualified name (for example, `package My_Math.Extra
is`), in which case the declaration is resolved against that child package's
own specification or body, not against its parent. Overloaded names are
disambiguated by matching the parameter profile of the decorated declaration
against the candidates in the target package. If no candidate matches, or more
than one candidate matches, the model decorator tool reports an error.

In a sidecar specification, model entries may target any declaration in the
public or private part of the corresponding package. In a sidecar body,
model entries may target only subprogram specifications.

**Synthesis algorithm**

1. Parse the main unit and collect all relevant declarations with their
 source locations.
2. Parse the sidecar unit; for each `decorated_subprogram_declaration`, resolve
 it against the main source declarations.
3. Conflict check: if a main source declaration already carries any of the
 aspects present in the sidecar entry for the same subprogram, then emit an error.
4. Build the decorated unit by iterating over the main source in source order,
 inserting linemarkers before each run of lines that share the same origin,
 and injecting the aspect specification from the sidecar immediately after the
 closing parenthesis of the subprogram profile (and before the semicolon that
 would otherwise terminate it).
5. Copy any sidecar code fragments that carry no `Model` aspect into the
 decorated output unchanged.
6. If the sidecar exists but the corresponding main unit does not, create the
 missing main unit and use it as the basis for the decorated output.
7. The subprogram specification of a model entry, and the `Model` aspect
 itself, are synthesis directives and are **not** emitted in the decorated
 unit; only the remaining aspects of the entry are.

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

The intent here is to keep decoration completely out of the production
compilation pipeline.
A separate sidecar unit keeps that separation at the file level: sidecar files
carry their own extensions (`.ams` / `.amb`), so a build that looks for `.ads`
and `.adb` never reads them, and their exclusion needs no rule of its own.

**Why an aspect rather than a `model` keyword?**

An earlier revision of this proposal introduced a `model` keyword, used both
as a prefix on the package (`model package My_Math is`) and on each decorated
declaration (`model function Sqrt ...`). Using the aspect `Model` instead has
several advantages:

* It adds no reserved word, so it cannot collide with existing identifiers and
 requires no change to the Ada grammar.
* A sidecar unit remains syntactically valid Ada, so ordinary editors,
 pretty-printers, and IDEs handle it without modification — which matters
 because a sidecar is written and maintained by hand.
* Decoration is expressed with the same mechanism as the contracts it carries.
 A model entry is simply a subprogram declaration whose aspect list starts
 with `Model`, so there is one syntax to learn rather than two.
* The marker sits on the declaration it applies to rather than on the enclosing
 package, which makes a sidecar unit that mixes model entries with ordinary
 helper code (as a sidecar body typically does) unambiguous to read.

The price is that a sidecar unit can no longer be recognized as such from its
first line. That role is taken over by the file extension: the `.ams` / `.amb`
pair identifies a sidecar unit before it is parsed, which is what the build
system needs, and does so without reserving a word in the language.

**Why an aspect rather than a library-level pragma?**

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
* The meaning of the `Model` aspect is entirely tool-defined; it has no runtime
 semantics and is rejected as an unknown aspect by a standard compiler.
* A sidecar unit is syntactically indistinguishable from the unit it decorates;
 only its file extension sets it apart. A sidecar that is deliberately added
 to the compilation chain is rejected — but for the unrelated reason that
 `Model` is not a known aspect, and possibly only after a duplicate-unit error
 that is harder to interpret.
* The `.ams` and `.amb` extensions must be taught to every tool that maps file
 names to Ada units — editors, project files, version-control attributes, and
 the model decorator itself — and they are not recognized by an unmodified
 `gprbuild`.
* Tool vendors must implement the conflict-detection rule independently, risking
 divergent interpretations.
* Decorated packages that model large third-party libraries may grow complex and
 require their own maintenance discipline.

Compatibility
=============

The feature is fully backward compatible: existing specifications and bodies are
unaffected. No reserved word is added, and the `Model` aspect only ever appears
in sidecar units. Sidecar units use the dedicated extensions `.ams` and `.amb`,
which no existing Ada source uses and which the default GNAT naming scheme does
not treat as Ada sources, so a project that does not know about this feature
never picks them up — even when the sidecar files sit in a source directory
alongside the units they decorate. The GNAT front-end therefore never sees a
sidecar unit in a regular build. If one is deliberately added to the
compilation chain, the compiler rightfully rejects it, since `Model` is not a
known aspect.

Decorated units are derived artifacts produced by the model decorator
tool; they use the ordinary `.ads` / `.adb` extensions of the unit they replace
and are valid Ada 2022. Analysis tools opt in by invoking the model decorator
tool before compilation.

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
