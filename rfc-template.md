- Feature ID: (fill me in with a unique ident, my_awesome_feature.
  That should be the same as the file name and will serve as a
  reference in tests and other documentation)
- Start Date: (fill me in with today's date, YYYY-MM-DD)
- RFC Issue: (leave this empty)
- RFC status: (Proposed | Planning | Design | Ready for prototyping | Implementation | Prouction | Rejected)

Summary
=======

One paragraph explanation of the feature.

Motivation
==========

Why are we doing this? What use cases does it support? What is the expected
outcome?

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

Why should we *not* do this?

Compatibility
=============

State clearly whether the change is backward compatible or not and suggest whether it should be part of the default feature set or available under a special switch.

Open questions
==============

List the topics that still need clarifications, if any.

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
