- Feature Name: Standard OOP model
- Start Date: May 5th 2020
- RFC PR:
- RFC Issue:

Summary
=======

The objective of this proposal is to draft an OOP model for a hypothetical new version of Ada, closer to the models languages
such as C++ and Java developers are accustomed to, fixing a number of oddities and vulnerabilities of the current Ada language.

Motivation
==========

The current Ada OOP model is source of a number of confusions and errors from people accustomed to OOP, in particular in
other languages such as C++ or Java. This proposal aims at adjusting the model to implement missing concept, fix Ada-specific
vulnerabilities and retain some of the Ada advantages.

This proposal also attempts at keeping capabilities that do not need to be specifically removed to fit within a more intuitive
OOP model, such as e.g. discriminants and aggregates.

Experience shows that whenever possible, capabilities that can be enabled to regular records should as well. A good exemple of that
is the trend observed of people declaring Ada types tagged just for the purpose of having access to prefix notation, while such notation
does not require inheritance or dispatching.

Guide-level explanation
=======================

Reference-level explanation
===========================

The proposal is split between the following parts:

Currently ready for prototyping:

- `Constructors <https://github.com/QuentinOchem/ada-spark-rfcs/blob/oop/considered/rfc-oop-constructors.rst>`_
- `Destructors <https://github.com/QuentinOchem/ada-spark-rfcs/blob/oop/considered/rfc-oop-destructors.rst>`_
- `Super cast <https://github.com/QuentinOchem/ada-spark-rfcs/blob/oop/considered/rfc-oop-super.rst>`_
- `First Controlling <https://github.com/QuentinOchem/ada-spark-rfcs/blob/oop/considered/rfc-oop-first-controlling.rst>`_

Under discussion:

- `New structure <https://github.com/QuentinOchem/ada-spark-rfcs/blob/oop/considered/rfc-oop-structure.rst>`_
- `Component declaration <https://github.com/QuentinOchem/ada-spark-rfcs/blob/oop/considered/rfc-oop-fields.rst>`_
- `Primitives declaration <https://github.com/QuentinOchem/ada-spark-rfcs/blob/oop/considered/rfc-oop-primitives.rst>`_
- `Attributes declaration <https://github.com/QuentinOchem/ada-spark-rfcs/blob/oop/considered/rfc-oop-attributes.rst>`_
- `Dispatching <https://github.com/QuentinOchem/ada-spark-rfcs/blob/oop/considered/rfc-oop-dispatching.rst>`_
- `New access types <https://github.com/QuentinOchem/ada-spark-rfcs/blob/oop/considered/rfc-oop-access.rst>`_
- `Final classes and primitives <https://github.com/QuentinOchem/ada-spark-rfcs/blob/oop/considered/rfc-oop-final.rst>`_
- `Body restriction lift <https://github.com/QuentinOchem/ada-spark-rfcs/blob/oop/considered/rfc-oop-body.rst>`_
- `Tagged record compatibilty <https://github.com/QuentinOchem/ada-spark-rfcs/blob/oop/considered/rfc-oop-tagged.rst>`_
- `Obsolete features <https://github.com/QuentinOchem/ada-spark-rfcs/blob/oop/considered/rfc-oop-obsolete.rst>`_


Rationale and alternatives
==========================

Global object hierarchy
-----------------------

We consider a global object hierarchy:

All class object implicitely derives from a top level object,
Ada.Classes.Object, defined as follows:

.. code-block:: ada

   package Ada.Classes is
      type Object is class record
         function Image (Self : Object) return String;

         function Hash (Self : Object) return Integer;
      end Object;
   end Ada.Classes;

Other top level primitives may be needed here.

However, there are several elements that argue against this design:

- the language that implement that (Java) initially introduced that as a way
  to workaround lack of genericity and `void *` notation. Ada provides
  genericity, and in the extreme cases where `void *` is required,
  `System.Address` is a reasonable replacement.
- As opposed to Java, many types in Ada are not objects. This concept would then
  be far less ubiquitous.

As a consequence, the identified use case ended up being to narrow to justify
the effort.



Drawbacks
=========


Prior art
=========

This proposal is heavily influence by C++, C# and Java (which arguably have influenced one another quite a lot).

Unresolved questions
====================

This proposal relies on the unified record syntax proposal, and will need to be updated in light of potential
revamped access model and finalization models.

A number of the capabilities of the standard run-time library rely today on tagged type. A thorough review should be made to
identify which should be removed (e.g. controlled type), which should be migrated, and which can actually be implemented without
relying on classes altogether (things such as streams or pools come to mind). The removal of coextensions types also supposes a
different model for general iteration, as it currently relies on user-defined references (implemented through coextensions).

Future possibilities
====================

Some of the notations introduced could be extended to other types, such as protected or tasks types.

The "with private;" notation should also be extended to nested packages, allowing to differenciate to nest the private part of a
nested package in the private part of its enclosing package.

The scoped primitive notation is currently specific to record types. It could be extended to all types (which would have the effect
or re-enabling the possibility to complete a simple private type by a record).

Move semantics as defined by C++ would be a very useful extension of the current
model, but has broader applicability and should be discussed separately.

Given the fact that a class is now a syntactical scope, we could also consider
to allow classes to be their own compilation units. This would fit a number
of architectures inherited from other programming languages, which require in
Ada to create an package for a single type.

A new syntax was considered to allow to override assignment:

.. code-block:: ada

   type T is null record;

   procedure ":=" (Destination : in out T; Source : T);

The difference with copy constructor was that it works on a previously
initialized type. At this stage however, the assignment semantic will be
destroying the destination object then calling the copy constructor with the
source in parameter.