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
