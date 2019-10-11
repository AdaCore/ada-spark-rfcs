- Feature Name: Conditional return
- Start Date: 2019-10-10
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

Similar to the `exit when` syntax available in loops a conditional `return when`
could be useful in procedures.

Motivation
==========

Linear algorithms or initialization sequences often require subsequent actions
and checks if an action was successful before continuing with the next one.
An often used pattern in this case is to nest the required checks:

.. code-block:: ada

   procedure Do_1 (Success : out Boolean);
   procedure Do_2 (Success : out Boolean);
   procedure Do_3 (Success : out Boolean);
   procedure Do_4 (Success : out Boolean);

   procedure Do_All (Success : out Boolean)
   is
   begin
      Do_1 (Success);
      if Success then
         Do_2 (Success);
         if Success then
            Do_3 (Success);
            if Success then
               Do_4 (Success);
            end if;
         end if;
      end if;
   end Do_All

While this might work for a few steps, in larger sequences it will create
exceedingly deep nesting levels that make code hardly readable, especially
when additional logic is required between those steps.

An alternative approach is to check against the failure of each procedure
and abort once an error happens. This prevents deep nesting levels while
allowing a (theoretical) arbitrary amount of steps:

.. code-block:: ada

   procedure Do_1 (Success : out Boolean);
   procedure Do_2 (Success : out Boolean);
   procedure Do_3 (Success : out Boolean);
   procedure Do_4 (Success : out Boolean);

   procedure Do_All (Success : out Boolean)
   is
   begin
      Do_1 (Success);
      if not Success then
         return;
      end if;
      Do_2 (Success);
      if not Success then
         return;
      end if;
      Do_3 (Success);
      if not Success then
         return;
      end if;
      Do_4 (Success);
   end Do_All;

In this case the code is much cleaner and better readable. But it is also longer
and the number of lines used to check for success is double the number of lines
doing actual work. The loop syntax in Ada provides a useful construct for this case,
the `exit when` conditional exit. For long sequences a single iteration loop can
be much shorter, and probably easier to read:

.. code-block:: ada

   procedure Do_1 (Success : out Boolean);
   procedure Do_2 (Success : out Boolean);
   procedure Do_3 (Success : out Boolean);
   procedure Do_4 (Success : out Boolean);

   procedure Do_All (Success : out Boolean)
   is
   begin
      for I in 1 .. 1 loop
         Do_1 (Success);
         exit when not Success;
         Do_2 (Success);
         exit when not Success;
         Do_3 (Success);
         exit when not Success;
         Do_4 (Success);
      end loop;
   end Do_All;

This last case requires the same number of lines as the first example, even though
it includes a seemingly useless loop, but is much easier to read. It is also cleaner
and shorter than the second example. A drawback is that the loop could lead to
misunderstandings or can lead to errors (if it iterates more than one time due to
an errorneous condition).

To solve these issues this RFC suggests to adapt the `exit when` syntax to procedure
return statements. In this case the loop could be omitted and a conditional return
can be expressed without much overhead while still being clearly understandable.

Guide-level explanation
=======================

To do a conditional return in a procedure the following syntax should be used:

.. code-block:: ada

   return when Condition;

This will return from the procedure if `Condition` is true.

Reference-level explanation
===========================

The conditional return is an extension to the conventional return in
procedures. It does not conflict with other features. The conventional
return is still available and equivalent to

.. code-block:: ada

   return when True;

An implementation of the same functionality could be

.. code-block:: ada

   if Condition then
      return;
   end if;

Rationale and alternatives
==========================

This feature aims to increase the readability of an often used concept while
reducing boiler plate code. It is similar to other features (`exit when`)
and does not introduce new keywords. It is kept short, clear and unambiguously
to make its meaning as clear as possible to the reader.

Drawbacks
=========

The scope where the conditional return is useful is relatively narrow. If the
condition that shall result in a return requires further operations it cannot be used.

Prior art
=========

The inspiration for this RFC comes from the loop exit syntax already
implemented in Ada.

Unresolved questions
====================

- What parts of the design do you expect to resolve through the RFC process
  before this gets merged?

- What parts of the design do you expect to resolve through the implementation
  of this feature before stabilization?

- What related issues do you consider out of scope for this RFC that could be
  addressed in the future independently of the solution that comes out of this
  RFC?

Future possibilities
====================

Think about what the natural extension and evolution of your proposal would
be and how it would affect the language and project as a whole in a holistic
way. Try to use this section as a tool to more fully consider all possible
interactions with the project and language in your proposal.
Also consider how the this all fits into the roadmap for the project
and of the relevant sub-team.

This is also a good place to "dump ideas", if they are out of scope for the
RFC you are writing but otherwise related.

If you have tried and cannot think of any future possibilities,
you may simply state that you cannot think of anything.

Note that having something written down in the future-possibilities section
is not a reason to accept the current or a future RFC; such notes should be
in the section on motivation or rationale in this or subsequent RFCs.
The section merely provides additional information.
