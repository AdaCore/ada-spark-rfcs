- Feature Name: Overriding_Interface_In_Child_Package
- Start Date: 2020-10-06
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

When adding an interface to a record, each abstract method must be overridden.
With a few interfaces added, a package implementing the interface could grow large quickly.
Proposed is a solution request to instruct the compiler to look for the interface overriding
in a child package.

Proposal:
.. code-block:: ada

   overriding interface <name> in <package.child>;

An alternative could be:
.. code-block:: ada

   interface <name> in separate;

Motivation
==========

Nexperia E&A is running a project to rejuvenate the die bonder SW architecture.
One of the chosen directions is to move behavior of the application in to interfaces
keeping the SOLID (https://en.wikipedia.org/wiki/SOLID) principle in mind. 
This leads to implementations where multiple interfaces are inherited by a record
and since each interface needs to be overridden, the record package is becoming large again.

The current straight forward solution implemented for distributing methods to child package
is to use the rename. However, this leads to 5 times the same method header:

- in the interface (Diagnose_Interface.ads): 
.. code-block:: ada

     function Do_Diagnose
        (Module : not null access Diagnose)
         return Boolean
        is abstract;

- in the parent specification (Adat_Pushup_Punch_Unit.ads):
.. code-block:: ada
     overriding

     function Do_Diagnose
        (Pu : not null access Pushup_Punch_Type)
        return Boolean;

- in the parent body (Adat_Pushup_Punch_Unit.adb):
.. code-block:: ada

     overriding
     function Do_Diagnose
        (Pu : not null access Pushup_Punch_Type)
        return Boolean
        renames Adat_Pushup_Punch_Unit.Diagnose.Do_Diagnose;

- In the child specification (Adat_Pushup_Punch_Unit-Diagnose.ads):
.. code-block:: ada

     function Do_Diagnose
        (Pu : not null access Pushup_Punch_Type)
        return Boolean;

- In the child body (Adat_Pushup_Punch_Unit-Diagnose.adb):
.. code-block:: ada

     function Do_Diagnose
        (Pu : not null access Pushup_Punch_Type)
        return Boolean
     is
     begin
        -- Finally the code really doing something
     end Do_Diagnose;

The redirection in the parent specification and body is adding a lot of lines and require
to be updated each time the interface changes. It would save development and maintenance time 
if the redirection of an interface to the child package could be defined with one line in
the parent specification. Such a single line indirection also improves the readability. 

Guide-level explanation
=======================

The new language concept could be:
.. code-block:: ada

   overriding interface <name> in <package.child>;

The change in the example given in the motivation are in the parent specification and body.

-  The overriding function statement in both the specification and body can be removed

-  Instead of the following line is added to the specification:
.. code-block:: ada

      overriding interface Diagnose in Adat_Pushup_Punch_Unit.Diagnose;

The proposed statement must be between the forward and full declaration of the record type using it.
As an architect I prefer to enforce the use of the interface and not the record, 
so I would like to have this statement in the private part of the parent package specification.

The compiler could handle the proposed new statement as a kind of in-place insertion.
Where the statement is given the methods defined in the child package should be inserted.
Al conditions, constraints and attributes now for overriding methods in the parent package
should be valid for the methods in the child package.  

Reference-level explanation
===========================

This proposed statement could be seen as the interface version of
.. code-block:: ada

   procedure <name> is separate;

An alternative for the proposed concept could also be:
.. code-block:: ada

  interface <name> is separate;

But then the child package name is forced by the interface name. 
And the overriding keyword emphazies the purpose of the redirect.

The implementation could be similar as the separate, but then not for a single function
but for a coherent group of functions (the interface). 

Rationale and alternatives
==========================

The design proposes a single line statement to redirect the overriding implementation
of an interface to a child package. 
The current chosen solution by Nexperia E&A (as shown in the motivation example) is
necessary to make the compiler happy, but is also adding more code lines and 
reduces the oversight on the rest of the code in the parent.

Using the available 'procedure <name> is separate' requires a package for each method in 
the interface. this leads to many, very small packages and also reduces the oversight.

The other alternative solution is using the source reference pragma.
But this moves 'coding' to the project files and probably leads 
(with several functions in a couple af added interfaces) to a maintenance nightmare.

Drawbacks
=========

Since it is an alike solution as 'procedure <name> is separate' I expect no drawbacks.

Prior art
=========

It is an interface version of 'procedure <name> is separate'.
That could be the guide for the implementation.

Unresolved questions
====================

None that I can think of.

Future possibilities
====================

I cannot think of anything more.
