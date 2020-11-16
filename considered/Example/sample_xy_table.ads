
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