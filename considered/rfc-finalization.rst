- Feature Name: Finalization with deferred statements
- Start Date: 2019-10-02
- RFC PR: 
- RFC Issue: 

Summary
=======

Provide means of final actions to be taken regardless of code path actually
executed.

Motivation
==========

Resource acquisition and proper release of acquired resources can be a hassle
in the presence of exceptions or in the case of "fail early" patterns.
Often, controlled types can be used to automate this, but this requires
explicit wrappers. This proposal tries to simplify and extend the concept of
locally scoped resource management.

Guide-level explanation
=======================

Deferred execution: A deferred execution is the execution of a sequence of
statements when leaving a local scope, which can either be a block or a
subprogram. It can be compared to the Finalize call of a controlled_type,
but allows more fine-grained control over what will be executed when.

Example:

Open a file and close it after use regardless of exceptions being raised
during processing.

.. code:: ada

  declare
    Input_File : Ada.Text_IO.File_Type;
  begin
    do
      Open (Input_File, "Some_File");
    and then terminate with
      Close (Input_File); -- execution of this statement is deferred until the end of the current scope
    end do;
    
    Do_Processing_Of_Input_File_With_Possible_Exceptions_Being_Raised;
  end;

is equivalent to

.. code:: ada

  declare
    Input_File : Ada.Text_IO.File_Type;
  begin
    Open (Input_File, "Some_File");
  
    begin
      Do_Processing_Of_Input_File_With_Possibile_Exceptions_Being_Raised;
    exception
      when others =>
        Close (Input_File);
        raise;
    end;
  end;

Example with evaluation of result:

.. code:: ada

  declare
    User_Defined_Resource : Some_Type;
    Result                : Some_Result_Type;
  begin
    do
      Result := Create (User_Defined_Resource);
    and then if Result = No_Error then terminate with
      Destroy (User_Defined_Resource);
    end do;
  
    case Result is
      when No_Error => Ada.Text_IO.Put_Line ("Everything is fine.");
      when others   => Ada.Text_IO.Put_Line ("Oops.")
    end case;
  
    -- some more processing
    if Failure_Detected then
      return;
    end if;
  
    -- ... etc. pp.
  end;

equivalent to:

.. code:: ada

  declare
    User_Defined_Resource : Some_Type;
    Result                : Some_Result_Type;
  begin
    Result := Create (User_Defined_Resource);
    pragma Unmodified (Result); -- To make sure we evaluate the same below.
  
    case Result is
      when No_Error => Ada.Text_IO.Put_Line ("Everything is fine.");
      when others   => Ada.Text_IO.Put_Line ("Oops.")
    end case;
  
    -- some more processing
    if Failure_Detected then
       Destroy (User_Defined_Resource);
       return;
    end if;
  
    if Result = No_Error then
      Destroy (User_Defined_Resource);
    end if;
  end;

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

- The feature does enhance on exception handling and localizes aspects of
  resource management that goes beyond the complexity of controlled types and
  reduces the need for artificial nested scopes.
- A language feature like a "finally" has been considered, but "finally" lacks
  flexibility and still needs proper scoping.
- It is syntax enhancement and has no impact on existing code, but probably
  requires relatively complex compiler support.
- The feature goes well with the general support of safe programming of the
  language.

Drawbacks
=========

- Code execution is not linear and overuse of this feature may lead to
  hard-to-understand code (OTOH, heavily nested blocks are not exactly
  readable, either).
- IDE support for folding blocks of code will be hampered.

Prior art
=========

- Delphi, C++, Java have "finally" (or similar) statements with all the drawbacks
  that may come with it, but these are mostly centered around exception handling.
  These are well understood and features that mostly work.
- The proposal was mostly inspired by the "defer" statement in Go and enhances
  on it.

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
