- Feature Name: model_of
- Start Date: 2026-04-02
- Status: Design

Summary
=======

This RFC proposes a mechanism for attaching analysis-oriented contracts (pre-
and postconditions, and other aspects) to subprograms without modifying the
original source of the package. The envisaged workflow is as follows:

* The developer creates a **sidecar .ads** file that contains selected subprogram
prototypes from the **main .ads** file with the necessary contract.

* A **model decorator** step merges these files into a
**decorated .ads** where code blocks are annotated to show their origin.

* The **decorated .ads** is used insted of **main .ads** when compiling or
analysing the code.

Technically, the proposal relies on five related components:

(1) Syntax for the **sidecar .ads** file.
(2) Implementation of the **model decorator** step.
(3) A workflow for integrating the model step with the rest of the
toolchain.
(4) Syntax for code annotations in **decorated .ads**.
(5) Compiler modifications to take code annotations into account when displaying
diagnostics messages.

Step (3) is outside the scope of this proposal and depends on the implementation choiches on step (2).
The alternatives for step (2) are either to implement it as a separate preprocessing tool or an integrated
step inside the compiler. 

Motivation
==========

It may not be always possible or reasonable to include a formal contract in the specification of the subprograms. Some examples of scenarios, where formal contracts in source code may not be feasible:

* When analysing legacy code, one may want to avoid unnecessary changes in the original sources.

* Formal contracs may be long and complex. Mixing them with functional code may reduce the readability and maintainability of both.

* In case of certified code, one needs to prove that all code is either fully verified or is completely isolated from the certified functionality. Removing the sidecar files is significantly simpler than proving the contracts are fully removed during compilation.

The workflow presented in the summary aims to minimize the impact on the complation process. The only envisaged 
changes are ignoring the syntax of the sidecar file (to avoid including it in compilation chain by accident) and the
support for annotations denoting the original location of the source code fragments.
Generating the decorated may happen outside the compiler.

Guide-level explanation
=======================

### (1) The sidecar .ads file

Consider an existing package that must not be modified:

```ada
-- my_math.ads  (main .ads, not modified)
package My_Math is
   function Sqrt (X : Float) return Float;
   function Log (X : Float) return Float;
end My_Math;
```

A developer wishing to supply contracts for formal analysis creates a companion
sidecar .ads file:

```ada
-- my_math_models.ads  (sidecar .ads, not compiled by the regular build)
model package My_Math is
   model function Sqrt (X : Float) return Float
     with
       Pre  => X >= 0.0,
       Post => Sqrt'Result >= 0.0;
end My_Math;
```

A sidecar .ads begins with `model package <package-name> is` instead of
`package <package-name> is`.  The `model` keyword signals to the tool that
this file supplies additional specification information and is never compiled
as a stand-alone unit.

Inside a sidecar package, each decorated subprogram declaration begins with
`model` (for example, `model function` or `model procedure`).  The name and
profile are resolved against the target package, and all other aspects on the
same subprogram declaration (`Pre`, `Post`, `Contract_Cases`, `Global`, etc.)
are the contracts to be injected.

### (2) The model decorator step

The model decorator step reads both the main .ads and the sidecar .ads, and produces the decorated .ads:

```ada
pragma Source_Annotations (On)

-- my_math_decorated.ads  (decorated .ads, consumed by analysis tools)
-- # 1 "my_math.ads" 1
package My_Math is
   function Sqrt (X : Float) return Float
-- # 3 "my_math_models.ads" 1
     with
-- # 5 "my_math_models.ads"
       Pre  => X >= 0.0,
       Post => Sqrt'Result >= 0.0;
-- # 3 "my_math.ads" 2
   function Log (X : Float) return Float;
end My_Math;
```

The decorated .ads is valid Ada 2022 (with contract aspects) and is passed to
analysis tools instead of the original main .ads.

`pragma Source_Annotations (On)` instructs compiler to apply special processing
to annotations representing code locations.

A given subprogram may carry contracts in at most one of the main .ads and the
sidecar .ads.  If both files supply a pre- or postcondition for the same
subprogram, the model decorator tool reports an error indicating the conflicting
line in each file.  This rule prevents silent shadowing of production contracts
by sidecar contracts.

### (3) Toolchain integration

Integrating the model decorator step with the rest of the toolchain is outside
the scope of this proposal.

### (4) Code annotations in the decorated .ads

Special syntax for code addotations is activated by `pragma Source_Annotations (On)`.

Each linemarker embedded in the decorated .ads is an Ada line comment of the
form:

```
-- # linenum "filename" [flags]
```

The semantics follow the C preprocessor convention (GCC manual §9.7):

| Field      | Meaning |
|------------|---------|
| `linenum`  | Line number in `filename` that the **immediately following** source line originated from. |
| `filename` | Quoted path to the origin file. |
| `1`        | First occurrence of this file (entering a new file). |
| `2`        | Returning to `filename` after lines were taken from another file. |
| *(absent)* | Continuation within the same file at a non-sequential line number. |

A new linemarker is emitted only when the origin file changes or when the next
line number is not the direct successor of the previous one (i.e., lines were
skipped — for instance because a sidecar declaration is a resolved reference
and does not appear in the output).

Using these rules, any tool processing the decorated .ads can reconstruct the
exact origin of each line by tracking the current `(filename, linenum)` pair
and incrementing `linenum` for each non-comment source line between markers.

### (5) Compiler support for code annotations

When the compiler encounters a linemarker comment in a decorated .ads, it uses
the embedded `(filename, linenum)` pair to attribute any diagnostics to the
originating source location rather than to the decorated .ads.  This ensures
that error and warning messages refer to lines in the main .ads or the sidecar
.ads, as appropriate.

