- Feature Name: case_statement_with_renamed_type_values
- Start Date: 2019-11-25
- RFC PR:
- RFC Issue:

Summary
=======

With this feature we could give more readable case statements in several
situations where we are using renamed type values of the given discrete
type.

Motivation
==========

For example in state machines we could look at the states from different
perspectives and in this way we could mention all names of the values
which are usable as a type value of a discrete type.
In these cases it could be a better solution than what we get by adding
comments after the "discrete_choice_list"...
e.g. "pressed_button" and "timer_started" could represent the same state.
(one is a rename of the other like "a" and "x" in the example)


Guide-level explanation
=======================

the key concepts are commented in the code below

-- compile command:
--    gnatmake case_statement.adb

procedure case_statement is
   type dt is (a);
   function x return dt renames a;

   d : dt := a;
begin
  -- the following is OK
  case d is
     when  a  => null;
  end case;

  -- the following is OK
  case d is
     when  x  => null;
  end case;

  -- for the following we will get:  
  -- Error: duplication of choice value: "a" at line ...
  case d is
     when a | x  => null;    -- here a is duplicated, but if we are writing a .. x  which is a .. a it will work (this solution is not usable with multiple renames...)
  end case;

-- because:
-- in this way we could get the same error
-- declare
   --   i : integer;
-- begin
--   case i is
--      when 2 | 2 => null;
--      when others => null;
--   end case;
-- end;

-- From AA.pdf
-- "A case_statement selects for execution one of a number of alternative sequences_of_statements..."
-- "... The goal of these coverage rules is that any possible value of the selecting_ expression of a case_statement should be covered by exactly one discrete_choice of the case_statement , and that this should be checked at compile time. ..."

-- I think it would be better and logical to allow multiple occurrences of a type value in the same "when case" e.g. "2 | 2" should be valid but "when 2 => ... when 2 => " should not.
-- in this case "The execution of a case_statement chooses one and only one alternative." remains true.
-- In my opinion by using the "|" instead of ".." would be more readable in this case and it also scales better and we could use three or more alternative names (renames) also...
end case_statement;


Reference-level explanation
===========================

At my level of understanding this extension of the case statement should not interfere with other language features.
((My feeling about this is something similar what I feel about the in out parameters of the functions.))


Rationale and alternatives
==========================

I think it is a more maintainable solution in many cases than just writing comments in the code. (I am thinking about find all references and other features instead of grep...)


Drawbacks
=========

I think none, but, 
In language subsets where the renaming is prohibited this feature is not useful.

Prior art
=========

none

Unresolved questions
====================

none

Future possibilities
====================

not yet
