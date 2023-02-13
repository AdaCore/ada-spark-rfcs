- Feature Name: Overriding_Interface_In_Child_Package
- Start Date: 2020-10-06
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Short description
=================

Ada has an option to place bodies in a separate compilation unit using the **seperate** keyword.
I would like to have an option to have a seperate compilation unit for an interface inherited by a type.
This proposal describe a possible solution.

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

Extensive example
=================
I do refer to the tagged type interface, but I would like to be able to have the actual inheritance by a type, to be implemented in a subpackage.
This to reduces the package size of the type inheriting the interface and have a better maintainability.

I added a sample with the following files:
- sample_reset_if.ads : a generic interface for a moudle which supports a reset action
- sample_xy_table_if.ads : an interface with XY tables which inherits the reset interface
- sample_xy_table.ads : the actual XY table type which inherits the XY table interface and thus the reset interface
- sample_xy_table.adb : implementing the methods of the XY table
- sample_xy_table-reset.ads : overriding the reset interface for the actual XY table type 
- sample_xy_table-reset.adb : implementing the reset interface for the actual XY table type

Inside the sample code, there are more comments explaining what I propose.

sample_reset_if.ads
------------------- 

.. code-block:: ada

   package Sample_Reset_If is
   
      type Resettable is limited interface;
      type Resettable_Iwa is access all Resettable'Class;
   
      procedure Do_Reset
        (I    : not null access Resettable)
         is null;
   
      function Is_Reset_In_Progress
         (I    : not null access Resettable)
         return Boolean
         is abstract;
   
      procedure Set_Axes_Enabled
         (I         : not null access Resettable;
          Enable    :                 Boolean)
         is null;
   
   end Sample_Reset_If;

sample_xy_table_if.ads
----------------------

.. code-block:: ada

   with Sample_Reset_If;
   
   package Sample_XY_Table_If is
   
      type XY_Table is limited interface
         and Sample_Reset_If.Resettable;
      type XY_Table_Iwa is access all XY_Table'Class;
   
      function Move_XY
         (XY       : not null access XY_Table;
          Position :                 Float_Point;
          Scale    :                 Float := 1.0)
         return Boolean
         is abstract;
   
      function Wait_XY
         (XY : not null access XY_Table)
         return Boolean
         is abstract;
   
      function XY_Position
         (XY        : not null access XY_Table;
          Generator :                 Boolean := True)
         return Float_Point
         is abstract;
   
   end Sample_XY_Table_If;

sample_xy_table.ads

-------------------
.. code-block:: ada

   with Sample_XY_Table_If;
   
   package Sample_XY_Table is
   
      --  This includes both the reset as the XY_Table interface
      type XY_Table_Type is
         new Sample_Xy_Table_If.XY_Table with private;
      type XY_Table_Cwa  is access all XY_Table_Type'Class;
   
      function Create
         return Sample_XY_Table_If.XY_Table_Iwa;
   
   private:
   
      --  Normally I now have to inherent all abstract functions
      --  and the null procedures I need
      --
      --  From the reset interface
      --
      --  overriding
      --     procedure Do_Reset
      --       (I    : not null access XY_Table_Type);
      --
      --  overriding
      --     function Is_Reset_In_Progress
      --        (I    : not null access XY_Table_Type)
      --        return Boolean;
      --
      --  overriding
      --     procedure Set_Axes_Enabled
      --        (I         : not null access XY_Table_Type;
      --         Enable    :                 Boolean);
      --
      --  This reset interface (and a few other generic interfaces, like diagnostics)
      --  I would like to implement in a separate package (and I was thinking of a child subpackage)
      --  So therefor I propose:
      overriding interface Resettable in sample_xy_table.reset;
      --  This tells the compiler to look in sample_xy_table-reset.ads for the declaration of this interface
      --  Like the 'separate' is defined to implement a function in a subpackage
   
      --  From the XY table interface
      --  This one is actually implementing the interface for this component so I don't mind
      --  to have it here
   
      overriding
      function Move_XY
         (XY       : not null access XY_Table_Type;
          Position :                 Float_Point;
          Scale    :                 Float := 1.0)
         return Boolean;
   
      overriding
       function Wait_XY
          (XY : not null access XY_Table_Type)
          return Boolean;
   
      overriding
       function XY_Position
          (XY        : not null access XY_Table_Type;
           Generator :                 Boolean := True)
          return Float_Point;
   
      type Pushup_XY_Type is
         new Sample_XY_Table_If.XY_Table
      with
      record
         X_Motor : Motion.Motor_Access;
         Y_Motor : Motion.Motor_Access;
      end record;
   
   end Sample_XY_Table;

