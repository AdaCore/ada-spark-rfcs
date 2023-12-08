- Feature Name: Standard OOP model
- Start Date: May 5th 2020
- RFC PR:
- RFC Issue:

Summary
=======

Motivation
==========

There are several motivations to this RFC. The first one is to get rid of
controlling return types, which are a complicated and seldom used feature of
Ada. The second is to simplify the scheme with regards to which parameters can
be dispatching.

Controlling return types
------------------------

Sometimes you want to be able to define primitives of a tagged type, that
return an instance of this tagged type, without being dispatching on the return
type:

.. code-block:: ada

   type Tree_Node is tagged private;

   function Child (Self : Tree_Node; Index : Integer) return Tree_Node;

In Ada for the moment, you cannot define this primitive without either making
the return type class-wide, which is extremely inconvenient because the return
type is now indefinite, or making `Self` class-wide, which is also
inconvenient, because the `Child` function is still a primitive of `Tree_Node`
and will be derived for every subtype, even if you don't wish to.

An alternative would be to define the `Child` function in a separate package,
but:

1. It is wildly inconvenient and unintuitive from an API design standpoint.
   There is no way to justify it except "Ada doesn't let me do what I need",
   which looks bad in a comment.

2. You lose the ability to call the `Child` function with the dot-notation.

Simplify dispatching
--------------------

In Ada, it is possible to define a controlling primitive on a tagged type that
dispatches on the second parameter:

.. code-block:: ada

   type Foo is tagged private;

   function Bar (A : Integer; Self : Foo) return Integer;
   -- This is a controlling primitive

The problem is that when you do that, you lose the ability to use the prefix
notation for calls. Along with that, you lose the ability to call this
primitive without `with`-ing the package in which it is defined.

We think that dot notation, and the ability to use primitives without with-ing
the defining package, are integral parts of idiomatic object-oriented
programming.

Also the use cases where the above is useful are extremely rare if not non
existent, so we feel it's OK to forbid them.

Guide-level explanation
=======================

A new pragma / aspect is introduced for tagged types, "First_Controlling_Parameter"
which modifies the semantic of primitive / controlling parameter.

When a tagged type is marked under this aspect, only subprograms that have the
first parameter of this type will be considered primitive. In addition, all
other parameters are not dispatching. This pragma / aspect applies to all
the hiearchy starting on this type.

Primitives inherited do not change.

For example:

.. code-block:: ada

    type Root is null record;

    procedure P (V : Integer; V2 : Root);
    -- Primitive

    type Child is new Root with null record
    with First_Controlling_Parameter;

    override
    procedure P (V : Integer; V2 : Child);
    -- Primitive

    procedure P2 (V : Integer; V2 : Child);
    -- NOT Primitive

    function F return Child; -- NOT Primitive

    function F2 (V : Child) return Child;
    -- Primitive, but only controlling on the first parameter

Note that `function F2 (V : Child) return Child;` differs from
`function F2 (V : Child) return Child'Class;` in that the returned type is a
definite type. It's also different from the legacy semantic which would force
further derivations adding fields to override the function.

For generic formals tagged types, you can specify whether the type has the
`First_Controlling_Parameter` aspect on or not.

.. code-block:: ada

    generic
       type T is tagged private with First_Controlling_Parameter;
    package T is
        type U is new T with null record;
        function Foo return U; -- Not a primitive
    end T;

For tagged partial views, the value of the aspect needs to be consistent
between the partial and the full view:

.. code-block:: ada

   type T is tagged private;

   private

   type T is tagged null record with First_Controlling_Parameter; -- ILLEGAL


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
