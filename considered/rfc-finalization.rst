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

Resource acquisition and proper release of acquired resources can be a burden in
the presence of exceptions or in the case of "fail early" patterns.
Often, controlled types can be used to automate this, but this requires explicit
wrappers and not all execution profiles support this (e.g. restricted runtimes
like Ravenscar, or safety critical coding standards).
This proposal tries to simplify and extend the concept of locally scoped
resource management in a safe and flexible way.

Guide-level explanation
=======================

Deferred execution: A deferred execution is the execution of a previously
declared sequence of statements when leaving a local scope, which can either be
a block or a subprogram.  It is comparable to the Finalize call of a controlled
type, but allows more fine-grained control over what will be executed, and when.
It is also agnostic to the occurrence of exceptions raised within the scope.

Proposed syntax (see below for possible alternatives):

.. code:: ada

  do
    <sequence_of_statements>
  and [if <condition>] then at exit
    <sequence_of_statements>
  end exit;

(Author's note: One reason, I chose for "and [...] then" is to hint at the
intended semantic that, if an exception is raised, the deferred sequence of
statements will not be considered.  Similarly, "at exit" was chosen, because it
was the combination of keywords closest to the meaning of "at the end" that I
could come up with.  An earlier version used "terminate with" instead, but after
some consideration, choosing "exit" instead of the rather morbid "terminate"
conveys more of the intended meaning (i.e. "do stuff when you exit this block of
code"). To C-programmers, "at exit" may even sound familiar and has a quite
similar meaning.  After all, "atexit()" is a function to register some final
actions to be taken when the process finishes. Now, I also chose for "end exit"
as block terminator instead of "end do" - which was rather stupid, anyway - so
instead of "deferred execution" we could call this thing an "extended exit
statement".
I also considered "and [if <condition>] then when exit ...", but to me it
doesn't sound right, the combination of "then when" looks awful.)

Example:

Open a file and close it after use regardless of exceptions being raised during
processing.

.. code:: ada

  declare
    Input_File : Ada.Text_IO.File_Type;
  begin
    do
      Open (Input_File, "Some_File");
    and then at exit
      Close (Input_File); -- execution of this statement is deferred until the
                          -- end of the enclosing scope
    end exit;
    
    Do_Processing_Of_Input_File_With_Possible_Exceptions_Being_Raised;
  end;

(The call to Open() will raise an exception if it fails. The assumption in such
a case is that no resource has been acquired, so the deferred sequence of
statements, i.e. the call to Close (Input_File) do not need to be executed.)

The above code is equivalent to

.. code:: ada

  declare
    Input_File : Ada.Text_IO.File_Type;
  begin
    Open (Input_File, "Some_File");
  
    begin
      Do_Processing_Of_Input_File_With_Possible_Exceptions_Being_Raised;
      Close (Input_File);
    exception
      when others =>
        Close (Input_File);
        raise;
    end;
  end;

(Author's note: One of the early reviewers pointed out that the first call to
"Close (Input_File)" was missing in an earlier draft. Which, in a sense, proves
the point that if multiple calls to 'cleanup' code are required due to exception
handling etc. at least one of them will be forgotten.)

Example with evaluation of result:

.. code:: ada

  declare
    User_Defined_Resource : Some_Type;
    Result                : Some_Result_Type;
  begin
    do
      Result := Create (User_Defined_Resource);
    and if Result = No_Error then at exit
      Destroy (User_Defined_Resource);
    end exit;
  
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
      if Result = No_Error then
        Destroy (User_Defined_Resource);
      end if;

      return;
    end if;
  
    if Result = No_Error then
      Destroy (User_Defined_Resource);
    end if;
  exception
    when others =>
      if Result = No_Error then
        Destroy (User_Defined_Resource);
      end if;

      raise;
  end;

Multiple deferred execution statements can occur within a single scope and are
to be executed in reverse order of declaration (i.e. LIFO order) upon leaving
the scope.

Reference-level explanation
===========================

Deferred execution can be viewed as a means to keep paired statements together
while the second part of the pair (the deferred statement) needs to be executed
at a later point.  This pattern is mostly used when resources are acquired and
need to be released even in case of exceptions.  A common way is to wrap such
resources into a controlled type, but this is a relatively heavyweight solution,
requires additional code to be written for the wrapper, and such a solution can
not be used in restricted runtime environments where controlled types or dynamic
dispatching are not allowed.

The proposal solves the resource management problem in a way that can - in
theory, at least - be achieved at compile time with no additional, or hidden
runtime overhead, and hence could be used in safety critical and hard real-time
environments.

A possible implementation could be that the compiler creates artifical scopes
for each deferred execution statement and emits the code to be executed whenever
such a scope is left.  A pure source code transformation (as a kind of a
preprocessing step) may also be a conceivable solution.

To extent on the previous example:

.. code:: ada

  declare
    User_Defined_Resource : Some_Type;
    Result                : Some_Result_Type;
  begin
    do
      Result := Create (User_Defined_Resource);
    and if Result = No_Error then at exit
      Destroy (User_Defined_Resource);
    end exit;
  
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

Here we have some user defined resource (for example, a database connection)
that, once it has been successfully acquired, needs to be released at the end of
the scope. In this example, we assume that the resource is only acquired if the
corresponding result is No_Error, so the deferred execution statement is guarded
by the appropriate condition.

Implementation note: The condition needs to be evaluated at the time of the
initial resource acquisition, so the result may need to be stored in a temporary
(hidden) variable until the time to execute the deferred statement. Another
possible approach would be to keep some kind of a stack of function pointers
where only the needed finalization code is stored, but this defeats the idea
that this feature has a static execution model.

Nested deferred execution shall be possible and execute the deferred statements
in reverse order of declaration.

Dynamic semantics:
------------------

- If an (unhandled) exception is raised during the execution of a deferred
  sequence of statement, all remaining deferred statements are being abandoned
  and the exception will be propagated as per the usual Ada rules (just like it
  would be if an exception occured within an exception handler).  We should
  allow exception handlers within a deferred block, so the user can locally
  handle them, if they desire to do so:

    .. code:: ada

      do
        <sequence_of_statements>
      and [if <condition>] then at exit
        <sequence_of_statements>
      [exception
        <exception_handler>]
      end exit;

  As stated earlier, deferred execution is agnostic to exceptions being raised
  in the enclosing scope.  That means a deferred execution block has no
  knowledge about an exception potentially being raised before it gets executed.
  (Hence, not handling an exception occuring during execution of the deferred
  block or reraising it will "hide" the original exception.  This is intentional
  and in line with the semantics of nested exception handling in Ada.)

- Expressions (like parameters to subprogram calls or similar) within the
  deferred block are evaluated at the deferred point, not when the deferred
  block is defined.  This ensures clearly defined semantics.
  However, the initial condition is evaluated at the point of the definition of
  the deferred block.

- Deferred statements are allowed to change variables defined within the
  enclosing scope (including in [out] parameters of the enclosing subprogram).
  That means, in the presence of a return statement, all effects must be
  evaluated before an (extended) return statement is being executed. Consider
  this (rather artifical and genuinely stupid) example:

  .. code:: ada

    function Locked_Increment (What      : in Integer;
                               By_Amount : in Positive) return Integer is
      Result : Integer;
    begin
      do
        Global_Lock.Acquire;
      and then at exit
        Global_Lock.Release;
        Result := Result + 1; -- Increment result variable (for fun and profit)
      end exit;

      Result := What + Amount;
      return Result;
    end Increment;

  Outside of SPARK (I would expect SPARK's flow analysis to flag the deferred
  write access to Result as illegal), the function will return
  "What + Amount + 1", because after assigning "What + Amount" to "Result",
  "Result" is incremented in the deferred block, but the return statement must
  take all changes into account.

Rationale and alternatives
==========================

- The feature does enhance on exception handling and localizes aspects of
  resource management that goes beyond the complexity of controlled types and
  reduces the need for artificial nested scopes.
- A language feature like "finally" has been considered, but "finally" lacks
  flexibility and still needs explicit scopes.  Consider the following example:
  
  .. code:: ada
  
    declare
      Resource_1 : Some_Type;
    begin
      Acquire (Resource_1);

      -- .. do some stuff with Resource_1

      declare
        Resource_2 : Some_Type;
      begin
        Acquire (Resource_2);
        -- .. do more stuff
      finally
        Release (Resource_2);
      end;
    finally
      Release (Resource_1);
    end;

  First of all, resource acquisition and subsequent release are (visually) far
  apart.
  Secondly, explicit nesting is required to make sure that the resources are
  only released when they actually have been acquired before. The code could be
  simplified like that:

  .. code:: ada
  
    declare
      Resource_1 : Some_Type;
      Resource_2 : Some_Type;
    begin
      do
        Acquire (Resource_1);
      and then at exit
        Release (Resource_1);
      end exit;

      -- .. do some stuff with Resource_1

      do
        Acquire (Resource_2)
      and then at exit
        Release (Resource_2);
      end exit;

      -- .. do more stuff
    end;

- It is a syntax enhancement and has no impact on existing code, but probably
  requires relatively complex compiler support.
- The feature goes well with the general support of safe programming of the
  language.

Drawbacks
=========

- Code execution is not linear and overuse of this feature may lead to
  hard-to-understand code (OTOH, heavily nested blocks are not exactly readable,
  either).
  One might play devil's advocate and go so far and say that Ada already has
  non-linear features (select statements with arbitrary order of execution, or
  asynchronous transfer of control), and some kind of deferred execution (abort
  deferred sections) as well.

- As hinted below, it would become technically possible to write "backwards"
  code, i.e. by declaring a set of deferred statements around null statements
  and then let the compiler execute them in reverse order:

  .. code:: ada

    begin
      do null; and then at exit
        Ada.Text_IO.Put_Line ("This will be executed last.");
      end exit;

      do null; and then at exit
        Ada.Text_IO.Put_Line ("This will be executed first.");
      end exit;
    end;

- Nested deferred execution statements may need a considerable amount of
  exception handling to ensure the intended semantics.

Prior art
=========

- The proposal was mostly inspired by the "defer" statement in Go, but extends
  the concept in a more flexible way.  See here for an introduction of the defer
  statement in Go: https://blog.golang.org/defer-panic-and-recover
- Delphi, C++, Java have "finally" (or similar) statements with all the
  drawbacks that may come with it, but these are mostly centered around
  exception handling, not resource acquisition and release.
- Python has a "with" statement that provides roughly the functionality of a
  controlled type.

Unresolved questions
====================

- The requirement that a return statement (including an extended return
  statement) must take all effects of deferred execution into account may be
  considered counter-intuitive and not 100% in the spirit of Ada.

  One solution could be introducing a new aspect (e.g. Deferred_Modification or
  such) that must be applied to variables being modified in the block of
  deferred statements.  This way, the reader of such a program would at least be
  hinted at the fact that something fishy may be going on.  If such an aspect is
  not provided, write accesses to local variables from within deferred blocks
  shall be forbidden.  Hence, the code mentioned above (see section "Dynamic
  semantics" in "Guide-level explanation") would only be allowed if we declare:

  .. code:: ada

    Result : Integer with
      Deferred_Modification => True; -- Not everything may be as it seems.

Future possibilities
====================

As stated, I tried to get away from defining a new keyword and used a mostly
natural chain of already existing keywords. If we're not shy about adding new
keywords a thing like

.. code:: ada

  do
    <sequence_of_statements>
  and [if <condition>] then defer
    <sequence_of_statements>
   [exception
     <exception_handler>] 
  end defer;

could be a more "natural" syntax that blends in relatively nicely into the
already existing syntax for select statements or asynchronous transfer of
control (i.e. "select ... then abort ...").

I am not certain if the whole "do ... and" syntax is necessary. The initial idea
was that when this block is executed, it will drive the decision if the deferred
statements are being executed later:
  - Either evaluate some result that can be used as a guard condition if the
    deferred statements are to be executed later, or
  - just raise an exception indicating that the deferred statements will not be
    executed later.  If no exception occurs the guard condition defaults to True
    and does not need to be specified.

A more simple syntax could be:

.. code:: ada

  Build (Something) and if Something /= null then defer
    Tear_Down_Again (Something);
  end defer;

Personally I don't like this, because it binds the whole deferred execution to a
single statement, which might be syntactically more pleasant to write, but it
may not be semantically true, so I would indeed prefer an explicit syntactic
block.

Similarly, I completely discarded the idea of having a "defer" block with no
syntactic connection to anything, mostly because I think it is way more readable
if the source emphasizes the connection between the statement(s) which acquire
the resource and the statement(s) which will release it again later. I mean, if
you'd look at a solution like this:

.. code:: ada

  -- some code
  defer
     Cleanup;
  end defer;

There is no visible connection to any previous statement(s) that would indicate
why the execution of "Cleanup" even needs to be deferred.  I could imagine a
beast like this to become a maintenance nightmare (not to mention that it
enables one to easily write horribly bad code, see the "backwards" code example
in the Drawbacks section), so I think, a syntactic connection between the
statements should be enforced by the language.

Note that writing

.. code:: ada

  do null; and then at exit
    Ada.Text_IO.Put_Line ("Why, oh why didn't I take the blue pill?");
  end exit;

would still be a possible way to write deferred statements with no connection to
any previous code. Here, the programmer at least makes their intention explicit,
and like other questionable use of certain language features, constructs like
these could easily be flagged by a coding standards checking tool.

Also, compiler or external static analysis tools may have it easier to find
potential flaws if both parts of the code are syntactically connected (e.g. I
could imagine checks that the same set of variables are referenced in both
blocks).
