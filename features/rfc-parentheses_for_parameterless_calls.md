- Feature ID: parentheses_for_parameterless_calls
- Start Date: 2025-11-08
- Status: Draft

# Summary

This RFC proposes requiring empty parentheses () for calls to functions and procedures that take no parameters, in pedantic Ada Flare. This change aims to bring Flare in line with other languages, while providing developers the ability to explicitly distinguish between value access and computation.

# Motivation

The primary motivation is to improve language consistency and code readability at the subprogram call site. In standard Ada/SPARK, a call to a parameterless function is syntactically indistinguishable from a constant or a variable access.

By allowing `My_Function ()`, Flare provides:

1. Explicit distinction between execution and access. In Ada, `X := Y;` is ambiguous. `Y` could be an object held in memory or it could be a function call that executes complex logic. By requiring () for function cals and [] for array and composite types access, Flare clarifies the semantics of the operation.

2. Familiarity with other languages. Most developers coming from C, C++, Rust, Java, or Python expect () for parameterless functions.

3. Consistency. Currently, Ada requires parentheses if there are arguments but forbids them if there are none. This creates an inconsistency in the lanaguge syntax.

# Guide-level explanation

In Flare, if you want to execute a subprogram, you must always use parentheses, even if there are no arguments.

**Ada Syntax:**

```ada
function Current_Status return State;
procedure Toggle_Led;

-- Invalid Flare:
-- Status := Current_Status;
-- Toggle_Led;

-- Valid Flare :
Status := Current_Status ();
Toggle_Led ();
```

# Reference-level explanation

None at this stage.

# Rationale and alternatives

## Impact on the Uniform Access Principle (UAP)

The Uniform Access Principle (UAP) suggests that a user should not know if a value is stored (as a record component) or computed (as a function call). An advantage is that you are able to refactor a variable, constant or record component into a function without changing the call sites.

Flare explicitly rejects this principle and creates a distinction between computation and storage.

### Python Properties

Python provides a middle ground that Flare may adopt in the future (see the Future Possibilities section below). Python requires () for functions but allows a @property decorator to expose a function as if it were a field.

# Drawbacks

The primary drawbacks are related to compatibility. See the Compatibility section below.

# Compatibility

In pedantic Ada Flare, the use of `()` for parameterless subprogram calls is mandatory. Its abcense is rejected.

In non-pedantic Ada Flare, both the Ada 2022 and the Ada Flare syntax remain valid to preserve backward compatibility.

# Open questions

None at this stage.

# Prior art

None at this stage.

# Unresolved questions

None at this stage.

# Future possibilities

Once () is mandatory for subprograms, a property concept could be introduced thorugh through a property aspect. This restores the UAP principle.
