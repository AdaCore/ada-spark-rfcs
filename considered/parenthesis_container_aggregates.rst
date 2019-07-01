- Feature Name: parenthesis_container_aggregates
- Start Date: (2019-07-01)
- RFC PR:
- RFC Issue:

Summary
=======

AI12-0121 (http://www.ada-auth.org/cgi-bin/cvsweb.cgi/ai12s/ai12-0212-1.txt) provides a very powerful notation to create containers
aggregates, based on the introduction of a new syntactic notation, square brackets. This proposal is exploring an alternate notation while 
retaining the core of the functionality, using parentheses. This will provide a consistent notation through the rest of the language.
Something like:

.. code:: ada

 X : My_Container := [1, 2, 3];
  
Would be written:

.. code:: ada

 X : My_Container := (1, 2, 3);
  
It addresses and generalizes issues mentioned in the AI:

- It introduces a way to differentiate between record and container aggregates in case of ambiguity:

.. code:: ada

 type R is record 
  A, B, C : Integer;
 end record
 with <insert aggregate-related-aspects>;

 V1 : R := R’Container(1, 2, 3); -- is this a container aggregate
 V2 : R := R’Record(1, 2, 3); -- is this a record aggregate
 
- It introduces a notation for record, arrays and containers empty aggregates:

.. code:: ada

 V : R := (null R);
 
- It introduces a notation for record, arrays and containers singletons positional aggregates through qualification:

.. code:: ada
	
 X : R’(1);

Motivation
==========

The initial proposal solves a number of issues, but at the cost of a number of a number of consistency drawbacks:

- Arguably, introducing a new syntactic element, [], is a significant change in the language. It could be disputed that this 
  relatively significant change is for a very useful but very specific capability.
- It makes record aggregates look very different than container aggregates.
- The new notation [] is set to also be valid for arrays, which introduces situations where arrays may use one notation or the other 
  and have potential for confusing users.
- the solution proposed to singleton aggregate isn't available for record aggregates.

The idea of the current proposal is to re-introduce () for all aggregates, and to solve two issues (singletons and empty arrays) in a
way that can be similar between records, arrays and containers, further converging the syntax.

Guide-level explanation
=======================

Ada 202X introduces a new aggregate notation. From a user perspective, everything you already know for arrays is valid for containers.
There are a couple of relatively rare cases that you need to be aware of:

- Empty aggregate are now market (null <name of the type>). This notation works will all kinds of aggregates 
  (record, arrays, containers) and should be preferred.
- Positional singletons used to be illegal. They are now allowed if qualified after the type of the object. This notation works 
  will all kinds of aggregates  (record, arrays, containers).
- In case of visibility to the full view of a record which is also a container, the compiler will resolve ambiguities by the types,
  number and names of the components in the aggregate as it would do with usual subprogram overloading rules. If it’s not possible to 
  resolve the ambiguity, the user will need to qualify the aggregate to be either a record aggregate (<type>’Record) or a container 
  aggregate (<type>’Container).
  
The rest of the initial AI is unchanged.

Reference-level explanation
===========================

Through the language, all usage of squared brackets should be converted back to regular parenthesis.

Three issues have to be covered by this proposal. First, there’s the issue of the ambiguity when visibility is provided over the full 
view of a record which is also a container, e.g.:

.. code:: ada

 type R is record 
  A, B, C : Integer;
 end record
 with <insert aggregate-related-aspects>;
 
 V : R := (1, 2, 3); -- is this a record aggregate or a container aggregate?

The proposal is to consider the container aggregate as to be some kind of an overloaded notation of the record aggregate, and have 
verloaded resolution. In most cases, the types and number of arguments of the aggregate will allow to discriminate. For the rare cases 
where such discrimination is impossible, as for other kind of overloading, a qualification will be necessary. This proposal introduces
<Type>‘Container and <Type>’Record notations to allow to qualify:

.. code:: ada

 V1 : R := R’Container(1, 2, 3); -- is this a container aggregate
 V2 : R := R’Record(1, 2, 3); -- is this a record aggregate
 
Note that Record becomes both a reserved word and an attribute, which is already the case for some other reserved words in Ada.
The second problem is the empty container. This is also a problem that arrays have today. The proposal is to extend on the
(null record) notation and provide (null <type>) notation instead:

.. code:: ada

 V : R := (null R);

Or when calling subprogram, again similar to (null record) notation:

.. code:: ada

 P ((null R));
 
Although the double parentheses may look weird at first sight, this is consistent with the empty record notation.

Note that this also have advantages for record, as (null <type>) is a typed expression, as opposed to (null record) which is not, and 
may help when resolving overloading. 

The proposal is to extend this notation to record as well, so that only one notation for empty aggregate can be used no matter the type.

Last problem is the singleton problem. It is currently illegal to write a container with a single element in Ada, as it creates 
ambiguous situations:

.. code:: ada

 V : R := (1) -- illegal
 
Currently, this forces to use the naming convention instead, which would be impossible in the case of containers without named indexes
(Lists, sets…). This protects from cases like:

.. code:: ada

 procedure x (a : integer);
 procedure x (a : array_of_integer);
 x ((1)); -- is this an integer or an array of integer aggregate?
 
The proposal is to introduce a new notation, available for record, arrays and containers, qualifying after the type of the array:

.. code:: ada
	
 X (array_of_integer’(1));

The above case resolves any type issue.

Rationale and alternatives
==========================

The driving rational is to stay as close as possible to the language, and have as much as possible a concept (aggregate) similar in many
different situations, while solving problems through solutions already applied in other cases (qualification) which should be more 
natural to users already used to applying this in other cases of ambiguity.

An alternative to the ambiguity between the container and record notation is to consider that container notation overrides record 
notation instead of overloading it, and to offer some capability to go back to the initial notation:

.. code:: ada

 type R is record 
  A, B, C : Integer;
 end record
 with <insert aggregate-related-aspects>;
 
 V1 : R := (1, 2, 3); -- is this a container aggregate
 V2 : R := R’Base(1, 2, 3); -- is this a record aggregate
 
The reason why this is not in the main proposal is that a consequence may be for a developer to mistakenly use a container aggregate
instead of a record one, and it was preferred and safer to always report the ambiguity and ask for a solution. This is closer to other
cases in Ada where the language prefers not to compile rather than making a choice (see strong typing for example).

Singletons aggregates could have also provided an other form. One of the core issues is that there is no name in the first place for
some container. This could have introduced by specific notations:

.. code:: ada

 V : R := (all => 1)
 V : R := (<> => 1)
 
However, these read less clearly and it’s not obvious that they refer to a one element container. The proposed notation also have the 
advantage to apply to record.

Drawbacks
=========

The work at compiler level is more complex than on the initial proposal, in particular as overloading resolution needs to be computed.

Prior art
=========

Nothing specific for this section.

Unresolved questions
====================

Nothing specific for this section.

Future possibilities
====================

Going back to the singleton issue, there's an ambiguity with:

.. code:: ada

 procedure x (a : integer);
 procedure x (a : array_of_integer);
 x ((1)); -- is this an integer or an array of integer aggregate?
 
We could argue that this should be detected by Ada. The fact that this is calling X on Integer may be surpring and usafe, it would be
safer to detect the ambiguity and force qualification. Once ambiguity can be detected, positional aggregate could also be allowed when
there's no such ambiguity. However, we'd need to check wether this ambiguity detection is feasible through the language as such extra
optional parenthesis are typically allowed in many cases.


