- Feature Name: Standard OOP model
- Start Date: May 5th 2020
- Status: Production

Summary
=======

Motivation
==========

There are several motivations to this RFC. The first one is to give explicit
control over which parameters and results of a primitive are dispatching, in
particular to allow primitives that return (or take) an instance of their type
without that result or parameter being dispatching - something that is awkward
to express in current Ada. The second is to simplify the scheme with regards to
which parameters can be dispatching.

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
type is now indefinite, or making ``Self`` class-wide, which is also
inconvenient, because the ``Child`` function is still a primitive of ``Tree_Node``
and will be derived for every subtype, even if you don't wish to.

An alternative would be to define the ``Child`` function in a separate package,
but:

1. It is wildly inconvenient and unintuitive from an API design standpoint.
   There is no way to justify it except "Ada doesn't let me do what I need",
   which looks bad in a comment.

2. You lose the ability to call the ``Child`` function with the dot-notation.

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
primitive without ``with``-ing the package in which it is defined.

We think that dot notation, and the ability to use primitives without with-ing
the defining package, are integral parts of idiomatic object-oriented
programming.

Also the use cases where the above is useful are extremely rare if not non-existent,
so we feel it's OK to forbid them.

Guide-level explanation
=======================

A new pragma / aspect is introduced for tagged types, ``First_Controlling_Parameter``
which modifies the semantics of primitive / controlling parameter.

When a tagged type is marked under this aspect, only subprograms that have the
first parameter of this type will be considered primitive.
This pragma / aspect applies to all the hierarchy starting on this type.

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
    -- Primitive, controlling on the first parameter and on the result

    function F3 (V : Child) return Child'Fixed;
    -- Primitive, controlling on the first parameter only; the result is fixed

As long as the first parameter is controlling, a primitive may also have
additional controlling parameters and a controlling result. These all dispatch
and are rewritten to the derived type when the primitive is overridden. When a
parameter or result should refer to the type without dispatching, it is marked
with the ``'Fixed`` attribute, as shown above with ``F3``.

Note that ``function F3 (V : Child) return Child'Fixed;`` differs from
``function F3 (V : Child) return Child'Class;`` in that the returned type is a
definite type. It is also different from a controlling (dispatching) result
such as ``F2``'s, which forces further derivations to override the function.

For generic formals tagged types, you can specify whether the type has the
``First_Controlling_Parameter`` aspect on or not.

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

``First_Controlling_Parameter`` is an aspect that can be specified on either:

* A tagged ``record_type_definition``
* A ``derived_type_definition`` or ``formal_derived_type_definition``
* A tagged ``private_type_declaration`` or ``formal_private_type_definition``
* An ``interface_type_definition`` or ``formal_interface_type_definition``

.. note:: This aspect doesn't seem useful on regular types, and as such has
    not been considered

A type which has the ``First_Controlling_Parameter`` aspect defined cannot be
passed as a tagged type generic formal. It can be passed as a more general
private type.

.. attention:: In a first step, rather than implementing the full generic
   machinery, disallowing the passing of types which have the aspect set to
   true as generic tagged formal seems to be a valid option, to simplify
   prototyping, and because that case seems to be extremely marginal (passing
   of tagged types in generics in general is a marginal use case as far as we
   can tell).

In the case of interface types:

* If an interface type has the ``First_Controlling_Parameter`` aspect
  specified, then any interface or tagged type deriving from it should have the
  aspect explicitly specified as well

* If a tagged type or interface extends several interfaces, they should be
  consistent with regards to the ``First_Controlling_Parameter`` aspect.

.. note:: Those two rules are not strictly necessary, and we could make the
   feature work without them. However, they seem necessary to make the feature
   user-friendly and explicit, avoiding situations where a type has a
   completely disjoint set of primitives with different rules.

Types which have the ``First_Controlling_Parameter`` aspect have specific rules
with regards to which subprograms will be considered primitives of the type:

1. A subprogram will be considered a primitive of type ``T`` following the same
   rules as for regular tagged types, with the added rule that **the first
   parameter of the subprogram needs to be a controlling parameter of type**
   ``T`` in order for the subprogram to be considered a primitive.

2. Beyond the first parameter, a primitive may have any number of additional
   controlling parameters as well as a controlling result. These all dispatch
   and are rewritten to the derived type when the primitive is overridden, as
   for regular tagged types.

The ``'Fixed`` attribute
------------------------

A parameter or result that refers to the type but should **not** dispatch can
be marked with the ``'Fixed`` attribute, applied to a subtype mark of the type.
``T'Fixed`` denotes a non-dispatching, definite reference to the subtype ``T``.

The following rules apply to ``'Fixed``:

* ``'Fixed`` may only be used in a position where the type may be controlling,
  i.e. on a parameter or result of a primitive of the type. It is illegal
  anywhere else.

* A ``'Fixed`` parameter or result keeps its subtype unchanged in overridings -
  it is not rewritten to the derived type - and does not participate in
  dispatching.

* ``'Fixed`` participates in subprogram conformance: two profiles conform only
  if their ``'Fixed`` markings match.

* ``'Fixed`` cannot be applied to the first parameter of a primitive, since the
  first parameter must always be controlling.

* ``'Fixed`` cannot be used on a generic formal parameter.

* ``'Fixed`` may be applied not only to the first subtype of the type but to any
  subtype of it.

For example:

.. code-block:: ada

   type Root is tagged null record with First_Controlling_Parameter;

   function F (Self : Root; Param : Root'Fixed) return Root'Fixed;

   type Child is new Root with null record;

   overriding
   function F (Self : Child; Param : Root'Fixed) return Root'Fixed;
   --  Only the first parameter changes to Child when overriding; the 'Fixed
   --  parameter and result keep the Root'Fixed subtype.

.. code-block:: ada

   type T is tagged null record with First_Controlling_Parameter;

   procedure Prim_1 (Self : T);  -- Primitive
   procedure Prim_2 (Self : T; Other : T);
   --  Primitive. Several controlling parameters are allowed as long as the
   --  first one is controlling; Other dispatches and becomes the derived type
   --  when overridden.

   procedure Prim_2b (Self : T; Other : T'Fixed);
   --  Primitive. Other refers to T but is fixed: it does not dispatch and keeps
   --  the T'Fixed subtype when overridden.

   function Prim_3 (Self : T) return T;
   --  Primitive, controlling on the result (return type dispatching).

   function Prim_3b (Self : T) return T'Fixed;
   --  Primitive. The result refers to T but is fixed: no return type
   --  dispatching.

   function "=" (Self, Other : T) return Boolean; -- Primitive (same as Prim_2)
   function Not_A_Prim_1 (Self : T'Class) return T; -- Not a primitive
   procedure Not_A_Prim_2 (Self : T'Class; Other : T); -- Not a primitive

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
