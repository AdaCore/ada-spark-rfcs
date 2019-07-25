- Feature Name: Exclusive if-then-else
- Start Date: 2019-0-25
- RFC PR:
- RFC Issue:

Summary
=======

We propose to amend `Ada Issue 0214-2
<http://www.ada-auth.org/cgi-bin/cvsweb.cgi/ai12s/ai12-0214-2.txt?rev=1.6>`_ to
use the syntax of if-then-else instead of a syntax based on ``case`` and/or
``select``.

This AI originates in the ``Contract_Cases`` aspect in SPARK, which is a
sometimes useful but in fact rarely used feature in practice. What is more,
it's unlikely that this new feature is going to replace all uses of
``Contract_Cases``, because ``Contract_Cases`` has the nice additional benefit
that guards are evaluated on subprogram entry, so in the general case you'd
have to sprinkle ``'Old`` all over your guards, which is unwise (it makes the
contract less readable and more likely to be incorrect if you miss a ``'Old``
somewhere). See the text of the AI for such a less-than-ideal example of
translation, repeated here:

.. code-block:: ada

  function T_Increment (X : T) return T with
    Global    => null,
    Pre       => X /= Max,
    Post      =>
      (case is
         when X.Seconds'Old < Seconds_T'Last =>
            T_Increment'Result.Seconds = X.Seconds + 1
              and then T_Increment'Result.Minutes = X.Minutes
              and then T_Increment'Result.Hours = X.Hours,
         when X.Seconds'Old = Seconds_T'Last
              and then X.Minutes'Old < Minutes_T'Last =>
            T_Increment'Result.Seconds = 0
              and then T_Increment'Result.Minutes = X.Minutes + 1
              and then T_Increment'Result.Hours = X.Hours,
         when X.Seconds'Old = Seconds_T'Last
              and then X.Minutes'Old = Minutes_T'Last =>
            T_Increment'Result.Seconds = 0
              and then T_Increment'Result.Minutes = 0
              and then T_Increment'Result.Hours = X.Hours + 1);

So the utility of this new feature completely rests on replacing existing
if-statements/expressions. It's more likely to happen with a syntax proposed
here by Richard Wai on the thread of the AI::

     If_statement ::=
	If condition then
		Sequence_of_statmenets
	{elsif condition then
		Sequence_of_statements} |
	{orif condition then
		Sequence_of_statements}
	[else
		Sequence_of_statements]
        end if;

Quoting his proposal::

   How about we just modify if statements (and expressions) by adding a new
   reserved word that is a sibling to elsif - "orif". "orif" would be mutually
   exclusive to "elsif" in a given if statement/expression.

   For if statements/expressions with orif, the following rules apply: All
   conditions for all "orif" as well as the initial "if" are always
   evaluated. If more than one (including the opening if) evaluates True,
   program_error is raised. If none evaluate True, else is executed (if it
   exists).

   Honestly I think this could end up being much more broadly useful than a
   "case expression without selecting_expressions".

   I know that there is a general discomfort with adding new reserved words,
   but I think "orif" is palatable since it is pretty unlikely to be used in an
   existing program (I'd think).

Contrary to the AI, we also propose to split the checks between:

- a completeness check when no ``else`` branch is provided, which is always
  executed, so when no guard applies ``Program_Error`` is raised; and

- a disjointness check, to verify that no more than one guard is enabled, which
  is enabled with assertions.

This makes it a light check on top of the usual ``elsif`` form, so that no
runtime penalty is paid when compiling with assertions turned off. This is
consistent with the use of the ``if`` syntax which indicates an order of
evaluation of guards, contrary to the ``case`` syntax which does not convey
this ordering.

Motivation
==========

The feature of "exclusive if" is one that is missing in all mainstream
programming languages, and that a programmer is likely to need from time to
time. The syntax proposed here feels natural for the user, and shows the strong
connection of the usual if-statement or if-expression to this new
construct. This makes it more likely that users start using that feature,
progressively replacing previous if-statements/expressions with this version
that simply spells out the distinction of cases.

The benefit of using the "exclusive if" version is particularly evident for
if-statements/expressions that span multiple pages of code, which makes it
difficult in the non-exclusive case to understand when a given branch is taken,
as it depends on all previous conditions evaluating to False.

For those if-statements/expressions that could be converted, there would be no
drawback to applying the conversion, as the "exclusive if" would entail no
runtime cost unless assertions are enabled.

Here is a typical example. The current code:

.. code-block:: ada

   if Kind(Obj) = Kind1 then
      ...
   elsif Kind(Obj) = Kind2
     and then Some_Other_Condition
   then
      ...
   elsif Kind(Obj) = Kind3
     and then Yet_Some_Other_Condition
   then
      ...
   else
      raise Program_Error;
   end if;

could be rewritten into:

.. code-block:: ada

   if Kind(Obj) = Kind1 then
      ...
   orif Kind(Obj) = Kind2
     and then Some_Other_Condition
   then
      ...
   orif Kind(Obj) = Kind3
     and then Yet_Some_Other_Condition
   then
      ...
   end if;

Note that there is no need to explicitly raise ``Program_Error`` when no guard
is enabled.

Guide-level explanation
=======================

An alternative syntax for if-statements/expressions is defined with the new
keyword ``orif`` being used where ``elsif`` is used in a regular
if-statement/expression. These two forms are mutually exclusive in an
if-statement/expression.

When this alternative syntax is used and assertions are enabled, all the
branching conditions are evaluated at the start of the if-statement/expression,
and a run-time check is performed that no more than 1 guard is enabled.

When no ``else`` branch is provided, an implicit ine is generated by the
compiler which raises ``Program_Error`` (independent of assertions being
enabled or not).

Then, the evaluation of the if-statement/expression proceeds as usual (the
compiler is free to optimize this case when assertions are enabled, as all
guards have already been evaluated), leading to evaluation of the branch
corresponding to the enabled guard, or the ``else`` branch if no guard is
enabled.

Reference-level explanation
===========================

TBD if this gets enough traction.

Rationale and alternatives
==========================

Many other syntax alternatives have been proposed on the AI:

- ``alternative when <guard> =>``
- ``case True is when <guard> =>``
- ``case is when <guard> =>``
- ``case <Type> is when <guard> =>``
- ``case select when <guard> =>``
- ``case when <guard> =>``

The problem with these proposals is that they build on the ``case`` while this
feature is essentially an ``if``. It is confusing, as this is **not** a case of
pattern-matching, even a degenerate/simple one like we find in Ada.

It was pointed out that ``elsif`` and ``orif`` could be seen as too close to
each other. But ``or`` and ``xor`` are even closer, and this does not seem to
cause problems to programmers or reviewers.

Drawbacks
=========

This may not be so useful, if programmers don't use it to replace some
if-statements/expressions which rely on exclusive conditions.

Only a part of ``Contract_Cases`` in SPARK can be replaced by this feature, and
there are already few uses of ``Contract_Cases``.

Prior art
=========

The closer precedent is ``Contract_Cases`` in SPARK. Similarly, this feature
would lead itself naturally to proving the disjointness and completeness of
cases in SPARK.

No other mainstream programming language proposes this feature, as its main
benefit appears when applying formal verification to statically check
disjointness and completeness. Note that other benefits would apply even if the
user does not prove her programs:

- increased readability of if-statements/expressions, especially when the
  conditions or the statements/expressions themselves are long; and

- additional specification power to indicate the programmer's intent, in order
  to catch violations at runtime.

Unresolved questions
====================

The main questions to solve are:

- whether this feature deserves consideration; and

- what should be its syntax if so.

Future possibilities
====================

A syntax based on ``case`` is ill-advised if Ada is ever to support richer
pattern-matching, which should be using a ``case`` syntax. The feature
discussed under this RFC is **not** pattern-matching.
