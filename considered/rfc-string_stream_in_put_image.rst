- Feature Name: rfc-string_stream_in_put_image
- Start Date: 2019-06-12
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

Usage Root_Stream_Type in Put_Image is error prone, too low level
and nonportable.

Motivation
==========

AI12-0020-1 introduces support for user defined Image attributes.
This is defined in terms of a procedure T'Put_Image, an
attribute with the specification

.. code::

   procedure T'Put_Image
       (Arg : T; Stream : not null access Ada.Streams.Root_Stream_Type'Class);

The user should convert its type to Stream_Element stream. But compiler/run-time
 then reads the stream into a Wide_Wide_String.

This is error prone, too low level and nonportable.

This is error prone because the user is able to write anything into the stream
instead of Wide_Wide_String and the compiler won't be able to report an error
statically. For instance:

.. code::

   procedure Put_Image
     (Arg    : Point;
      Stream : access Ada.Streams.Root_Stream_Type'Class) is
   begin
      String'Write (Arg.X, Stream);
      Wide_String'Write (Arg.Y, Stream);
      Real'Write (Arg.Z, Stream);
      Unbounded_String'Write (Arg.Comment, Stream);
   end;

This is too low level in the same way as proposal to use Stream_Element instead of
Character and Stream_Element_Array instead of String, Wide_String and Wide_Wide_String.

This is nonportable because encoding of text differs on platforms. For example,
if user wants to control string layout it should insert end of line characters
into the stream. But Windows uses CR/LF for this and others OS uses LF or even
other bytes for this. So result code is unportable

.. code::

   procedure Put_Image
     (Arg    : Point;
      Stream : access Ada.Streams.Root_Stream_Type'Class) is
   begin
      Wide_Wide_String'Write (Arg.X, Stream);
      --  Insert new line here:
      Wide_Wide_Character (Wide_Wide_Latin_1.LF, Stream);
      Wide_Wide_String'Write (Arg.Y, Stream);
   end;

Instead new string stream should be defined and used in Put_Image specification.

.. code::

   type Output_Text_Stream is limited interface;

   not overriding procedure Put
    (Self : in out Output_Text_Stream;
     Item : Wide_Wide_String) is abstract;

   not overriding procedure New_Line
    (Self : in out Output_Text_Stream) is abstract;

   procedure T'Put_Image
       (Arg : T; Stream : not null access Output_Text_Stream'Class);

Guide-level explanation
=======================

Introduce new package and type for text streams

.. code::

   package Ada.Streams.Text_Streams is
      type Output_Text_Stream is limited interface;

      not overriding procedure Put
       (Self : in out Output_Text_Stream;
        Item : Wide_Wide_String) is abstract;

      not overriding procedure New_Line
       (Self : in out Output_Text_Stream) is abstract;

   end Ada.Streams.Text_Streams;

Change definition of 'Put_Image to

.. code::

   procedure T'Put_Image
    (Value  : T;
     Stream : not null access
       Ada.Streams.Text_Streams.Output_Text_Stream'Class);


Reference-level explanation
===========================

Run-time will provide an implementation of Output_Text_Stream that
uses correct encoding of characters for given platform.

Perhaps Input_Text_Stream should be defined to let runtime read
Output_Text_Stream during conversion to String/Wide_Wtring/Wide_Wide_String.

.. code::

   type Input_Text_Stream is limited interface;

   not overriding function Get_Line
    (Self : in out Input_Text_Stream)
      return Wide_Wide_String is abstract;

   not overriding function End_Of_Stream
    (Self : in out Input_Text_Stream)
      return Boolean is abstract;

Conversion routine will then read lines from Input_Text_Stream using
Get_Line concatinate them with correct end-of-line separator
until End_Of_Stream.


Rationale and alternatives
==========================

This way compiler will be able to detect described error in user
provided Put_Image routines at compile time. User will have
better understanding how Put_Image should work.

This meets the general philosophy of the languages of safe and
secure programming.

Drawbacks
=========

This could be a little more complicated in implementations then
original proposal, but we feel that the added safety is worth it.


Prior art
=========

Java has Writer_ abstract class whith similar purposes.

.. _Writer https://docs.oracle.com/javase/8/docs/api/java/io/Writer.html


Unresolved questions
====================

- Shall Ada run-time provide Input_Text_Stream interface explicitly?
- Shall Ada run-time provide concrete implementation of
  Output_Text_Stream/Input_Text_Stream pipe explicitly?

Future possibilities
====================

I cannot think of anything of  any future possibilities.

