- Feature Name: sensitive_aspect_for_security_and_SPARK
- Start Date: 2019-06-27
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)


Summary
=======

In security development, one good practice asks to avoid sensitive data remaining
accessible when they are no longueur needed (as they may be used for an attack).
This is generally called in short: sanitization.
Here sensitive data may be whatever the programmer defines
(keys, unencrypted data, passwords, etc).

We propose to add the new aspect Sensitive to an Ada object that needs to be
sanitized:
::
  My_Key : Key_Type := Get_Key with Sensitive; -- will be sanitized
  KLen : constant Positive := Get_Len with Sensitive; -- even constants are concerned
or to a type whom objects of that type need to be sanitized:
::
  type Key_Type is array (Positive range <>) of Byte with Sensitive;
  My_Key : Key_Type := Get_Key; -- will be sanitized

Sanitization occurs when the concerned object is at the end of scope.
That is for instance at the end of a procedure for a local object or when freeing
a dynamic object.

This aspect works together with the pragma Sanitize_Policy (and possibly a compiler
switch) which defines the action taken when sensitive value isn't more used:

- Ignore: do nothing
- Numerical value: value used to cleanup the sensitive objects
(like a pattern of bits which is consumed or repeated as needed by the size of the
sensitive value)

Reference:
https://www.auto.tuwien.ac.at/~blieb/AE2017/presentations/ae2017_chapman.pdf


Motivation
==========

In order to achieve the sanitization goal, Ada is not so helpful and SPARK complains,
for instance if we use current Ada:
::
    procedure Sensitive_Data_Process is
      My_Key : Key_Type := Get_Key;
    begin
    -- Do something with My_Key
    ...
    My_Key := Invalid_Key;
    end;

a) On the Ada side a constant or function Invalid_Key has to be
declared. A simple value or aggregate value is not always possible or suitable
with complex tagged private types for instance.

b) Programmers may forget to sanitize, so strong peer reviews have to be set on every uses.
Whereas a validated compiler will do the job everywhere.

c) Assignation is not possible with limited types.
A dedicated procedure may be declared for user defined limited types:
procedure Sanitize (V : out Key_type);
But it is not possible with library limited types where nothing is provided.

d) On SPARK side, the message "warning: unused assignment" is issued by gnatprove.
This can be silenced by a warning off which has to be added everywhere it is needed.
Whereas the aspect Sensitive will have the effect to avoid this message.

e) The assigned value has to be valid whereas we might want to put an arbitrary value.

f) The assignation may be removed by compiler optimizations.


Guide-level explanation
=======================

In order to be in conformity with “Secure coding” standards, the aspect Sensitive
on a variable give the assurance that the content of this variable
will be swept out by an arbitrary value at the end of its life.
No need for hand defined assignments or calls to dedicated procedures.
Just apply aspect Sensitive to the concerned variables in the program and defined
the arbitrary value with the pragma Sanitize_Policy.
The pragma Sanitize_Policy has two possibilities: Ignore (nothing is cleaned) and a
numerical value (the cleaning value).
The aspect is also suitable for types, thus all variables declared with these types
will be sanitized.

Example 1:
::
    procedure Sensitive_Data_Process is
      pragma Sanitize_Policy (16#55AA#);
      My_Key : Key_Type := Get_Key with Sensitive;
    begin
    -- Do something with My_Key
    ...
    end; -- My_Key is cleaned with specified value

Example 2:
::
    package Sensitive_Definition is
      pragma Sanitize_Policy (16#55AA#);
      type Key_Type is array (Positive range <>) of Byte with Sensitive;
      function Get_Key return Key_Type is (...);
    end;
    with Sensitive_Definition;
    procedure Sensitive_Data_Process is
      My_Key : constant Sensitive_Definition.Key_Type := Sensitive_Definition.Get_Key;
    begin
    -- Do something with My_Key
    ...
    end; -- My_Key is cleaned with specified value

Example 3:
::
    package Sensitive_Definition is
      type Key_Type is limited private;
      procedure Get_Key (Key : out Key_Type);
    private
      pragma Sanitize_Policy (16#55AA#);
      type Sensitive_Data is record
        A : Integer;
        B : Character;
        end record with Sensitive
      type Key_Type is record
        N : String (1..8);
        V : Sensitive_Data;
        end record;
    end;
    with Sensitive_Definition;
    procedure Sensitive_Data_Process is
      My_Key : Sensitive_Definition.Key_Type;
    begin
    Sensitive_Definition.Get_Key (My_Key);
    -- Do something with My_Key
    ...
    end; -- My_Key is cleaned (fields A and B) with specified value

Example 4:
::
    package Sensitive_Definition is
      pragma Sanitize_Policy (16#55AA#);
      type Key_Type is array (Positive range <>) of Byte with Sensitive;
    end;
    with Sensitive_Definition;
    procedure Sensitive_Data_Process (Key : in Sensitive_Definition.Key_Type) is
    begin
    -- Do something with Key
    ...
    end; -- Key is cleaned with specified value


Reference-level explanation
===========================

Sensitive aspect is given on objects in order to sanitize theses objects and types to sanitize
the objects of these types.

Sanitization occurs when the concerned objects are at the end of their scope.
That is for instance at the end of a procedure for a local object, when freeing
memory for a dynamic object or the end of program for global object.

The default value for the sanitization value is 0;

The sanitization value is a numerical value considered as a pattern of bits which
is consumed or repeated as needed by the size of the sensitive value.

When applied on types the aspect Sensitive is propagated to outer types referring to these
types like limited types does. When the object of outer type is at the end of scope then the inner object
is sanitized. See example 3.

The sanitizing action takes place when the sensitive value is no more used, for instance:

- At subprogram end for local objects including "in" parameters,
- When dealocating memory for dynamic object,
- When exiting the program for global variables or global constants.

Sanitization occurs after all other finalize actions from controlled types.

Actually the value itself from sensitive object is sensitive and also all plain
copies in central memory, cache memory, registers... shall also be sanitized.
Thus it implies No_Caching aspect (see rfc-local-volatile-for-security-in-SPARK.rst).
On sensitive objects the compiler should minimize copies in order to minimize sanitizing.


Rationale and alternatives
==========================

Sensitive objects could be considered by the compiler implementer as they are of type
controlled with a finalize action which clean up the object with the specified value.

Alternatives may be:
a) controlled types, but:

- it must be a valid value.
- SPARK compatibility is not yet available.
- it is not automatic see above point b).

b) erasing all stack, but:

- it is not effective on dynamically allocated object.


Drawbacks
=========

The compiler modifications effort may be quite consequent but it will be
hugely appreciated by programmers and assessors for security certifications.


Prior art
=========

Lot of prior works are hand made custom solutions.


Unresolved questions
====================

What is going on with operating system paging and virtual memory?


Future possibilities
====================

Add more parameters for Sanitize_Policy :

- Number of cleaning passes with corresponding array of cleaning values
- Check: optional parameter to check the cleaning value on each pass, raise Sanitize_Error if fail

Add a compiler warning if a part of a sensitive object is transfered to a non sensitive object.

Apply the aspect to subprograms, that is all local objects and "in" parameters are sanitized
at the end of the subprogram.
