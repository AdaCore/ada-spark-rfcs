- Feature Name: spark_exceptional_contracts
- Start Date: 2022-01-03
- RFC PR:
- RFC Issue:

Summary
=======

Regular postconditions are only verified on normal exit of a subprogram. We
want to allow users to write `exceptional contracts`, which should describe in
which cases an exception will be raised, and optionally supply a
postcondition that shall be verified in this case. 

Motivation
==========

The support for exceptions in SPARK is minimal, as
they are only allowed inside logically dead code (typically, as defensive coding
inside branches disallowed by the precondition). A more extended support would
be beneficial, as it is not uncommon for the normal behavior of a subprogram to
include raising an exception. As SPARK analysis is modular on a per suprogram
basis, a better support requires being able to describe the exceptional cases
in subprogram contracts.

Guide-level explanation
=======================

Exceptional contracts in SPARK reuse the pragma ``Contract_Cases``, introduced
to specify the behavior of a subprogram as a conjunction of disjunct cases.
In regular usage, a pragma ``Contract_Cases`` provides a sequence of individual
contracts, each made of a precondition, evaluated before the call, and a
postcondition. For each call, exactly one of these preconditions should
evaluate to True. It is the asscociated postcondition which is verified at the
end of the call. An OTHERS case can be used at the end of the sequence:

```ada
procedure P (...) with
  Contract_Cases =>
    (Pre_1  => Post_1,
     Pre_2  => Post_2,
     ...
     others => Post_others);
```

If a subprogram is allowed to raise an exception in the domain of its
precondition, it is possible to add `exceptional cases` to a pragma
``Contract_Cases`` to describe in which cases an exception is expected.
Exceptional cases typically have a postcondition made of a single raise
expression, providing the expected exception. For example, in the following
snippet, ``Pre_3`` and ``Pre_4`` are exceptional cases:

```ada
procedure P (...) with
  Contract_Cases =>
    (Pre_1  => Post_1,
     Pre_2  => Post_2,
     Pre_3  => raise Exp_1,
     Pre_4  => raise Exp_2,
     ...
     others => Post_others);
```

When the precondition associated to such a case evaluates to True, a check is
made that the subprogram exits by raising the correct exception. In addition,
if a pragma ``Contract_Cases`` contains at least an exceptional case, a check is
made that the subprogram exits normally in non-exceptional cases. For example,
if ``Pre_3`` evaluates to True at the beginning of ``P`` above, a check is made
that ``P`` exits while raising ``Exp_1``. If ``Pre_1`` evaluates to True, then a
check is made that the subprogram exits normally and that ``Post_1`` holds at
the end of the call.

It is possible when necessary, to add a postcondition to an exceptional case. It
should be added to the raise expression using an AND THEN boolean operator. If
such a postcondition is supplied, it should hold on the exceptional exit of the
subprogram. To minimize surprises if parameters are passed by copy, such a
postcondition shall not reference OUT or IN OUT parameters of the subprogram
unless they are of a by-reference type.

```ada
procedure P (...) with
  Contract_Cases =>
    (Pre_1  => Post_1,
     Pre_2  => Post_2,
     Pre_3  => raise Exp_1,
     Pre_4  => raise Exp_2 and then Post_4,
     ...
     others => Post_others);
```

The checks corresponding to the contract cases of ``P`` above are
equivalent to the following assertions:

```ada
procedure P (...) is
   --  Evaluation of the guards in the pre-state
   C_1 : constant Boolean := Pre_1;
   C_2 : constant Boolean := Pre_2;
   C_3 : constant Boolean := Pre_3;
   C_4 : constant Boolean := Pre_4;

begin
   --  Check that the contract cases are disjoint. If there is no OTHERS
   --  choice, it is also necessary to check that at least one is True.
   pragma Assert
     (if C_1 then not (C_2 or C_3 or C_4)
      elsif C_2 then not (C_3 or C_4)
      elsif C_3 then not C_4);

   --  normal body of of P
   declare
   ...
   end;

   --  Check the postcondition of the appropriate contract case on normal
   --  exit. Exceptional cases should never occur.
   if C_1 then
      pragma Assert (Post_1);
   elsif C_2 then
      pragma Assert (Post_2);
   elsif C_3 then
      pragma Assert (False);
   elsif C_4 then
      pragma Assert (False);
   else
      pragma Assert (Post_Others);
   end if;

exception
   when E : others =>

      --  Check that the expected exception is raised and the postcondition
      --  of the appropriate contract case on exceptional exit. Normal cases
      --  should never occur.

      if C_1 then
         pragma Assert (False);
      elsif C_2 then
         pragma Assert (False);
      elsif C_3 then
         pragma Assert (Exception_Identity (E) = Exp_1'Identity);
      elsif C_4 then
         pragma Assert (Exception_Identity (E) = Exp_2'Identity);
         pragma Assert (Post_4);
      else
         pragma Assert (False);
      end if;
      raise;
end P;
```

To make it easier to see at first glance whether a case in a pragma
``Contract_Cases`` is exceptional or not, occurrences of a raise expression in
a contract case which are not in one of the two forms above are not allowed.

Reference-level explanation
===========================

TBD

Rationale and alternatives
==========================

We could consider adding a new pragma ``Exceptional_Cases`` supplying
exceptional postconditions for all the exceptions that can be raised in the
subprogram:

```ada
procedure Q (...) with
  Exceptional_Cases =>
    (Exp_1 => True,
     Exp_2 => Post_4,
     ...);

As opposed to the proposal above, it does not allow/require supplying a
precondition, stating in which cases the exception is raised. This
alternative is more expressive than what we propose, as it allows stating
that a subprogram raises an exception without stating in which cases it does.
However, the contract case approach seems easier to write and more readable in
the common case where we want to precisely define when the exceptions are
raised.

For example, if we wanted to write a contract equivalent to the contract of
``P`` using an ``Exceptional_Cases`` contract, we would have to write
something like:

```ada
procedure P (...) with
  --  Contract case for normal exit 
  Contract_Cases =>
    (Pre_1  => Post_1,
     Pre_2  => Post_2,
     ...
     others => Post_others),
  --  Additional post to state that P does not exit normally on exceptional
  --  cases.
  Post => not Pre_3'Old and then not Pre_4'Old,
  --  Contract on exceptional passes with additional checks that the exceptions
  --  are only raised when expected
  Exceptional_Cases =>
    (Exp_1 => Pre_3'Old,
     Exp_2 => Pre_4'Old and then Post_4,
     ...);

Note that in the above, the cases from the contract case and the exceptional
case are not disjoint anymore. The contract cases should cover the whole
precondition, but the associated postconditions will only be checked on mormal
exits.

Drawbacks
=========

It is not possible to speak about the message of an exception in exceptional
cases. We also cannot state that a subprogram might raise an exception without
stating which one and exactly in which case the exception will be raised. Both
issues are solved by the alternative proposal above.

Prior art
=========

In Why3, it is possible to supply exceptional postconditions similarly to what
is described in the alternative section above.

Unresolved questions
====================

Future possibilities
====================