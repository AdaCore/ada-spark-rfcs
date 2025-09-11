- Feature Name: Conditional "when" constructs
- Start Date: 2019-10-10
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)
- Status: Production

Summary
=======

In line with the `exit when` construct available in loops a conditional -
`return ... when`, `raise ... when`, and `goto ... when` constructs could
supply a similar convience.

Motivation
==========

Linear algorithms or initialization sequences often require subsequent actions
and checks if an action was successful before continuing with the next one.
An often used pattern in this case is to nest the required checks. Here return is
used as an example:

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

The loop syntax in Ada provides a useful construct for the above case, the
`exit when` conditional exit. For long sequences a single iteration loop can
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

This last case requires a similar number of lines as the first example, even though
it includes a seemingly useless loop, but is much easier to read. A drawback is that
the loop could lead to misunderstandings or can lead to errors (if it iterates more
than one time due to an errorneous condition).

An alternative approach is to check against the failure of each procedure
and abort once an error happens. This prevents deep nesting levels while
allowing a (theoretical) arbitrary amount of steps. Here the other `when`
constructs are used as well:

.. code-block:: ada

   procedure Do_1 (Success : out Boolean);
   procedure Do_2 (Success : out Boolean);
   procedure Do_3 (Success : out Boolean);
   procedure Do_4 (Success : out Boolean);

   function Do_All (Success : out Boolean) return Integer is
      Result : Integer := ...;
   begin
      Do_1 (Success);
      if not Success and ... then
         raise Program_Error;
      end if;
      if not Success and ... then
         goto <<Label>>
      end if;
      if not Success and ... then
         return Result;
      end if;

      Do_2 (Success);
      if not Success and ... then
         raise Program_Error;
      end if;
      if not Success and ... then
         goto <<Label>>
      end if;
      if not Success and ... then
         return Result;
      end if;

      Do_3 (Success);
      if not Success and ... then
         raise Program_Error;
      end if;
      if not Success and ... then
         goto <<Label>>
      end if;
      if not Success and ... then
         return Result;
      end if;

      Do_4 (Success);

   <<Label>>

      return Result;
   end;

In this case the code is much cleaner and better readable. But it is also longer
and the number of lines used to check for success is double the number of lines
doing actual work. 
   
Guide-level explanation
=======================

To do a conditional return in a procedure the following syntax should be used:

.. code-block:: ada

   procedure P (Condition : Boolean) is
   begin
      return when Condition;
   end;

This will return from the procedure if `Condition` is true.

When being used in a function the conditional part comes after the return value:

.. code-block:: ada

   function Is_Null (I : Integer) return Boolean is
   begin
      return True when I = 0;
      return False;
   end;

In a similar way to the `exit when` a `goto ... when` can be employed:

.. code-block:: ada

   procedure Low_Level_Optimized is
      Flags : Bitmapping;
   begin
      Do_1 (Flags);
      goto Cleanup when Flags (1);

      Do_2 (Flags);
      goto Cleanup when Flags (32);

      --  ...

   <<Cleanup>>
      --  ...
   end;

.. code-block

To use a conditional raise construct:

.. code-block:: ada

   procedure Foo is
   begin
      raise Error when Imported_C_Func /= 0;
   end;

An exception message can also be added:

.. code-block:: ada

   procedure Foo is
   begin
      raise Error with "Unix Error"
        when Imported_C_Func /= 0;
   end;

Reference-level explanation
===========================

The proposed conditional constructs are an extension of their base constructs.
They do not conflict with other features and they allow a simple straight-foreward
expansion.

To use `return ... when` as an example - is still available and equivalent to:

.. code-block:: ada

   return when True;

An implementation of the same functionality could be

.. code-block:: ada

   if Condition then
      return;
   end if;

The implementation for functions is quite similar so that

.. code-block:: ada

   return Value when Condition;

could be implemented as

.. code-block:: ada

   if Condition then
      return Value;
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
condition that shall result in a return requires further operations it cannot be used,
also large aggregates may serve to hide the `when` section in the return case and lead
to confusion.

Prior art
=========

The inspiration for this RFC comes from the loop exit syntax already
implemented in Ada.

Unresolved questions
====================

The main question arising is if the narrow use case is worth a slight
extension of the language specification.