Reference-level explanation
===========================

### (1) Sidecar .ads grammar

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
  | global_aspect | depends_aspect
  | <any other subprogram aspect legal in the target Ada standard>
```

Every `decorated_subprogram_declaration` must begin with `model` and must
contain only contract-related aspects.

### (2) Model decorator step: resolution and synthesis

**Resolution rules for decorated subprogram declarations**

A `model` subprogram declaration must name a subprogram declared in the
package named by the enclosing `model package` clause.  Overloaded names are
disambiguated by matching the parameter profile of the decorated declaration
against the candidates in the target package.  If no candidate matches, or more
than one candidate matches, the model decorator tool reports an error.

**Synthesis algorithm**

1. Parse the main .ads and collect all subprogram declarations with their
   source locations.
2. Parse the sidecar .ads; for each `decorated_subprogram_declaration`, resolve
   it against the main .ads declarations.
3. Conflict check: if a main .ads declaration already carries any of the aspects
   present in the sidecar .ads entry for the same subprogram, emit an error.
4. Build the decorated .ads by iterating over the main .ads in source order,
   inserting linemarkers before each run of lines that shares the same origin,
   and injecting the `with` clause from the sidecar .ads immediately after the
   closing parenthesis of the subprogram profile (and before the semicolon that
   would otherwise terminate it).
5. The `model` declaration is a synthesis directive and is **not** emitted in the
   decorated .ads.

### (4) Linemarker emission rules (normative)

Let `(file, line)` be the origin of the most recently emitted non-comment
source line.  Before emitting the next source line with origin `(file', line')`:

* If `file' ≠ file`:
  * If `file'` has not been seen before in the current decorated .ads, emit
    `-- # line' "file'" 1`.
  * Otherwise emit `-- # line' "file'" 2`.
* Else if `line' ≠ line + 1`:
  * Emit `-- # line' "file'"` (no flag).
* Otherwise no marker is needed.

Rationale and alternatives
==========================

**Why a separate sidecar .ads rather than a pragma or pragma-based approach?**

Pragmas are compiled by `gprbuild` and visible to all tools.  The intent here
is to keep decoration completely out of the production compilation pipeline.
A separate sidecar .ads with `model package` syntax makes this separation
syntactically unambiguous: build systems can exclude sidecar .ads files without
any special configuration by recognizing the `model package` keyword.

**Why `model package` syntax rather than a library-level pragma?**

A pragma-based approach (e.g., `pragma Decorate (My_Math, ...);`) would be
structurally flat and offer no natural place to write a full subprogram
profile including aspects.  Mirroring the package declaration provides a
familiar, IDE-navigable structure and reuses Ada's existing aspect syntax
without any new grammar for individual contracts.

**Why linemarkers in comments rather than a separate source-map file?**

A separate source-map file risks going out of sync with the decorated .ads if
the decorated .ads is post-processed.  Embedding linemarkers as comments keeps
provenance co-located with the text, survives most transformations, and follows
a well-understood convention already used by GCC, Clang, and the Ada
preprocessor.

Drawbacks
=========

* Introduces a sidecar .ads artifact and a model decorator step not part of
  standard Ada.
* Meaning of `model` declarations is entirely tool-defined; the syntax has no
  runtime semantics and is rejected by a standard compiler unless hidden behind
  a configuration pragma.
* Tool vendors must implement the conflict-detection rule independently, risking
  divergent interpretations.
* Decorated packages that model large third-party libraries may grow complex and
  require their own maintenance discipline.

Compatibility
=============

The feature is fully backward compatible: existing `.ads` files are unaffected.
Sidecar .ads files are never seen by the GNAT front-end in a regular build. If they still are included in the compilation chain, the compiler rejects them
rightfully.

Decorated .ads files are derived artifacts produced by the model decorator
tool; they use the standard `.ads` extension and are valid Ada 2022.  Analysis
tools opt in by invoking the model decorator tool before compilation.

Open questions
==============

* **Overloading**: should the profile in the sidecar .ads declaration be
  required to be identical to the one in the main .ads (same parameter names,
  modes, and types), or only conformant (matching types and modes but allowing
  different names)?
* **Child packages**: can a sidecar .ads file decorate subprograms in a child
  package specification?  If so, should the `model package` clause mirror the
  full dotted name?
* **`with` clauses in sidecar .ads files**: what context clauses are permitted?
  Are they inherited from the main .ads's context, or must they be repeated
  explicitly?
* **Ghost aspects**: should Ghost aspects from SPARK be allowed in sidecar .ads
  files?  They are analysis-only by nature and would be consistent with the
  intent of this RFC.

Prior art
=========

**C preprocessor linemarkers** (GCC manual §9.7): The `# linenum "file" flags`
convention for tracking source provenance through a preprocessing pipeline is
the direct inspiration for the decorated .ads linemarker format.

**Frama-C ACSL annotations**: The ACSL specification language for C uses
`/*@ ... */` comment blocks to attach contracts to C functions without
modifying the source.  The present proposal differs in that it uses a separate
file rather than inline comments, but shares the goal of non-invasive contract
attachment.

**SPARK ghost code and model packages**: SPARK already distinguishes between
executable code and ghost code.  Model packages written with `pragma
Annotate (GNATprove, External_Axiomatization, ...)` serve a similar purpose to
sidecar .ads files but are package-body replacements rather than specification
overlays, and they are visible to the GNAT front-end.

**JML (Java Modeling Language)**: JML attaches formal contracts to Java methods
via specially formatted comments.  Like this RFC, it keeps contracts out of
the executable source; unlike this RFC, it does not introduce a separate file
or a provenance-tracking output format.
