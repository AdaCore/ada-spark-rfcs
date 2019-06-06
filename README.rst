Project
=======

This platform is a hub through which evolutions of the SPARK & Ada languages
will be discussed, as implemented in AdaCore’s `GNAT toolchain
<https://www.adacore.com/community>`_.

The aims of this platform are:

- To give visibility on the design process of new features through a modern
  platform where users can give feedback on the desirability of a feature.

- To give an opportunity to people to propose new features/improvements and
  fixes where they can have a direct connection with AdaCore’s language design
  team.

This platform is centered around *language* changes rather than toolchain
improvements.

It is recommended to refer to the following resources for the current
definition of Ada and SPARK languages:

- `currrent Ada Reference Manual (Ada 2012)
  <http://www.ada-auth.org/standards/rm12_w_tc1/html/RM-TOC.html>`_
- `draft Ada Reference Manual for next version (Ada 202X)
  <http://www.ada-auth.org/standards/2xrm/html/RM-TTL.html>`_
- `current SPARK Reference Manual
  <http://docs.adacore.com/spark2014-docs/html/lrm/>`_

There is no guarantee that changes discussed and eventually prototyped &
implemented will ever make it into the Ada standard, even though AdaCore will
do its best to collaborate with the `Ada Rapporteur Group (ARG)
<http://www.ada-auth.org/arg.html>`_.

AdaCore will commit to discuss changes that it plans on this platform, so that
users can give and get feedback on RFCs. It will also make it possible for
people from the community to propose and discuss potential features and
improvements.

The process
===========

Before creating an RFC
----------------------

Any language change can have potentially large effects on other parts of the
language. There are several questions that need to be discussed for any new
feature:

- What problem does the proposed change address?

- Is it a desirable change or not?

- How does it interact with other features?

- Does it fit the general philosophy of the language?

It follows that a possible first step before creating an RFC is to create an
issue to informally discuss the feature, and gather different levels of
feedback. The less certain you are about the feature, both in terms of
desirability and in terms of maturity, the more this step should be favored.

Creating an RFC
---------------

The process to add a feature to the language starts by submitting an RFC into the
RFC repository as a RST file. At that point the RFC is considered alive. It
does not necessarily mean that it will get implemented, but that it is amongst
those that are considered for addition.

Here is the process to get an RFC into alive state:

- Fork this repository.

- Copy ``rfc-template.rst`` to ``considered/rfc-my-feature.rst`` (where
  ``my-feature`` is descriptive).

- Fill in the RFC. This part of the process is the most important. RFCs that do
  not present convincing arguments, demonstrate impact of the design on the
  rest of the language, will have less chances of being considered. Don’t
  hesitate to get help from people sharing your mindset about a feature.

- Submit a pull request, with the title: ``[RFC]: <name of your rfc>``.
  As a pull request the RFC will receive design feedback from AdaCore’s
  language design team, and from the larger community, and the author
  should be prepared to revise it in response.

At this stage, expect several iterations between discussions, consensus
building, and clarifications.

A simple way for others to signal support for a proposal is to add a +1
reaction ("thumb up") to the corresponding Pull Request.

At some point, a member of the AdaCore language design team will make a
decision about the future of the RFC, which can be either accept, reject, or
postpone.

- A rejected RFC’s pull request will simply be closed.

- An accepted RFC’s pull request will be merged.

- A postponed RFC’s pull request will be labeled as "postponed".

What happens afterwards
-----------------------

- After an RFC has been merged in the ``considered`` folder, it will be
  considered for prototyping by relevant engineers at AdaCore.

  * Note that, if as a member of the community you want to try your hand at
    implementing a feature in GNAT, you can propose a patch against `GNAT’s
    FSF repository <https://www.gnu.org/software/gnat/>`_, which will then be
    considered for merging into AdaCore’s GNAT Pro compiler. For SPARK,
    `AdaCore’s SPARK GitHub repository
    <https://github.com/AdaCore/spark2014>`_ is the reference implementation.

- When a prototype has been implemented by one means or another, the RFC will be
  re-considered, and a pull request moving the RFC from the ``considered`` folder
  to the ``prototyped`` folder. Any facts/drawbacks/additional work discovered
  during prototyping, as well as an evaluation of the feature will be conducted
  on the PR. The feature will be made available through the ``-gnatX`` flag so
  that people from the community can play with it and give feedback too.

- Finally, a member of the AdaCore team will give a final decision about the
  RFC’s inclusion in GNAT, and potential submission to the ARG if necessary.

Credits
-------

Most of the content of this document was inspired by the `RFC process from the
Rust community <https://github.com/rust-lang/rfcs>`_.
