- Feature Name: initialization_for_out_parameters
- Start Date: 2019-11-22
- RFC PR:
- RFC Issue:

Summary
=======

Default initialization is allowed only for ``in`` parameters. This adds the
possibility of allowing them for ``out`` parameters,

Motivation
==========

When writing the body of a subprogram which has one or more ``out``
parameters, one has to ensure that all these parameters are initialized
in all the paths that the function could take, otherwise the program
might access unitialized memory.

This is fragile to maintain: it's easy to miss an initialization in
the body of complex subpgrograms, and the errors introduced might be
hard to detect, as unitialized memory might have "by chance" a correct
value.

Guide-level explanation
=======================

Any ``out`` parameter in a subprogram declaration can be assigned
a default expression, just line ``in`` parameters.

.. code-block:: ada

   procedure Save (The_Data : in  Integer := 0;
                   Success  : out Boolean := False);

When present, this default expression will always be evaluated as part of the
call, and the result will be initially assigned to the variable at the
start of the subprogram execution, before evaluating its declarative part.

This does not make it possible to omit the out parameter at the point of the
call.

.. code-block:: ada

   declare
      Data        : Integer;
      Did_Succeed : Boolean;
   begin

      Save (The_Data => Data, Success => Did_Succeed);
      --  the above is valid

      Save (Success => Did_Succeed);
      --  the above is valid

      Save (The_Data => Data);
      --  the above is invalid: an error message should be produced, saying
      --     missing argument for parameter "Success"

   end;

Reference-level explanation
===========================

6.1.19 should be changed to say ::

    A default_expression is allowed in a parameter_specification
    for a formal parameter of mode in or out.

Just like default expression for ``in`` parameters, default expressions
for ``out`` parameters should be evaluated at the point of the call, ie
before the evaluation of the declarative part.

Rationale and alternatives
==========================

Some alternative considered:

  - remove the ``out`` mode altogether: this seemed too much of an earthquake,
    not backwards-compatible, so I don't think this is a viable option.

  - use of tools (compiler or more advanced static analyzers) to guarantee
    the absence of uninitialized variables: I was surprised in some easy cases
    that the GNAT compiler was not able to detect paths where the variables
    were never initialized; I interpreted it as this being a more difficult
    problem than it seems.

  - enforce (via a compiler flag?) the initialization of all ``out`` parameters
    at the beginning of the sequence of statements in the subprogram: I found
    this inelegant and unnatural

Drawbacks
=========

See unresolved questions.

Prior art
=========

I don't know.

Unresolved questions
====================

Should we think about the impact that this has on requiring initialization
for unconstrained types? (Although the use of these types

Future possibilities
====================

One advantage of allowing this is is that it allows writing a coding
standard rule that *requires* default initialization to ``out`` parameters,
which is an easy way to allow the use of ``out`` parameters, while completely
eliminating the dangers of uninitialized memory associated to these. It's also
easy to write a tool or a compiler warning that enforces this rule.
