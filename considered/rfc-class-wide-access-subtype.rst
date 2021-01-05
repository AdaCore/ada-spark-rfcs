- Feature Name: Class-Wide Access Subtype
- Start Date: 2021-01-05
- RFC PR:
- RFC Issue:

Summary
=======

We propose to add a new constraint kind to restrict values of class-wide
access types. Values of constrained subtype could point to a given derived
type or a hierarchy. As with other subtypes this allows us to have
a more precise and clean code, eliminates the need of many extra
type-conventions and extra subtype declarations. Example:

.. code-block:: ada
  type Shape is abstract tagged private;
  type Shape_Access is access all Shape'Class;
  type Cube is new Shape with private;
  My_Cube : Shape_Access for access Cube := new Cube;

Now My_Cube.all designates a Cube object, but My_Cube still has
Shape_Access type. So you can initialize/use the object without
an extra convention to the Cube and in the same time you can use
the pointer where class-wide Shape_Access expected.

Motivation
==========

Subtypes are an important part of the Ada language. It makes code
more expressive and precise allowing both the reader and the compiler
better understand the author intend.

But for now access types has only null-exclusion constraint.

Proposed new constraint allows a restriction based on referenced values:
a restricted subtype can point only to the given derived type or class-wide
type. Having this restricted value the author doesn't need to convert
dereferenced value to the derived type.

As an example let's consider a typical pattern in OOP style. We declare a
type hierarchy for geomerty shapes and a procedure to register shape objects.

.. code-block:: ada
  type Shape is abstract tagged null record;
  type Shape_Access is access all Shape'Class;
  procedure Register (Object : Shape_Access);
  type Rectangle is new Shape with record
     Width, Height : Natural;
  end record;

Next code registers a Rectangle and a circle without using a new constraints.
The first approach uses an extra access type:

.. code-block:: ada
  type Rectangle_Access is access all Rectangle;  --  an extra type
  declare
     My_Rectangle : Rectangle_Access := new Rectangle;
  begin
     My_Rectangle.Width := 10;
     My_Rectangle.Heigth := 5;
     Register (Shape_Access (My_Rectangle));  --  an extra type convention
  end;

The first approach uses an extra type convention:

.. code-block:: ada
  declare
     My_Rectangle : Shape_Access := new Rectangle;
  begin
     Rectangle (My_Rectangle).Width := 10;  --  an extra type convention
     Rectangle (My_Rectangle).Heigth := 5;  --  an extra type convention
     Register (My_Rectangle);
  end;

With new constraint the code is cleaner:

.. code-block:: ada
  declare
     My_Rectangle : Shape_Access for access Rectangle := new Rectangle;
  begin
     My_Rectangle.Width := 10;  --  Dereference denotes Rectangle
     My_Rectangle.Heigth := 5;
     Register (My_Rectangle);  --  no extra type convention
  end;

In many cases new construct replaces anonymous access types. This
eliminates several issues with anonymous access types:

- accessibility level of object is "not clear" in many cases, in
  particular when object allocated in the call of a subprogram
- when passed object need to be stored somewhere it can't be safely
  converted to named access type
- use of .all'Unchecked_Access/.all'Unrestricted_Access doesn't work
  for 'null' pointer

All of these issues could be detected only during execution, and sometimes
in corner cases only.

----
Why are we doing this? What use cases does it support? What is the expected
outcome?

Guide-level explanation
=======================

This RFC introduces a new kind of subtype constraint (class_wide_access_constraint).
It has a syntax form of **for access** *Name*, where *Name* is T or T'Class for some
tagged type T. The constraint is compatible only with an access-to-object type whose
designated subtype is a class-wide type.

With this constraint the author could define subtypes:

.. code-block:: ada
   subtype Rectangle_Access is Shape_Access for access Rectangle;

The Rectangle_Access still has Shape_Access type and can be used whereevere
Shape_Access is expected. In the same time (implicit or explicit) dereferenced value
denotes Rectangle type (if the acess value is not null).

This constraint could be used in other places where constraint is allowed.
For example,

- in an object declaration:

.. code-block:: ada
     My_Rectangle : constant Shape_Access for access Rectangle := new Rectangle;

- in a return object declartion:

.. code-block:: ada
  return Result : Shape_Access for access Rectangle := new Rectangle do
     Result.Witch := 10;
     Result.Height := 5;
  end return;

----
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

Add to *scalar_constraint* (in 3.2.2) a new rule

.. code-block::
  scalar_constraint ::= 
     range_constraint | digits_constraint | delta_constraint
     | class_wide_access_constraint
  
  class_wide_access_constraint ::=
    **for access** *type_*name

----
This is the technical portion of the RFC. Explain the design in sufficient
detail that:

- Its interaction with other features is clear.
- It is reasonably clear how the feature would be implemented.
- Corner cases are dissected by example.

The section should return to the examples given in the previous section, and
explain more fully how the detailed proposal makes those examples work.

Rationale and alternatives
==========================

The nearest feature is anonymous access types, but they have issues (see above). 

In our point of view this new constraint kind fits well with Ada philosophy
and best practices.

----
- Why is this design the best in the space of possible designs?
- What other designs have been considered and what is the rationale for not
  choosing them?
- What is the impact of not doing this?
- How does this feature meshes with the general philosophy of the languages ?

Drawbacks
=========

None :)

----
Why should we *not* do this?

Prior art
=========

This is too Ada specific to have a precedent in other languages, I guess.

----
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

None found yet.

----
- What parts of the design do you expect to resolve through the RFC process
  before this gets merged?

- What parts of the design do you expect to resolve through the implementation
  of this feature before stabilization?

- What related issues do you consider out of scope for this RFC that could be
  addressed in the future independently of the solution that comes out of this
  RFC?

Future possibilities
====================

No other ideas yet.

----
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
