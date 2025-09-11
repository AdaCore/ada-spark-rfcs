- Feature Name: continue
- Start Date: 2021-07-15
- Status: Production

Summary
=======

This RFC aims to introduce the `continue` keyword into Ada. It is used to
stop the execution of a loop iteration and continue with the next one.
It behaves similar to `exit` however instead of leaving the loop execution
will start again at the loop start.

Motivation
==========

This is a helpful construct for control flow in loops. It allows to prematurely
finish a loop iteration when a certain condition is met. It also reduces the
code complexity of loop bodies since the only way to implement different
conditional sections in a loop would either be multiple if statements or multiple
procedures.

Lets say we have two procedures `Procedure_A` and `Procedure_B` that are only
executed when `Condition_A` and `Condition_B` are true respectively. Usually
this would be done with a nested if statement:

```Ada
while Condition loop
   if Condition_A then
      Procedure_A;
      if Condition_B then
         Procedure_B;
      end if;
   end if;
end loop;
```

This could be implemented shorter and with less nesting when `continue` is used:

```Ada
while Condition loop
   continue when not Condition_A;
   Procedure_A;
   continue when not Condition_B;
   Procedure_B;
end loop;
```
It reduces the length of the code without sacrificing its readability.

Guide-level explanation
=======================

All loop types allow the use of `continue`. When it is called the loop
execution will always start at the top and the loop condition will be
evaluated:

```Ada
loop
   Do_Something;
   if Condition then
      Do_Something_Conditional;
      continue;
   end if;
   Do_Something_Else;
end if;

while Loop_Condition loop
   Do_Something;
   if Condition then
      Do_Something_Conditional;
      continue;
   end if;
   Do_Something_Else;
end if;

for I in Var'Range loop
   Do_Something;
   if Condition then
      Do_Something_Conditional;
      continue;
   end if;
   Do_Something_Else;
end if;
```

If there is no other operation inside the if statement other than the
`continue` it can be shortened with `when` which behaves the same as
it does in `exit when`:

```Ada
loop
   Do_Something;
   continue when Condition;
   Do_Something_Else;
end loop;
```

In case of nested loops it always applies to the loop it is called in
unless it is given a label:

```Ada
Outer:
loop
   Do_Something;
   Inner:
   loop
       Do_Something;
       continue when Condition;
   end loop Inner;
   Do_Something_Else;
end loop Outer;

Outer:
loop
   Do_Something;
   Inner:
   loop
       Do_Something;
       continue Outer when Condition;
   end loop Inner;
   Do_Something_Else;
end loop Outer;
```

In the first example execution will jump the loop head of the inner loop
while in the second it will jump the loop head of the outer one.

Reference-level explanation
===========================

`continue` is the complement to `exit` and does not conflict with any other
language features. As such it behaves similar to `exit` and has the same syntax.

```
continue_statement ::= continue [loop_name] [when condition]
```

When `continue` is called it will jump to the start of the loop and honour the
loop condition in the case of for and while loops.

Rationale and alternatives
==========================

Loops can be structured in different ways, the most direct one being if statements.
However this can lead to complex nested structures. In subprograms and if a loop
should stop iterating this nesting can be reduced with `return` and `exit`
however there is no comparable mechanism if a loop should not exit.

An alternative to a `continue` statement can be the use of `goto` which could
jump to a label inside the loop. However this cause the risk of accidentally
creating infinite loops. The jump label has to be at the end of the loop to make
sure that the loop condition is evaluated. This is especially dangerous if `loop`
is converted to `while loop` in case there is a label at the beginning of the
loop. Then this label would have to be moved to the end. `continue` prevents
these dangers by providing a defined way to deal with this problem and by
automatically respecting loop conditions.

```Ada
loop
   Do_Something;
   goto continue when Condition;
   Do_Something_Else;
   <<continue>>
end loop;

loop
   <<continue>>
   Do_Something;
   goto continue when Condition;
   Do_Something_Else;
end loop;
```

In this example both loops are semantically identical. However if they're
converted to a while loop the second example must be changed or the loop condition
will be ignored in case of a continue.
Furthermore the use of gotos is often prohibited in coding standards.

Another alternative is the use of nested loops where an exit from the inner loop
has the same semantic as a continue and an exit from the outer loop is the actual exit:

```Ada
Outer:
while Condition loop
   loop
      Do_Something;
      exit when Condition; --  continue
      exit Outer when Other_Condition; --  exit
      Do_Something_Else;
   end loop;
end loop Outer;
```

Since nested loops are also used in regular code this approach will increase the
complexity of the code and make it far less readable. It is merely a workaround
for a missing continue instead of a solution.

Another important aspect is the wide spread use of `continue` in other languages.
Its usage and semantics are well known by many programmers that would not only
miss that feature in Ada but would have to learn and discover workarounds that
come with drawbacks as described above.

Drawbacks
=========

It introduces a new feature and a new keyword to Ada.

Prior art
=========

The `continue` statement is available in a large number of popular
imperative languages. It is avilable in old languages such as C or C++
and more modern ones like Rust and Swift. It also exists across multiple
domains with both native and interpreted languages e.g. Python, Java,
JavaScript, Bash.
