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

    procedure P (V : Integer; V2 : Root); -- Primitive

    type Child1 is null record
    with First_Controlling_Parameter;

    override
    procedure P (V : Integer; V2 : Root); -- Primitive

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
