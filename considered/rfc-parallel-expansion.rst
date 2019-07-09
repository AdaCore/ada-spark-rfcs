- Feature Name: Proposed expansion of Ada 202X parallel for-loop
- Start Date: 2019-07-09
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

This RFC is documenting a possible expansion of the Ada 202X parallel for-loop feature

Motivation
==========

The goal is to document a proposed simple expansion of the parallel for-loop syntax first into a pragma, 
and from there into a call on an Ada library routine which could be provided by a third party or the user.

Guide-level explanation
=======================

This is not proposing a new feature per se, but rather a possible new default
expansion of the existing Ada 202X proposed parallel for-loop features.
We show a pragma-based loop as an intermediate point in the expansion.  

For the initial prototype we would start from something like::

   pragma Par_Loop(Num_Chunks);
   for I in A'Range loop
       A(I) := A(I) * 2 + 1;
   end loop;

and expand it into the declaration of a local procedure that iterates over a subrange, 
and a call on a procedure declared in the Ada.Parallelism package.

Any calls on the intrinsic Chunk_Index function that appear in the <loop body> would be 
replaced by references to the Chunk_Index parameter passed to the Loop_Body procedure.


Reference-level explanation
===========================

Expansions for Ada 202X parallel loop: 

We go through an intermediate step of a pragma Par_Loop so that parallel loops 
can be used while remaining compilable by older Ada compilers, analogous to the 
way the "Pre" aspect expands into pragma Precondition.  

The value of the chunk index may be referenced when inside the body of a parallel 
loop by calling the intrinsic parameterless function Ada.Parallelism.Chunk_Index, 
which will always return 1 in a version of the Ada.Parallelism package for use 
with pre-Ada-202X implementations.  If there is an explicit "chunk parameter" 
in the chunk specification, references to the chunk parameter will be replaced by 
a computation based on the result of a call to this intrinsic Chunk_Index function.

General expansion::

   parallel (Num_Chunks)
   for ... loop
      <loop body>
   end loop;

expands into::

   pragma Par_Loop(Num_Chunks);
   for ... loop
      <loop body>
   end loop;

which expands further according to the kind of for-loop immediately following the pragma Par_Loop:

Parallel loop over a range of values::

   pragma Par_Loop(Num_Chunks);
   for I in S range A..B loop
      <loop body>
   end loop;

expands into::

  declare
    procedure I__Loop_Body 
      (I__Low, I__High : Longest_Integer; I__Chunk_Index : Positive) is
    begin
        for I in S'Val (I__Low) .. S'Val (I__High) loop
            <loop body>
        end loop;
    end I__Loop_Body;
  begin
    Ada.Parallelism.Par_Range_Loop
       (S'Pos(A), S'Pos(B), Num_Chunks, I__Loop_Body'Access);
  end;

Parallel loop over an array::

   pragma Par_Loop(Num_Chunks);
   for C of Arr loop
      <loop body>
   end loop;

expands into::

   pragma Par_Loop(Num_Chunks);
   for C__Index in Arr'Range loop
      declare
         C renames Arr(C__Index);
      begin
         <loop body>
      end;
   end loop;

which then expands according to expansion (1) above for a loop over a range.  Note that a loop over a multidimensional array would be transformed effectively into a loop over a conceptually flattened array, as is done in the sequential loop case.

Parallel loop over a generalized iterator::

   pragma Par_Loop(Num_Chunks);
   for C of Iterator loop
      <loop body>
   end loop;

expands into::

   declare
      package Inst renames <some instantiation of Ada.Iterator_Interfaces>;
      package Par_Iterator_Inst is new Ada.Parallelism.Par_Iterator_Loop(Inst);

      procedure C__Loop_Body
        (C__Iterator : Inst.Parallel_Iterator'Class; C__Chunk_Index : Positive) is
          C : Inst.Cursor := C__Iterator.First (C__Chunk_Index);
      begin
          while Has_Element(C) loop
              <loop body>
              C := C__Iterator.Next (C, C__Chunk_Index);
          end loop;
       end C__Loop_Body;

   begin
       Par_Iterator_Inst(Iterator, Num_Chunks, C__Loop_Body'Access);
   end;

Parallel loop over a container::

   pragma Par_Loop(Num_Chunks);
   for E of Container loop
       <loop body>
   end loop;

expands into::

   pragma Par_Loop(Num_Chunks);
   for E__Cursor of Container'Default_Iterator(Container) loop
      declare
         E renames Container(E__Cursor);
      begin
         <loop body>
      end;
   end loop;

which then expands according to (3) above for a loop over an iterator.

Ada.Parallelism package

The Ada.Parallelism package spec would contain (at least) the following::

 package Ada.Parallelism is
   type Longest_Integer is range System.Min_Int .. System.Max_Int;
      --  Not worrying about unsigned ranges with upper bound > System.Max_Int for now.
      --  Could be handled by having a version of Par_Range_Loop that operates on
      --  unsigned integers.

   procedure Par_Range_Loop 
     (Low, High : Longest_Integer;
      Num_Chunks : Positive;
      Loop_Body : access procedure
                      (Low, High : Longest_Integer; Chunk_Index : Positive));

   function Chunk_Index return Positive
      with Convention => Intrinsic;

   generic
       with package Inst is new Ada.Iterator_Interfaces(<>);
   procedure Par_Iterator_Loop
     (Iterator : Inst.Parallel_Iterator'Class;
      Num_Chunks : Positive;
      Loop_Body : access procedure
                     (Iterator : Inst.Parallel_Iterator'Class; Chunk_Index : Positive));
   --  NOTE: Depending on what is simpler for the compiler, we might want Par_Iterator_Loop to
   --        be a (generic) child of Ada.Interfaces rather than being a nested generic procedure
   --        with Ada.Interfaces as a formal package parameter.

 end Ada.Parallelism;

Rationale and alternatives
==========================

- This approach provides an easy way to turn a sequential loop into a parallel loop,
  without significant restructuring.
- The semantics are such that the loop may be run sequentially if parallelism is
  not supported, or if the Num_Chunks is specified as "1"
- We can choose whether to make the expansion part of the language standard, or
  merely a GNAT feature that we promise to retain, at least as an option.
- This nicely composes with all kinds of iterators, filters, etc. without requiring
  any other new language features.
- The Par_Iterator_Loop generic supports user-defined "spliterators" which are
  iterators that implement the Parallel_Iterator interface.

Drawbacks
=========

- This implies the addition of the "parallel" reserved word.

Prior art
=========

The notion of a parallel or concurrent loop is probably the most common
feature of any language supporting light-weight parallelism.  Some support for "chunking" and
"reductions" is also generally provided.  Cilk, OpenMP, HPF (High-Performance Fortran),
C++17 are examples of languages with a simple way of turning a sequential
loop into a parallel loop, analogous to what Ada 202X proposes.  OpenMP does
not specify the expansion, but it is beginning to standardize on an expansion
currently used by the "clang" OpenMP-supporting front end.

Future possibilities
====================

Versions of the Par_Range_Loop that take more parameters could be defined as we 
decide to support more tuning.  OpenMP and OpenACC can provide useful examples
here in terms of the number of tuning parameters/pragmas that make sense in
the context of a chunked parallel loop.  Par_Iterator_Loop might also make
use of more parameters in some contexts.
