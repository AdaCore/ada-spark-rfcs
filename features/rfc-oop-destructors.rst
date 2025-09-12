- Feature Name: Standard OOP model
- Start Date: May 5th 2020
- Status: Production

Summary
=======

Motivation
==========

Guide-level explanation
=======================

Record, tagged records and class records can declare destructors. The
destructor is identifed by the `<type>'Destructor` attribute, e.g.:

.. code-block:: ada

   package P is
      type T is tagged null record;

      procedure T'Destructor (Self : in out T);

      type T2 is new T with null record;

      procedure T2'Destructor (Self : in out T2);
   end P;

The destructor expands into a Finalizable type, and the runtime semantics can
be thought about in terms of that expansion.

The expansion is meant to allow the following:

1. Allow C++ like destructor semantics, where the parent destructor is
   automatically called (so destruction cannot be forgotten)

2. Only overriding of the destructor possible is via `procedure
   My_Type'Destructor`, without the `overriding` qualifier, or via the aspect,
   and specifiying a new procedure.

3. A destructor procedure can hence never be overriden via the `overriding`
   qualifier. We deem that it would be confusing wrt. the auto call parent
   semantics.

Here is a proposed expansion for the example above:

.. code-block:: ada

   package P is
      type T is tagged null record
      with Finalizable => (Finalize => T_Destructor_Wrapper);

      procedure T_Destructor_Wrapper (Self : in out T);
      procedure T_Destructor (Self : in out T);

      type T2 is new T with null record;

      procedure T2_Destructor (Self : in out T2);
      overriding procedure T_Destructor_Wrapper (Self : in out T2);
   end P;

   package body P is
      procedure T_Destructor_Wrapper (Self : in out T) is
      begin
        T_Destructor (Self);
      end T_Destructor_Wrapper;

      overriding procedure T_Destructor_Wrapper (Self : in out T2) is
      begin
        T2_Destructor (Self);
        T_Destructor (Self);
      end T_Destructor_Wrapper;
   end P;

The destruction sequence works in the following way:

- If a type has an explicit destructor, it is first called.
- If a type has components hierarchy, wether or not it has an explicit
  destructor, the destructor sequence is called on each components, in
  reverse order of construction.
- If a type is in a tagged hierarchy, wether or not it has an explicit
  destructor, the parent destructor sequence is called.

Destructors are called at the same place as when Ada finalization is run.

Reference-level explanation
===========================

Name resolution rules
---------------------

* The ``Destructor`` attribute expects a procedure with a single parameter of the
  type on which the aspect is defined.

Legality rules
--------------

* The `Destructor` attribute can be re-specified for types derived from a type
  that has a `Destructor` aspect.

* The subprogram passed to the destructor aspect should have the ``in out``
  mode on the first (and only) parameter.

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

