
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