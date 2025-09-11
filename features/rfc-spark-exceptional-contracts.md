- Feature Name: spark_exceptional_contracts
- Start Date: 2022-01-03
- Status: Production

Summary
=======

Regular postconditions are only verified on normal exit of a subprogram. We
want to allow users to write *exceptional contracts*, which should describe in
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

It is possible to annotate a subprogram with an aspect ``Exceptional_Cases``.
It supplies postconditions which should hold for all the exceptions that can be
raised in the subprogram. Basically, it is a sequence of exception choices like
those that can be used in a regular exception block:

```ada
procedure P (...) with
  Exceptional_Cases =>
    (Exp_1 => True,
     E : Exp_2 => Post_4);
```

When the body of subprogram annotated with this aspect returns by raising
an exception, a check is made that the postcondition of the first case in
the ``Exceptional_Cases`` that matches the exception holds. If this
postcondition fails or if there is no such case in the ``Exceptional_Cases``,
``Assert_Failure`` is raised.
This is equivalent to the following expansion, using an exception handler:

```ada
procedure P (...) is
begin
   --  normal body of of P
   declare
   ...
   end;

exception
   when Exp1 =>
      pragma Assert (True);
      raise;
   when E : Exp2 =>
      pragma Assert (Post_4);
      raise;
   when others =>
      pragma Assert (False);
      raise;
end P;
```

Potential exceptions raised inside the specification (Pre/postconditions,
Contract_Cases...) of the subprogram are not handled by this mechanism.

It is possible to use an ``Exceptional_Cases`` aspect to ensure that no
exception is raised by the body of a subprogram:

```ada
procedure Do_Not_Raise_Exception (...) with
  Exceptional_Cases =>
    (others => False);
```

Note that it is the default for formal analysis using SPARK. It needs only
be stated if a dynamic verification is expected.

Reference-level explanation
===========================

The pragma ``Exceptional_Contracts`` expects as an argument an
*exceptional_contract_list* defined below.

```
 exceptional_contract_list ::= ( exceptional_contract   {,  exceptional_contract  })
 exceptional_contract      ::= [choice_parameter_specification:] exception_choice {'|' exception_choice} => consequence
```

where

```
 consequence ::= Boolean_expression
```

The boolean expression in the consequences should be resolved as regular
postconditions. In particular, the ``'Old`` attribute is allowed to appear
in them. However, parameters of modes OUT or IN OUT of the subprogram
shall not occur in the consequences of an exceptional contract
unless they either are of a by-reference type or occur
in the prefix of a reference to the ``'Old`` attribute. All prefixes of
references to the ``'Old`` attribute in exceptional cases are expected to
be evaluated in the at the beginning of the call regardless of whether or
not the particular exception is raised. This allows to introduce constants for
these prefixes at the beginning of the subprogram together with the ones
introduced for the regular postcondition.

A call to a subprogram:

```ada
procedure P (...) with
  Pre  => Normal_Pre,
  Post => Normal_Post,
  Exceptional_Cases =>
    (Exp_1 => Exp_Post,
     ...);
```

should be equivalent to:

```ada
--  Check the precondition
pragma Assert (Normal_Pre);

--  Block with the exception handler
declare
   --  Insert internal constants for references of 'Old in the postcondition
   ...
   --  Insert internal constants for references of 'Old in the exceptional cases
   ...

begin
   --  Evaluation of the body of P
   declare
      ...
   end;

--  Handler for the exceptional cases
exception
   when Exp_1 =>
      pragma Assert (Exp_Post);
      raise;
   ...
end;

--  Check the postcondition
pragma Assert (Normal_Post);
```

Rationale and alternatives
==========================

We could consider reusing the aspect ``Contract_Cases``, introduced
to specify the behavior of a subprogram as a conjunction of disjunct cases.
In regular usage, an aspect ``Contract_Cases`` provides a sequence of individual
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
precondition, we could allow adding *exceptional cases* to an aspect
``Contract_Cases`` to describe in which cases an exception is expected.
Exceptional cases would typically have a postcondition made of a single raise
expression, providing the expected exception. For example, in the following
snippet, ``Pre_3`` and ``Pre_4`` are exceptional cases:

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

The checks corresponding to the contract cases of ``P`` above would be
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
     (Boolean'Pos (C_1) + Boolean'Pos (C_2) + Boolean'Pos (C_3) +
      Boolean'Pos (C_4) <= 1);

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
As opposed to the main proposal, this alternative requires users to supply a
precondition, stating in which cases the exception is raised. This
alternative is less expressive than what we propose, as it does not allow stating
that a subprogram raises an exception without stating in which cases it does.
We believe that such a capability is important to represent subprograms which
might depend on some external information. As an example, consider ``Open``
from ``Text_IO`` which might raise exceptions depending on the file system.

Note that in the above, the cases from the contract case and the exceptional
case are checked to be disjoint which is not the case in the main proposal.

Drawbacks
=========

We might worry that the main proposal would be harder to read in the
arguably most common case where we can precisely describe where the exception
is raised. Here are some examples in the 2 syntaxes:

```ada
   function Find (A : Int_Array; E : Integer) return Integer with
     Post => Find'Result in A'Range and then A (Find'Result) = E,
     Exceptional_Cases =>
       (Not_Found => (for all F of A => F /= E));

   function Parse_Integer (Str : String) return Integer with
     Post => Is_Valid_Integer (Str)
     and then Parse_Integer'Result = To_Integer_Ghost (Str),
     Exceptional_Cases =>
       (Parse_Error => not Is_Valid_Integer (Str));

   function Find (A : Int_Array; E : Integer) return Integer with
     Contract_Cases =>
       ((for all F of A => F /= E) => raise Not_Found,
        others                     =>
          Find'Result in A'Range and then A (Find'Result) = E);

   function Parse_Integer (Str : String) return Integer with
     Contract_Cases =>
       (Is_Valid_Integer (Str) => Parse_Integer'Result = To_Integer_Ghost (Str),
        others                 => raise Parse_Error);
```

Both versions specify precisely when the exception will be raised. We
believe that the one using ``Exceptional_Cases`` stays readable.

Prior art
=========

In Why3, it is possible to supply exceptional postconditions similarly to what
is described in the main proposal.

Unresolved questions
====================

Future possibilities
====================
