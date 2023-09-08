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

A new restriction is introduced, `Tagged_Class_Compatible` which ensures that
a tagged type observes the restrictions of classes. It can be set for a given
tagged type:

.. code-block:: ada

   type R is tagged null record
      with Tagged_Class_Compatible;

Or set for an entire partition:

.. code-block:: ada

   package P is
      pragma Restrictions (Tagged_Class_Compatible);

The Tagged_Class_Compatible is a constraint on a tagged type and its parents.
Its children may not be covered by the same restriction.

A restricted tagged type has the following contraints:

   - It can only have one controlling parameter, the first one
   - It cannot have a controlling result
   - It cannot derive from Controlled nor contain a Controlled objects
   - It cannot have coextensions

The advantage of a restricted tagged record is that it can be extended by a
class record, thus providing an initial mirgration path.

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
