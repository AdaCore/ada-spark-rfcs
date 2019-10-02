- Feature Name: Finalization with Deferred Execution
- Start Date: 2019-10-02
- RFC PR: 
- RFC Issue: 

Summary
=======

Provide means of final actions to be taken regardless of code path actually
executed.

Motivation
==========

Resource acquisition and proper release of acquired resources can be a burden
in the presence of exceptions or in the case of "fail early" patterns.
Often, controlled types could be used to automate this, but this requires
explicit wrappers and not all execution profiles support this (e.g. restricted runtime like Ravenscar, or safety critical code). This proposal tries to simplify and extend the concept of locally scoped resource management in a safe and flexible way.

Guide-level explanation
=======================

Deferred execution: A deferred execution is the execution of a sequence of
statements when leaving a local scope, which can either be a block or a
subprogram. It can be compared to the Finalize call of a controlled_type,
but allows more fine-grained control over what will be executed when. It is also agnostic to the occurrence of exceptions raised within the scope.

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

Multiple deferred execution statements can occur within a single scope and are to be executed in reverse order (i.e. LIFO order) upon leaving the scope.

Reference-level explanation
===========================

Deferred execution can be viewed as a means to keep paired statement together while the second part of the pair (the deferred statement) needs to be executed at a later point. This pattern is mostly used when resources are acquired and need
to be released even in case of exceptions. A common pattern is to wrap such resources into a controlled type, but this is a relatively heavyweight solution, and requires additional code for the wrapper. Also, this solution can not be used in restricted runtime environments where controlled types or dynamic dispatching is not allowed.

The proposal solves the resource management problem in a way that can be
achieved at compile time with no additional, or hidden runtime overhead, and hence could be used in safety critical and hard real-time environments.

A possible implementation could be that the compiler creates artifical
scopes for each deferred execution statement and emits the code to be
executed whenever such a scope is left. A pure source code transformation
(as a kind of a preprocessing step) is also a conceivable solution.

To extent on the previous example:

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

Here we have some user defined resource (for example, a database connection) that needs to be finalized at the end of the scope. The resource is only acquired if the corresponding result is No_Error, so the deferred execution statement is guarded by the appropriate condition. Implementation note: The condition needs to be evaluated at the time of the initial resource acquisition, so the result may need to be stored in a temporary (hidden) variable by the compiler until the time to execute the deferred statement. Another possible approach would be to keep some kind of a stack of function pointers where only the needed finalization code is stored, but this defeats the idea that this feature has a static execution model.

Nested deferred execution shall be possible and execute the deferred code in reverse order.

Rationale and alternatives
==========================

- The feature does enhance on exception handling and localizes aspects of resource management that goes beyond the complexity of controlled types and reduces the need for artificial nested scopes.
- A language feature like a "finally" has been considered, but "finally" lacks flexibility and still needs proper scoping.
- It is syntax enhancement and has no impact on existing code, but probably requires relatively complex compiler support.
- The feature goes well with the general support of safe programming of the language.

Drawbacks
=========

- Code execution is not linear and overuse of this feature may lead to hard-to-understand code (OTOH, heavily nested blocks are not exactly readable, either).
- IDE support for folding blocks of code will be hampered.
- Nested deferred execution statements may need a considerable amount of exception handling to ensure the intended semantics (see below).

Prior art
=========

- Delphi, C++, Java have "finally" (or similar) statements with all the drawbacks
  that may come with it, but these are mostly centered around exception handling.
  These are well understood and features that mostly work.
- The proposal was mostly inspired by the "defer" statement in Go and enhances
  on it.

Unresolved questions
====================

- It is unclear what to do in case of multiple exceptions happening during the execution of deferred statements.
- One solution would be to abort the whole execution, another to simply define that exceptions occurring during deferred execution have to be considered erroneous execution which puts more restrictions on the statements - up until the point that deferred execution statements may define their own exception handlers.
- A more complex, but the semantically preferred solution would be to execute all statements anyway and then reraise the first exception that has been encountered.

Future possibilities
====================

Here, I tried to get away from defining a new keyword and used a mostly natural chain of already existing keywords. If we're not shy about adding new keywords a thing like

.. code:: ada

  do
    <sequence_of_statements>
  and [if <condition> then] defer
    <sequence_of_statements>
   [exception
     <exception_handler>] 
  end do;

could be a more "natural" syntax.
