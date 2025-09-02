Project
=======

This platform is a hub through which evolutions of the SPARK & Ada languages
will be discussed, as implemented in AdaCore’s [GNAT
toolchain](https://www.adacore.com/community).

The aims of this platform are:

- To give visibility on the design process of new features through a modern
  platform where users can give feedback on the desirability of a feature.

- To give an opportunity to people to propose new features/improvements and
  fixes where they can have a direct connection with AdaCore’s language design
  team.

The platform is centered around *language* changes rather than toolchain
improvements.

It is recommended to consult the following resources for the current
definition of Ada and SPARK languages before submitting a proposal for a language change:

- The current [Ada Reference Manual (Ada 2012)](http://www.ada-auth.org/standards/rm12_w_tc1/html/RM-TOC.html)
- Draft [Ada Reference Manual for next version (Ada 202X)](http://www.ada-auth.org/standards/2xrm/html/RM-TTL.html)
- The current [SPARK Reference Manual](http://docs.adacore.com/spark2014-docs/html/lrm/)

There is no guarantee that changes discussed and eventually prototyped &
implemented will ever make it into the Ada standard, even though AdaCore will
do its best to collaborate with the [Ada Rapporteur Group
(ARG)](http://www.ada-auth.org/arg.html).

AdaCore will commit to discuss changes that it plans on this platform, so that
users can give and get feedback on RFCs. It will also make it possible for
people from the community to propose and discuss potential features and
improvements.

Organisation
------------

NB! Note that there is a change in the process introduced in August 2025. Earlier the RFC process was centered around a single pull request. This made it difficult to keep track of the state of the proposal and distinguish major decisions form small improvements. The new process relies on issues instead and promotes short-lived pull requests with concrete target.

RFCs are submitted to review as issues summarizing the intent and keeping the state of the proposal. There are two kind of RFCs:

* High-level RFCs: Those RFCs concern a high level area where we want to make
  changes, and how. They should include at least two regular RFCs. The high-level RFC's are stored in the folder named `meta`.

* Regular RFCs: Those RFCs explain how a single change to the language will be
  made. They might (or might not) be part of a high level RFC. Regular RFC's shall be sumbitted to the folder `features`.

Once a RFC is reviewed, it will be either abandoned or merged. When it's
merged, high-level RFCs will go in the `meta` folder, and regular ones will
first go in `considered`, and then, eventually, when prototyped in GNAT, in the
`prototyped` folder.

The process
===========

Lifecycle of a RFC
----------------------

A RFC may be in one of the following states:

* Proposed – a proposal from the initiator, waiting for go-ahead; 
* Rejected – the discussions around the proposal concluded that the RFC will not be processed further;
* Planning – the proposal has been considered interesting enough, and it has been selected for detailed design work. If the RFC wasn't created before the date in issue, it shall be propagated to a pull request at this stage;
* Design – there is a team allocated to work on the refinement of the RFC;
* Ready for prototyping – the RFC is mature enough to start with the compiler support prototype;
* Implementation – working on the tool support;
* Production – the planned tool support is implemented.

The status of a RFC is made visible in the issue tracking the RFC discussions and in the recorded RFC document. It is assumed that pull requests are closed each time before changing the issue status.

### Proposed: submitting the initial proposal

The person initiating a language change shall start by creating an issue in the ada-spark-rfcs repository. If the proposal is detailed enough then it can be followed immediately by a pull request that is prepared according to the RFC template. However, for deciding if the proposal is likely to be worth the effort of detailed design work, an issue is normally enough.

There are several questions that need to be discussed for any new feature. The initiator shall make sure that the initial proposal presents her/his viewpoint to those topics:

- What problem does the proposed change address?

- Is it a desirable change or not?

- How does it interact with other features?

- Does it fit the general philosophy of the language?

### Rejected/planning: the initial assessment

The LD team will decide on a case-by-case basis whether the proposal has promise and whether we should proceed with the rest of the process or abandon it at this stage. This process may involve extensive discussions between the interested parties, recorded on the issue. As a result, the RFC is either marked as `Planning` (i.e., it will eventually be taken further) or `Rejected`. In either case, the proposal details present on the issue shall be populated to the RFC document. When the status is `Planned` the document shall be committed in `meta` or `features` according to their type. The `Rejected` RFC's are moved to `attic`.

### Design: refining the feature description

In this phase, the AdaCore LD team (or a dedicated task force) is refining the proposal. The feature discussions shall be organized around the ada-spark-rfcs issue created at the beginning of the process—either as comments to the issue itself or as pull requests proposing concrete changes. A feature can be analysed on its own or in a group of related features.

To declare the design phase output sufficient for prototyping at least the following sections must be filled:

* Summary
* Motivation
* Guide-level explanation
* Reference-level explanation
* Rationale and alternatives
* Drawbacks
* Compatibility

The compatibility sections shall clearly state whether the change is backward compatible or not, and suggest whether it should be part of the default feature set or available under a special switch.

### Ready for prototyping: the green light for implementation

Once the specification is deemed to be complete enough to start tooling design and implementation the LD team shall mark it as Ready for prototyping. This doesn’t necessarily mean that the design is completely finished. However, the LD team must be confident that the available information is sufficient for the initial analysis of compiler support. All known remaining open questions shall be listed in the Open questions section of the RFC.

### Implementation: parallel work by the affected teams

A prototype will then be implemented by the affected teams. The work normally start from the language frontends, followed by the other tools.

The feature will first and always be added to the `Experimental` subset of language extensions the `-gnatX0` flag).

The goal is after stabilization of tests (notably the cross tool language testsuite), for it to go either in the Flare or backwards compatible set of features.

After stabilization of the tests, the feature will move either to the Flare subset or the backwards-compatible set of language features. The final documentation of the feature shall appear in [GNAT Reference Manual](https://docs.adacore.com/gnat_rm-docs/html/gnat_rm/gnat_rm/gnat_language_extensions.html).

### Production: Tool support ready
The feature is marked in state `Production` after all the required tool support has been implemented and the feature is documented in the reference manual. While changing the state of the RFC, one must add a disclaimer after the metadata block at the top of the document:

*The final documentation of this feature can be found in \<RM reference\>. The descriptions in “Guide-level explanation” and “Referece-level explanation” may not be fully up to date.*

Technical guidance
===================

Creating an RFC
---------------

Here is the process to get an RFC into alive state:

- Browse the file [rfc-template.md](https://github.com/AdaCore/ada-spark-rfcs/blob/master/rfc-template.md)

- Edit this file, using the pen next to the `Raw` and `Blame` buttons.

- On the editing page, rename `rfc-template.md` to something descriptive such
  as `features/<feature-id>.md`. Make sure to put the
  resulting file in the directory that corresponds to its type (`meta` or `features`).

- Fill in the RFC. This part of the process is the most important. RFCs that do
  not present convincing arguments, demonstrate impact of the design on the
  rest of the language, will have less chances of being considered. Don’t
  hesitate to get help from people sharing your mindset about a feature.

  For help on the GitHub-flavored Markdown syntax, see [this quick-start
  guide](https://guides.github.com/features/mastering-markdown/) or this [more
  advanced
  guide](https://help.github.com/en/github/writing-on-github/basic-writing-and-formatting-syntax)

- Name your commit `[RFC]: <name of your rfc>`, and then validate the creation
  of the commit itself. We suggest you use a meaningful name for the branch,
  but this is optional.

- On the next page, GitHub will automate the creation of the Pull Request.
  Just hit `Create pull request`.

As a pull request the RFC will receive design feedback from AdaCore’s
language design team, and from the larger community, and the author
should be prepared to revise it in response. Expect several iterations
between discussions, consensus building, and clarifications.

Supporting an RFC/providing feedback
------------------------------------

As a community member, you are encouraged to provide support/feedback on
existing RFCs.

If you have remarks/comments on an RFC, you can simply comment on the
issue proposing the RFC or submit a pull request with the changes that you propose.

If you want simply to signal support for a proposal, you should add a +1
reaction ("thumb up") to the corresponding issue.

Submitting your own implementation
-----------------------------------

As a member of the community you may want to go further than just recommending a
language feature. If can propose a patch in the [GNAT’s FSF repository](https://www.gnu.org/software/gnat/) with the compiler modification, which will then be
considered for merging into AdaCore’s GNAT Pro compiler.
For SPARK, [AdaCore’s SPARK GitHub repository](https://github.com/AdaCore/spark2014)
is the reference implementation.
