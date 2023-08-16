- Feature Name: Finally for handled_sequence_of_statements
- Start Date: 2023-02-13 

## Summary

Add a `finally` part to `handled_sequence_of_statements`. The statements
will be executed unconditionally, whichever path the execution takes in the
`handled_sequence_of_statements`.

## Motivation

Ada is a language with exceptions, but there is no way to have uncondional
finalization of objects, apart from using either `goto_statements`, which are a
verbose workaround, and controlled objects, which impose performance penalties
and are not the most expressive way in some situations.

We propose to add a common construct in languages with exceptions, which is the
`finally` block. Every statement in the `finally` block of statements will be
executed, regardless of whether an exception has been caught by the `exception`
block or not.

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

## Prior art

Most languages with exceptions (Java, C#, C++, Python, ...) have a finally
block.
