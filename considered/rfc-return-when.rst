- Feature Name: Return When
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

Explain the proposal as if it was already included in the language and you were
teaching it to another Ada/SPARK programmer. That generally means:

- Introducing new named concepts.
- Explaining the feature largely in terms of examples.

- Explaining how Ada/SPARK programmers should *think* about the feature, and
  how it should impact the way they use it. It should explain the impact as
  concretely as possible.

- If applicable, provide sample error messages, deprecation warnings, or
  migration guidance.

For implementation-oriented RFCs (e.g. for RFCS that have no or little
user-facing impact), this section should focus on how compiler contributors
should think about the change, and give examples of its concrete impact.

For "bug-fixes" RFCs, this section should explain briefly the bug and why it
matters.

Reference-level explanation
===========================

This is the technical portion of the RFC. Explain the design in sufficient
detail that:

- Its interaction with other features is clear.
- It is reasonably clear how the feature would be implemented.
- Corner cases are dissected by example.

The section should return to the examples given in the previous section, and
explain more fully how the detailed proposal makes those examples work.

Rationale and alternatives
==========================

- Why is this design the best in the space of possible designs?
- What other designs have been considered and what is the rationale for not
  choosing them?
- What is the impact of not doing this?
- How does this feature meshes with the general philosophy of the languages ?

Drawbacks
=========

- Why should we *not* do this?


Prior art
=========

Discuss prior art, both the good and the bad, in relation to this proposal.

- For language, library, and compiler proposals: Does this feature exist in
  other programming languages and what experience have their community had?

- Papers: Are there any published papers or great posts that discuss this? If
  you have some relevant papers to refer to, this can serve as a more detailed
  theoretical background.

This section is intended to encourage you as an author to think about the
lessons from other languages, provide readers of your RFC with a fuller
picture.

If there is no prior art, that is fine - your ideas are interesting to us
whether they are brand new or if it is an adaptation from other languages.

Note that while precedent set by other languages is some motivation, it does
not on its own motivate an RFC.

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
