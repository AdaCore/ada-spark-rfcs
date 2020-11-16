

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