- Feature Name: expression_functions_as_default_for_generic_formal_function_parameters
- Start Date: 2019-05-16
- RFC PR:
- RFC Issue:

Summary
=======

Allow specifying a default for a generic formal function parameter by using an
expression function. For example, it could be used to provide a Copy function
to a container package in the following way:


generic
   type Element_Type is private;

   with function "=" (Left, Right : Element_Type)
      return Boolean is <>;

   with function Copy (Item : Element_Type) return Element_Type is (Item);

package Ada.Containers.Formal_Doubly_Linked_Lists is 

Motivation
==========

It could be used to add new parameters to generic packages for special cases.
For example, on formal containers, we would need to be able to provide a Copy
function for containers containing SPARK ownership types (types containing
access types, so for which a deep copy is required). But we would not want to
force all users to provide the Copy function if they are using regular types.

Guide-level explanation
=======================

Instead of a default name, it is also possible to supply a direct definition
for the default value of a formal function parameter. This definition is given
in the form of an expression function. If no values are supplied for the formal
parameter, then an expression function with the formal name and the supplied
definition is used instead. It is a bit similar to the null default for formal
procedure parameters.
As an example, we all know the usual example of a generic stack:

generic
   type T is private;
package Stacks is
   type Stack is private;
   procedure Push (S : Stack; X : T);
   ...

However, if we use this generic to store access based structure, it may not do
what we expect. For example, in the code below, the aliasing between X and the
pointer stored in the stack means that the top of the stack is modified by
assigning to X.all, and so "21" is printed instead of "12":

with Stacks;
with Ada.Text_IO;
procedure Use_Stacks is
   type Int_Acc is access Integer;

   package Int_Acc_Stacks is new Stacks (T => Int_Acc);
   use Int_Acc_Stacks;

   S : Stack;
   X : Int_Acc := new Integer'(12);
begin
   Push (S, X);
   X.all := 21;
   Ada.Text_IO.Put_Line (Peek (S).all'Image);
end Use_Stacks;

Depending on the use case, we may want the object in the stack to be copied
using either a deep copy, or a shallow copy. To handle the first case, we need
to supply an additional formal function parameter to the generic, to provide
the Copy function that we want to use:

generic
   type T is private;
   with function Copy (Item : T) return T;
package Stacks is
   type Stack is private;
   procedure Push (S : Stack; X : T);
   ...

But in general, we still want to instantiate stacks in the usual way, that is
so that usual copy is used on assignment. This can be achieved by supplying a
default for the Copy function using an expression function:

   with function Copy (Item : T) return T is (Item);

Reference-level explanation
===========================

The language now accepts expressions as subprogram_default of formal
subprograms. The expression should be checked so that the subprogram yields a
valid expression function. When a generic is instantiated with no actual for
a formal function parameter with such a default, an expression function is
constructed from the profile and definition given by the formal parameter. It
is then used inside the generic in place of the missing actual parameter.

For example, let us look at the example in the previous section:

package Int_Acc_Stacks is new Stacks (T => Int_Acc);

Since no value is supplied for the Copy parameter, this should produce the
instance:

package Int_Acc_Stacks is
   subtype T is Int_Acc;
   function Copy (Item : T) return T is (Item);

   type Stack is private;
   procedure Push (S : Stack; X : T);
   ...

Rationale and alternatives
==========================

I think this change is a natural extension of the language, now that expression
functions have been introduced. It matches what is done for null procedures.
If we don't introduce this feature, in use cases like the example before, either
each instances should provide a value for Copy, or a new generic package should
be made, providing a simplified instanciation pattern for the usual use-case:

generic
   type T is private;
   with function Copy (Item : T) return T;
package Stacks is
   type Stack is private;
   procedure Push (S : Stack; X : T);
   ...
end Stacks

generic
   type T is private;
package Usual_Stacks is
   function Copy (Item : T) return T is (Item);
   
   package Inst is new Stacks (T => T, Copy => Copy);
end Usual_Stacks;

The draw-backs of this work-around are:
 - the different name of the generic package (we have to know is exists and what
   it does)
 - the nesting of the generic instance, as now either users should call
   Int_Acc_Stacks.Inst.Push or renamings should be introduced for all entities
   declared in Stacks.

Drawbacks
=========

None that I can think of, except a new use case of expression functions.


Prior art
=========

I don't know of any.

Unresolved questions
====================
None that I can think of.

Future possibilities
====================

I cannot think of anything more.
