
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