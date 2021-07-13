- Feature Name: scalar-initialization-checks
- Start Date: 2021-07-09
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

The aim of this RFC is to introduce static checks for the initialization of
local scalar variables before use. As these checks reject valid use cases (the
approach is pessimistic), they would be enabled by a specific restriction.

Motivation
==========

Reads of uninitialized data are a common cause of error in software. Different
languages have introduced static restrictions to statically prevent them (Java,
Rust, Swift...). However, deciding whether a given object is initialized is
complicated. In the most general case, it can require inter-procedural analysis
and powerful static verification techniques. As a result, static checks mandated
in programming languages tend to reject code where no reads of uninitialized
data actually occur. Finding a good balance between ease of verification and
expressivity is of essence here.

This RFC concentrates on scalar variables because Ada mandates initialization of
scalars on copy. As a result, parameters of a scalar type should be initialized
on entry/exit of a subprogram, making an intra-procedural analysis easier to
design. In the same way, we only consider the initialization of local variables
to avoid the necessity of a whole program analysis.

Guide-level explanation
=======================

The restriction "No_Uninitialized_Local_Scalars" can be used to instruct the
compiler to check that every local variable of a scalar type (or of a private
type whose completion is a scalar type) is initialized before it is read
(copy-back of OUT parameters counts as a read).

A read variable is considered to be local if either, the variable
is library level and the read occurs directly in the elaboration of one of
its enclosing packages or the variable is declared inside a subprogram, task, or
entry and the expression is evaluated in the body or spec of the same
unit.

A variable is considered to be initialized if either it is a parameter of mode
IN OUT, its type has a Default_Value aspect, an initial expression is supplied
for its declaration, or it can be statically determined that all program paths
leading to the read contain at least an assignment (including copy-back on OUT
parameters).

For example, in the following code, a check will be done at compile time to
ensure that `F1`, `X1`, `X2`, and `X3` are initialized before the call to
`Read`. The check will succeed. Indeed, `F1` is considered to be initialized at
call site, `X1` and `X2` are initialized at declaration
(either implicitly or explicitly), and `X3` is initialized on all paths leading
to the call. Another check is performed to ensure that the OUT parameter `F2`
is initialized on all paths exiting the subprogram normally, as it will be read
on copy-back. This one will fail as it is possible to return before the
assignment into `F2`.

```
procedure Init (X : out Integer);

procedure Do_Something (F1 : in out Integer; F2 : out Integer) is
  X1 : Integer := 14;
  type My_Int is new Integer with Default_Value => 0;
  X2 : My_Int;
  X3 : Integer;
begin
  if <...> then
    X3 := 42;
  elsif <...> then
    Init (X3);
  else
    return;
  end if;
  
  F2 := Read (F1, X1, X2, X3);
end;
```

Values of conditions, in conditional expressions or loops for example, are not
tacken into account to decide whether a path is considered to be feasible,
unless the condition is statically known. For example, in the following code,
`X` will not be considered initialized after the first if-statement. As a
result, the initialization check in the second if-statment will fail at
compile time, even if the conditions on both if-statements match.

```
declare
  X : Integer;
begin
  if B then
    X := 12;
  end if;

  if B then
    X := X + 1;
  end if;
end;
```

The read of `X` at the end of the declare block in the following snippet is
valid however, as it can be statically determined that the body of the loop is
executed at least once.

```
declare
  X : Integer;
begin
  for I in 1 .. 10 loop
    X := 13;
  end loop;

  X := X + 1;
end;
```

All classical control flow construsts are supported, including goto statements
and exception handling. However, to ensure that no uninitialized scalar
variables can be read, they are necessarily handled in the most pessimistic
way. For example, in the following code, the check ensuring that `F` is
initialized at the end of `Do_Something` will fail. Indeed, even if `F` is set
before every explicit raise of the exception `A`, we cannot be sure statically
that no other constructs in the body of `Do_Something` won't raise `A`, so
`F` needs to be initialized before the handled sequence of statements or
in the exception handler.

```
procedure Do_Something (F : out Integer) is
begin
  if ... then
    F := 11;
    raise A;
  elsif ... then
    raise B;
  else
    F := ...;
  end if;
  
exception
  when A => null; -- F could be uninitialized here
end Do_Something;
```

Note that only paths exiting a subprogram normally are considered when
checking that a parameter of mode OUT is initialized on subprogram exit. In
the example above, the fact that `F` is not initialized when exception `B` is
raised is not a problem, since `B` is not handled in the subprogram. Calls
to subprograms annotated with `No_Return` and pragma `Assert` with a statically
false expression are handled in the same way.

Reference-level explanation
===========================


Rationale and alternatives
==========================


Drawbacks
=========


Prior art
=========

Rust considers immutable variables to be uninitialized until the compiler can
prove that all paths include an explicit initialization. Values for conditions
on branches are ignored. They have fairly subtle patterns using unsafe code for
piecewise array initialization. 

Swift ensures initialization at declaration through initializers (constructors).
Failure during initialization makes the object nil. The compiler enforces that
each variable was initialized before it is used.

Dart ensures initialization and non-nullity using flow analysis similar to Rust.

Java requires initialization of local variables on all paths if not initialized
at declaration.


Unresolved questions
====================

Future possibilities
====================

Another restriction could be introduced to force static initialization checking
for all composite objects. This would provide more safety, but with additional
constraints.

The `Global` annotation could be used to support global objects.

The analysis performed here could be reused to check for absence of null
dereference for local access objects. The fact that parameters and return type
of subprograms can be annotated with null exclusion could hopefully lead to
an acceptable trade-off between safety and expressivity.
