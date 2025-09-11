- Feature Name: initialization_for_out_parameters
- Start Date: 2019-11-22
- Status: Proposed

Summary
=======

Default initialization is allowed only for ``in`` parameters. This adds the
possibility of allowing them for ``out`` parameters in the body of subprograms.

Motivation
==========

When writing the body of a subprogram which has one or more ``out``
parameters, the author has to ensure that all these parameters are initialized
in all the paths that the function could take, otherwise the program
might access unitialized memory.

This is fragile to maintain: it's easy to miss an initialization in
the body of complex subpgrograms, and the errors introduced might be
hard to detect, as unitialized memory might have "by chance" a correct
value.

Guide-level explanation
=======================

Any ``out`` parameter in the specification for a subprogram body
may be assigned a default expression, just line ``in`` parameters.

.. code-block:: ada

   procedure Save (The_Data : in  Integer := 0;
                   Success  : out Boolean);
   --  Save The_Data to disk.
   --  Success is set to True iff the operation succeeded.

   procedure Save (The_Data : in  Integer := 0;
                   Success  : out Boolean := False)
   --  Default initialization for Success ^^^^^^^^
   is
      ...

When present, this default expression will always be evaluated as part of the
call, and the result will be initially assigned to the variable at the
start of the subprogram execution, before evaluating its declarative part.

Reference-level explanation
===========================

6.1.19 should be changed to say ::

   In subprogram declarations, a default_expression is only allowed
    in a parameter_specification for a formal parameter of mode in.
   In subprogram bodies, a default_expression is only allowed
    in a parameter_specification for a formal parameter of mode in or out.

Just like default expression for ``in`` parameters, default expressions
for ``out`` parameters should be evaluated at the point of the call, ie
before the evaluation of the declarative part.

Rationale and alternatives
==========================

The first alternative considered was to allow initialisation of ``out``
variables in the specification as well as in the body. This would have
introduced pitfalls (or the necessity to introduce complexity) when
renaming or overriding subprograms. Furthermore, it makes little sense
to publicise the default value of ``out`` parameters: this is a decision
that should concern only the implementation of the subprogram.

Other alternatives considered:

  - remove the ``out`` mode altogether: this seemed too much of an earthquake,
    not backwards-compatible, so I don't think this is a viable option.

  - use of tools (compiler or more advanced static analyzers) to guarantee
    the absence of uninitialized variables: I was surprised in some easy cases
    that the GNAT compiler was not able to detect paths where the variables
    were never initialized; I interpreted it as this being a more difficult
    problem than it seems.

  - enforce (via a compiler flag?) the initialization of all ``out`` parameters
    at the beginning of the sequence of statements in the subprogram: I found
    this inelegant and unnatural.

Drawbacks
=========

This proposal means that there can be differences in the formal_part
of the specification and body of a given subprogram, if the implementor
chose to use a default initialization for one or more ``out`` parameters.

Prior art
=========

I don't know.

Unresolved questions
====================

None so far.

Future possibilities
====================

One advantage of allowing this is is that it allows writing a coding
standard rule that *requires* default initialization to ``out`` parameters,
which is an easy way to allow the use of ``out`` parameters, while completely
eliminating the dangers of uninitialized memory associated to these. It's also
easy to write a tool or a compiler warning that enforces this rule.