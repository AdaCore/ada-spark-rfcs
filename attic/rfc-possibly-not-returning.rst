- Feature Name: possibly_not_returning
- Start Date: 2019-10-07
- Status: Production

Summary
=======

This is a SPARK-related RFC.

In SPARK, calling a procedure marked ``No_Return`` is `interpreted as an error
<http://docs.adacore.com/spark2014-docs/html/ug/en/source/language_restrictions.html#raising-exceptions-and-other-error-signaling-mechanisms>`_,
and the SPARK tools will issue a `check` message if such a call is reachable::

  call to nonreturning subprogram might be executed

Of course, a user can readily `justify such a message
<http://docs.adacore.com/spark2014-docs/html/ug/en/source/how_to_use_gnatprove_in_a_team.html#direct-justification-with-pragma-annotate>`_
via pragma ``Annotate``, but this should be used with care, as an underlying
assumption of proof technology is that all subprograms terminate normally on
inputs allowed in their precondition. In particular, GNATprove (the SPARK proof
tool) will generate an `axiom` for every function that states that, given
inputs that satisfy its precondition, the function produces outputs that
satisfy its postcondition. If this mathematical axiom is unsound (because no
satisfying output can be found for a given value of inputs), then the proof
itself may become unsound, as a prover may be able to deduce an inconsistency
from the unsound axiom.

GNATprove has some mechanisms to protect against such use of unsound axioms
(called `axiom guards`) but they are not protecting against all uses. The main
protection is the use of GNATprove to ensure that all functions are indeed
terminating and proved correct (no runtime errors, contract proved). This is
not the case if the user justifies a message as mentioned above.

Thus, in a case where a user justifies a message for a call to a procedure
marked ``No_Return``, the user also needs to check that the call stack for
reaching that point is only made of procedures, not functions. As this is
difficult to do manually, and even more difficult to maintain as code evolves,
we propose to add the support for this verification in GNATprove, using an
annotation on SPARK procedures that may not return:

.. code-block:: ada

   procedure Proc with
     Annotate => (GNATprove, Possibly_Not_Returning);

Such a procedure would be allowed to call a procedure marked ``No_Return``, and
GNATprove would handle correctly the possibility of nonreturning in flow
analysis and in proof.

Motivation
==========

A user of SPARK has expressed a critical need to be able to call procedures
marked ``No_Return`` in their code, not as a way to signal errors (which is the
current interpretation in GNATprove of such calls) but as a legitimate context
switch to another execution thread outside of the SPARK code.

As explained above, this may lead to unsoundness if not properly handled, and
the current manual checking is not satisfying. Firstly, checking that a call
can only occur in a call-stack made only of procedures is (1) non-trivial in
presence of dispatching calls and subprogram callbacks (which we expect to
support in SPARK in the future) and (2) impossible to do for a library where
part of the call-back is not available. Secondly, maintaining these guarantees
during code maintenance is brittle.

We'd rather provide a way to explicitly acknowledge that a procedure may not
return as part its normal operations, and adapt the toolchain to support that
use case.

Guide-level explanation
=======================

We could be proposing either a new aspect (for inclusion in SPARK Reference
Manual) or a new annotation (for inclusion in SPARK User's Guide). Given the
limited scope of the proposed feature, we propose to use an annotation, but the
explanation is the same. It is essentially a language feature with support from
the tools.

The new annotation should be described in `SPARK User's Guide appendix
<http://docs.adacore.com/spark2014-docs/html/ug/en/appendix/additional_annotate_pragmas.html>`_.

A possibly nonreturning procedure is defined as a procedure annotated with
``Possibly_Not_Returning`` as follows:

.. code-block:: ada

   procedure Proc with
     Annotate => (GNATprove, Possibly_Not_Returning);

In the body of such a procedure, it is not considered an error to call a
nonreturning procedure (marked with aspect/pragma ``No_Return``) or a possibly
nonreturning procedure (marked with annotation
``Possibly_Not_Returning``). Instead, a call to a nonreturning procedure is
considered as stopping the flow of execution, while a call to a possibly
nonreturning procedure is considered to continue execution in the caller past
the call only for the cases that do return.

Any other call to a (possibly) nonreturning procedure inside a subprogram will
lead to a check that the call is provably unreachable. Beware of justifying
such calls with pragma ``Annotate`` as this might lead to unsoundness.

Reference-level explanation
===========================

The support for this feature in GNATprove consists of two parts:

- in flow analysis, a call to (possibly) nonreturning procedure inside a
  possibly nonreturning caller should take into account all effects occurring
  in the path leading to the call, contrary to what is done currently for calls
  to nonreturning procedures. Technically, this requires to modify the graph
  of statements inside the caller.

- in proof, the contract of a possibly nonreturning procedure inside a
  possibly nonreturning caller should only apply to those inputs that
  return. Technicaly, this requires to model in Why3 the nonreturning cases
  with a Boolean variable ``no_return`` in Why3 set to ``true`` when a call
  does not return. The postcondition of the callee becomes ``if not no_return
  then <original postcondition>``.

Calls to (possibly) nonreturning procedures outside of a possibly
nonreturning caller are handled like calls to nonreturning procedures are
currently handled. In the unlikely case of a possibly nonreturning procedure
being called from a nonreturning subprogram, we also prefer to issue a check
that the call is unreachable, as this non-sensical case would require too much
special treatment otherwise.

A dispatching subprogram and the subprogram it overrides shall be either
both possibly nonreturning, or not.

Rationale and alternatives
==========================

Language support, be it under an annotation, is necessary for a correct
automatic support for this new use case.

The main alternative considered is to have a separate checking outside of
GNATprove, but this is brittle.

Handling of this specification by GNATprove will also make sure that future
evolutions of the tools correctly handle this use case.

This feature seems like a natural extension of SPARK to go beyond the overly
restrictive current interpretation of calls to nonreturning procedures.

Drawbacks
=========

This feature adds complexity to the tool, but this is deemed as reasonable for
the expected benefit.

Prior art
=========

ACSL has `terminates clauses <https://frama-c.com/download/acsl.pdf>`_ for
exactly this purpose. It is unclear how this clause is supported by the
supporting tool Frama-C in its Jessie and WP plugins. Those clauses are more
expressive than the current proposal, by allowing to state a Boolean expression
defining the condition for terminating. It is also not seen as necessary here.

Unresolved questions
====================

Is the proposed annotation and handling adequate for all use cases where people
may want to call a possibly nonreturning procedure?

Future possibilities
====================

None yet. Extension to functions that may not return would require far more
modifications in GNATprove for sound handling.
