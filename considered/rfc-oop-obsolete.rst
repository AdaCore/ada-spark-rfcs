- Feature Name: Standard OOP model
- Start Date: May 5th 2020
- RFC PR:
- RFC Issue:

Summary
=======

This section summarises Ada OOP capabilities that are rendered obsolete or not
ported in the new model.

Motivation
==========

Guide-level explanation
=======================

Operators and exotic primitives
-------------------------------

Class record do not provide dispatching on multiple parameters, on parameters
other than the first, or dispatching on results. If you declare primitives with
references to the type other than the first parameter, they will not be used
for

Under the current model, coextensions are replaced by constructors
(it's possible to mandate an object to be used in the construction of the
class) and destructors (that same object can always be destroyed in the
destructor). There is no way to create a coextension on a class record.

Controlled types are replaced by constructor / destructors and are not allowed.

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
