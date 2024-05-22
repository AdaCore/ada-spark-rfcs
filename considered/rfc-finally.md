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

Every statement in the optional `sequence_of_statements` contained in the
`finally` branch will be executed unconditionally, after the main
`sequence_of_statements` is executed, and after any potential
`exception_handler` is executed.

The finally block is considered as being outside of the
`handled_sequence_of_statements`, so that if an exception is raised while
executing it, `exception_handlers` will *not* be considered.

Please note that if the attached declarative region was not properly
elaborated, then the `finally` block won't be executed. This in turns allows
the finally block to have access to the declarations declared in the attached
declarative region.

## Rationale & alternatives

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

## Unresolved questions

### Finalizing in case of exceptions

We decided in this RFC to make the declarations declared in the attached
declarative region available to the finally block, and to only execute the
finally block if the declarative region has been properly executed, in line
with the design of exception handlers. 

This has the drawback of not allowing finalization in the case where the
elaboration of the declarative region was not done. There is no obvious fix to
this.

### New keyword vs. existing keywords

The current version of the RFC introduces a new keyword, which has pros & cons.

If we want to use only existing keywords:

* A proposed alternative was `end with`, but `end ...` is generally used to
  finish a block defining an entity in Ada, which makes it confusing.

* Another proposed alternative was `at end`, which seems workable.

Pros for using a new keyword:

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



## Prior art

Most languages with exceptions (Java, C#, C++, Python, ...) have a finally
block.
