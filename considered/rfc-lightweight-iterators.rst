- Feature Name: lightweight-iterators
- Start Date: 2020-01-08
- RFC PR:
- RFC Issue:

Summary
=======

We propose new iterator aspects to allow lightweight iterators over a container
with wellknown interface and abstract API support. Do implement it we sacrifice
direct access to contained elements, but propose some workarounds.

Motivation
==========

1. We are looking for a much simpler solution. The inspiration for this proposal is
   GNAT Iterable_ aspect, but we allow multiple iterators per container.

2. We would like a user iterators for non-tagged container types also.

3. Currently compiler creates and destroyes a cursor object on each iteration, because
   `Next` is a function. If cursor is something more complex then elementary type
   it could be costly. Consider a container that keeps records about all its cursors,
   to avoid memory leeks and keep their states consistent. Then cursor should be
   a controlled type. We would like to avoid an overhead of useless create/destrory.

4. With current iterators it's very hard to write abstract API (expressed in terms of
   interfaces) that supports iterators. But if you write it, an implementation
   will be inefficient (See 3). An example:

.. code-block:: ada

   type Element is limited interface;
   type Element_Vector is limited interface;
   --  To express iterable interface over vector you need a cursor
   --  but you can't provide concrete cursor because you haven't known
   --  implementation of the vector yet. So Cursor becames an interface.
   
   type Cursor is interface;
   function Has_More (X : Cursor) return Boolean is abstract;
   
   function Has_Element (X : Cursor'Class) return Boolean is (X.Has_More);
   package Vector_Iterator_Interfaces is new
      Ada.Iterator_Interfaces (Cursor'Class, Has_Element);
   
   function Iterate (X : Vector)
     return Vector_Iterator_Interfaces.Reversible_Iterator'Class is abstract;

With this approach both iterator and cursor should be class-wide types.
On each iterator compiler will create a new Cursor'Class object, then
assign it and destroy previous cursor. Such operations can't be
inlined and optimized. They are useless hard overheads.

5. If container uses some kind of encoding or compression for contained
   elements, then it's impossible to access them using user-defined
   reference type, because such references are expressed in form of direct
   access to the element.

6. `The common aproach <https://en.wikipedia.org/wiki/Iterator_pattern>`_
   is to keep iteration state in the iterator itself. But in
   Ada 2012 iterator doesn't keep iteration state.

.. code-block:: ada

   function Next
     (Object   : Forward_Iterator;
      Position : Cursor) return Cursor is abstract;

The iterator object is merely
used to bind First/Next/etc methods in runtime. It could mislead new users.
It also prevents compiler from futher code optimization. Instead
we propose this profile for Next:

.. code-block:: ada

   procedure Next (Self : in out Iterator);

To overcome all these issues we propose to staticaly bind iterator types
through a new aspect clauses.

Guide-level explanation
=======================

A container type can have one or more iterators. Iterators are enumerated in
the container type declaration. For instance:

.. code-block:: ada

   limited with Magic_Strings.Word_Iterators;
   limited with Magic_Strings.Line_Iterators;
   
   package Magic_Strings is
   
      type Magic_String is private
        with Iterators =>
          (Each_Character,             --  both iterator name and its type
           Word_Iterators.Each_Word,   --  Each_Word is iterator name
           Line_Iterators.Each_Line);  --  Each_Line is also iterator name

New aspect `Iterators` contains list of names (direct_name or selected_component).
Such name should resolve to a type (a type of iterator object).
Direct name it-self (and selector_name of selected_component) is also used
as iteator name in iteration or loops. Consider:

.. code-block:: ada

   function Funct (Text : Magic_String) return Natural is
      Count : Natural := 0;
   begin
      for J in Text.Each_Character loop
        Count := Count + 1;
      end loop;

Iterator type should have a set of related operations. It also
points to the container type:

.. code-block:: ada

   type Each_Character is limited private
     with Iterate => Magic_String;
   
   --  Compiler interface:
   function First (Self : Magic_String) return Each_Character;
   function Has_Element (Self : Each_Character) return Boolean;
   procedure Next (Self : in out Each_Character);

Compiler uses these operation to implement a loop. It expands
a loop to something like thise:

.. code-block:: ada

   function Funct (Text : Magic_String) return Natural is
      Count : Natural := 0;
      J     : Each_Character := First (Text);
   begin
      while Has_Element (J) loop
         Count := Count + 1;
         Next (J);
      end loop;

To provide access to the current element of iteration and possible
other related information the author of the iterator type can also
defines extra functions. Example:

.. code-block:: ada

   --  User interface:
   function Element (Self : Each_Character) return Wide_Wide_Character;
   --  Current character of iteration
   
   function UTF_8_Offset (Self : Each_Character) return Natural;
   --  Offset in UTF-8 storage elements
   
   function UTF_16_Offset (Self : Each_Character) return Natural;
   --  Offset in UTF-16 storage elements

Usage example:

.. code-block:: ada

   function Get_X_Offset (Text : Magic_String) return Natural is
   begin
      for J in Text.Each_Character loop
         if Element (J) = 'X' then
            return UTF_8_Offset (J);
         end if;
      end loop;
      return 0;
   end Get_X_Offset;

With some new aspects we can provide a shortcut to avoid writting
`Element (J)` and just write `J`. We also have ideas how to allow
assigment to `J` for elementary and private types. Also one of iterator
could be marked as "default iterator", so we can skip `.Each` part in
iteration scheme. To be discussed.

Now let's consider profiles of compiler interface subprograms.

The `function First` can have some extra parameters. In this case
user should provide corresponding actual values after interface name:

.. code-block:: ada

   function First
     (Self : Magic_String;
      Staring_From : Positive) return Each_Character;
   ...
      for J in Text.Each_Character (Staring_From => 5) loop

This means the function can be overloaded.

To support SPARK, the iterator can express compiler interface subprograms
in another form. In this form `Next` and `Has_Element` subprograms
have an extra parameter for container. This way the iterator doesn't
keep a reference to the container and no aliasing issue is possible.
For example:

.. code-block:: ada

   function Has_Element
     (Self      : Each_Character;
      Container : Magic_String) return Boolean;
   
   procedure Next
     (Self      : in out Each_Character;
      Container : Magic_String);

One more variation has class-wide iterator as parameter type.
Consider an example with abstract API.

.. code-block:: ada

   type Element is limited interface;
   type Element_Access is access all Element'Class with Storage_Size => 0;
   
   function Is_Nice (Self : Element) return Boolean is abstract;
   
   type Element_Vector is limited interface
     with Iterators => Each;
   
   type Each is limited interface
     with Iterate => Element_Vector;
   
   --  Compiler interface:
   function First (Target : Element_Vector) return Each'Class is abstract;
   function Has_Element (Self : Each) return Boolean is abstract;
   procedure Next (Self : in out Each) is abstract;
   
   --  User interface:
   function Element (Self : Each) return Element_Access;
   
   --  Usage:
   function Count_Nice
     (Vector : Element_Vector'Class) return Natural
   is
      Result : Natural := 0;
   begin
      for J in Vector.Each loop
         if J.Element.Is_Nice then
            Result := Result + 1;
         end if;
      end loop;
   
      return Result;
   end Count_Nice;

Such iterator's specification allows us to describe an abstract API
for container of abstract elements, but we still have a way to
iterate over any implementation of this API using handy form
of iteration.

It would be nice to allow limited view to iterator type in
`Iterators` aspect. It permits definition of iterators in
child packages and allows better modularity. Of course
usage of such iterators is allowed only where there is full
visibility of the iterator types. See `Each_Word` in the first
example.



Reference-level explanation
===========================

TBD

Rationale and alternatives
==========================

TBD

Drawbacks
=========

TBD


Prior art
=========

TBD

Unresolved questions
====================

1. Can we avoid tempered checks?

Future possibilities
====================

TBD


.. _Iterable: https://github.com/reznikmm/ada-spark-rfcs/blob/lightweight-iterators2/considered/rfc-lightweight-iterators.rst
