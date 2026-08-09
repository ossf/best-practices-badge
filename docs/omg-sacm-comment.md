# Issue: ArgumentReasoning Connection to AssertedInference is Underspecified in SACM v2.3

**Specification**: OMG Structured Assurance Case Metamodel (SACM), v2.3
**Document**: OMG Formal/23-05-08, October 2023
**Sections affected**: §11.12, §11.13, §11.14, Annex C §C.7, §C.8
**Machine-readable source**: OMG ptc/22-03-014 (`SACM_profile.xml`, 2022-05-24)

## Summary

Any Annex C diagram showing `ArgumentReasoning` connected to an
`AssertedInference` dot is **underspecified** with respect to the normative
model.

Annex C of SACM v2.3 defines a graphical shape for `ArgumentReasoning` (§C.7,
Figure C13) and §C.8 describes `AssertedInference` diagrams in which sources
connect to the reification dot with undirected line segments. The intent,
evident from §11.12's semantics, is that `ArgumentReasoning` elements appear
in diagrams connected with an `AssertedRelationship`, at least
`AssertedInference`. However, the normative class definitions in
§11 do not provide a clear basis for this connection. Specifically:

1. §11.14 informally restricts `AssertedInference` +source values
   to `Assertion`, but
   `ArgumentReasoning` (§11.12) is **not** a subtype of `Assertion` per
   Figure 11.1, so it cannot satisfy that constraint.
2. §11.13 defines a `+reasoning: ArgumentReasoning[0..1]` property on
   `AssertedRelationship` that could serve this purpose, but Annex C defines
   **no graphical notation** for it.

The result: a diagram showing `ArgumentReasoning` connected by an undirected
line to a reification dot is underspecified. It cannot be unambiguously
serialized to a SACM model instance using only the specification.

## Background

### Class Hierarchy (Figure 11.1, p. 35)

The relevant portion of the Argumentation Package hierarchy is:

- `ArgumentAsset` (abstract)
  - `ArtifactReference` (§11.9)
  - `ArgumentReasoning` (§11.12)
  - `Assertion` (abstract, §11.10)
    - `Claim` (§11.11)
    - `AssertedRelationship` (abstract, §11.13)
      - `AssertedInference` (§11.14)
      - `AssertedEvidence` (§11.15)
      - `AssertedContext` (§11.16)
      - `AssertedArtifactSupport` (§11.17)
      - `AssertedArtifactContext` (§11.18)

`ArgumentReasoning` is a **sibling** of `Assertion` under `ArgumentAsset`,
not a subtype of `Assertion`.

### §11.12 ArgumentReasoning (p. 40)

§11.12 states that `ArgumentReasoning` "can be used to provide additional
description or explanation of the asserted relationship. For example, it can
be used to provide description of an **AssertedInference** that connects one
or more Claims (premises) to another Claim (conclusion)." It further states:
"ArgumentReasoning elements are therefore **related to AssertedInferences,
AssertedContexts, and AssertedEvidence**."

This indicates the intent: `ArgumentReasoning` is meant to appear
in diagrams involving these relationship types. The normative mechanism for
this connection, however, is not made clear in §C.7 or §C.8.

### Real-world demonstration in Selviandro et al

In the paper "A Visual Notation for the Representation of
Assurance Cases using SACM" by
Nungki Selviandro, Richard Hawkins, and Ibrahim Habli,
they clearly expect ArgumentReasoning to be connectable with
AssertedInference (at least). They say:

> In some cases, the relationship that associates more than one Claim
> may not always be obvious. In such cases, ArgumentReasoning can be
> used to provide a further description of the reasoning involved. An
> ArgumentReasoning is visu- ally represented using an annotation symbol
> (as shown in Figure 1). It can be attached to the AssertedInference
> relationship that connect the Claims.

Their figure 2 clearly shows an `AssertedInference` (represented by
a black dot) with a `Claim` as its target. This figure shows two
(sub)Claims connected with undirected lines, presumably sources.
This figure also shows the black dot connected with an undirected line
to a single `ArgumentReasoning` instance.

This paper discusses an older version of SACM, but the same question
applies to the current version: it is expected that an ArgumentReasoning
instance can be visually connected to an AssertedInference, but the
normative model does not clearly specify what that connection represents.

### §11.13 AssertedRelationship (p. 40)

`AssertedRelationship` defines:

