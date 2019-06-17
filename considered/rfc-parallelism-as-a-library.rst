Parallelism as a library
========================

* Feature Name: parrallelism_as_library
* Start Date: 2019-06-14
* RFC PR: (leave this empty)
* RFC Issue: (leave this empty)

.. IMPORTANT::

   The following document is a meta RFC, describing a general
   approach using specific features. As such, it will suffer from several
   caveats.

   * It uses syntax that is not formally defined
   * It references RFCs that are not yet written

   The goal of this meta RFC is to create discussion and gather feedback on a
   high level approach. As such it is considered that those caveats are
   acceptable, and can/will be fixed when appropriate.

Summary
-------

The Ada 2020 standard introduces two new aspects, ``'Reduce`` and
``'Parallel_Reduce``. Those aspects allow possibly parallel
`folding <https://en.wikipedia.org/wiki/Fold_(higher-order_function)>`__
of collections.

This RFC proposes to instead use generic functions for reduction, and
introduces a series of enhancements to Ada generics which purpose is to
make the call to those generic functions as expressive as the use of the
reduce attribute.

The Ada 2020 standard also introduces more general purpose
`parallel operations
<http://www.ada-auth.org/cgi-bin/cvsweb.cgi/ai12s/ai12-0119-1.txt>`_.

This RFC also proposes to replace this heavy language level support by
orthogonal improvements to the language, and eventual library support.

Motivation
----------

This RFC proposes to instead use generic functions for reduction, and
introduces a series of enhancements to Ada generics which purpose is to
make the call to those generic functions as expressive as the use of the
reduce attribute. This way, instead of introducing more special cases in
the implementation of Ada compilers, we will:

1. Introduce more general enhancements in the language that allow user
   to implement their own powerful abstractions.
2. Fix deficiencies of Ada generics that users have been complaining
   about for a long time.

This will also imply being largely more coherent, internally (reduce is
a function like any other) as well as with regards to other languages,
where reduce is typically implemented as a function.

This would ultimately allow people to write the following example (using
proposed Ada 2020 semantics)

