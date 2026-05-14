- Feature ID: parentheses_for_parameterless_calls
- Start Date: 2025-11-08
- Status: Draft

# Summary

In pedantic Ada Flare, calls to functions, procedures, protected procedures, and task entries that take no parameters must use empty parentheses (). This RFC proposes this Flare specific rule to bring Flare in line with other languages, while allowing developers to explicitly distinguish subprogram calls from objects or components access.

# Motivation

The primary motivation is to improve language consistency and code readability at the subprogram call site. In standard Ada/SPARK, a call to a parameterless function is syntactically indistinguishable from a constant or a variable access.

By requiring `My_Function ()`, Flare provides:

1. Explicit distinction between subprogram execution and object access. In Ada, `X := Y;` is ambiguous. `Y` could be an object held in memory or it could be a function call that executes complex logic. This RFC requires () for function calls; separate RFC work will cover [] for array and composite type access. Together, these changes clarify the semantics of the operation.

2. Familiarity with other languages. Most developers coming from C, C++, Rust, Java, or Python expect () for parameterless functions.

3. Consistency. Currently, Ada requires parentheses if there are arguments but forbids them if there are none. This creates an inconsistency in the language syntax.

# Guide-level explanation

In Flare, if you want to execute a subprogram, you must always use parentheses, even if there are no arguments.

**Example:**

```ada
function Current_Status return State;
procedure Toggle_Led;

-- Invalid Flare:
Status := Current_Status;
Toggle_Led;

-- Valid Flare:
Status := Current_Status ();
Toggle_Led ();
```

# Reference-level explanation

None at this stage.

# Rationale and alternatives

## Impact on the Uniform Access Principle (UAP)

The Uniform Access Principle (UAP) suggests that a user should not know if a value is stored (for instance, as a record component or static constant) or computed (as a function call). One advantage is that you can refactor a variable, constant, or record component into a function without changing the call sites.

Flare explicitly rejects this principle here, considering the benefits described in the Motivation section more important than UAP.

### Python Properties

Python provides a middle ground that Flare may adopt in the future (see the Future Possibilities section below). Python requires () for functions but allows a `@property` decorator to expose a function as if it were a field.

## Additional analysis

The following examples were considered because they look like possible silent migration hazards. In particular, they test whether omitting `()` during migration could cause a name that denoted an inner parameterless function in Ada to resolve to an outer object in Flare.

Under Ada-style visibility rules, this problem does not occur:

- Ada RM 2022 8.3 specifies the relevant visibility rules: callable declarations are overloadable; same-name declarations are homographs unless both are overloadable and their profiles differ; and an inner declaration hides any outer homograph from direct visibility.
- Ada RM 2022 6.4 allows a `function_call` to be written as just a `function_name`, which is the Ada syntax this RFC changes in Flare.

### Example 1:

Consider the following Ada program:

```ada
with Ada.Text_IO;

procedure Main is
   X : Integer := 1;  -- Outer scope X

begin
   declare
      function X return Integer is (2);  -- Inner scope X, shadows outer scope X
      Y : constant Integer := X;  -- Ada resolves this to the inner function X → Y = 2
   begin
      Ada.Text_IO.Put_Line (Y'Image);
   end;
end Main;
```

In Ada, `X` resolves to the inner function (inner declarations shadow outer ones), so `Y` is `2`.

In Flare, if the migration omits the parentheses, `X` still resolves to the inner function, because the inner function declaration hides the outer variable from direct visibility. Pedantic Flare then rejects `X` because parameterless subprogram calls require `()`. The call would need to be updated to `X ()`.

### Example 2:

Example 2 shows how the same analysis applies when the parameterless function returns an array. Consider the following Ada program:

```ada
with Ada.Text_IO;

procedure Main is

   type Z_Range is range 1 .. 10;
   type Z_Array is array (Z_Range) of Integer;
   Z : Z_Array := [others => 1];  -- Outer scope Z

begin
   declare
      function Z return Z_Array is ([others => 2]);  -- Inner scope Z, shadows outer scope Z
      Y : constant Integer := Z (1);  -- Ada resolves this to the inner function Z -> Y = 2
   begin
      Ada.Text_IO.Put_Line (Y'Image);
   end;
end Main;
```

In Ada, `Z (1)` calls the inner parameterless function `Z` which returns a `Z_Array`. Indexing with `(1)` returns `2`.

In Flare, `Z` still resolves to the inner function, because the inner function declaration hides the outer array variable from direct visibility. Omitting `()` is therefore a compile-time error rather than a silent change to indexing the outer array variable.

The call would need to be updated to `Z () (1)` (and once RFC `mandatory_square_bracket_array_aggregates` is applied, it would need to be updated to `Z () [1]`).

# Drawbacks

Some drawbacks are related to compatibility. See the Compatibility section below.

This proposal necessitates "chained parentheses" when accessing elements of a returned array or composite type, which is arguably not a particularly pleasing syntax:

- Ada: `Element := Get_Array (1);`
- Flare: `Element := Get_Array () (1);`

However, this is improved by using square brackets for indexing: `Element := Get_Array () [1]`. It visually distinguishes the function call () from the index []. Square bracket indexing is proposed as mandatory in RFC `mandatory_square_bracket_array_aggregates`.

# Compatibility

In pedantic Ada Flare, the use of `()` for parameterless subprogram calls is mandatory. Its absence is rejected.

In non-pedantic Ada Flare, both the Ada 2022 and the Ada Flare syntax remain valid to preserve backward compatibility.

# Open questions

None at this stage.

# Prior art

None at this stage.

# Unresolved questions

None at this stage.

# Future possibilities

Once `()` is mandatory for subprograms, a `property` aspect could be introduced to expose a subprogram as if it were a stored value. This restores the UAP principle.
