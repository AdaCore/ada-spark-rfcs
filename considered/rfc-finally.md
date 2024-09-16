- Feature Name: Finally for handled_sequence_of_statements
- Start Date: 2023-02-13

## Summary

Add a `finally` part to `handled_sequence_of_statements`. The statements
will be executed unconditionally, whichever path the execution takes in the
`handled_sequence_of_statements`.

## Motivation

Ada is a language with exceptions, but there is no way to have unconditional
finalization of objects, apart from using either `goto_statements`, which are a
verbose workaround, and controlled objects, which impose performance penalties
and are not the most expressive way in some situations.

We propose to add a common construct in languages with exceptions, which is the
`finally` block. Every statement in the `finally` block of statements will be
executed, regardless of whether an exception has been caught by the `exception`
block or not, allowing to run finalization actions.

```ada
procedure Example is
   F         : File_Type;
   File_Name : constant String := "simple.txt";
   Bar : Integer := Function_That_Might_Raise;
begin
   Create (F, Out_File, File_Name);
   Put_Line (F, "Hello World #1");
   Put_Line (F, "Hello World #2");
   Put_Line (F, "Hello World #3");
finally
   Close (F);
end Example;
```

## Reference level explanation

### Syntax

The grammar is extended as follows:

```
handled_sequence_of_statements ::=
     sequence_of_statements
  [exception
     exception_handler
    {exception_handler}]
  [finally
    sequence_of_statements]
```

### Name resolution

No specific amendment for name resolution, the `sequence_of_statements` after
the finally block is resolved as any other sequence of statements.

### Legality

* Return statements in the `sequence_of_statements` attached to the finally are
  forbidden.

* Goto & continue where the target is outside of the finally's
  `sequence_of_statements` are forbidden

### Runtime semantics

* Statements in the optional `sequence_of_statements` contained in the
  `finally` branch will be executed unconditionally, after the main
  `sequence_of_statements` is executed, and after any potential
  `exception_handler` is executed.

> [!NOTE]
>
> This is added as a note, because it follows naturally from the syntactic
> nesting, but it is worth mentionning anyway:
>
> The finally is executed **before** items in the enclosing declarative region
> are finalized. Also, any exception raised in the enclosing declarative region
> will happen before the handled sequence of statements, and hence the finally
> block won't be executed. This is consistent with exception
> handlers, but the consequence is that if one wants to use a `finally` block
> to ensure stuff is executed even if there is an exception raised during
> initialization of related values, he must encapsluate the declarations inside
> the finaly block:
>
> ```ada
> begin
>     declare
>         F : Foo := Create_Foo;
>     begin
>         ...;
>     end;
> finally
>    ...
> end;
>
> --  Using gnatX declaration syntax
>
> begin
>    F : Foo := Create_Foo;
>    ...;
> finally
>    ...
> end;
> ```

* If an exception is raised in the finally part, it cannot be caught by the
  `exception_handlers`.

* Abort/ATC (asynchronous transfer of control) cannot interrupt a finally
  block, nor prevent its execution, that is the finally block must be executed
  in full even if the containing task is aborted, or if the control is
  transferred out of the block.

## Rationale & alternatives

### Syntax

We discussed in the working group the pros & cons of using a new reserved word,
vs. using existing reserved words. The concrete alternative was "at end":

```ada
procedure Example is
   F         : File_Type;
   File_Name : constant String := "simple.txt";
   Bar : Integer := Function_That_Might_Raise;
begin
   Create (F, Out_File, File_Name);
   Put_Line (F, "Hello World #1");
   Put_Line (F, "Hello World #2");
   Put_Line (F, "Hello World #3");
at end
   Close (F);
end Example;
```
The considered pros & cons were the following. Pros:

* We have a very low migration cost, in this particular case, because naming a
  variable `Finally` is very unlikely. We didn't find an occurence in any
  codebase we have access to.

* `finally` being the keyword used in other languages makes it very easy to
  discover/recognize, and is also one less thing to learn/remember for every
  multi-lingual programmer.

* We don't have a lot of people migrating language versions and those who
  migrate are OK to dedicate some resources to migrating, so we already decided
  a while back that we're not completely against breaking things, if it makes
  sense.

* Very easy to do an automatic migrator if needed.

Cons:

* One more keyword in Ada which already has more than fifty
* It might be annoying for some people to have to change their code

### Misc

Other designs such as something similar to Go's `defer` were considered
https://github.com/AdaCore/ada-spark-rfcs/pull/29.

In the end we're going with this design both because of its cognitive
simplicity, because it's easy to implement in GNAT, and because it's familiar
to programmers and thus harder to fall into a trap.

We think that in many cases, type based finalization is a better fit, and
something like Ada's controlled object, or a simple mechanism akin to what is
described in https://github.com/AdaCore/ada-spark-rfcs/pull/65 is the best fit,
with `finally` complementing this feature when needed.

Feel free to read from
[here](https://github.com/AdaCore/ada-spark-rfcs/pull/29#issuecomment-539025062)
for more discussion about the `defer`-like proposal.

### Finalizing in case of exceptions

We decided in this RFC to make the declarations declared in the attached
declarative region available to the finally block, and to only execute the
finally block if the declarative region has been properly executed, in line
with the design of exception handlers, and respecting the syntactic nesting.

This has the drawback of not allowing finalization in the case where the
elaboration of the declarative region was not done. One must nest declarations
inside the `sequence_of_statements` for that.

```ada
declare
    A : Integer := raise Constraint_Error;
begin
    ...
finally
    Put_Line ("Hello");  --  Not printed
end;

begin
    A : Integer := raise Constraint_Error;
finally
    Put_Line ("Hello");  --  Printed
end;
```

## Prior art

Most languages with exceptions (Java, C#, C++, Python, ...) have a finally
block.
