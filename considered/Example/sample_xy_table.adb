

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