- `source: ArgumentAsset[1..*]`: the source(s) of the relationship
- `target: ArgumentAsset[1]`: the target of the relationship
- `reasoning: ArgumentReasoning[0..1]`: "an optional reference to
  [a] description of the reasoning underlying the AssertedRelationship"

Note: the spec text as printed for `reasoning`
reads "an optional reference to **the a**
description", which appears to be a typographical error; "the a" should
read "a" or "the" (probably "the").

Note also that the `+reasoning` property exists at the `AssertedRelationship`
level, meaning it applies to all five subtypes (§11.14–§11.18), not only
`AssertedInference`, though that isn't necessarily a problem.

### §11.14 AssertedInference (p. 40)

§11.14 states: "AssertedInference association records the inference that a
user declares to exist between **one or more Assertion (premise)** and
**another Assertion (conclusion)**."

No OCL constraint is given to enforce this source/target type restriction.
This stands in contrast to, for example, §11.15 (AssertedEvidence), which
provides an explicit OCL constraint:

```
self.source->forall(s | s.oclIsTypeOf(ArtifactReference))
```

and §11.17 (AssertedArtifactSupport) and §11.18 (AssertedArtifactContext),
which each state explicitly: "The source and target of [this relationship]
must be of type ArtifactReference."

The absence of an OCL constraint in §11.14 makes it ambiguous whether the
prose "one or more Assertion (premise)" is normative or merely descriptive.

### §C.7 and §C.8 (p. 59)

- **§C.7**: Defines the graphical shape for `ArgumentReasoning` (Figure C13:
  an open-right-bracket shape containing name and statement).
- **§C.8**: Defines `AssertedInference` graphical notation (Figure C14):
  "the edge **without** an arrow represents the `+source` reference of the
  AssertedInference, and the edge **with** an arrow represents the `+target`
  reference of the AssertedInference."

§C.8 says nothing about how (or whether) an `ArgumentReasoning` node connects
to the reification dot. No figure in Annex C or Annex D shows an
`ArgumentReasoning` connected to an `AssertedInference` dot, despite §11.12
explicitly describing this use case.

No section in Annex C defines a graphical notation for the `+reasoning`
property of §11.13.

### How Annex C Identifies the Dot's Relationship Type (§C.8–§C.12, pp. 59–64)

All five `AssertedRelationship` subtypes use the same reified-dot graphical
form: a solid dot node connected to source(s) via plain (undirected) lines, and
connected to the target via a decorated directed edge. Annex C provides no
explicit algorithm for identifying which subtype a dot represents; the type
instead appears to be derived by combining two implicit visual cues.

**Cue 1: The endpoint decoration on the `+target` edge** (primary
discriminator).

§C.10 (p. 61) introduces a **filled square (■)** endpoint on the target edge
for `AssertedContext`, in contrast to the **filled arrowhead (→)** used by the
other three subtypes (§C.8, §C.9, §C.11). This separates the five subtypes
into two groups:

- **Arrow group** (`→` endpoint): `AssertedInference` (§C.8),
  `AssertedEvidence` (§C.9), `AssertedArtifactSupport` (§C.11)
- **Square group** (`■` endpoint): `AssertedContext` (§C.10),
  `AssertedArtifactContext` (§C.12)

**Cue 2: The node types (shapes) at `+source` and `+target`** (secondary
discriminator, within each group).

Within the arrow group, the subtypes are distinguished by whether the source
and target nodes are `ArtifactReference` instances or not:

- **`AssertedInference`** (§C.8, §11.14): sources are `Claim` or
  `AssertedRelationship`; target is `Claim` or `AssertedRelationship`.
- **`AssertedEvidence`** (§C.9, §11.15): sources are `ArtifactReference`
  (enforced by OCL constraint); target is `Claim` or `AssertedRelationship`.
