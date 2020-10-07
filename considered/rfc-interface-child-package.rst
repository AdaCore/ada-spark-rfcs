- Feature Name: Overriding_Interface_In_Child_Package
- Start Date: 2020-10-06
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

When adding an interface to a record, each abstract method must be expliticy overridden.
With a few interfaces added, a package implementing these interfaces could grow large quickly 
resulting in a large file.
Ada has the capabiliy to implement a single method of a record type in a separate package, 
the request for change is extending this capability with a grouping concept also already in Ada,
the interface. 
Proposed is a solution request to instruct the compiler to look for the interface overriding
in a child package.

Proposal:

.. code-block:: ada

      overriding interface <name> in <package.child>;

Motivation
==========

Nexperia E&A is running a project to rejuvenate the die bonder SW architecture.
One of the chosen directions is to move behavior of the application in to interfaces
keeping the SOLID (https://en.wikipedia.org/wiki/SOLID) principle in mind. 
This leads to implementations where multiple interfaces are inherited by a record
and since each interface needs to be overridden, the record package is becoming large again.

The current straight forward solution implemented for distributing methods to a child package
is to use the rename. However, this requires statemens per method in both the body 
and specification of the package deriving the interface:

- in the interface specification (Diagnose_Interface.ads): 
.. code-block:: ada

     type Diagnose is limited interface

     function Do_Diagnose
        (Module : not null access Diagnose)
         return Boolean
        is abstract;

- in the containing specification (Adat_Pushup_Punch_Unit.ads):
.. code-block:: ada

   type Pushup_Punch_Type is
      new Diagnose_Interface.Diagnose with private;

     overriding
     function Do_Diagnose
        (Pu : not null access Pushup_Punch_Type)
        return Boolean;

- in the containing body (Adat_Pushup_Punch_Unit.adb):
.. code-block:: ada

     overriding
     function Do_Diagnose
        (Pu : not null access Pushup_Punch_Type)
        return Boolean
        renames Adat_Pushup_Punch_Unit.Diagnose.Do_Diagnose;

- In the delegator (child of containing) specification (Adat_Pushup_Punch_Unit-Diagnose.ads):
.. code-block:: ada

     function Do_Diagnose
        (Pu : not null access Pushup_Punch_Type)
        return Boolean;

- In the delegator body (Adat_Pushup_Punch_Unit-Diagnose.adb):
.. code-block:: ada

     function Do_Diagnose
        (Pu : not null access Pushup_Punch_Type)
        return Boolean
     is
     begin
        -- Finally the code really doing something
     end Do_Diagnose;

The redirection in the containing specification and body is requiring a lot of lines and
could need an update with each interface change. It would save development and maintenance time 
if the redirection of an interface to the delegator package could be defined with one line in
the containing specification. Such a single line indirection also improves the readability. 

Some example data:
   Suppose there are 6 interface connected to a record
   and on average an interface has 8 methods with an average of 40 lines
   then the containing body already has 1920 lines.
   And the containing specification around 192 lines.

   The solution we use now reduces, the number of lines in the containing body, 
   to around 216 lines. But saves nothing in the specification.

   By introducing the proposed feature.
   The containing body doesn't need additional lines for the intercafe at all and
   the specification only needs 6 lines. 

Guide-level explanation
=======================

The new language concept could be:

.. code-block:: ada

      overriding interface <name> in <package.child>;

I have choosen to add the overriding declarator to make it the child package
is overriding the interface methods.
Adding <package.child> gives some naming flexibility in case 
two different packages are using the same name for an interface. 

The changes in the example given in the motivation are in the containing specification and body.

-  The overriding function statements in both the specification and body can be removed

-  Instead of the following line is added to the specification:
.. code-block:: ada

      overriding interface Diagnose in Adat_Pushup_Punch_Unit.Diagnose;

In the delegator package, the ``overriding``  declarator needs to be prefixed to the methods. 

The proposed statement must be between the forward and full declaration of the record type using it.
As an architect I prefer to enforce the use of the interface and not the record, 
so I would like to also have it possible this statement can be in the private part 
of the containing package specification.

The compiler could handle the proposed new statement as a kind of in-place insertion.
Where the statement is given the methods defined in the child package should be inserted.
All conditions, constraints and attributes now for overriding methods in the containing package
should be valid for the methods in the child package.  

Reference-level explanation
===========================

This proposed statement could be seen as the interface version of

.. code-block:: ada

      procedure <name> is separate;


But then the child package name is forced by the interface name. 
And the overriding keyword emphazies the purpose of the redirect.

The implementation could be similar as the separate, but then not for a single function
but for a coherent group of functions (the interface). 

Rationale and alternatives
==========================

An alternative for the proposed concept could also be:

.. code-block:: ada

      interface <name> is separate;

The design proposes a single line statement to redirect the overriding implementation
of an interface to a child package. 
The current chosen solution by Nexperia E&A (as shown in the motivation example) is
necessary to make the compiler happy, but is also adding more code lines and 
reduces the oversight on the rest of the code in the parent.

Using the available 'procedure <name> is separate' requires a package for each method in 
the interface. This leads to many, very small packages and also reduces the oversight.

The other alternative solution is using the source reference pragma.
But this moves 'coding' to the project files and probably leads 
(with several functions in a couple of added interfaces) to a maintenance nightmare.

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
