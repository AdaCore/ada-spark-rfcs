Summary
=======
 
Ada 2012 lets the user provide custom indexing aspects to our types, via
Constant_Indexing and Variable_Indexing aspects.
 
However, we cannot control the ``..`` range notation.

Motivation
==========
 
When using a vector or an unbounded string, it would be nice
to be able write
 
     S : constant Unbounded_String := V (2 .. 3)
     S (2 .. 3) := 'AB';
 
instead of
 
     S : Unbounded_String := Unbounded_Slice (V, 2, 3);
     Replace_Slice (S, 2, 3, 'AB');
 
Guide level explanation
=======================

Constant_Range_Indexing
-----------------------
 
The Constant_Range_Indexing aspect allows the user to map the ``..`` notation
to an user defined operation:

The following declaration
 
.. code-block::

     type T is private
        with Constant_Range_Indexing => Slice;

will allow users of the type T to use the ``..`` notation on instances of the type T, via a function defined via the user (here, named ``Slice``) that takes a parameter of type T and two parameters for indices.

Variable_Range_Indexing
-----------------------
 
Like ``Constant_Range_Indexing``, the ``Variable_Range_Indexing`` aspect allows the user to map the ``..`` notation, except in this case with the purpose of modifying the targeted instance of the type on which the aspect is specified.

For example, the following declaration

.. code-block::
 
    type T is private
       with Variable_Range_Indexing => Replace_Slice;


will allow users of the type T to use the ``..`` on instances of the type T, to modify an instance of it.

The requirements with regards to parameters are the same, except that the parameter of type ``T`` needs to be an ``in out`` parameter.

Reference-level explanation
===========================

Constant_Range_Indexing
-----------------------

The code

.. code-block::

     type T is private
        with Constant_Range_Indexing => Slice;
 
will look for a subprogram Slice in the current declarative region, with
the following profile: first parameter is of type T or T'Class or an access
parameter whose designated type is T or T'Class.

The second and third parameters are indexes (for compatibility
with Ada.Strings.Unbounded.Slice, we propose that the two types need not be
the same, or perhaps both subtypes of the same type). The return value is
any type.

This is similar to the requirements for user-defined iterator types
in the Ada reference manual, sections 5.5.1 (8/3) or user-defined indexing in
4.1.6.
 
So for instance we could have the following in our spec:

.. code-block::
 
    function Slice (Self : T; Low, High : Integer) return String;
    function Slice (Self : T'Class; Low, High : Character) return T;
 
and both would be applicable via overriding.
 
When we then use

.. code-block::
 
     V : T;
     S : constant String := V (2 .. 3);
     --  expanded to      V.Slice (2, 3)  which is unambiguous
 
     T : constant T := V ('A' .. 'Z’);
 
Variable_Range_Indexing
-----------------------
 
The following declaration

.. code-block::
 
    type T is private
       with Variable_Range_Indexing => Replace_Slice;
 
will look for a subprogram Replace_Slice with the following profile: first
parameter is an "in out" T or T'Class, or an access parameter whose designated
type is T or T'Class.
The second and third parameters have the same requirements as above. There is
an additional fourth parameter whose type is any type.
 
So we could have the following in our spec:
 
.. code-block::

     procedure Replace_Slice
        (Self : in out T; Low, High : Integer; By : String);
     procedure Replace_Slice
        (Self : in out T; Low, High : Character; By : Vector);
 
We can then use:
 
.. code-block::

     V : T;
 
     V (2 .. 3) := "some string";
     --  expanded to   Replace_Slice (V, 2, 3, "some_string")

Rationale and alternatives
==========================

Rationale is explained in the motivation section. There is no clear alternatives in the context of Ada.

In terms of alternatives, Python provides a slice operator too. The way you override it is by providing custom ways to get an item (similar to the ``Constant_Indexing`` and ``Variable_Indexing`` aspects). Python will then itself apply those operations over every item concerned by the slice.

There are some positives to that approach, namely that there is one less operation to define. However, in terms of drawbacks, it makes the functionality potentially slower (you cannot optimize for the slice case) and more rigid (you can only slice over integers).

Drawbacks
=========

None found.

Prior art
=========

Like said in the "Rationale and alternatives" section, Python possesses a
similar functionality.

Unresolved questions
====================

None found.
