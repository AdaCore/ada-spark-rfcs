- Feature ID: spark-constant-in-iterator
- Start Date: 2026-01-09
- Status: Design

Summary
=======

The Iterable aspect is a GNAT specific aspect that provides user defined iteration over containers. Currently, it requires `First`, `Next`, and `Has_Element` functions to iterate over the cursors of the container at minimum. An `Element` function can be added to obtain iteration over the content of the container (`for Item of C loop`, instead of `for Position in Container` loop). In a use-case when the elements of the container are 
fetched only for reading the data, this method is unnecessarily slow as it
involves copying the element. 
The performance issue can be solved by adding an optional `Constant_Reference` function returning an anonymous access-to-constant view of the element instead of copy.

Motivation
==========

The use of Constant_Reference would avoid copying the element, in particular in quantified expressions where using a while loop is not an alternative (at least not for SPARK).

Guide-level explanation
=======================


As an example, we currently have:

```ada
   type List (Capacity : Count_Type) is private
   with
     Iterable  =>
       (First       => First,
        Next        => Next,
        Has_Element => Has_Element,
        Element     => Element),

   function Element (Container : List; Position : Cursor) return Element_Type;
```

The current proposal adds an alternative prototype:

```ada
   type List (Capacity : Count_Type) is private
   with
     Iterable =>
       (First       => First,
        Next        => Next,
        Has_Element => Has_Element,
        Constant_Reference => Constant_Reference),

   function Constant_Reference (Container : List; Position : Cursor) return not null access constant Element_Type;
```

When Constant_Reference is specified for an Iterable then the following loop

```ada
for E of Container loop
  P (E);
end loop;
```

will be expanded to code corresponding to

```ada
declare
   Position : Cursor := First (Container);
begin
   while Has_Element (Container, Position) loop
      declare
         Ref : constant access constant Element_Type := Constant_Reference (Container, Position);
         E : Element_Type renames Ref.all;
      begin
         P (E);
      end;
      Position := Next (Container, Position);
   end loop;
end;
```

Reference-level explanation
===========================

The main scenario is already explained in the Guide-level explanation section. 
Specifying both Element and Constant_Reference shall not be possible.

Rationale and alternatives
==========================

An alternative to this proposal would be [5.5.3 Procedural Iterators](https://ada-rapporteur-group.github.io/ARM/Ada_202Y/AA-5-5-3.html). That would solve the
problem of potentially dangling reference. Reference would be passed as IN parameter and it's lifetime is strictly limited. However, it would create a different kind of performance issue as the compiler optimisation would be 
disabled in some cases. The LD group the decided to drop this alternative
because, despite of being safer, wouldn't solve the original problem outlined
of the summary of this RFC.

Another possible enhancement would be allowing private functions in the
prototype of Iterable. That is considered a much wider change and shall be
considered separately.

Drawbacks
=========

A small caveat is that, since E is a renaming and not an object, it would not be possible to use it at certain places, for example inside Global and Depends contracts. That is considered to be a minor shortcoming.

As a follow-up, we could consider having a way to supply a Reference function that would allow direct mutation inside the container. It is notably more complicated to do that in a SPARK-compatible way though, because of aliasing restrictions, so it may be better to keep it as a separate RFC.

Compatibility
=============

The change does not change the behaviour of legacy code.

Open questions
==============

None.

Prior art
=========


Unresolved questions
====================

TBD

Future possibilities
====================

Allowing private functions in the prototype of Iterable would remove the issue
of uncontrolled dangling pointers. E.g.

```ada
type Bytes is private
   with Iterable => (First       => First,
                     Next        => Next,
                     Has_Element => Has_Element,
                     Element     => Unsafe_Get);
```

For effcient implementation, the `Element` implementation shall not check the
bounds (given that this check is already done by the `Has_Element` function).
Making the function `Unsafe_Get` private would ensure that it is not used
outside of the iteration context.
