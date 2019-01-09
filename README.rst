Project
=======

This platform is a hub through which evolutions of the SPARK & Ada languages
will be discussed. It is focused around AdaCore’s GNAT toolchain.

The aims of this platform are:

To give visibility on the design process of new features through a modern
platform where users can give feedback on the desirability of a feature.

To give an opportunity to people to propose new features/improvements and fixes
where they can have a direct connection with AdaCore’s language design team.

This platform is centered around *language* changes rather than toolchain
improvements.

There is no guarantee that changes discussed and eventually prototyped &
implemented will ever make it into the Ada standard, even though AdaCore will
do its best to collaborate with the Ada Rapporteur Group.

AdaCore will commit to discuss changes that it plans on this platform, so that
users can give feedback on RFCs. It will also make it eventually possible for
people from the community to propose and discuss potential features and
improvements.

The process
===========

Before creating an RFC
----------------------

Any language change can have potentially large effects on other parts of the
language. There are several questions that need to be discussed for any new
feature:

- Whether a change is desirable or not

- How it interacts with other features

- What purpose does it serve with regards to the general philosophy of the language

It follows that a possible first step before creating an RFC is to create an
issue to informally discuss the feature, and gather different levels of
feedback. The less certain you are about the feature, both in terms of
desirability and in terms of maturity, the more this step should be favored.

Creating an RFC
---------------

The process to add a feature to the language starts by merging an RFC into the
RFC repository as an RST file. At that point the RFC is considered alive. It
does not necessarily mean that it will get implemented, but that it is amongst
those that are considered for addition.

Here is the process to get an RFC into alive state:

- Fork the RFC repo

- Copy rfc-template.rst to considered/rfc-my-feature.rst (where "my-feature" is
  descriptive).

- Fill in the RFC. This part of the process is the most important. RFCs that do
  not present convincing arguments, demonstrate impact  of the design on the
  rest of the language, will have less chances of being considered. Don’t
  hesitate to get help from people sharing your mindset about a feature.

- Submit a pull request. As a pull request the RFC will receive design feedback
  from AdaCore’s language design team, and from the larger community, and the
  author should be prepared to revise it in response.

At this stage, expect several iterations between discussions, consensus
building, and clarifications.

At some point, a member of the AdaCore language design team will make a
decision about the future of the RFC, which can be either accept, reject, or
postpone.

- A rejected RFC’s pull request will simply be closed

- An accepted RFC’s pull request will be merged

- A postponed RFC’s pull request will be altered so that the RFC file is put in
  the postponed/rfc-my-feature.rst

What happens afterwards
-----------------------

- After an RFC has been merged in the considered folder, it will be considered
  for prototyping by relevant engineers at AdaCore.

    * Note that, if as a member of the community you want to try your hand at
      implementing a feature in GNAT, you can propose a patch against GNAT’s
      FSF repository, which will then be considered for merging into AdaCore’s
      GNAT Pro compiler. For SPARK, AdaCore’s SPARK GitHub repository is the
      reference implementation.

- When a prototype has been implemented by a mean or another, the RFC will be
  re-considered, and a pull request moving the rfc from the considered folder
  to the prototyped folder. Any facts/drawbacks/additional work discovered
  during prototyping, as well as an evaluation of the feature will be conducted
  on the PR. The feature will be made available through the -GNATXP flag so
  that people from the community can play with it and give feedback too.

- Finally, a member of the AdaCore team will give a final decision about the
  RFC’s inclusion in GNAT, and potential submission to the ARG if necessary.
