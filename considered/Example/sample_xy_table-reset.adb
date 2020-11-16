

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