- **`AssertedArtifactSupport`** (§C.11, §11.17): source **and** target are
  both `ArtifactReference` (§11.17: "The source and target…must be of type
  ArtifactReference").

Within the square group:

- **`AssertedContext`** (§C.10, §11.16): source may be `ArtifactReference`
  or `Claim`; target may be `Claim`, `AssertedRelationship`, or
  `ArgumentReasoning` (§11.16 explicitly permits `ArgumentReasoning` as
  target).
- **`AssertedArtifactContext`** (§C.12, §11.18): source **and** target are
  both `ArtifactReference` (§11.18: "The source and target…must be of type
  ArtifactReference").

The complete discrimination matrix, as implied by §C.8–§C.12:

| `+target` endpoint | Source shape | Target shape | Inferred subtype |
|---|---|---|---|
| Arrow (→) | `Claim` or `AssertedRelationship` | `Claim` or `AssertedRelationship` | `AssertedInference` (§C.8) |
| Arrow (→) | `ArtifactReference` | `Claim` or `AssertedRelationship` | `AssertedEvidence` (§C.9) |
| Arrow (→) | `ArtifactReference` | `ArtifactReference` | `AssertedArtifactSupport` (§C.11) |
| Square (■) | `Claim` or `ArtifactReference` | `Claim`, `AssertedRelationship`, or `ArgumentReasoning` | `AssertedContext` (§C.10) |
| Square (■) | `ArtifactReference` | `ArtifactReference` | `AssertedArtifactContext` (§C.12) |

Note that the `AssertedInference` and `AssertedContext` rows overlap on source
shape (`Claim`), but are cleanly separated by the target endpoint decoration
(→ vs ■). The target decoration is therefore the **primary** discriminator, and
node types provide the secondary discrimination within each group.

`ArgumentReasoning` does not appear in **any source column** of this matrix.
It appears only as a valid **target** of `AssertedContext` (§11.16). This
omission from the source side is precisely the gap described as the issue below.

Under Solution 2a or 2b (see below), the `AssertedInference` source column
becomes "`Claim`, `AssertedRelationship`, or `ArgumentReasoning`". No other
row changes. The discrimination is preserved because `ArgumentReasoning`'s
open right-bracket shape (§C.7) is visually distinct from `ArtifactReference`'s
stacked-pages shape (§C.9), so the `AssertedInference` row remains
distinguishable from `AssertedEvidence` and `AssertedArtifactSupport`.

**Significance for the proposed solutions.**

The discrimination within the arrow group is entirely between
`ArtifactReference` and non-`ArtifactReference` source shapes.
`ArtifactReference` has a distinctive graphical notation (stacked-pages shape
with corner ↗ arrow, §C.9), visually different from both `Claim` (plain
rectangle, §C.6) and `ArgumentReasoning` (open right-bracket, §C.7).

Consequently, in the proposed solutions discussed later:

- **Solution 2a/2b** (allow `ArgumentReasoning` as `+source` of
  `AssertedInference`): the `ArgumentReasoning` shape is distinct from
  `ArtifactReference`, so no row in the table above collapses. The
  type-discrimination mechanism is **fully preserved**.

- **Solution 1** (map undirected line from `ArgumentReasoning` to
  `+reasoning`): the undirected plain line currently uniformly represents
  `+source` across all five subtypes. Under Solution 1, it would additionally
  represent `+reasoning` when the connected node is `ArgumentReasoning`.
  This does not collapse any row of the table (the five subtypes remain
  distinguishable), but it introduces a **new implicit rule** absent from the
  current Annex C mechanism: a reader must inspect the connected node's shape
  to determine whether the line means `+source` or `+reasoning`. This
  additional rule could be eliminated by using a visually distinct notation
  (e.g., a dashed undirected line) for `+reasoning`.

### Evidence from the OMG XMI Profile (OMG ptc/22-03-014)

The OMG document `ptc/22-03-014` contains a UML Profile for SACM in XMI format
(`SACM_profile.xml`), exported from MagicDraw Clean XMI Exporter v19.0 and
dated 2022-05-24. This is a pre-ballot document that predates the final v2.3
specification (October 2023). It represents SACM as a set of UML stereotypes,
and its content is directly relevant to the ambiguity described here.

**Finding 1: `AssertedRelationship.source` and `.target` are typed
`ArgumentAsset`, not `Assertion`.**

The `source` property on the `AssertedRelationship` stereotype
(xmi:id `_19_0_4_68a022b_1652244041732_228916_5398`) is declared as:

```xml
<ownedAttribute xmi:type="uml:Property"
    xmi:id="_19_0_4_68a022b_1652244079675_278704_5441"
    name="source"
    visibility="public"
    type="_19_0_4_68a022b_1652243886557_40724_5238"
    association="_19_0_4_68a022b_1652244079675_691162_5440">
  <upperValue xmi:type="uml:LiteralUnlimitedNatural"
      xmi:id="_19_0_4_68a022b_1652244092460_391867_5452"
      value="*"/>
</ownedAttribute>
```

The `type` attribute `_19_0_4_68a022b_1652243886557_40724_5238` identifies the
`ArgumentAsset` stereotype (confirmed by its `name="ArgumentAsset"` declaration
elsewhere in the file). `ArgumentAsset` is the abstract parent of
`ArtifactReference`, `ArgumentReasoning`, AND `Assertion`. The type of `source`
is therefore `ArgumentAsset[*]`, **not** `Assertion`. The `target` property
carries the same `ArgumentAsset` type with multiplicity 1.

In the machine-readable definition, both `source` and `target` accept any
`ArgumentAsset`, including `ArgumentReasoning`.
This is consistent with figure 11.1 in the textual spec, which also
shows this.
The prose restriction in §11.14
("one or more Assertion (premise)") does not appear in the profile.

**Finding 2: `AssertedInference` adds no source/target type constraints.**

The `AssertedInference` stereotype
(xmi:id `_19_0_4_68a022b_1652244176182_10606_5548`) inherits from
`AssertedRelationship` and adds only a `base_Class` attribute (standard
boilerplate for UML profiles). It contains no `ownedRule` elements and no
narrowing of the `source` or `target` types. The inherited `source:
ArgumentAsset[*]` is therefore the effective constraint at the machine-readable
level.

**Finding 3: No OCL constraints exist anywhere in the profile.**

A search of `SACM_profile.xml` for `ownedRule`, `OpaqueExpression`, and OCL
keywords returns no matches. None of the five `AssertedRelationship` subtypes
carry any OCL constraints in the profile, not even `AssertedEvidence`, which
has an explicit OCL constraint in §11.15 of the final spec:

```
self.source->forall(s | s.oclIsTypeOf(ArtifactReference))
```

This suggests the profile and the final spec text were developed somewhat
independently. It also illustrates that the source-type restrictions in the
spec text are not consistently carried through to the machine-readable form.

**Finding 4: `reasoning: ArgumentReasoning[0..1]` is present and separate.**

The `reasoning` property is defined on `AssertedRelationship` with type
`_19_0_4_68a022b_1652243876371_514933_5211`, which the file identifies as the
`ArgumentReasoning` stereotype (`name="ArgumentReasoning"`). It has a lower
bound of 0 (optional), confirming it is a separate, optional annotation property
coexisting with the `source` property that already accepts `ArgumentReasoning`.

This is also what spec figure 11.1 says (presuming `reasonging` is
supposed to be `reasoning`).

**Finding 5: `ArtifactAssertedRelationship` contains a property-name typo.**

A separate stereotype `ArtifactAssertedRelationship` (Artifact Package, distinct
from the Argumentation Package) has its target property
named `targt` rather than `target` at line 1108:

```xml
<ownedAttribute xmi:type="uml:Property"
    xmi:id="_19_0_4_68a022b_1652244685644_747127_6144"
    name="targt"
    visibility="public"
    type="_19_0_4_68a022b_1652244401515_877827_5728"
    association="_19_0_4_68a022b_1652244685644_369103_6143"/>
```

In the spec figure F.5 (Artifact component of the SACM profile)
this is shown as the presumably correct `target` and not as `targt`.

This typo is unrelated to the primary issue.

**Significance.**

The profile provides machine-readable evidence that the SACM model was
implemented with `source: ArgumentAsset[*]` (which already admits
`ArgumentReasoning`) at the `AssertedRelationship` level, with no narrowing
introduced by `AssertedInference`. This is consistent with the §11.14 prose
restriction ("one or more Assertion (premise)") being unintentional rather
than a deliberate design choice. Under Solution 2a (see below), the spec prose
would be brought into alignment with the profile definition; no change to the
model as implemented would be required.

## The Problem

Taken together, the above produces a lack of clarity
or possibly contradiction with no specified resolution:

1. **`ArgumentReasoning` cannot be a `+source`** of `AssertedInference`,
   according to the §11.14 prose,
   because §11.14's prose says sources must be `Assertion`, and
   `ArgumentReasoning` is not a subtype of `Assertion` (Figure 11.1).
   This is a textual constraint with no OCL, but if taken literally,
   it excludes `ArgumentReasoning`.

2. **`ArgumentReasoning` could connect via `+reasoning`** (§11.13), but
   Annex C provides no clear statement that any
   graphical notation is intended for this property. A reader of
   Annex C has no way to determine with certainty that an undirected line from
   an `ArgumentReasoning` represents `+reasoning` rather than `+source`.
   This might be the intent, but if it is,
   the specification fails to say this clearly.

3. **`ArgumentReasoning` is clearly intended to appear in diagrams**
   (§11.12, §C.7), but the normative pathway for this appearance is
   undefined.

The net result: any diagram showing `ArgumentReasoning` connected to an
`AssertedInference` dot is **underspecified** with respect to the normative
model. A tool or human cannot unambiguously be certain of what is
meant reading only the SACM specification.

## Proposed Solutions

### Solution 1: Formalize `+reasoning` as the Graphical Connection

Declare in Annex C that an undirected line from an `ArgumentReasoning` node
to a reification dot represents the `+reasoning` property of
`AssertedRelationship` (§11.13), distinct from a `+source` line (which must
come from an `Assertion` or `ArtifactReference` per the relevant subtype).

Required changes:

1. **§C.8**: Add text stating that when an `ArgumentReasoning` (open-bracket
   shape, §C.7) connects to an `AssertedInference` dot with an undirected
   line, this represents the `+reasoning` association of §11.13, **not** a
   `+source` reference. Optionally add a new figure (e.g., Figure C14a)
   illustrating this.
2. **§11.14**: Optionally add an explicit OCL constraint (absent today)
   confirming that `+source` must be `Assertion`:

   ```
   self.source->forall(s | s.oclIsKindOf(Assertion))
   ```

**Advantage**: Minimal change. Preserves the semantics that `+source`
premises are propositional (`Assertion`) elements.

**Limitation**: The undirected line would be overloaded:
it would represent `+source`
when the connected node is a `Claim` or `AssertedRelationship`, and
`+reasoning` when the connected node is an `ArgumentReasoning`. Readers
must rely on the node's shape to determine which property is represented.
Defining a visually distinct notation for `+reasoning` (e.g., a dashed
undirected line) would eliminate this residual ambiguity.
That said, the black dot already overloads several types, which can
be disambiguated from the local context, so perhaps this isn't really
much different.

In addition, `+reasoning` is defined as having at most one value.
This would mean that multiple ArgumentReasonings could not be
connected to a given `AssertedRelationship`.
That seems like a reasonable limitation, but it's important that
this be intentional.

### Solution 2: Formally Allow `ArgumentReasoning` as a `+source` of `AssertedInference`

Permit `ArgumentReasoning` to be a valid `+source` of `AssertedInference`,
treating it as a reasoning premise rather than a mere annotation. Several
sub-options are possible:

#### Sub-option 2a: Revise §11.14 prose and add OCL (minimal change)

The current §11.14 text reads (emphasis on the constraint being changed):

> "AssertedInference association records the inference that a user
> declares to exist between **one or more Assertion (premise)** and
> **another Assertion (conclusion)**. It is important to note that such
> a declaration is itself an assertion on behalf of the user."

**Proposed revised text:**

> "AssertedInference association records the inference that a user
> declares to exist between **one or more `Assertion` or
> `ArgumentReasoning` (premise)** and **another `Assertion`
> (conclusion)**. It is important to note that such a declaration is
> itself an assertion on behalf of the user."

**Proposed OCL constraint** (to be added to §11.14, matching the pattern
of §11.15, §11.17, §11.18):

```
self.source->forall(s | s.oclIsKindOf(Assertion) or
                        s.oclIsKindOf(ArgumentReasoning))
self.target.oclIsKindOf(Assertion)
```

The source constraint explicitly permits `ArgumentReasoning` alongside
`Assertion` (including all its subtypes: `Claim`, `AssertedRelationship`,
and all five relationship subtypes). The target constraint formalizes the
existing prose requirement that the conclusion be an `Assertion`.

This wording is consistent with the `source: ArgumentAsset[*]` type
declared in the OMG XMI profile (ptc/22-03-014), narrowed to exclude
`ArtifactReference` (which belongs to `AssertedEvidence` and
`AssertedArtifactSupport`) while including `ArgumentReasoning`.
It also aligns with §11.12's explicit statement that `ArgumentReasoning`
is "related to AssertedInferences, AssertedContexts, and AssertedEvidence."

This is the smallest targeted change. It brings the normative constraint
into agreement with the evident intent of Annex C and the profile, while
leaving the rest of the meta-model untouched. The `+reasoning` property
of §11.13 would remain available for metadata annotation purposes,
distinct from the `+source` role in a diagram.

#### Sub-option 2b: Introduce per-subtype OCL constraints in §11.14 (and siblings)

Remove the informal source-type language from §11.14's prose and instead
add explicit, per-subtype OCL constraints across all five `AssertedRelationship`
subtypes (§11.14–§11.18), matching the pattern already established by
§11.15, §11.17, and §11.18. For `AssertedInference`:

```
self.source->forall(s | s.oclIsKindOf(Assertion) or
                        s.oclIsKindOf(ArgumentReasoning))
self.target.oclIsKindOf(Assertion)
```

This approach makes type constraints uniformly explicit across all subtypes,
rather than relying on informal prose, and reduces the discrepancy between
the documented constraints in §11.14 and those in §11.15, §11.17, §11.18.

#### Sub-option 2c: Move `ArgumentReasoning` under `Assertion` in the hierarchy

Revise Figure 11.1 to make `ArgumentReasoning` a subtype of `Assertion`.
This would automatically satisfy the "source = Assertion" constraint of
§11.14, allow `ArgumentReasoning` to carry an `assertionDeclaration`
attribute (§11.10), and permit it to appear as `+target` as well as
`+source`.

However, this is a significant semantic change: `Assertion` carries the
`assertionDeclaration: AssertionDeclaration[1] = asserted` attribute
(§11.10) with enumeration values (asserted, needsSupport, assumed,
axiomatic, defeated, asCited), which may not be conceptually appropriate
for a reasoning description. This sub-option is listed for completeness but
is likely too disruptive to the meta-model's intended semantics.

### Role of `+reasoning` if Solution 2 is Adopted

Under Solution 2, both `+source` and `+reasoning` accept `ArgumentReasoning`
values for `AssertedInference`, which could lead to inconsistent use without a
clear semantic distinction. Any revision adopting Solution 2
should clarify the intended difference between the two.

**Semantic distinction.**

- `+source` with an `ArgumentReasoning` node: the reasoning is a structural
  participant in the argument. It is a visible premise or warrant that jointly
  contributes to the inference, shown in Annex C diagrams as a node connected
  to the reification dot with a plain undirected line.
- `+reasoning`: a meta-level annotation on the relationship itself.
  It has no Annex C graphical notation and no structural role in the argument.
  Perhaps it's more of description of why the relationship exists at all.

**`+reasoning` retains independent utility under Solution 2.**

First, `+reasoning` is the only mechanism for attaching an `ArgumentReasoning`
to four of the five subtypes. Solution 2a only loosens the source constraint
for `AssertedInference` (§11.14). For `AssertedEvidence` (§11.15),
`AssertedArtifactSupport` (§11.17), and `AssertedArtifactContext` (§11.18),
sources are constrained to `ArtifactReference`; for `AssertedContext` (§11.16),
sources are `ArtifactReference` or `Claim`. `ArgumentReasoning` cannot appear
as `+source` in any of those four subtypes. The `+reasoning` property on the
parent `AssertedRelationship` (§11.13) is therefore the only way to attach an
`ArgumentReasoning` annotation to those relationships at all.

Second, `+reasoning` has no Annex C graphical notation (see §C.7–§C.12), which
makes it a natural home for model-level annotation that tools carry internally
but do not display in diagrams.

Third, the multiplicity difference is meaningful. `+source` permits multiple
`ArgumentReasoning` values (inherited multiplicity `1..*`),
while `+reasoning` is
limited to one (0..1). If the intent is a single concise annotation on the
relationship, `+reasoning` expresses that constraint directly.

**Risk of ambiguity that a Solution 2 revision should address.**

Under Solution 2, a developer creating an `AssertedInference` has two ways to
attach an `ArgumentReasoning`: as `+source` (visible in diagrams, structurally
participating in the inference) or as `+reasoning` (not displayed, annotation
only). Without clarification, implementers might make inconsistent choices,
harming model interchange. The revised §11.14 text, and ideally a note in
§11.13, should state the intended semantic distinction explicitly.

I don't know that distinction is.
Here's one attempt at it: "Any `AssertedRelationship` `+source` of
`ArgumentReasoning` nodes are structural premises, visible in Annex C diagrams.
`+reasoning` is a non-displayed annotation applicable to all five
`AssertedRelationship` subtypes."
Note that `+reasoning` is the only `ArgumentReasoning` attachment mechanism
available for the four subtypes whose source types are constrained to
`ArtifactReference` or `Claim`."

## Effect on Annex C Dot Ambiguity

As described above in "How Annex C Identifies the Dot's Relationship Type",
the five `AssertedRelationship` subtypes are discriminated by (a) the
endpoint decoration on the `+target` edge and (b) whether source/target
nodes are `ArtifactReference` instances. `ArgumentReasoning` does not
participate in this discrimination on the source side in the current spec.

None of the proposed solutions collapse the discrimination matrix.
Specifically:

- **Solutions 2a, 2b** (allow `ArgumentReasoning` as `+source` of
  `AssertedInference`): `ArgumentReasoning`'s open-bracket shape is
  visually distinct from `ArtifactReference`'s stacked-pages shape.
  Adding `ArgumentReasoning` to the `AssertedInference` source row does
  not make that row indistinguishable from the `AssertedEvidence` or
  `AssertedArtifactSupport` rows. No change to Annex C is required.

- **Solution 2c** (move `ArgumentReasoning` under `Assertion`): no change
  to the discrimination mechanism; the shapes and endpoint decorations
  are unaffected.

- **Solution 1** (formalize `+reasoning` as a distinct graphical connection):
  the undirected plain line would carry two meanings depending on the connected
  node's shape. The five-subtype discrimination itself remains intact, but a
  visually distinct notation for `+reasoning` (e.g., a dashed undirected line)
  would make the two meanings unambiguous without requiring a reader to inspect
  the node shape.

## Summary of Proposed Changes

| | Sol. 1 | Sol. 2a | Sol. 2b | Sol. 2c |
|---|:---:|:---:|:---:|:---:|
| Change §11.13 (fix typo) | Yes | Yes | Yes | Yes |
| Change §11.14 prose | No | Yes | Yes | No |
| Add OCL to §11.14 | Optional | Yes | Yes | No |
| Change class hierarchy | No | No | No | Yes |
| Change Annex C | Yes | No | No | No |
| Semantic impact | Minimal | Minimal | Minimal | Significant |
| Dot ambiguity introduced | No | No | No | No |
| Consistent with XMI profile (ptc/22-03-014) | No | **Yes** | **Yes** | No |

I recommend **solution 2a**, though **solution 1** is also plausible.

The XMI profile evidence (ptc/22-03-014) provides additional support for
**Solution 2a**: the machine-readable model already types `source` as
`ArgumentAsset`, which inherently permits `ArgumentReasoning`. Solution 2a
would bring the spec prose into agreement with the profile without requiring
any change to Annex C or to the model as implemented.

That said, it's possible that solution 1 (or another solution) was
intended; if so, that needs to be clear.

## Related issues Found

The following related issues were identified.

### In OMG Formal/23-05-08 (SACM v2.3)

1. **§11.13, p. 40**: `reasoning` property description: the printed text reads
   "an optional reference to **the a** description of the reasoning underlying
   the AssertedRelationship". The phrase "the a" is a typographical error;
   it should read "a" or "the" (probably "the").

2. **Figure 11.1, p. 35**: the association from `AssertedRelationship` to
   `ArgumentReasoning` is labeled `+reasonging` (with a transposed `g`).
   The correct spelling is `+reasoning`.

### In OMG ptc/22-03-014 (`SACM_profile.xml`)

3. **`ArtifactAssertedRelationship` stereotype**: the `target` property is
   named `targt` (missing `e`):

   ```xml
   <ownedAttribute xmi:type="uml:Property"
       xmi:id="_19_0_4_68a022b_1652244685644_747127_6144"
       name="targt"
       .../>
   ```

   The intended name is `target`, consistent with the parallel `source`
   property and with the `AssertedRelationship` stereotype.

4. **OCL constraints absent from profile**: §11.15 includes an explicit OCL
   constraint (`self.source->forall(s | s.oclIsTypeOf(ArtifactReference))`) for
   `AssertedEvidence`, and §11.17/§11.18 include prose constraints for
   `AssertedArtifactSupport` and `AssertedArtifactContext`. None of these
   constraints appear as `ownedRule` elements in the corresponding stereotypes
   in the profile. A future version of the profile should include these OCL
   constraints so that the profile and spec remain consistent.