.. code-block:: ada

   function Sin (X : Float; Num_Terms : Positive := 5) return Float
   is
     ([for I in 1..Num_Terms =>
        (-1.0)**(I-1) * X**(2*I-1)/Float(Fact(2*I-1))]'Reduce("+", 0.0));

This way:

.. code:: ada

   type Float_Array is array (Positive range <>) of Float;

   function Sin (X : Float; Num_Terms : Positive := 5) return Float
   is
     (Reduce (Fn => "+")
       (Float_Array'
         ([for I in 1..Num_Terms => (-1.0)**(I-1) * X**(2*I-1)/Float(Fact(2*I-1))])))

..

   Note: Since reduce is a regular function, and not a magical
   attribute, it’ll need to work on an object of a non ambiguous type,
   hence the qualification above.

Regarding parallel loops and blocks, our aim is to allow people to write the
following proposed Ada 2020 code:

.. code:: ada

     A, B, C : Int_Array;

     parallel for I in A'Range loop
          A (I) := B (I) + C (I);
     end loop

into

.. code:: ada

     A, B, C : Int_Array;

     Parallel (A'Range) (
        procedure (I) is begin
           A (I) := B (I) + C (I);
        end
     );

An additional benefit is that fine tuning parametrization of parallel
iteration can use simple subprogram parameters, instead of needing language
extensions via pragmas or aspects.

For example, scheduling/chunking, in the above example, can directly use a
parameter to parallel iterate, with the following structure (to take back
OpenMP's scheduling params):

.. code:: ada

     type Scheduling_Kind is (Static, Dynamic, Guided, Auto);
     type Scheduling (Kind : Scheduling_Kind := Static) is record
        case Kind is
           when Static | Dynamic | Guided : Chunk_Size : Chunk_Size_Type
             := No_Default;
           when Auto => null;
        end case;
     end record;

We could then decide to iterate in parallel with ``Guided`` chunking and chunk
size ``4``:

.. code:: ada

     A, B, C : Int_Array;

     Parallel (A'Range, Scheduling'(Guided, 4)) (
        procedure (I) is begin
           A (I) := B (I) + C (I);
        end
     );


If we decide at a later stage that parallelism is important enough to warrant
specific syntax, and that such specific syntax has significant benefits over
the library approach, we can still ratify such syntax, and keep the
orthogonal improvements in the language, that will further allow easier
prototyping of other features as libraries.

Explanation
-----------

We will now walk through the set of proposed features that will allow us
to write the above, starting from the current set of Ada’s generic
features.

First step: Current Ada
~~~~~~~~~~~~~~~~~~~~~~~

Reduce on an array is already implementable in Ada as a function with
the following signature:

.. code:: ada

   --  Supporting code
   generic
      type Index_Type is (<>);
      type El_Type is private;
      type Array_Type is array (Index_Type range <>) of El_Type;

      type Accum is private;
      with function Fn (Current : Accum; El : El_Type) return Accum;
   function Array_Reduce (Init : Accum; Arr : Array_Type) return Accum;

The above ``Sin`` example would then be written in the following way in
current Ada:

.. code:: ada

   function Sin (X : Float; Num_Terms : Positive := 5) return Float is
      F : Float_Array (1 .. Num_Terms);
      function Red is new Array_Reduce (Positive, Float, Float_Array, Float, "+");
   begin
      for I in 1 .. Num_Terms loop
         F (I) := (-1.0) ** (I - 1) * X ** (2 * I - 1) / Float (Fact(2 * I - 1));
      end loop;
      return Red (0.0, F);
   end Sin;

Or, if we imagine we already have map expressions:

.. code:: ada

   function Sin (X : Float; Num_Terms : Positive := 5) return Float is
      function Red is new Array_Reduce (Positive, Float, Float_Array, Float, 0.0, "+");
   begin
      return Red
        (0.0, Float_Array'
          (for in in 1 .. Num_Terms =>
            (-1.0) ** (I - 1) * X ** (2 * I - 1) / Float (Fact(2 * I - 1))));
   end Sin;

..

   Opinion: The first thing to notice here is that this solution is
   already very readable and parallelizable. It is verbose, but that was
   never supposed to be a problem in Ada. The code intent is very clear.

Second step: Inference of dependent types in generic instantiations
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Using the feature described in `this rfc
(TODO) <https://todoaddlink>`__, we could then simplify the above code’s
Reduce instantiation:

.. code:: ada

   function Sin (X : Float; Num_Terms : Positive := 5) return Float is
      --  Index and element types are automatically deduced
      function Red is new Array_Reduce  (<>, <>, Float_Array, Float, "+");
   begin
      return Red
        (0.0, Float_Array'
          (for in in 1 .. Num_Terms =>
            (-1.0) ** (I - 1) * X ** (2 * I - 1) / Float (Fact(2 * I - 1))));
   end Sin;

Here, we’re allowed to not specify generic actual parameters for
parameters that can be deduced from other parameters, according to the
rules described in the RFC.

This simplifies the instantiation of the Array_Reduce generic function a
little, but is not a big step up from the last version. We will
understand the true edge this feature gives us in the last step. Let’s
go to the next iteration

Third step: Implicit instantiation of generic functions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This one is the big step up, that will allow us to get one step closer
to the initial intent. Using implicit instantiation of generic functions
`(see RFC here (TODO)) <https://TODO>`__, we would be able to write the
following:

.. code:: ada

   function Sin (X : Float; Num_Terms : Positive := 5) return Float is
     (Array_Reduce (<>, <>, Float_Array, Float, 0.0, "+");
        (0.0, Float_Array'
          (for in in 1 .. Num_Terms =>
            (-1.0) ** (I - 1) * X ** (2 * I - 1) / Float (Fact(2 * I - 1)))));

The last step we would like to get rid of is the repetitive
instantiation parameters.

Fourth step: inference of generic actual parameters from function call params
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Lastly, using inference of actual generic actuals using call actuals
`(see RFC here (TODO)) <https://TODO>`__, we can express the above as:

.. code:: ada

   function Sin (X : Float; Num_Terms : Positive := 5) return Float is
     (Array_Reduce (Fn => "+")
        (0.0, Float_Array'
          (for in in 1 .. Num_Terms =>
            (-1.0) ** (I - 1) * X ** (2 * I - 1) / Float (Fact(2 * I - 1)))));

Here, the only generic actual we have to specify is \`Fn`, because:

-  All array type parameters are infered from the ``Self`` actual
   parameter. ``Self`` allows us to deduce the type of the
   ``Array_Type`` generic formal, and from this we can deduce the
   ``Index_Type`` and ``Element_Type``.
-  The ``Accum`` type can be deduced either from the value of ``Init``,
   or from the expected target type of the function call. In this case,
   since ``0.0`` is an universal real, we deduce ``Accum`` from the
   expected type of the function call, which is the return type of the
   ``Sin`` function.

Last step: anonymous subprograms
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

A last feature that will allow us complete freedom to express parallel
features as libraries is anonymous subprograms.

An `anonymous subprogram
<https://en.wikipedia.org/wiki/Anonymous_function>`_, which is a very common
construct in modern programming languages, allows you to inline the
declaration of a subprogram inside of an expression. Using anonymous
functions, we can express more complex reductions, which need a custom
function, without having to previously declare that function, such as in the
following example:

.. code:: ada

     function Max_Length_String (Strings : String_Vector) return Positive
     is
       (Reduce
         (function (L, R : String) is (Positive'Max (L'Length, R'Length)))
         (Strings));

Further, using anonymous subprograms, we can express any parallel construct
(parallel blocks or loops) in a pretty expressive way, where the example
written in the rationale is made possible:

.. code:: ada

     A, B, C : Int_Array;

     Parallel (A'Range, Scheduling'(Guided, 4)) (
        procedure (I)
           A (I) := B (I) + C (I);
        end
     );

But also parallel block code, such as the following example, adapted from the
parallel ARG AI.

.. code:: ada

   function Search (S : String; Char : Character) return Boolean is
      Res : Boolean;
   begin
      if S'Length <= 1000 then
          -- Sequential scan
          return (for some C of S => C = Char);
      else
          -- Parallel divide and conquer
          declare
            Mid : constant Positive := S'First + S'Length/2 - 1;
          begin
            Parallel_Do ((
              procedure Res := Search (S (S'First .. Mid), Char) end;
              procedure Res := Search (S (Mid + 1 .. S'Last), Char) end;
            ));
            return Res;
          end;
      end if;
   end Search;

Reference-level explanation
---------------------------

Since this RFC is more of a meta-RFC, the reference level explanation is
contained in the other referenced RFCs, namely [list of RFCS]

Rationale
---------

The rationale, as explained above, is to avoid introducing magic
behavior for what we believe is a corner case (Reduce/Parallel_Reduce),
instead generally improving the language to make it more expressive.

The improvements proposed in this group of RFCS would allow for example.

Other useful container utilities
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If you can implement and call reduce, you can implement and use easily
other very useful container functions, such as ``map``/``filter``/etc..

.. code:: ada

   generic
      type Index_Type is (<>);
      type El_Type is private;
      type Array_Type is array (Index_Type range <>) of El_Type;

      type Out_Index_Type is (<>);
      type Out_El_Type is private;
      type Out_Array_Type is array (Out_Index_Type range <>) of Out_El_Type;
   function Map
     (In_Array  : Array_Type;
      Transform : access function (El : El_Type) return Out_El_Type)
     return Out_Array_Type;

This function is a bit tedious to declare, but more importantly, it is
tedious to use in today’s Ada, making it kind of counter productive.

With the proposed improvements, and imagining we have a corresponding
Filter function, you could easily write code such as the following:

.. code:: ada

   with Ada.Character.Handling; use Ada.Character.Handling;
   with Ada.Text_IO; use Ada.Text_IO;

   procedure Main is
       S : String := "what is that";
   begin
       --  Prints "WHATISTHAT"
       Put_Line (Map (Filter (S, function (C) is (C in 'a' .. 'z')), To_Upper));
   end Main;

Existing library functions
~~~~~~~~~~~~~~~~~~~~~~~~~~

Some library functions, such as ``Unchecked_Deallocation``, are made
much easier to use by the introduced changes. You could call unchecked
deallocation with fully implicit generic formals in most cases:

.. code:: ada

   with Ada.Unchecked_Deallocation; use Ada;

   procedure Main is
       type A is access all Integer;
       Inst : A := new Integer'(12);
   begin
       Unchecked_Deallocation (Inst);
   end Main;

.. code:: ada

   function Sin (X : Float; Num_Terms : Positive := 5) return Float is
       Terms : Float_Array :=
         (for in in 1 .. Num_Terms =>
          (-1.0) ** (I - 1) * X ** (2 * I - 1) / Float (Fact(2 * I - 1)))
   begin
       Array_Reduce (Fn => "+") (0.0, Terms);
   end Sin;

While this could seem as a counter argument to the whole implicit
instantiation thing, in practice, in big codebases using dynamic memory
management, you often see things like this (extracted from GPS):

.. code:: ada

      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
         ( Entity_DDR, Entity_Data);
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
         ( Entity_Message_DDR, Entity_Message_Data);
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
         ( Message_DDR, Message_Data);
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
         ( Message_Property_DDR, Message_Property_Data);
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
         ( Property_DDR, Property_Data);
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
         ( Resource_DDR, Resource_Data);
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
         ( Resource_Message_DDR, Resource_Message_Data);
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
         ( Resource_Tree_DDR, Resource_Tree_Data);
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
         ( Rule_DDR, Rule_Data);
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
         ( Tool_DDR, Tool_Data);
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
        (Detached_Entity'Class, Detached_Entity_Access);
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
        (Detached_Message'Class, Detached_Message_Access);
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
        (Detached_Property'Class, Detached_Property_Access);
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
        (Detached_Resource'Class, Detached_Resource_Access);
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
        (Detached_Rule'Class, Detached_Rule_Access);
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
        (Detached_Tool'Class, Detached_Tool_Access);

Where every instantiation is then used only once. Being able to avoid
such unnecessary boilerplate seems like a worthy enough goal.

Subprograms taking subprograms as arguments
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The runtime already contains ``Iterate`` procedures, that takes callbacks as
arguments. In the same spirit as for parallelism, the ARG has `proposed a
special case syntax
<http://www.ada-auth.org/cgi-bin/cvsweb.cgi/ai12s/ai12-0187-1.txt?rev=1.14&raw=N>`_
to allow a simpler use of those procedures, as in the example below:

.. code:: ada
   declare
      Found : Boolean := False;
   begin
      for (Name, Val) of Ada.Environment_Variables.Iterate loop
         if Name = "good" then
            Found := True;
            exit;
         elsif Name = "bad" then
            raise Very_Bad_News;
         end if;
      end loop;
   end;

This is another case where specific syntax and semantics could be avoided,
avoiding more implementation work. Instead we could use the form with an
anonymous procedure:

.. code:: ada

   declare
      Found : Boolean := False;
   begin
      Ada.Environment_Variables.Iterate (procedure (Name, Val)
         if Name = "good" then
            Found := True;
         elsif Name = "bad" then
            raise Very_Bad_News;
         end if;
      end);
   end;

The above has also the added advantage of not hiding implementation to the
user: Here we know that a callback is being called. In the for-loop body
procedure case, the `exit` statement in the loop is meant to be implemented as
a special case "uncatchable by users" exception (see Implementation note in the
above document). Not even going into the problems this might cause for compiler
implementors, this also hides that on platforms using the "zero-cost" exception
model, exiting from a loop will be much more costly than exiting from a normal
loop.

With the transparent semantics described above, the user can still exit the
procedure, *explicitly* via an exception. If we decide that exiting early is
important, we can add overloads in the standard library to every `Iterate` that
takes a procedure, which will instead take a function returning an exit status.
There will be no hidden cost, and the semantics will stay transparent.
