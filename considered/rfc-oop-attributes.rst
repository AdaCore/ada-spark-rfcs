- Feature Name: Standard OOP model
- Start Date:
- RFC PR:
- RFC Issue:

Summary
=======

Motivation
==========

Guide-level explanation
=======================

Today, specifying a subprogram attribute of a type requires to declare a
subprogram and then to use an aspect or an attribute to link it to a type, e.g.

.. code-block:: ada

   type T is null record;

   for T'Write use My_Write;

   procedure My_Write(
      Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Item : in T);

This proposal allows to define directly the procedure as being an attribute of
the type:

.. code-block:: ada

   type T is null record;

   procedure T'Write(
      Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Item : in T);

In addition, this can be used as a scoped attribute, possibly with re-ordering
of parameters to ensure that the first parameter is conceptually the one
"owning" the primitive, e.g.:

.. code-block:: ada

   type T is tagged record

      procedure T'Write(
         Stream : not null access Ada.Streams.Root_Stream_Type'Class;
         Item : in T);

   end T;

This provide a seamless solution in particular to scope a destructor:


.. code-block:: ada

   type T is tagged record
      procedure T'Destructor (Self : in out T);
   end record;

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


