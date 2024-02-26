- Feature Name: Standard OOP model
- Start Date: May 5th 2020
- RFC PR:
- RFC Issue:

Summary
=======

Motivation
==========

Guide-level explanation
=======================

Record, tagged records and class records can declare destructors. The
destructor is identifed by the `Destructor` attribute, e.g.:

.. code-block:: ada

   package P is
      type T is tagged null record;
      for T'Destructor use My_Destructor;

      procedure My_Destructor (Self : in out T);

      type T2 is new T with null record
      with Destructor => My_Destructor;

      procedure My_Destructor (Self : in out T2);
   end P;

The destruction sequence works in the following way:
- If a type has an explicit destructor, it is first called.
- If a type has components hierarchy, wether or not it has an explicit
  destructor, the destructor sequence is called on each components.
- If a type is in a tagged hierarchy, wether or not it has an explicit
  destructor, the parent destructor sequence is called.

Destructors are called following the same rules as Ada finalization.


Reference-level explanation
===========================


Rationale and alternatives
==========================

Drawbacks
=========


Prior art
=========

Unresolved questions
====================

Future possibilities
====================

We need a scoped syntax for the destructor. One option is to piggy back on
a separate RFC being written that allows to define attributes directly in
the form of type'attribute name. For example, specifying Write could be done
in the following way:

.. code-block:: ada

   type T is null record;

   procedure S'Write(
      Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Item : in T);

Using this gives us a new un-scoped notation:

.. code-block:: ada

   package P is
      type T is tagged null record;

      procedure T'Destructor (Self : in out T);

   end P;

And this can be easily extended to a scoped notation for Destructor as well as
other attributes:

.. code-block:: ada

   package P is
      type T is tagged record
          procedure T'Destructor (Self : in out T);
      end record;
   end P;