sample_xy_table.adb
-------------------

.. code-block:: ada

   package body Sample_XY_Table is
   
      --  Normally I now have to implement all abstract functions
      --  and the null procedures I need
      --
      --  From the reset interface
      --
      --  overriding
      --     procedure Do_Reset
      --       (I    : not null access XY_Table_Type);
      --
      --  overriding
      --     function Is_Reset_In_Progress
      --        (I    : not null access XY_Table_Type)
      --        return Boolean;
      --
      --  overriding
      --     procedure Set_Axes_Enabled
      --        (I         : not null access XY_Table_Type;
      --         Enable    :                 Boolean);
      --
   
      --  But now they are in sample_xy_table-reset.adb
      --  When adding several interface, this keeps this package maintainable
   
      --  From the XY table interface
   
      overriding
      function Move_XY
         (XY       : not null access XY_Table_Type;
          Position :                 Float_Point;
          Scale    :                 Float := 1.0)
         return Boolean
      is
      begin
         some code doing something
      end Move_XY;
   
      overriding
       function Wait_XY
          (XY : not null access XY_Table_Type)
          return Boolean
      is
      begin
         some code doing something
      end Wait_XY;
   
      overriding
       function XY_Position
          (XY        : not null access XY_Table_Type;
           Generator :                 Boolean := True)
          return Float_Point
      is
      begin
         some code doing something
      end XY_Position;
   
   end Sample_XY_Table;

sample_xy_table-reset.ads
-------------------------

.. code-block:: ada

   --  Declaring the inherited reset interface with XY_Table_Type
   package Sample_XY_Table.Reset is
   
      --  From the reset interface
   
      overriding
      procedure Do_Reset
        (I    : not null access XY_Table_Type);
   
      overriding
      function Is_Reset_In_Progress
         (I    : not null access XY_Table_Type)
         return Boolean;
   
      overriding
      procedure Set_Axes_Enabled
         (I         : not null access XY_Table_Type;
          Enable    :                 Boolean);
   
   end Sample_XY_Table.Reset;

sample_xy_table-reset.adb
-------------------------

.. code-block:: ada

   --  Implementing the inherited reset interface with XY_Table_Type
   package body Sample_XY_Table.Reset is
   
      --  From the reset interface
   
      overriding
      procedure Do_Reset
        (I    : not null access XY_Table_Type)
      is
      begin
         Enable (I.X_Motor);
         Enable (I.Y_Motor);
         Home (I.X_Motor);
         Home (I.Y_Motor);
      end Do_Reset;
   
      overriding
      function Is_Reset_In_Progress
         (I    : not null access XY_Table_Type)
         return Boolean
      is
      begin
         return Is_Moving (I.X_Motor)
            or Is_Moving (I.Y_Motor);
      end Is_Reset_In_Progress;
   
      overriding
      procedure Set_Axes_Enabled
         (I         : not null access XY_Table_Type;
          Enable    :                 Boolean)
      begin
         if Enable then
            Enable (I.X_Motor);
            Enable (I.Y_Motor);
         else
            Disable (I.X_Motor);
            Disable (I.Y_Motor);
         end if;
      end Set_Axes_Enabled;
   
   end Sample_XY_Table.Reset;

