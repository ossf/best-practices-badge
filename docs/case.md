# BadgeApp Security: Its Assurance Case

<!-- SPDX-License-Identifier: (MIT OR CC-BY-3.0+) -->

Security is important and challenging.
This document describes why we think this software (the "BadgeApp")
is adequately secure.
In other words, this document is the "assurance case" for the BadgeApp.
This document is the result of continuous threat/attack modeling
while the system is developed and maintained, and it is modified
as the situation changes.
For simplicity, this document also serves as detailed documentation of
the security requirements, since in this case we found it
easier to put them all in one document.

Sadly, perfection is rare; we really want your help.
If you find a vulnerability, please see
[CONTRIBUTING.md#how_to_report_vulnerabilities](../CONTRIBUTING.md#how_to_report_vulnerabilities)
for how to submit a vulnerability report.
For more technical information on the implementation, see
[implementation.md](implementation.md).

You can see a video summarizing an older version of
this assurance case (as of September 2017),
along with some more general information about developing secure software:
["How to Develop Secure Applications: The BadgeApp Example" by David A. Wheeler, 2017-09-18](https://www.youtube.com/watch?v=5a5D4d6hcEY).
For more information on developing secure software, see
["Secure Programming HOWTO" by David A. Wheeler](http://www.dwheeler.com/secure-programs/).
[_A Sample Security Assurance Case Pattern_ by David A. Wheeler (2018)](https://www.ida.org/idamedia/Corporate/Files/Publications/IDA_Documents/ITSD/2019/P-9278.pdf)
shows how to create an assurance case for your project, using
a version of this assurance case as an example.

We thank Scott Ankrum (MITRE)
for analyzing an earlier version of this assurance case.
He provided a number of helpful comments and provided a lot of feedback
in how to convert its notation from the
Claims, Arguments, and Evidence (CAE) notation to
Structured Assurance Case Metamodel (SACM) notation.
For his initial work in converting this assurance case to SACM notation, see
[*BadgeApp Assurance Case in SACM Notation* by T. Scott Ankrum, The MITRE Corporation, May 2021](https://www.researchgate.net/publication/351854207_BadgeApp_Assurance_Case_in_SACM_Notation).

## Assurance case summary

The following figures summarize why we think this application
is adequately secure (more detail is provided in the rest of this document):
The figures are simply a summary; the text below provides the details.

### Assurance case structure

<!-- verocase package * -->
<!-- DO NOT EDIT text from here until "end verocase" -->

<a id="package-security"></a>
### Package Security: The system is adequately secure against moderate threats

```mermaid
---
config:
  theme: neutral
  flowchart:
    curve: linear
    htmlLabels: true
    rankSpacing: 60
    nodeSpacing: 45
    padding: 15
---
flowchart BT
    classDef invisible opacity:0
    classDef sacmDot fill:#000,stroke:#000
    classDef connector fill:none,stroke:#cccccc,stroke-width:1px;
    classDef abstractClaim stroke-width:2px,stroke-dasharray: 5 5;
    Security["<b>Security</b><br>The system is adequately secure against moderate threats"]
    Processes[/"<b>Processes</b><br>Security is argued by examining all lifecycle processes"/]
    Controls[["<b>Controls</b>"]]
    TechProcesses["<b>TechProcesses</b><br>Technical lifecycle processes implement security"]
    NonTechnical[["<b>NonTechnical</b>"]]
    Requirements[["<b>Requirements</b>"]]
    Design[["<b>Design</b>"]]
    Implementation[["<b>Implementation</b>"]]
    Verification[["<b>Verification</b>"]]
    Deployment[["<b>Deployment</b>"]]
    Maintenance[["<b>Maintenance</b>"]]
    Dot1((" ")):::sacmDot
    Dot2((" ")):::sacmDot
    click Security "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-security"
    click Processes "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#strategy-processes"
    click Controls "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#package-controls"
    click TechProcesses "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-techprocesses"
    click NonTechnical "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#package-nontechnical"
    click Requirements "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#package-requirements"
    click Design "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#package-design"
    click Implementation "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#package-implementation"
    click Verification "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#package-verification"
    click Deployment "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#package-deployment"
    click Maintenance "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#package-maintenance"

    BottomPadding1["<br/><br/><br/>"]:::invisible ~~~~ Processes
    BottomPadding2["<br/><br/><br/>"]:::invisible ~~~~ Controls
    BottomPadding3["<br/><br/><br/>"]:::invisible ~~~~ NonTechnical
    BottomPadding4["<br/><br/><br/>"]:::invisible ~~~~ Requirements
    BottomPadding5["<br/><br/><br/>"]:::invisible ~~~~ Design
    BottomPadding6["<br/><br/><br/>"]:::invisible ~~~~ Implementation
    BottomPadding7["<br/><br/><br/>"]:::invisible ~~~~ Verification
    BottomPadding8["<br/><br/><br/>"]:::invisible ~~~~ Deployment
    BottomPadding9["<br/><br/><br/>"]:::invisible ~~~~ Maintenance
    Requirements --- Dot1
    Design --- Dot1
    Implementation --- Dot1
    Verification --- Dot1
    Deployment --- Dot1
    Maintenance --- Dot1
    Dot1 --> TechProcesses
    TechProcesses --- Dot2
    NonTechnical --- Dot2
    Processes --- Dot2
    Controls --- Dot2
    Dot2 --> Security
```

Defines: **[Claim Security](#claim-security)**, [Strategy Processes](#strategy-processes), [Claim TechProcesses](#claim-techprocesses)

Citing: [Claim Controls](#package-controls), [Claim NonTechnical](#package-nontechnical), [Claim Maintenance](#package-maintenance), [Claim Deployment](#package-deployment), [Claim Verification](#package-verification), [Claim Implementation](#package-implementation), [Claim Design](#package-design), [Claim Requirements](#package-requirements)

<a id="package-requirements"></a>
### Package Requirements: Security requirements are identified and met

```mermaid
---
config:
  theme: neutral
  flowchart:
    curve: linear
    htmlLabels: true
    rankSpacing: 60
    nodeSpacing: 45
    padding: 15
---
flowchart BT
    classDef invisible opacity:0
    classDef sacmDot fill:#000,stroke:#000
    classDef connector fill:none,stroke:#cccccc,stroke-width:1px;
    classDef abstractClaim stroke-width:2px,stroke-dasharray: 5 5;
    Requirements["<b>Requirements</b><br>Security requirements are identified and met"]
    SecTriad[/"<b>SecTriad</b><br>Security triad (CIA) and access control address the requirements"/]
    Assets["<b>Assets</b><br>Assets & threat actors identified & addressed"]
    Confidentiality[["<b>Confidentiality</b><br>Confidentiality is maintained"]]
    Integrity["<b>Integrity</b><br>Integrity is maintained"]
    Availability[["<b>Availability</b><br>Availability is maintained including limited DDoS resilience"]]
    AccessControl["<b>AccessControl</b><br>Access control is in place"]
    AssetsIdentified["<b>AssetsIdentified</b><br>Key assets (badge data, user credentials, system availability) have been identified<br>..."]
    ThreatsIdentified["<b>ThreatsIdentified</b><br>Key threat actors (external attackers, bots, insiders, nation-states) have been identified and addressed<br>..."]
    DataModAuth["<b>DataModAuth</b><br>Data modification requires authorization"]
    AppModAuth["<b>AppModAuth</b><br>Application modification requires authorization"]
    AuthN["<b>AuthN</b><br>Users must identify and authenticate themselves"]
    AuthZ["<b>AuthZ</b><br>Authorization to resources and actions is controlled"]
    DataModAuthEv[("<b>DataModAuthEv</b>&nbsp;↗<br>before_action guards can_edit_else_redirect and can_control_else_redirect protect all project modifications")]
    AppModAuthEv[("<b>AppModAuthEv</b>&nbsp;↗<br>GitHub repository requires authenticated access; branch protection rules enforce code review before merging to main; governance.md documents the process")]
    LocalAuthN["<b>LocalAuthN</b><br>Local users must supply a password"]
    RemoteAuthN["<b>RemoteAuthN</b><br>Remote users are authenticated by a trusted remote service"]
    AuthZEv[("<b>AuthZEv</b>&nbsp;↗<br>can_edit? and can_control? methods implement role-based authorization; all access enforced server-side through controllers")]
    LocalAuthNEv[("<b>LocalAuthNEv</b>&nbsp;↗<br>sessions_controller create action authenticates local users by verifying email and bcrypt password hash before establishing session")]
    OAuthEv[("<b>OAuthEv</b>&nbsp;↗<br>OmniAuth-GitHub middleware authenticates remote users via GitHub OAuth 2.0; callback validates identity before creating local session")]
    Dot1((" ")):::sacmDot
    Dot2((" ")):::sacmDot
    Dot3((" ")):::sacmDot
    Dot4((" ")):::sacmDot
    Dot5((" ")):::sacmDot
    click Requirements "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-requirements"
    click SecTriad "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#strategy-sectriad"
    click Assets "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-assets"
    click Confidentiality "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#package-confidentiality"
    click Integrity "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-integrity"
    click Availability "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#package-availability"
    click AccessControl "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-accesscontrol"
    click AssetsIdentified "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-assetsidentified"
    click ThreatsIdentified "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-threatsidentified"
    click DataModAuth "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-datamodauth"
    click AppModAuth "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-appmodauth"
    click AuthN "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-authn"
    click AuthZ "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-authz"
    click DataModAuthEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-datamodauthev"
    click AppModAuthEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-appmodauthev"
    click LocalAuthN "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-localauthn"
    click RemoteAuthN "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-remoteauthn"
    click AuthZEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-authzev"
    click LocalAuthNEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-localauthnev"
    click OAuthEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-oauthev"

    BottomPadding1["<br/><br/><br/>"]:::invisible ~~~~ SecTriad
    BottomPadding2["<br/><br/><br/>"]:::invisible ~~~~ Confidentiality
    BottomPadding3["<br/><br/><br/>"]:::invisible ~~~~ Availability
    BottomPadding4["<br/><br/><br/>"]:::invisible ~~~~ AssetsIdentified
    BottomPadding5["<br/><br/><br/>"]:::invisible ~~~~ ThreatsIdentified
    BottomPadding6["<br/><br/><br/>"]:::invisible ~~~~ DataModAuthEv
    BottomPadding7["<br/><br/><br/>"]:::invisible ~~~~ AppModAuthEv
    BottomPadding8["<br/><br/><br/>"]:::invisible ~~~~ AuthZEv
    BottomPadding9["<br/><br/><br/>"]:::invisible ~~~~ LocalAuthNEv
    BottomPadding10["<br/><br/><br/>"]:::invisible ~~~~ OAuthEv
    DataModAuthEv --> DataModAuth
    AppModAuthEv --> AppModAuth
    DataModAuth --- Dot1
    AppModAuth --- Dot1
    Dot1 --> Integrity
    LocalAuthNEv --> LocalAuthN
    OAuthEv --> RemoteAuthN
    LocalAuthN --- Dot2
    RemoteAuthN --- Dot2
    Dot2 --> AuthN
    AuthZEv --> AuthZ
    AuthN --- Dot3
    AuthZ --- Dot3
    Dot3 --> AccessControl
    AssetsIdentified --- Dot4
    ThreatsIdentified --- Dot4
    Dot4 --> Assets
    Confidentiality --- Dot5
    Integrity --- Dot5
    Availability --- Dot5
    AccessControl --- Dot5
    SecTriad --- Dot5
    Assets --- Dot5
    Dot5 --> Requirements
```

Defines: **[Claim Requirements](#claim-requirements)**, [Claim Assets](#claim-assets), [Claim ThreatsIdentified](#claim-threatsidentified), [Claim AssetsIdentified](#claim-assetsidentified), [Strategy SecTriad](#strategy-sectriad), [Claim AccessControl](#claim-accesscontrol), [Claim AuthZ](#claim-authz), [Evidence AuthZEv](#evidence-authzev), [Claim AuthN](#claim-authn), [Claim RemoteAuthN](#claim-remoteauthn), [Evidence OAuthEv](#evidence-oauthev), [Claim LocalAuthN](#claim-localauthn), [Evidence LocalAuthNEv](#evidence-localauthnev), [Claim Integrity](#claim-integrity), [Claim AppModAuth](#claim-appmodauth), [Evidence AppModAuthEv](#evidence-appmodauthev), [Claim DataModAuth](#claim-datamodauth), [Evidence DataModAuthEv](#evidence-datamodauthev)

Citing: [Claim Availability](#package-availability), [Claim Confidentiality](#package-confidentiality)

Cited by: [Package Security](#package-security)

<a id="package-design"></a>
### Package Design: Security in design

```mermaid
---
config:
  theme: neutral
  flowchart:
    curve: linear
    htmlLabels: true
    rankSpacing: 60
    nodeSpacing: 45
    padding: 15
---
flowchart BT
    classDef invisible opacity:0
    classDef sacmDot fill:#000,stroke:#000
    classDef connector fill:none,stroke:#cccccc,stroke-width:1px;
    classDef abstractClaim stroke-width:2px,stroke-dasharray: 5 5;
    Design["<b>Design</b><br>Security in design"]
    SimpleDesign["<b>SimpleDesign</b><br>Economy of mechanism: simple design is used"]
    STRIDE["<b>STRIDE</b><br>STRIDE threat model has been analyzed"]
    DesignPrinciples[["<b>DesignPrinciples</b><br>Secure design principles are applied"]]
    Scalability["<b>Scalability</b><br>Availability through scalability"]
    MemSafe["<b>MemSafe</b><br>Memory-safe languages are used"]
    SimpleDesignEv[("<b>SimpleDesignEv</b>&nbsp;↗<br>Standard Rails MVC architecture with models, views, and controllers; no microservices or complex distributed patterns; custom code kept minimal")]
    STRIDEEv[("<b>STRIDEEv</b>&nbsp;↗<br>STRIDE threat analysis documented for all major components: web server, controllers/models/views, DBMS, Chief/Detective classes, admin CLI, and i18n service")]
    ScalabilityEv[("<b>ScalabilityEv</b>&nbsp;↗<br>Heroku dyno-based deployment enables horizontal scaling; Fastly CDN offloads static asset and badge requests from origin server")]
    MemSafeEv[("<b>MemSafeEv</b>&nbsp;↗<br>All custom application code is written in Ruby and JavaScript, both memory-managed languages; buffer overflows and memory corruption cannot occur in custom code")]
    Dot1((" ")):::sacmDot
    click Design "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-design"
    click SimpleDesign "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-simpledesign"
    click STRIDE "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-stride"
    click DesignPrinciples "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#package-designprinciples"
    click Scalability "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-scalability"
    click MemSafe "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-memsafe"
    click SimpleDesignEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-simpledesignev"
    click STRIDEEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-strideev"
    click ScalabilityEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-scalabilityev"
    click MemSafeEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-memsafeev"

    BottomPadding1["<br/><br/><br/>"]:::invisible ~~~~ DesignPrinciples
    BottomPadding2["<br/><br/><br/>"]:::invisible ~~~~ SimpleDesignEv
    BottomPadding3["<br/><br/><br/>"]:::invisible ~~~~ STRIDEEv
    BottomPadding4["<br/><br/><br/>"]:::invisible ~~~~ ScalabilityEv
    BottomPadding5["<br/><br/><br/>"]:::invisible ~~~~ MemSafeEv
    SimpleDesignEv --> SimpleDesign
    STRIDEEv --> STRIDE
    ScalabilityEv --> Scalability
    MemSafeEv --> MemSafe
    SimpleDesign --- Dot1
    STRIDE --- Dot1
    DesignPrinciples --- Dot1
    Scalability --- Dot1
    MemSafe --- Dot1
    Dot1 --> Design
```

Defines: **[Claim Design](#claim-design)**, [Claim MemSafe](#claim-memsafe), [Evidence MemSafeEv](#evidence-memsafeev), [Claim Scalability](#claim-scalability), [Evidence ScalabilityEv](#evidence-scalabilityev), [Claim STRIDE](#claim-stride), [Evidence STRIDEEv](#evidence-strideev), [Claim SimpleDesign](#claim-simpledesign), [Evidence SimpleDesignEv](#evidence-simpledesignev)

Citing: [Claim DesignPrinciples](#package-designprinciples)

Cited by: [Package Security](#package-security)

<a id="package-implementation"></a>
### Package Implementation: Security in implementation

```mermaid
---
config:
  theme: neutral
  flowchart:
    curve: linear
    htmlLabels: true
    rankSpacing: 60
    nodeSpacing: 45
    padding: 15
---
flowchart BT
    classDef invisible opacity:0
    classDef sacmDot fill:#000,stroke:#000
    classDef connector fill:none,stroke:#cccccc,stroke-width:1px;
    classDef abstractClaim stroke-width:2px,stroke-dasharray: 5 5;
    Implementation["<b>Implementation</b><br>Security in implementation"]
    CommonVulns[/"<b>CommonVulns</b><br>Most implementation vulnerabilities are due to common types of implementation errors or common misconfigurations, so countering them greatly reduces security risks"/]
    HardeningStrat[/"<b>HardeningStrat</b><br>Hardening can reduce or eliminate the impact of defects in some cases"/]
    PubVulns["<b>PubVulns</b><br>Public vulnerability information monitored"]
    OWASPClaim[["<b>OWASPClaim</b><br>All of the most common important implementation vulnerability types (weaknesses) countered"]]
    MisconfigClaim["<b>MisconfigClaim</b><br>All of the most common known security-relevant misconfiguration errors countered"]
    ReuseSec[["<b>ReuseSec</b><br>Reused software is secure"]]
    Hardening[["<b>Hardening</b><br>Hardening is applied"]]
    PubVulnsBundleEv[("<b>PubVulnsBundleEv</b>&nbsp;↗<br>bundle-audit checks all gem versions against NVD vulnerability database on every rake run")]
    PubVulnsDependabotEv[("<b>PubVulnsDependabotEv</b>&nbsp;↗<br>GitHub Dependabot alerts and automated pull requests for vulnerable dependencies")]
    RailsGuide["<b>RailsGuide</b><br>Entire most-relevant security guide applied"]
    RailsGuideEv[("<b>RailsGuideEv</b>&nbsp;↗<br>Rails security guide reviewed and countermeasures applied for sessions, CSRF, XSS, injection, and other Rails-specific issues")]
    Dot1((" ")):::sacmDot
    Dot2((" ")):::sacmDot
    click Implementation "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-implementation"
    click CommonVulns "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#strategy-commonvulns"
    click HardeningStrat "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#strategy-hardeningstrat"
    click PubVulns "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-pubvulns"
    click OWASPClaim "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#package-owaspclaim"
    click MisconfigClaim "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-misconfigclaim"
    click ReuseSec "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#package-reusesec"
    click Hardening "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#package-hardening"
    click PubVulnsBundleEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-pubvulnsbundleev"
    click PubVulnsDependabotEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-pubvulnsdependabotev"
    click RailsGuide "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-railsguide"
    click RailsGuideEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-railsguideev"

    BottomPadding1["<br/><br/><br/>"]:::invisible ~~~~ CommonVulns
    BottomPadding2["<br/><br/><br/>"]:::invisible ~~~~ HardeningStrat
    BottomPadding3["<br/><br/><br/>"]:::invisible ~~~~ OWASPClaim
    BottomPadding4["<br/><br/><br/>"]:::invisible ~~~~ ReuseSec
    BottomPadding5["<br/><br/><br/>"]:::invisible ~~~~ Hardening
    BottomPadding6["<br/><br/><br/>"]:::invisible ~~~~ PubVulnsBundleEv
    BottomPadding7["<br/><br/><br/>"]:::invisible ~~~~ PubVulnsDependabotEv
    BottomPadding8["<br/><br/><br/>"]:::invisible ~~~~ RailsGuideEv
    RailsGuideEv --> RailsGuide
    RailsGuide --> MisconfigClaim
    PubVulnsBundleEv --- Dot1
    PubVulnsDependabotEv --- Dot1
    Dot1 --> PubVulns
    OWASPClaim --- Dot2
    MisconfigClaim --- Dot2
    ReuseSec --- Dot2
    CommonVulns --- Dot2
    Hardening --- Dot2
    HardeningStrat --- Dot2
    PubVulns --- Dot2
    Dot2 --> Implementation
```

Defines: **[Claim Implementation](#claim-implementation)**, [Claim PubVulns](#claim-pubvulns), [Evidence PubVulnsDependabotEv](#evidence-pubvulnsdependabotev), [Evidence PubVulnsBundleEv](#evidence-pubvulnsbundleev), [Strategy HardeningStrat](#strategy-hardeningstrat), [Strategy CommonVulns](#strategy-commonvulns), [Claim MisconfigClaim](#claim-misconfigclaim), [Claim RailsGuide](#claim-railsguide), [Evidence RailsGuideEv](#evidence-railsguideev)

Citing: [Claim Hardening](#package-hardening), [Claim ReuseSec](#package-reusesec), [Claim OWASPClaim](#package-owaspclaim)

Cited by: [Package Security](#package-security)

<a id="package-verification"></a>
### Package Verification: Security in integration & verification

```mermaid
---
config:
  theme: neutral
  flowchart:
    curve: linear
    htmlLabels: true
    rankSpacing: 60
    nodeSpacing: 45
    padding: 15
---
flowchart BT
    classDef invisible opacity:0
    classDef sacmDot fill:#000,stroke:#000
    classDef connector fill:none,stroke:#cccccc,stroke-width:1px;
    classDef abstractClaim stroke-width:2px,stroke-dasharray: 5 5;
    Verification["<b>Verification</b><br>Security in integration & verification"]
    VerifStrat[/"<b>VerifStrat</b><br>Static & dynamic verifications are performed and enforced on all integrations, reducing risk"/]
    VerifSteps["<b>VerifSteps</b><br>Verification steps reduce risk"]
    CIRequired["<b>CIRequired</b><br>Successful verification required by continuous integration before deployment"]
    StaticVerif["<b>StaticVerif</b><br>Static verifications are performed"]
    DynamicVerif["<b>DynamicVerif</b><br>Dynamic verifications are performed"]
    CIConfigEv[("<b>CIConfigEv</b>&nbsp;↗<br>CI configuration")]
    StyleChecks["<b>StyleChecks</b><br>Style checks pass"]
    WeaknessAnalysis["<b>WeaknessAnalysis</b><br>Source code analyzed for weaknesses & all issues resolved"]
    FLOSSVerif["<b>FLOSSVerif</b><br>All reused components are verified as FLOSS"]
    TestCoverage["<b>TestCoverage</b><br>Automated testing performed with excellent statement coverage"]
    NegTests["<b>NegTests</b><br>Negative tests failed as desired"]
    StyleEv[("<b>StyleEv</b>&nbsp;↗<br>Style checkers as pronto runners in Gemfile: eslint, rails_best_practices, rubocop")]
    BrakemanEv[("<b>BrakemanEv</b>&nbsp;↗<br>Brakeman source code weakness analyzer")]
    LicenseFinderEv[("<b>LicenseFinderEv</b>&nbsp;↗<br>license_finder")]
    FOSSAEv[("<b>FOSSAEv</b>&nbsp;↗<br>FOSSA check")]
    CITestEv[("<b>CITestEv</b>&nbsp;↗<br>Automated tests run by CI")]
    NegTestsEv[("<b>NegTestsEv</b>&nbsp;↗<br>Negative test suite")]
    Dot1((" ")):::sacmDot
    Dot2((" ")):::sacmDot
    Dot3((" ")):::sacmDot
    Dot4((" ")):::sacmDot
    Dot5((" ")):::sacmDot
    click Verification "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-verification"
    click VerifStrat "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#strategy-verifstrat"
    click VerifSteps "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-verifsteps"
    click CIRequired "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-cirequired"
    click StaticVerif "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-staticverif"
    click DynamicVerif "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-dynamicverif"
    click CIConfigEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-ciconfigev"
    click StyleChecks "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-stylechecks"
    click WeaknessAnalysis "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-weaknessanalysis"
    click FLOSSVerif "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-flossverif"
    click TestCoverage "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-testcoverage"
    click NegTests "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-negtests"
    click StyleEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-styleev"
    click BrakemanEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-brakemanev"
    click LicenseFinderEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-licensefinderev"
    click FOSSAEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-fossaev"
    click CITestEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-citestev"
    click NegTestsEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-negtestsev"

    BottomPadding1["<br/><br/><br/>"]:::invisible ~~~~ VerifStrat
    BottomPadding2["<br/><br/><br/>"]:::invisible ~~~~ CIConfigEv
    BottomPadding3["<br/><br/><br/>"]:::invisible ~~~~ StyleEv
    BottomPadding4["<br/><br/><br/>"]:::invisible ~~~~ BrakemanEv
    BottomPadding5["<br/><br/><br/>"]:::invisible ~~~~ LicenseFinderEv
    BottomPadding6["<br/><br/><br/>"]:::invisible ~~~~ FOSSAEv
    BottomPadding7["<br/><br/><br/>"]:::invisible ~~~~ CITestEv
    BottomPadding8["<br/><br/><br/>"]:::invisible ~~~~ NegTestsEv
    StyleEv --> StyleChecks
    BrakemanEv --> WeaknessAnalysis
    LicenseFinderEv --- Dot1
    FOSSAEv --- Dot1
    Dot1 --> FLOSSVerif
    StyleChecks --- Dot2
    WeaknessAnalysis --- Dot2
    FLOSSVerif --- Dot2
    Dot2 --> StaticVerif
    CITestEv --> TestCoverage
    NegTestsEv --> NegTests
    TestCoverage --- Dot3
    NegTests --- Dot3
    Dot3 --> DynamicVerif
    StaticVerif --- Dot4
    DynamicVerif --- Dot4
    Dot4 --> VerifSteps
    CIConfigEv --> CIRequired
    VerifSteps --- Dot5
    CIRequired --- Dot5
    VerifStrat --- Dot5
    Dot5 --> Verification
```

Defines: **[Claim Verification](#claim-verification)**, [Strategy VerifStrat](#strategy-verifstrat), [Claim CIRequired](#claim-cirequired), [Evidence CIConfigEv](#evidence-ciconfigev), [Claim VerifSteps](#claim-verifsteps), [Claim DynamicVerif](#claim-dynamicverif), [Claim NegTests](#claim-negtests), [Evidence NegTestsEv](#evidence-negtestsev), [Claim TestCoverage](#claim-testcoverage), [Evidence CITestEv](#evidence-citestev), [Claim StaticVerif](#claim-staticverif), [Claim FLOSSVerif](#claim-flossverif), [Evidence FOSSAEv](#evidence-fossaev), [Evidence LicenseFinderEv](#evidence-licensefinderev), [Claim WeaknessAnalysis](#claim-weaknessanalysis), [Evidence BrakemanEv](#evidence-brakemanev), [Claim StyleChecks](#claim-stylechecks), [Evidence StyleEv](#evidence-styleev)

Cited by: [Package Security](#package-security)

<a id="package-deployment"></a>
### Package Deployment: Security in transition & operation

```mermaid
---
config:
  theme: neutral
  flowchart:
    curve: linear
    htmlLabels: true
    rankSpacing: 60
    nodeSpacing: 45
    padding: 15
---
flowchart BT
    classDef invisible opacity:0
    classDef sacmDot fill:#000,stroke:#000
    classDef connector fill:none,stroke:#cccccc,stroke-width:1px;
    classDef abstractClaim stroke-width:2px,stroke-dasharray: 5 5;
    Deployment["<b>Deployment</b><br>Security in transition & operation"]
    DeployProvider["<b>DeployProvider</b><br>Deployment provider maintains security"]
    Detection["<b>Detection</b><br>Threats and anomalies are detected"]
    OnlineCheckers["<b>OnlineCheckers</b><br>Online security checkers are used"]
    RecoveryPlan["<b>RecoveryPlan</b><br>Recovery plan including backups is in place"]
    HerokuSecEv[("<b>HerokuSecEv</b>&nbsp;↗<br>Heroku security policy describes physical and environmental safeguards")]
    ExtMonitor["<b>ExtMonitor</b><br>External monitoring is in place"]
    IntLogging["<b>IntLogging</b><br>Internal logging and anomaly detection is in place"]
    OnlineCheckersEv[("<b>OnlineCheckersEv</b>&nbsp;↗<br>Mozilla Observatory, Security Headers, and similar online tools verify HTTP response headers and flag misconfiguration")]
    RecoveryPlanEv[("<b>RecoveryPlanEv</b>&nbsp;↗<br>Recovery procedures documented including database restoration from Heroku Postgres backups, BADGEAPP_DENY_LOGIN degraded mode, and mass_email and rekey rake tasks")]
    ExtMonitorEv[("<b>ExtMonitorEv</b>&nbsp;↗<br>UptimeRobot provides external alerting when the website goes down")]
    IntLoggingEv[("<b>IntLoggingEv</b>&nbsp;↗<br>filter_parameter_logging.rb excludes passwords from logs; events stream to stdout per 12-factor app")]
    Dot1((" ")):::sacmDot
    Dot2((" ")):::sacmDot
    click Deployment "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-deployment"
    click DeployProvider "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-deployprovider"
    click Detection "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-detection"
    click OnlineCheckers "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-onlinecheckers"
    click RecoveryPlan "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-recoveryplan"
    click HerokuSecEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-herokusecev"
    click ExtMonitor "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-extmonitor"
    click IntLogging "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-intlogging"
    click OnlineCheckersEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-onlinecheckersev"
    click RecoveryPlanEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-recoveryplanev"
    click ExtMonitorEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-extmonitorev"
    click IntLoggingEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-intloggingev"

    BottomPadding1["<br/><br/><br/>"]:::invisible ~~~~ HerokuSecEv
    BottomPadding2["<br/><br/><br/>"]:::invisible ~~~~ OnlineCheckersEv
    BottomPadding3["<br/><br/><br/>"]:::invisible ~~~~ RecoveryPlanEv
    BottomPadding4["<br/><br/><br/>"]:::invisible ~~~~ ExtMonitorEv
    BottomPadding5["<br/><br/><br/>"]:::invisible ~~~~ IntLoggingEv
    HerokuSecEv --> DeployProvider
    ExtMonitorEv --> ExtMonitor
    IntLoggingEv --> IntLogging
    ExtMonitor --- Dot1
    IntLogging --- Dot1
    Dot1 --> Detection
    OnlineCheckersEv --> OnlineCheckers
    RecoveryPlanEv --> RecoveryPlan
    DeployProvider --- Dot2
    Detection --- Dot2
    OnlineCheckers --- Dot2
    RecoveryPlan --- Dot2
    Dot2 --> Deployment
```

Defines: **[Claim Deployment](#claim-deployment)**, [Claim RecoveryPlan](#claim-recoveryplan), [Evidence RecoveryPlanEv](#evidence-recoveryplanev), [Claim OnlineCheckers](#claim-onlinecheckers), [Evidence OnlineCheckersEv](#evidence-onlinecheckersev), [Claim Detection](#claim-detection), [Claim IntLogging](#claim-intlogging), [Evidence IntLoggingEv](#evidence-intloggingev), [Claim ExtMonitor](#claim-extmonitor), [Evidence ExtMonitorEv](#evidence-extmonitorev), [Claim DeployProvider](#claim-deployprovider), [Evidence HerokuSecEv](#evidence-herokusecev)

Cited by: [Package Security](#package-security)

<a id="package-maintenance"></a>
### Package Maintenance: Security in maintenance

```mermaid
---
config:
  theme: neutral
  flowchart:
    curve: linear
    htmlLabels: true
    rankSpacing: 60
    nodeSpacing: 45
    padding: 15
---
flowchart BT
    classDef invisible opacity:0
    classDef sacmDot fill:#000,stroke:#000
    classDef connector fill:none,stroke:#cccccc,stroke-width:1px;
    classDef abstractClaim stroke-width:2px,stroke-dasharray: 5 5;
    Maintenance["<b>Maintenance</b><br>Security in maintenance"]
    AutoDetect["<b>AutoDetect</b><br>Vulnerabilities are auto-detected when publicly reported"]
    RapidUpdate["<b>RapidUpdate</b><br>Rapid update process is in place"]
    AutoDetectBundleEv[("<b>AutoDetectBundleEv</b>&nbsp;↗<br>bundle-audit checks all gem versions against NVD vulnerability database on every rake run")]
    AutoDetectGitHubEv[("<b>AutoDetectGitHubEv</b>&nbsp;↗<br>GitHub Dependabot alerts and automated pull requests for vulnerable dependencies")]
    RapidUpdateEv[("<b>RapidUpdateEv</b>&nbsp;↗<br>Bundler enables library updates in one command; high test coverage enables rapid verify-and-deploy; CI/CD pipeline deploys to Heroku automatically on passing tests")]
    Dot1((" ")):::sacmDot
    Dot2((" ")):::sacmDot
    click Maintenance "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-maintenance"
    click AutoDetect "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-autodetect"
    click RapidUpdate "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-rapidupdate"
    click AutoDetectBundleEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-autodetectbundleev"
    click AutoDetectGitHubEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-autodetectgithubev"
    click RapidUpdateEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-rapidupdateev"

    BottomPadding1["<br/><br/><br/>"]:::invisible ~~~~ AutoDetectBundleEv
    BottomPadding2["<br/><br/><br/>"]:::invisible ~~~~ AutoDetectGitHubEv
    BottomPadding3["<br/><br/><br/>"]:::invisible ~~~~ RapidUpdateEv
    AutoDetectBundleEv --- Dot1
    AutoDetectGitHubEv --- Dot1
    Dot1 --> AutoDetect
    RapidUpdateEv --> RapidUpdate
    AutoDetect --- Dot2
    RapidUpdate --- Dot2
    Dot2 --> Maintenance
```

Defines: **[Claim Maintenance](#claim-maintenance)**, [Claim RapidUpdate](#claim-rapidupdate), [Evidence RapidUpdateEv](#evidence-rapidupdateev), [Claim AutoDetect](#claim-autodetect), [Evidence AutoDetectGitHubEv](#evidence-autodetectgithubev), [Evidence AutoDetectBundleEv](#evidence-autodetectbundleev)

Cited by: [Package Security](#package-security)

<a id="package-nontechnical"></a>
### Package NonTechnical: Security implemented by other life cycle processes

```mermaid
---
config:
  theme: neutral
  flowchart:
    curve: linear
    htmlLabels: true
    rankSpacing: 60
    nodeSpacing: 45
    padding: 15
---
flowchart BT
    classDef invisible opacity:0
    classDef sacmDot fill:#000,stroke:#000
    classDef connector fill:none,stroke:#cccccc,stroke-width:1px;
    classDef abstractClaim stroke-width:2px,stroke-dasharray: 5 5;
    NonTechnical["<b>NonTechnical</b><br>Security implemented by other life cycle processes"]
    AgreementProc["<b>AgreementProc</b><br>Agreement processes implement security"]
    OrgProc["<b>OrgProc</b><br>Organizational project-enabling processes implement security"]
    TechMgmt["<b>TechMgmt</b><br>Technical management processes implement security"]
    Acquisition["<b>Acquisition</b><br>Acquisition process implements security"]
    Infrastructure["<b>Infrastructure</b><br>Infrastructure management implements security"]
    HumanRes["<b>HumanRes</b><br>Human resource management implements security"]
    ProjectPlanning["<b>ProjectPlanning</b><br>Project planning addresses security"]
    RiskMgmt["<b>RiskMgmt</b><br>Risk management addresses security"]
    ConfigMgmt["<b>ConfigMgmt</b><br>Configuration management addresses security"]
    QA["<b>QA</b><br>Quality assurance addresses security"]
    Contracts["<b>Contracts</b><br>Contracts with deployment and CDN provider address security"]
    DevEnvSec["<b>DevEnvSec</b><br>Development & test environments are protected from attack"]
    CINoData["<b>CINoData</b><br>CI automated test environment does not contain protected data"]
    DevKnowledge["<b>DevKnowledge</b><br>Key developers know how to develop secure software"]
    ProjectPlanningEv[("<b>ProjectPlanningEv</b>&nbsp;↗<br>Project roadmap and governance prioritize security; long-term security maintenance documented as a goal")]
    RiskMgmtEv[("<b>RiskMgmtEv</b>&nbsp;↗<br>Continuous threat modeling implemented via this assurance case; regular dependency audits, static analysis, and security-focused development practices address identified risks")]
    ConfigMgmtEv[("<b>ConfigMgmtEv</b>&nbsp;↗<br>Git version control via GitHub with authenticated access; governance documented")]
    QAEv[("<b>QAEv</b>&nbsp;↗<br>CI pipeline runs rubocop, eslint, rails_best_practices, whitespace checks, and full test suite on every commit, enforcing quality and security standards")]
    ContractsEv[("<b>ContractsEv</b>&nbsp;↗<br>Heroku Data Processing Addendum and security policy cover deployment environment; Fastly service agreement covers CDN security")]
    DevEnvSecEv[("<b>DevEnvSecEv</b>&nbsp;↗<br>Development uses local git repositories; GitHub requires authenticated access; no production secrets stored in development environments; CI/CD pipeline validates branch names before use")]
    CINoDataEv[("<b>CINoDataEv</b>&nbsp;↗<br>CircleCI environment uses separate test database with no production data; production credentials never present in CI context; test database seeded only with synthetic test fixtures")]
    DevKnowledgeEv[("<b>DevKnowledgeEv</b>&nbsp;↗<br>Key developers have demonstrated expertise in secure software development including creation of OpenSSF Best Practices criteria, academic research on secure programming, and security-focused professional work")]
    Dot1((" ")):::sacmDot
    Dot2((" ")):::sacmDot
    Dot3((" ")):::sacmDot
    Dot4((" ")):::sacmDot
    click NonTechnical "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-nontechnical"
    click AgreementProc "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-agreementproc"
    click OrgProc "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-orgproc"
    click TechMgmt "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-techmgmt"
    click Acquisition "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-acquisition"
    click Infrastructure "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-infrastructure"
    click HumanRes "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-humanres"
    click ProjectPlanning "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-projectplanning"
    click RiskMgmt "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-riskmgmt"
    click ConfigMgmt "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-configmgmt"
    click QA "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-qa"
    click Contracts "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-contracts"
    click DevEnvSec "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-devenvsec"
    click CINoData "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-cinodata"
    click DevKnowledge "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-devknowledge"
    click ProjectPlanningEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-projectplanningev"
    click RiskMgmtEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-riskmgmtev"
    click ConfigMgmtEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-configmgmtev"
    click QAEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-qaev"
    click ContractsEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-contractsev"
    click DevEnvSecEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-devenvsecev"
    click CINoDataEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-cinodataev"
    click DevKnowledgeEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-devknowledgeev"

    BottomPadding1["<br/><br/><br/>"]:::invisible ~~~~ ProjectPlanningEv
    BottomPadding2["<br/><br/><br/>"]:::invisible ~~~~ RiskMgmtEv
    BottomPadding3["<br/><br/><br/>"]:::invisible ~~~~ ConfigMgmtEv
    BottomPadding4["<br/><br/><br/>"]:::invisible ~~~~ QAEv
    BottomPadding5["<br/><br/><br/>"]:::invisible ~~~~ ContractsEv
    BottomPadding6["<br/><br/><br/>"]:::invisible ~~~~ DevEnvSecEv
    BottomPadding7["<br/><br/><br/>"]:::invisible ~~~~ CINoDataEv
    BottomPadding8["<br/><br/><br/>"]:::invisible ~~~~ DevKnowledgeEv
    ContractsEv --> Contracts
    Contracts --> Acquisition
    Acquisition --> AgreementProc
    DevEnvSecEv --> DevEnvSec
    CINoDataEv --> CINoData
    DevEnvSec --- Dot1
    CINoData --- Dot1
    Dot1 --> Infrastructure
    DevKnowledgeEv --> DevKnowledge
    DevKnowledge --> HumanRes
    Infrastructure --- Dot2
    HumanRes --- Dot2
    Dot2 --> OrgProc
    ProjectPlanningEv --> ProjectPlanning
    RiskMgmtEv --> RiskMgmt
    ConfigMgmtEv --> ConfigMgmt
    QAEv --> QA
    ProjectPlanning --- Dot3
    RiskMgmt --- Dot3
    ConfigMgmt --- Dot3
    QA --- Dot3
    Dot3 --> TechMgmt
    AgreementProc --- Dot4
    OrgProc --- Dot4
    TechMgmt --- Dot4
    Dot4 --> NonTechnical
```

Defines: **[Claim NonTechnical](#claim-nontechnical)**, [Claim TechMgmt](#claim-techmgmt), [Claim QA](#claim-qa), [Evidence QAEv](#evidence-qaev), [Claim ConfigMgmt](#claim-configmgmt), [Evidence ConfigMgmtEv](#evidence-configmgmtev), [Claim RiskMgmt](#claim-riskmgmt), [Evidence RiskMgmtEv](#evidence-riskmgmtev), [Claim ProjectPlanning](#claim-projectplanning), [Evidence ProjectPlanningEv](#evidence-projectplanningev), [Claim OrgProc](#claim-orgproc), [Claim HumanRes](#claim-humanres), [Claim DevKnowledge](#claim-devknowledge), [Evidence DevKnowledgeEv](#evidence-devknowledgeev), [Claim Infrastructure](#claim-infrastructure), [Claim CINoData](#claim-cinodata), [Evidence CINoDataEv](#evidence-cinodataev), [Claim DevEnvSec](#claim-devenvsec), [Evidence DevEnvSecEv](#evidence-devenvsecev), [Claim AgreementProc](#claim-agreementproc), [Claim Acquisition](#claim-acquisition), [Claim Contracts](#claim-contracts), [Evidence ContractsEv](#evidence-contractsev)

Cited by: [Package Security](#package-security)

<a id="package-controls"></a>
### Package Controls: Certifications & controls provide confidence in operating results

```mermaid
---
config:
  theme: neutral
  flowchart:
    curve: linear
    htmlLabels: true
    rankSpacing: 60
    nodeSpacing: 45
    padding: 15
---
flowchart BT
    classDef invisible opacity:0
    classDef sacmDot fill:#000,stroke:#000
    classDef connector fill:none,stroke:#cccccc,stroke-width:1px;
    classDef abstractClaim stroke-width:2px,stroke-dasharray: 5 5;
    Controls["<b>Controls</b><br>Certifications & controls provide confidence in operating results"]
    CIIBadge["<b>CIIBadge</b><br>CII Best Practices Badge certification is obtained"]
    CIIBadgeEv[("<b>CIIBadgeEv</b>&nbsp;↗<br>BadgeApp achieves gold CII Best Practices Badge")]
    click Controls "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-controls"
    click CIIBadge "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-ciibadge"
    click CIIBadgeEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-ciibadgeev"

    BottomPadding1["<br/><br/><br/>"]:::invisible ~~~~ CIIBadgeEv
    CIIBadgeEv --> CIIBadge
    CIIBadge --> Controls
```

Defines: **[Claim Controls](#claim-controls)**, [Claim CIIBadge](#claim-ciibadge), [Evidence CIIBadgeEv](#evidence-ciibadgeev)

Cited by: [Package Security](#package-security)

<a id="package-owaspclaim"></a>
### Package OWASPClaim: All of the most common important implementation vulnerability types (weaknesses) countered

```mermaid
---
config:
  theme: neutral
  flowchart:
    curve: linear
    htmlLabels: true
    rankSpacing: 60
    nodeSpacing: 45
    padding: 15
---
flowchart BT
    classDef invisible opacity:0
    classDef sacmDot fill:#000,stroke:#000
    classDef connector fill:none,stroke:#cccccc,stroke-width:1px;
    classDef abstractClaim stroke-width:2px,stroke-dasharray: 5 5;
    OWASPClaim["<b>OWASPClaim</b><br>All of the most common important implementation vulnerability types (weaknesses) countered"]
    OWASPStrat[/"<b>OWASPStrat</b><br>OWASP top 10 represents a broad consensus of the most critical web application security flaws"/]
    OWASP1013["<b>OWASP1013</b><br>All OWASP top 10 (2013 & 2017) countered"]
    OWASP1["<b>OWASP1</b><br>Injection (including SQL injection) countered"]
    OWASP2["<b>OWASP2</b><br>Broken Authentication and Session Management countered"]
    OWASP3["<b>OWASP3</b><br>Cross-site scripting (XSS) countered"]
    _Connector_00000000((" ")):::connector
    OWASP11["<b>OWASP11</b><br>XXE countered (2017 A4)"]
    OWASP12["<b>OWASP12</b><br>Insecure Deserialization countered (2017 A8)"]
    OWASP13["<b>OWASP13</b><br>Insufficient Logging and Monitoring countered (2017 A10)"]
    OWASP1Ev[("<b>OWASP1Ev</b>&nbsp;↗<br>ActiveRecord ORM uses parameterized queries by default; direct SQL uses sanitize_sql_like or bound parameters; shell is never used to process untrusted content")]
    OWASP2Ev[("<b>OWASP2Ev</b>&nbsp;↗<br>Sessions use encrypted signed cookies; has_secure_password enforces bcrypt; remember-me uses bcrypt-stored nonce; session_store.rb configures secure cookie settings")]
    OWASP3Ev[("<b>OWASP3Ev</b>&nbsp;↗<br>Rails SafeBuffer escapes all template output by default; markdown processing whitelists safe tags and attributes; CSP enforced via secure_headers gem")]
    OWASP4["<b>OWASP4</b><br>Insecure Direct Object References countered"]
    OWASP5["<b>OWASP5</b><br>Security Misconfiguration countered"]
    OWASP6["<b>OWASP6</b><br>Sensitive Data Exposure countered"]
    OWASP7["<b>OWASP7</b><br>Missing Access Control countered"]
    OWASP8["<b>OWASP8</b><br>CSRF countered"]
    OWASP9["<b>OWASP9</b><br>Known Vulnerabilities countered"]
    OWASP10["<b>OWASP10</b><br>Unvalidated Redirects and Forwards countered"]
    OWASP11Ev[("<b>OWASP11Ev</b>&nbsp;↗<br>Nokogiri configured to disable external entity processing; XML parsing restricted to safe subset; SpecialAnalysis documents this exception")]
    OWASP12Ev[("<b>OWASP12Ev</b>&nbsp;↗<br>Rails session data stored in signed encrypted cookies; no untrusted object deserialization; JSON used for API data")]
    OWASP13Ev[("<b>OWASP13Ev</b>&nbsp;↗<br>filter_parameter_logging excludes passwords from logs; events stream to stdout per 12-factor app; UptimeRobot monitors availability externally")]
    OWASP4Ev[("<b>OWASP4Ev</b>&nbsp;↗<br>All project access goes through can_edit? and can_control? authorization checks; no direct object references exposed without authorization")]
    OWASP5Ev[("<b>OWASP5Ev</b>&nbsp;↗<br>secure_headers gem enforces HTTP security headers; Rails secrets managed via environment variables; CI runs security checks on every commit")]
    OWASP6Ev[("<b>OWASP6Ev</b>&nbsp;↗<br>Email encrypted with AES-256-GCM; passwords stored via bcrypt; all data in transit protected by TLS; filter_parameter_logging excludes sensitive fields from logs")]
    OWASP7Ev[("<b>OWASP7Ev</b>&nbsp;↗<br>can_edit? and can_control? enforced server-side on all mutating actions; no security decisions made client-side")]
    OWASP8Ev[("<b>OWASP8Ev</b>&nbsp;↗<br>protect_from_forgery with per-form tokens and origin-header check, enabled via load_defaults")]
    OWASP9BundleEv[("<b>OWASP9BundleEv</b>&nbsp;↗<br>bundle-audit checks all gems against NVD vulnerability database on every rake run")]
    OWASP9DependabotEv[("<b>OWASP9DependabotEv</b>&nbsp;↗<br>GitHub Dependabot alerts on vulnerable dependencies and opens PRs to update them")]
    OWASP10Ev[("<b>OWASP10Ev</b>&nbsp;↗<br>Redirect destinations validated against allowlists; no open redirect vulnerabilities; after-login redirect uses stored path validated server-side")]
    Dot1((" ")):::sacmDot
    Dot2((" ")):::sacmDot
    Dot3((" ")):::sacmDot
    click OWASPClaim "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-owaspclaim"
    click OWASPStrat "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#strategy-owaspstrat"
    click OWASP1013 "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-owasp1013"
    click OWASP1 "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-owasp1"
    click OWASP2 "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-owasp2"
    click OWASP3 "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-owasp3"
    click _Connector_00000000 "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#connector-_connector_00000000"
    click OWASP11 "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-owasp11"
    click OWASP12 "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-owasp12"
    click OWASP13 "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-owasp13"
    click OWASP1Ev "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-owasp1ev"
    click OWASP2Ev "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-owasp2ev"
    click OWASP3Ev "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-owasp3ev"
    click OWASP4 "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-owasp4"
    click OWASP5 "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-owasp5"
    click OWASP6 "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-owasp6"
    click OWASP7 "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-owasp7"
    click OWASP8 "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-owasp8"
    click OWASP9 "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-owasp9"
    click OWASP10 "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-owasp10"
    click OWASP11Ev "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-owasp11ev"
    click OWASP12Ev "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-owasp12ev"
    click OWASP13Ev "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-owasp13ev"
    click OWASP4Ev "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-owasp4ev"
    click OWASP5Ev "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-owasp5ev"
    click OWASP6Ev "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-owasp6ev"
    click OWASP7Ev "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-owasp7ev"
    click OWASP8Ev "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-owasp8ev"
    click OWASP9BundleEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-owasp9bundleev"
    click OWASP9DependabotEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-owasp9dependabotev"
    click OWASP10Ev "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-owasp10ev"

    BottomPadding1["<br/><br/><br/>"]:::invisible ~~~~ OWASPStrat
    BottomPadding2["<br/><br/><br/>"]:::invisible ~~~~ OWASP1Ev
    BottomPadding3["<br/><br/><br/>"]:::invisible ~~~~ OWASP2Ev
    BottomPadding4["<br/><br/><br/>"]:::invisible ~~~~ OWASP3Ev
    BottomPadding5["<br/><br/><br/>"]:::invisible ~~~~ OWASP11Ev
    BottomPadding6["<br/><br/><br/>"]:::invisible ~~~~ OWASP12Ev
    BottomPadding7["<br/><br/><br/>"]:::invisible ~~~~ OWASP13Ev
    BottomPadding8["<br/><br/><br/>"]:::invisible ~~~~ OWASP4Ev
    BottomPadding9["<br/><br/><br/>"]:::invisible ~~~~ OWASP5Ev
    BottomPadding10["<br/><br/><br/>"]:::invisible ~~~~ OWASP6Ev
    BottomPadding11["<br/><br/><br/>"]:::invisible ~~~~ OWASP7Ev
    BottomPadding12["<br/><br/><br/>"]:::invisible ~~~~ OWASP8Ev
    BottomPadding13["<br/><br/><br/>"]:::invisible ~~~~ OWASP9BundleEv
    BottomPadding14["<br/><br/><br/>"]:::invisible ~~~~ OWASP9DependabotEv
    BottomPadding15["<br/><br/><br/>"]:::invisible ~~~~ OWASP10Ev
    OWASP1Ev --> OWASP1
    OWASP2Ev --> OWASP2
    OWASP3Ev --> OWASP3
    OWASP4Ev --> OWASP4
    OWASP5Ev --> OWASP5
    OWASP6Ev --> OWASP6
    OWASP7Ev --> OWASP7
    OWASP8Ev --> OWASP8
    OWASP9BundleEv --- Dot1
    OWASP9DependabotEv --- Dot1
    Dot1 --> OWASP9
    OWASP10Ev --> OWASP10
    OWASP4 --- _Connector_00000000
    OWASP5 --- _Connector_00000000
    OWASP6 --- _Connector_00000000
    OWASP7 --- _Connector_00000000
    OWASP8 --- _Connector_00000000
    OWASP9 --- _Connector_00000000
    OWASP10 --- _Connector_00000000
    OWASP11Ev --> OWASP11
    OWASP12Ev --> OWASP12
    OWASP13Ev --> OWASP13
    OWASP1 --- Dot2
    OWASP2 --- Dot2
    OWASP3 --- Dot2
    _Connector_00000000 --- Dot2
    OWASP11 --- Dot2
    OWASP12 --- Dot2
    OWASP13 --- Dot2
    Dot2 --> OWASP1013
    OWASP1013 --- Dot3
    OWASPStrat --- Dot3
    Dot3 --> OWASPClaim
```

Defines: **[Claim OWASPClaim](#claim-owaspclaim)**, [Strategy OWASPStrat](#strategy-owaspstrat), [Claim OWASP1013](#claim-owasp1013), [Claim OWASP13](#claim-owasp13), [Evidence OWASP13Ev](#evidence-owasp13ev), [Claim OWASP12](#claim-owasp12), [Evidence OWASP12Ev](#evidence-owasp12ev), [Claim OWASP11](#claim-owasp11), [Evidence OWASP11Ev](#evidence-owasp11ev), [Claim OWASP10](#claim-owasp10), [Evidence OWASP10Ev](#evidence-owasp10ev), [Claim OWASP9](#claim-owasp9), [Evidence OWASP9DependabotEv](#evidence-owasp9dependabotev), [Evidence OWASP9BundleEv](#evidence-owasp9bundleev), [Claim OWASP8](#claim-owasp8), [Evidence OWASP8Ev](#evidence-owasp8ev), [Claim OWASP7](#claim-owasp7), [Evidence OWASP7Ev](#evidence-owasp7ev), [Claim OWASP6](#claim-owasp6), [Evidence OWASP6Ev](#evidence-owasp6ev), [Claim OWASP5](#claim-owasp5), [Evidence OWASP5Ev](#evidence-owasp5ev), [Claim OWASP4](#claim-owasp4), [Evidence OWASP4Ev](#evidence-owasp4ev), [Claim OWASP3](#claim-owasp3), [Evidence OWASP3Ev](#evidence-owasp3ev), [Claim OWASP2](#claim-owasp2), [Evidence OWASP2Ev](#evidence-owasp2ev), [Claim OWASP1](#claim-owasp1), [Evidence OWASP1Ev](#evidence-owasp1ev)

Cited by: [Package Implementation](#package-implementation)

<a id="package-hardening"></a>
### Package Hardening: Hardening is applied

```mermaid
---
config:
  theme: neutral
  flowchart:
    curve: linear
    htmlLabels: true
    rankSpacing: 60
    nodeSpacing: 45
    padding: 15
---
flowchart BT
    classDef invisible opacity:0
    classDef sacmDot fill:#000,stroke:#000
    classDef connector fill:none,stroke:#cccccc,stroke-width:1px;
    classDef abstractClaim stroke-width:2px,stroke-dasharray: 5 5;
    Hardening["<b>Hardening</b><br>Hardening is applied"]
    HardenHTTPS["<b>HardenHTTPS</b><br>HTTPS use enforced (including by HSTS)"]
    HardenCSP["<b>HardenCSP</b><br>Outgoing HTTP headers hardened including restrictive CSP"]
    HardenCookies["<b>HardenCookies</b><br>Cookies limited"]
    HardenCSRF["<b>HardenCSRF</b><br>CSRF tokens hardened"]
    HardenRateIn["<b>HardenRateIn</b><br>Incoming rate limits enforced"]
    HardenRateOut["<b>HardenRateOut</b><br>Outgoing email rate limits enforced"]
    HardenEmailEnc["<b>HardenEmailEnc</b><br>Email addresses encrypted"]
    HardenGravatar["<b>HardenGravatar</b><br>Gravatar restricted"]
    HardenHTTPSEv[("<b>HardenHTTPSEv</b>&nbsp;↗<br>config.force_ssl enables TLS redirection, secure cookies, and HSTS; domain in Chrome HSTS preload list")]
    HardenCSPEv[("<b>HardenCSPEv</b>&nbsp;↗<br>secure_headers gem enforces CSP and security headers; integration test verifies header values")]
    HardenCookiesEv[("<b>HardenCookiesEv</b>&nbsp;↗<br>secure_headers gem sets httponly, secure, and SameSite=Lax cookie attributes; session cookies use AES-256-GCM")]
    HardenCSRFEv[("<b>HardenCSRFEv</b>&nbsp;↗<br>protect_from_forgery with per-form tokens and origin-header check, enabled via load_defaults")]
    HardenRateInEv[("<b>HardenRateInEv</b>&nbsp;↗<br>Rack::Attack rate limits on requests, logins, and signups by client IP address")]
    HardenRateOutEv[("<b>HardenRateOutEv</b>&nbsp;↗<br>projects_to_remind class method and hard limit on outgoing reminder email count")]
    HardenEmailEncEv[("<b>HardenEmailEncEv</b>&nbsp;↗<br>attr_encrypted and blind_index gems encrypt email addresses with AES-256-GCM and PBKDF2-HMAC-SHA256 index")]
    HardenGravatarEv[("<b>HardenGravatarEv</b>&nbsp;↗<br>use_gravatar boolean controls whether gravatar MD5 hash is revealed for each local user")]
    Dot1((" ")):::sacmDot
    click Hardening "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-hardening"
    click HardenHTTPS "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-hardenhttps"
    click HardenCSP "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-hardencsp"
    click HardenCookies "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-hardencookies"
    click HardenCSRF "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-hardencsrf"
    click HardenRateIn "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-hardenratein"
    click HardenRateOut "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-hardenrateout"
    click HardenEmailEnc "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-hardenemailenc"
    click HardenGravatar "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-hardengravatar"
    click HardenHTTPSEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-hardenhttpsev"
    click HardenCSPEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-hardencspev"
    click HardenCookiesEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-hardencookiesev"
    click HardenCSRFEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-hardencsrfev"
    click HardenRateInEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-hardenrateinev"
    click HardenRateOutEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-hardenrateoutev"
    click HardenEmailEncEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-hardenemailencev"
    click HardenGravatarEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-hardengravatarev"

    BottomPadding1["<br/><br/><br/>"]:::invisible ~~~~ HardenHTTPSEv
    BottomPadding2["<br/><br/><br/>"]:::invisible ~~~~ HardenCSPEv
    BottomPadding3["<br/><br/><br/>"]:::invisible ~~~~ HardenCookiesEv
    BottomPadding4["<br/><br/><br/>"]:::invisible ~~~~ HardenCSRFEv
    BottomPadding5["<br/><br/><br/>"]:::invisible ~~~~ HardenRateInEv
    BottomPadding6["<br/><br/><br/>"]:::invisible ~~~~ HardenRateOutEv
    BottomPadding7["<br/><br/><br/>"]:::invisible ~~~~ HardenEmailEncEv
    BottomPadding8["<br/><br/><br/>"]:::invisible ~~~~ HardenGravatarEv
    HardenHTTPSEv --> HardenHTTPS
    HardenCSPEv --> HardenCSP
    HardenCookiesEv --> HardenCookies
    HardenCSRFEv --> HardenCSRF
    HardenRateInEv --> HardenRateIn
    HardenRateOutEv --> HardenRateOut
    HardenEmailEncEv --> HardenEmailEnc
    HardenGravatarEv --> HardenGravatar
    HardenHTTPS --- Dot1
    HardenCSP --- Dot1
    HardenCookies --- Dot1
    HardenCSRF --- Dot1
    HardenRateIn --- Dot1
    HardenRateOut --- Dot1
    HardenEmailEnc --- Dot1
    HardenGravatar --- Dot1
    Dot1 --> Hardening
```

Defines: **[Claim Hardening](#claim-hardening)**, [Claim HardenGravatar](#claim-hardengravatar), [Evidence HardenGravatarEv](#evidence-hardengravatarev), [Claim HardenEmailEnc](#claim-hardenemailenc), [Evidence HardenEmailEncEv](#evidence-hardenemailencev), [Claim HardenRateOut](#claim-hardenrateout), [Evidence HardenRateOutEv](#evidence-hardenrateoutev), [Claim HardenRateIn](#claim-hardenratein), [Evidence HardenRateInEv](#evidence-hardenrateinev), [Claim HardenCSRF](#claim-hardencsrf), [Evidence HardenCSRFEv](#evidence-hardencsrfev), [Claim HardenCookies](#claim-hardencookies), [Evidence HardenCookiesEv](#evidence-hardencookiesev), [Claim HardenCSP](#claim-hardencsp), [Evidence HardenCSPEv](#evidence-hardencspev), [Claim HardenHTTPS](#claim-hardenhttps), [Evidence HardenHTTPSEv](#evidence-hardenhttpsev)

Cited by: [Package Implementation](#package-implementation)

<a id="package-confidentiality"></a>
### Package Confidentiality: Confidentiality is maintained

```mermaid
---
config:
  theme: neutral
  flowchart:
    curve: linear
    htmlLabels: true
    rankSpacing: 60
    nodeSpacing: 45
    padding: 15
---
flowchart BT
    classDef invisible opacity:0
    classDef sacmDot fill:#000,stroke:#000
    classDef connector fill:none,stroke:#cccccc,stroke-width:1px;
    classDef abstractClaim stroke-width:2px,stroke-dasharray: 5 5;
    Confidentiality["<b>Confidentiality</b><br>Confidentiality is maintained"]
    NonPublicData["<b>NonPublicData</b><br>Non-public data is kept confidential"]
    UserPrivacy["<b>UserPrivacy</b><br>User privacy is maintained"]
    MostDataPublic["<b>MostDataPublic</b><br>Almost all data is not confidential<br>━━━"]
    ConfDataAtRest["<b>ConfDataAtRest</b><br>Confidential data at rest is protected"]
    DataInMotion["<b>DataInMotion</b><br>Data in motion encrypted with HTTPS"]
    SelfHostedAssets["<b>SelfHostedAssets</b><br>All web assets are self-hosted; no third-party transclusions reveal user activity to unrelated sites"]
    GravatarPrivacyEv[("<b>GravatarPrivacyEv</b>&nbsp;↗<br>use_gravatar boolean controls whether any MD5 hash is sent to Gravatar, giving each user control over this external disclosure")]
    Passwords["<b>Passwords</b><br>User passwords stored securely (using bcrypt)"]
    RememberMe["<b>RememberMe</b><br>Remember me token is secured"]
    EmailSecured["<b>EmailSecured</b><br>Email addresses are secured (encrypted and only accessible to admin & owner)"]
    DataInMotionEv[("<b>DataInMotionEv</b>&nbsp;↗<br>config.force_ssl = true enforces HTTPS with TLS redirection and secure cookies in production")]
    SelfHostedAssetsEv[("<b>SelfHostedAssetsEv</b>&nbsp;↗<br>Content-Security-Policy restricts script-src and style-src to self; application layouts contain no external CDN script or font references")]
    PasswordsEv[("<b>PasswordsEv</b>&nbsp;↗<br>has_secure_password in user model stores passwords via bcrypt")]
    RememberMeEv[("<b>RememberMeEv</b>&nbsp;↗<br>remember method in user model creates bcrypt-stored nonce; sessions controller and helper manage it; login test verifies cleartext not stored in cookie")]
    EmailSecuredEv[("<b>EmailSecuredEv</b>&nbsp;↗<br>Views, mailers, and controllers restrict email address access to owners and admins; use grep -Ri 'user.*\.email' to verify")]
    Dot1((" ")):::sacmDot
    Dot2((" ")):::sacmDot
    Dot3((" ")):::sacmDot
    Dot4((" ")):::sacmDot
    click Confidentiality "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-confidentiality"
    click NonPublicData "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-nonpublicdata"
    click UserPrivacy "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-userprivacy"
    click MostDataPublic "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-mostdatapublic"
    click ConfDataAtRest "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-confdataatrest"
    click DataInMotion "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-datainmotion"
    click SelfHostedAssets "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-selfhostedassets"
    click GravatarPrivacyEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-gravatarprivacyev"
    click Passwords "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-passwords"
    click RememberMe "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-rememberme"
    click EmailSecured "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-emailsecured"
    click DataInMotionEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-datainmotionev"
    click SelfHostedAssetsEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-selfhostedassetsev"
    click PasswordsEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-passwordsev"
    click RememberMeEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-remembermeev"
    click EmailSecuredEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-emailsecuredev"

    BottomPadding1["<br/><br/><br/>"]:::invisible ~~~~ MostDataPublic
    BottomPadding2["<br/><br/><br/>"]:::invisible ~~~~ GravatarPrivacyEv
    BottomPadding3["<br/><br/><br/>"]:::invisible ~~~~ DataInMotionEv
    BottomPadding4["<br/><br/><br/>"]:::invisible ~~~~ SelfHostedAssetsEv
    BottomPadding5["<br/><br/><br/>"]:::invisible ~~~~ PasswordsEv
    BottomPadding6["<br/><br/><br/>"]:::invisible ~~~~ RememberMeEv
    BottomPadding7["<br/><br/><br/>"]:::invisible ~~~~ EmailSecuredEv
    PasswordsEv --> Passwords
    RememberMeEv --> RememberMe
    EmailSecuredEv --> EmailSecured
    Passwords --- Dot1
    RememberMe --- Dot1
    EmailSecured --- Dot1
    Dot1 --> ConfDataAtRest
    DataInMotionEv --> DataInMotion
    ConfDataAtRest --- Dot2
    DataInMotion --- Dot2
    Dot2 --> NonPublicData
    SelfHostedAssetsEv --> SelfHostedAssets
    SelfHostedAssets --- Dot3
    GravatarPrivacyEv --- Dot3
    Dot3 --> UserPrivacy
    NonPublicData --- Dot4
    UserPrivacy --- Dot4
    MostDataPublic --- Dot4
    Dot4 --> Confidentiality
```

Defines: **[Claim Confidentiality](#claim-confidentiality)**, [Claim MostDataPublic](#claim-mostdatapublic), [Claim UserPrivacy](#claim-userprivacy), [Evidence GravatarPrivacyEv](#evidence-gravatarprivacyev), [Claim SelfHostedAssets](#claim-selfhostedassets), [Evidence SelfHostedAssetsEv](#evidence-selfhostedassetsev), [Claim NonPublicData](#claim-nonpublicdata), [Claim DataInMotion](#claim-datainmotion), [Evidence DataInMotionEv](#evidence-datainmotionev), [Claim ConfDataAtRest](#claim-confdataatrest), [Claim EmailSecured](#claim-emailsecured), [Evidence EmailSecuredEv](#evidence-emailsecuredev), [Claim RememberMe](#claim-rememberme), [Evidence RememberMeEv](#evidence-remembermeev), [Claim Passwords](#claim-passwords), [Evidence PasswordsEv](#evidence-passwordsev)

Cited by: [Package Requirements](#package-requirements)

<a id="package-availability"></a>
### Package Availability: Availability is maintained including limited DDoS resilience

```mermaid
---
config:
  theme: neutral
  flowchart:
    curve: linear
    htmlLabels: true
    rankSpacing: 60
    nodeSpacing: 45
    padding: 15
---
flowchart BT
    classDef invisible opacity:0
    classDef sacmDot fill:#000,stroke:#000
    classDef connector fill:none,stroke:#cccccc,stroke-width:1px;
    classDef abstractClaim stroke-width:2px,stroke-dasharray: 5 5;
    Availability["<b>Availability</b><br>Availability is maintained including limited DDoS resilience"]
    CDNDDoS["<b>CDNDDoS</b><br>CDN counters DDoS attacks on specific resources"]
    Timeout["<b>Timeout</b><br>Timeout limits maximum request time"]
    QuickRecovery["<b>QuickRecovery</b><br>Can return to operation quickly after DDoS ended"]
    LoginDisabled["<b>LoginDisabled</b><br>Logon disabled mode mitigates against some vulnerabilities"]
    Backups["<b>Backups</b><br>Data corruption and loss are mitigated by multiple backups"]
    ScaleUp["<b>ScaleUp</b><br>Cloud resources can be rapidly increased"]
    FastlyCDNEv[("<b>FastlyCDNEv</b>&nbsp;↗<br>Fastly CDN configured as reverse proxy; badge image and static asset requests absorbed by CDN before reaching origin application server")]
    TimeoutEv[("<b>TimeoutEv</b>&nbsp;↗<br>Rack::Timeout.service_timeout set in production configuration limits all request times")]
    QuickRecoveryEv[("<b>QuickRecoveryEv</b>&nbsp;↗<br>Heroku allows rapid dyno restart and redeploy from last known good git commit, restoring service within minutes of an incident")]
    LoginDisabledEv[("<b>LoginDisabledEv</b>&nbsp;↗<br>deny_login initializer reads BADGEAPP_DENY_LOGIN env var to disable all logins")]
    BackupsEv[("<b>BackupsEv</b>&nbsp;↗<br>Heroku Postgres automated daily backups retained across multiple snapshots; standard Rails and PostgreSQL restore mechanisms enable database recovery")]
    ScaleUpEv[("<b>ScaleUpEv</b>&nbsp;↗<br>Heroku cloud platform supports on-demand dyno scaling; Fastly CDN reduces origin load during traffic spikes")]
    Dot1((" ")):::sacmDot
    click Availability "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-availability"
    click CDNDDoS "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-cdnddos"
    click Timeout "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-timeout"
    click QuickRecovery "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-quickrecovery"
    click LoginDisabled "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-logindisabled"
    click Backups "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-backups"
    click ScaleUp "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-scaleup"
    click FastlyCDNEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-fastlycdnev"
    click TimeoutEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-timeoutev"
    click QuickRecoveryEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-quickrecoveryev"
    click LoginDisabledEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-logindisabledev"
    click BackupsEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-backupsev"
    click ScaleUpEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-scaleupev"

    BottomPadding1["<br/><br/><br/>"]:::invisible ~~~~ FastlyCDNEv
    BottomPadding2["<br/><br/><br/>"]:::invisible ~~~~ TimeoutEv
    BottomPadding3["<br/><br/><br/>"]:::invisible ~~~~ QuickRecoveryEv
    BottomPadding4["<br/><br/><br/>"]:::invisible ~~~~ LoginDisabledEv
    BottomPadding5["<br/><br/><br/>"]:::invisible ~~~~ BackupsEv
    BottomPadding6["<br/><br/><br/>"]:::invisible ~~~~ ScaleUpEv
    FastlyCDNEv --> CDNDDoS
    TimeoutEv --> Timeout
    QuickRecoveryEv --> QuickRecovery
    LoginDisabledEv --> LoginDisabled
    BackupsEv --> Backups
    ScaleUpEv --> ScaleUp
    CDNDDoS --- Dot1
    Timeout --- Dot1
    QuickRecovery --- Dot1
    LoginDisabled --- Dot1
    Backups --- Dot1
    ScaleUp --- Dot1
    Dot1 --> Availability
```

Defines: **[Claim Availability](#claim-availability)**, [Claim ScaleUp](#claim-scaleup), [Evidence ScaleUpEv](#evidence-scaleupev), [Claim Backups](#claim-backups), [Evidence BackupsEv](#evidence-backupsev), [Claim LoginDisabled](#claim-logindisabled), [Evidence LoginDisabledEv](#evidence-logindisabledev), [Claim QuickRecovery](#claim-quickrecovery), [Evidence QuickRecoveryEv](#evidence-quickrecoveryev), [Claim Timeout](#claim-timeout), [Evidence TimeoutEv](#evidence-timeoutev), [Claim CDNDDoS](#claim-cdnddos), [Evidence FastlyCDNEv](#evidence-fastlycdnev)

Cited by: [Package Requirements](#package-requirements)

<a id="package-designprinciples"></a>
### Package DesignPrinciples: Secure design principles are applied

```mermaid
---
config:
  theme: neutral
  flowchart:
    curve: linear
    htmlLabels: true
    rankSpacing: 60
    nodeSpacing: 45
    padding: 15
---
flowchart BT
    classDef invisible opacity:0
    classDef sacmDot fill:#000,stroke:#000
    classDef connector fill:none,stroke:#cccccc,stroke-width:1px;
    classDef abstractClaim stroke-width:2px,stroke-dasharray: 5 5;
    DesignPrinciples["<b>DesignPrinciples</b><br>Secure design principles are applied"]
    EconomyMech["<b>EconomyMech</b><br>Economy of mechanism"]
    CompleteMed["<b>CompleteMed</b><br>Complete mediation"]
    FailSafe["<b>FailSafe</b><br>Fail-safe defaults"]
    _Connector_00000000((" ")):::connector
    PsychAccept["<b>PsychAccept</b><br>Psychological acceptability"]
    LimitedAttack["<b>LimitedAttack</b><br>Limited attack surface"]
    InputValid["<b>InputValid</b><br>Input validation with whitelists"]
    EconomyMechEv[("<b>EconomyMechEv</b>&nbsp;↗<br>Custom code kept minimal and DRY; standard Rails patterns used; Gemfile shows focused, well-scoped dependency set")]
    CompleteMedEv[("<b>CompleteMedEv</b>&nbsp;↗<br>before_action authorization hooks in ApplicationController run on every request; no client-side access control decisions are made")]
    FailSafeEv[("<b>FailSafeEv</b>&nbsp;↗<br>can_edit_else_redirect and can_control_else_redirect redirect unauthenticated or unauthorized requests; default deny enforced server-side")]
    OpenDesign["<b>OpenDesign</b><br>Open design"]
    SepPriv["<b>SepPriv</b><br>Separation of privilege"]
    LeastPriv["<b>LeastPriv</b><br>Least privilege"]
    LeastCommon["<b>LeastCommon</b><br>Least common mechanism"]
    PsychAcceptEv[("<b>PsychAcceptEv</b>&nbsp;↗<br>Standard web authentication UX (email/password or GitHub OAuth login); badge criteria presented in plain language; security controls do not impose undue burden on legitimate use")]
    LimitedAttackEv[("<b>LimitedAttackEv</b>&nbsp;↗<br>Restrictive CSP limits script execution sources; routes.rb exposes only necessary endpoints; Rack::Attack blocks abusive IPs")]
    InputValidEv[("<b>InputValidEv</b>&nbsp;↗<br>Project and User models use Rails validators to enforce field constraints; controllers use strong parameters (permit) to whitelist allowed input fields")]
    OpenDesignEv[("<b>OpenDesignEv</b>&nbsp;↗<br>Full source code publicly available; security does not depend on keeping implementation secret")]
    SepPrivEv[("<b>SepPrivEv</b>&nbsp;↗<br>admin? method in User model separates admin role from normal user; admin-only actions checked explicitly and separately from ownership")]
    LeastPrivEv[("<b>LeastPrivEv</b>&nbsp;↗<br>can_edit? grants edit access only to project owner or admins; additional_rights table enables explicit narrow collaborator grants")]
    LeastCommonEv[("<b>LeastCommonEv</b>&nbsp;↗<br>Per-request processing; session state stored in per-user encrypted client-side cookies, not shared server-side sessions")]
    Dot1((" ")):::sacmDot
    click DesignPrinciples "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-designprinciples"
    click EconomyMech "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-economymech"
    click CompleteMed "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-completemed"
    click FailSafe "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-failsafe"
    click _Connector_00000000 "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#connector-_connector_00000000"
    click PsychAccept "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-psychaccept"
    click LimitedAttack "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-limitedattack"
    click InputValid "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-inputvalid"
    click EconomyMechEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-economymechev"
    click CompleteMedEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-completemedev"
    click FailSafeEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-failsafeev"
    click OpenDesign "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-opendesign"
    click SepPriv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-seppriv"
    click LeastPriv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-leastpriv"
    click LeastCommon "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-leastcommon"
    click PsychAcceptEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-psychacceptev"
    click LimitedAttackEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-limitedattackev"
    click InputValidEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-inputvalidev"
    click OpenDesignEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-opendesignev"
    click SepPrivEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-sepprivev"
    click LeastPrivEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-leastprivev"
    click LeastCommonEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-leastcommonev"

    BottomPadding1["<br/><br/><br/>"]:::invisible ~~~~ EconomyMechEv
    BottomPadding2["<br/><br/><br/>"]:::invisible ~~~~ CompleteMedEv
    BottomPadding3["<br/><br/><br/>"]:::invisible ~~~~ FailSafeEv
    BottomPadding4["<br/><br/><br/>"]:::invisible ~~~~ PsychAcceptEv
    BottomPadding5["<br/><br/><br/>"]:::invisible ~~~~ LimitedAttackEv
    BottomPadding6["<br/><br/><br/>"]:::invisible ~~~~ InputValidEv
    BottomPadding7["<br/><br/><br/>"]:::invisible ~~~~ OpenDesignEv
    BottomPadding8["<br/><br/><br/>"]:::invisible ~~~~ SepPrivEv
    BottomPadding9["<br/><br/><br/>"]:::invisible ~~~~ LeastPrivEv
    BottomPadding10["<br/><br/><br/>"]:::invisible ~~~~ LeastCommonEv
    EconomyMechEv --> EconomyMech
    CompleteMedEv --> CompleteMed
    FailSafeEv --> FailSafe
    OpenDesignEv --> OpenDesign
    SepPrivEv --> SepPriv
    LeastPrivEv --> LeastPriv
    LeastCommonEv --> LeastCommon
    OpenDesign --- _Connector_00000000
    SepPriv --- _Connector_00000000
    LeastPriv --- _Connector_00000000
    LeastCommon --- _Connector_00000000
    PsychAcceptEv --> PsychAccept
    LimitedAttackEv --> LimitedAttack
    InputValidEv --> InputValid
    EconomyMech --- Dot1
    CompleteMed --- Dot1
    FailSafe --- Dot1
    _Connector_00000000 --- Dot1
    PsychAccept --- Dot1
    LimitedAttack --- Dot1
    InputValid --- Dot1
    Dot1 --> DesignPrinciples
```

Defines: **[Claim DesignPrinciples](#claim-designprinciples)**, [Claim InputValid](#claim-inputvalid), [Evidence InputValidEv](#evidence-inputvalidev), [Claim LimitedAttack](#claim-limitedattack), [Evidence LimitedAttackEv](#evidence-limitedattackev), [Claim PsychAccept](#claim-psychaccept), [Evidence PsychAcceptEv](#evidence-psychacceptev), [Claim LeastCommon](#claim-leastcommon), [Evidence LeastCommonEv](#evidence-leastcommonev), [Claim LeastPriv](#claim-leastpriv), [Evidence LeastPrivEv](#evidence-leastprivev), [Claim SepPriv](#claim-seppriv), [Evidence SepPrivEv](#evidence-sepprivev), [Claim OpenDesign](#claim-opendesign), [Evidence OpenDesignEv](#evidence-opendesignev), [Claim FailSafe](#claim-failsafe), [Evidence FailSafeEv](#evidence-failsafeev), [Claim CompleteMed](#claim-completemed), [Evidence CompleteMedEv](#evidence-completemedev), [Claim EconomyMech](#claim-economymech), [Evidence EconomyMechEv](#evidence-economymechev)

Cited by: [Package Design](#package-design)

<a id="package-reusesec"></a>
### Package ReuseSec: Reused software is secure

```mermaid
---
config:
  theme: neutral
  flowchart:
    curve: linear
    htmlLabels: true
    rankSpacing: 60
    nodeSpacing: 45
    padding: 15
---
flowchart BT
    classDef invisible opacity:0
    classDef sacmDot fill:#000,stroke:#000
    classDef connector fill:none,stroke:#cccccc,stroke-width:1px;
    classDef abstractClaim stroke-width:2px,stroke-dasharray: 5 5;
    ReuseSec["<b>ReuseSec</b><br>Reused software is secure"]
    ReuseStrat[/"<b>ReuseStrat</b><br>Reuse is often appropriate and can be done securely"/]
    KnownVulns["<b>KnownVulns</b><br>Known vulnerabilities in reused components are detected"]
    ReuseReview["<b>ReuseReview</b><br>Reused software is reviewed before use"]
    ReuseAuth["<b>ReuseAuth</b><br>Reused software is authentic"]
    PkgMgr["<b>PkgMgr</b><br>Package managers used"]
    SpecialAnalysis["<b>SpecialAnalysis</b><br>Special analysis justifies exceptions"]
    KnownVulnsBundleEv[("<b>KnownVulnsBundleEv</b>&nbsp;↗<br>bundle-audit checks all gem versions against the NVD on every rake run, detecting known CVEs in dependencies")]
    KnownVulnsDependabotEv[("<b>KnownVulnsDependabotEv</b>&nbsp;↗<br>GitHub Dependabot automatically alerts on vulnerable gem dependencies and opens PRs with updated versions")]
    ReuseReviewEv[("<b>ReuseReviewEv</b>&nbsp;↗<br>New gem dependencies reviewed for purpose, maintenance, and security before addition; CONTRIBUTING.md documents review expectations")]
    ReuseAuthEv[("<b>ReuseAuthEv</b>&nbsp;↗<br>Gemfile.lock records exact versions and SHA-512 checksums for all gems, ensuring reproducible authenticated builds")]
    PkgMgrEv[("<b>PkgMgrEv</b>&nbsp;↗<br>Gemfile and Gemfile.lock manage all gem dependencies via bundler")]
    XXESafe["<b>XXESafe</b><br>Nokogiri/libxml2 XXE exception (CVE-2016-9318) poses no risk in our deployment"]
    ErubisSafe["<b>ErubisSafe</b><br>XSS from erubis via pronto-rails_best_practices poses no production risk"]
    LocalSecretSafe["<b>LocalSecretSafe</b><br>Checked-in tmp/local_secret.txt secret_key_base value poses no security risk"]
    ActionCableSafe["<b>ActionCableSafe</b><br>ActionCable information-exposure risk is mitigated because ActionCable is not used"]
    XXESafeEv[("<b>XXESafeEv</b>&nbsp;↗<br>Nokogiri disables DTD loading and network access by default; we never process incoming XML in production; loofah never opts into DTDLOAD or NONET")]
    ErubisSafeEv[("<b>ErubisSafeEv</b>&nbsp;↗<br>rails_best_practices and pronto are dev/test-only dependencies; they never execute against untrusted input in production")]
    LocalSecretSafeEv[("<b>LocalSecretSafeEv</b>&nbsp;↗<br>The file is only used in development and test; production always uses the SECRET_KEY_BASE environment variable; the checked-in value protects no real secrets")]
    ActionCableSafeEv[("<b>ActionCableSafeEv</b>&nbsp;↗<br>ActionCable is a Rails transitive dependency but is never configured or invoked; no sensitive data flows through it")]
    Dot1((" ")):::sacmDot
    Dot2((" ")):::sacmDot
    Dot3((" ")):::sacmDot
    click ReuseSec "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-reusesec"
    click ReuseStrat "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#strategy-reusestrat"
    click KnownVulns "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-knownvulns"
    click ReuseReview "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-reusereview"
    click ReuseAuth "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-reuseauth"
    click PkgMgr "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-pkgmgr"
    click SpecialAnalysis "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-specialanalysis"
    click KnownVulnsBundleEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-knownvulnsbundleev"
    click KnownVulnsDependabotEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-knownvulnsdependabotev"
    click ReuseReviewEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-reusereviewev"
    click ReuseAuthEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-reuseauthev"
    click PkgMgrEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-pkgmgrev"
    click XXESafe "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-xxesafe"
    click ErubisSafe "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-erubissafe"
    click LocalSecretSafe "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-localsecretsafe"
    click ActionCableSafe "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#claim-actioncablesafe"
    click XXESafeEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-xxesafeev"
    click ErubisSafeEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-erubissafeev"
    click LocalSecretSafeEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-localsecretsafeev"
    click ActionCableSafeEv "https://github.com/ossf/best-practices-badge/blob/main/docs/case.md#evidence-actioncablesafeev"

    BottomPadding1["<br/><br/><br/>"]:::invisible ~~~~ ReuseStrat
    BottomPadding2["<br/><br/><br/>"]:::invisible ~~~~ KnownVulnsBundleEv
    BottomPadding3["<br/><br/><br/>"]:::invisible ~~~~ KnownVulnsDependabotEv
    BottomPadding4["<br/><br/><br/>"]:::invisible ~~~~ ReuseReviewEv
    BottomPadding5["<br/><br/><br/>"]:::invisible ~~~~ ReuseAuthEv
    BottomPadding6["<br/><br/><br/>"]:::invisible ~~~~ PkgMgrEv
    BottomPadding7["<br/><br/><br/>"]:::invisible ~~~~ XXESafeEv
    BottomPadding8["<br/><br/><br/>"]:::invisible ~~~~ ErubisSafeEv
    BottomPadding9["<br/><br/><br/>"]:::invisible ~~~~ LocalSecretSafeEv
    BottomPadding10["<br/><br/><br/>"]:::invisible ~~~~ ActionCableSafeEv
    ReuseReviewEv --> ReuseReview
    ReuseAuthEv --> ReuseAuth
    PkgMgrEv --> PkgMgr
    XXESafeEv --> XXESafe
    ErubisSafeEv --> ErubisSafe
    LocalSecretSafeEv --> LocalSecretSafe
    ActionCableSafeEv --> ActionCableSafe
    XXESafe --- Dot1
    ErubisSafe --- Dot1
    LocalSecretSafe --- Dot1
    ActionCableSafe --- Dot1
    Dot1 --> SpecialAnalysis
    KnownVulnsBundleEv --- Dot2
    KnownVulnsDependabotEv --- Dot2
    Dot2 --> KnownVulns
    ReuseReview --- Dot3
    ReuseAuth --- Dot3
    PkgMgr --- Dot3
    SpecialAnalysis --- Dot3
    ReuseStrat --- Dot3
    KnownVulns --- Dot3
    Dot3 --> ReuseSec
```

Defines: **[Claim ReuseSec](#claim-reusesec)**, [Claim KnownVulns](#claim-knownvulns), [Evidence KnownVulnsDependabotEv](#evidence-knownvulnsdependabotev), [Evidence KnownVulnsBundleEv](#evidence-knownvulnsbundleev), [Strategy ReuseStrat](#strategy-reusestrat), [Claim SpecialAnalysis](#claim-specialanalysis), [Claim ActionCableSafe](#claim-actioncablesafe), [Evidence ActionCableSafeEv](#evidence-actioncablesafeev), [Claim LocalSecretSafe](#claim-localsecretsafe), [Evidence LocalSecretSafeEv](#evidence-localsecretsafeev), [Claim ErubisSafe](#claim-erubissafe), [Evidence ErubisSafeEv](#evidence-erubissafeev), [Claim XXESafe](#claim-xxesafe), [Evidence XXESafeEv](#evidence-xxesafeev), [Claim PkgMgr](#claim-pkgmgr), [Evidence PkgMgrEv](#evidence-pkgmgrev), [Claim ReuseAuth](#claim-reuseauth), [Evidence ReuseAuthEv](#evidence-reuseauthev), [Claim ReuseReview](#claim-reusereview), [Evidence ReuseReviewEv](#evidence-reusereviewev)

Cited by: [Package Implementation](#package-implementation)
<!-- end verocase -->

### Overall approach

Our overall security approach is called
defense-in-breadth, that is, we consider
security (including security countermeasures) in all
our relevant software life cycle processes (including
requirements, design, implementation, and verification).
In each software life cycle process we
identify the specific issues that most need to be addressed,
and then address them.

We do *not* use a waterfall model for software development.
It's important to note that when we use the word *process* it
has a completely different meaning from a *stage* (aka *phase*).
Instead, we use the word "process" with its standard meaning in
software and systems engineering, that is,
a "process" is just a "set of interrelated or interacting activities
that transforms inputs into outputs" (ISO/IEC/IEEE 12207:2017).
In a waterfall model, these processes are done to completion
in a strict sequence of stages (where each stage occurs for some
period of time).
That is, you create all of the requirements in
one stage, then do all the design in the next stage, and so on.
Winston Royce's paper "Managing the Development of Large Software Systems"
(1970) notes that in software development this naive waterfall approach
"is risky and invites failure" - in practice
"design iterations are never confined to the successive steps".
We obviously *do* determine what the software will do differently
(requirements), as well as design, implement, and verify it, so we
certainly do have these processes.
However, as with almost all real software development projects,
we perform these processes in parallel, iterating and
feeding back as appropriate.
Trying to make decisions without feedback is extremely dangerous, e.g., see
[How Our Physics Envy Results In False Confidence In Our Organizations](https://www.younglingfeynman.com/essays/physicsenvy).
Each process is (notionally) run in parallel;
each receives inputs and produces outputs.

To help make sure that we "cover all important cases", most of
this assurance case is organized by the life cycle processes
as defined by ISO/IEC/IEEE 12207:2017,
<i>Systems and software engineering - Software life cycle processes</i>.
We consider every process, and include in the assurance case every
process important to it.
We don't claim that we conform to this standard, instead, we simply
use the 12207 structure to help ensure that we've considered
all of the lifecycle processes.

There are other ways to organize assurance cases, and we have taken
steps to ensure that issues that would covered by them are indeed covered.
An alternate way to view security issues is to discuss
"process, product, and people";
we evaluate the product in the verification process, and
the people in the human resources process.
It is important to secure the enabling environments, including the
development environments and test environment; it may not be obvious,
but that is covered by the infrastructure management process.
At the end we cover certifications and controls, which also help us
reduce the risk of failing to identify something important.

The following sections are organized following the assurance case figures:

* We begin with the overall security requirements.
  This includes not just the high-level requirements in terms
  of confidentiality, integrity, and availability, but also
  access control in terms of identification, authentication (login),
  and authorization.  Authentication
  is a cross-cutting and critical supporting security mechanism, so
  it's easier to describe it all in one place.
* This is followed in the software life cycle processes, focusing on
  the software lifecycle technical processes:
  design, implementation, integration and verification,
  transition (deployment) and operations, and maintenance.
  We omit requirements, since that was covered earlier.
  This is a merger of the second and third assurance case figures
  (implementation is shown in a separate figure because there is so much
  to it, but in the text we merge the contents of these two figures).
* We then discuss security implemented by other life cycle processes,
  broken into the main 12207 headings:
  agreement processes, organizational project-enabling processes, and
  technical management processes.
  Note that the organizational project-enabling processes include
  infrastructure management (where we discuss security of the
  development and test environment)
  and human resource management (where we discuss the knowledge of
  the key people involved in development).
* We close with a discussion of certifications and controls.
  Certification processes
  can help us find something we missed, as well as provide confidence
  that we haven't missed anything important).
  Note that the project receives its own badge
  (the CII best practices badge),
  which provides additional evidence that it applies best practices
  that can lead to more secure software.
  Similarly, selecting IA controls can help us review important issues
  to ensure that the system will be adequately secure in its intended
  environment (including any compensating controls added to its environment).
  We controls in the context of the
  [Center for Internet Security (CIS) Controls](https://www.cisecurity.org/controls/)
  (aka critical controls).

We conclude with a short discussion of residual risks,
describe the vulnerability report handling process, and make
a final appeal to report to us if you find a vulnerability.

In this assurance case we typically point to source code or tests as
evidence, and not the results of the tests themselves. We do not
ship to production unless tests pass, so there is usually no reason to
see the test results unless a test fails.
That said, the test results for the master branch
are available if desired at:
https://app.circleci.com/pipelines/github/ossf/best-practices-badge?branch=master

## Assurance case tooling and notation

This assurance case is maintained using the LTAC (Linked Text Assurance Case)
format with the `verocase` tool.
The LTAC source file (`docs/case.ltac`) contains the argument skeleton —
packages, claims, strategies, evidence identifiers, and their relationships.
The `verocase` tool validates the argument structure (checking for
circular reasoning, missing elements, and consistency) and automatically
regenerates the Mermaid diagrams in this document from that skeleton.

The diagrams follow the SACM (Structured Assurance Case Metamodel) graphical
notation, explained in the next section.
We do not show most evidence in the diagrams; instead, we provide evidence in
the supporting text below, because the text is far easier to keep current than
large diagrams.

For the history of how we previously managed this assurance case using
LibreOffice Draw with CAE and SACM notation, and why we chose SACM over
CAE, see the
[History: Previous LibreOffice-based approach](#history-previous-libreoffice-based-approach)
section near the end of this document.

## Structured Assurance Case Metamodel (SACM) Graphical Notation

Some figures of this assurance case uses a subset of the
[Object Management Group (OMG) Structured Assurance Case Metamodel (SACM)](Structured Assurance Case Metamodel (SACM))
graphical notation.
The OMG specification, which is publicly available, defines SACM in detail.
In this section we'll explain the subset of SACM
graphical notation and conventions that we use.

Assurance cases typically use one of three graphical notations:
[Claims- Arguments- Evidence (CAE) notation](https://www.adelard.com/asce/choosing-asce/cae.html),
Goal Structuring Notation (GSN), or the SACM graphical notation.
The original BadgeApp assurance case used the
CAE notation because it is simple and the SACM graphical notation did not exist.
However, the SACM specification version 2.1 added in 2020
a graphical notation that has many advantages, so we have switched to SACM.
Later in this document we'll discuss the advantages of SACM.

### Explanation of SACM Notation Subset

Here is the subset of the SACM graphical notation that we use:

1. *Claim*.
   A claim is a statement that can be either true or false (not both).
   A claim is represented as a rectangle (filled, in the verocase Mermaid output),
   A claim that supports another claim is also called a subclaim.
   It is equivalent to the CAE Claim and GSN Goal.
2. *ArtifactReference*, which is used for  *evidence*.
   An ArtifactReference refers to some artifact (such as a piece of information),
   and is represented as a shadowed rectangle.
   When an ArtifactReference is used to support a claim,
   which is the only way we use them, they're also called evidence.
   The official SACM graphical notation includes an angled arrow in its icon,
   but our tools don't easily support that.
   As we use them this is equivalent to the CAE Evidence and GSN Solution.
3. *ArgumentReasoning* aka *argument*.
   An argument explains why the supporting claims and evidence justify
   the claim.
   It is represented as a half-open rectangle
   (rendered as a parallelogram in the verocase Mermaid output).
4. *AssertedInference* and *AssertedEvidence*, aka kinds of *relationships*.
   SACM terminology is that an AssertedInference shows that a claim supports
   another claim, and an AssertedEvidence shows that an ArtifactReference
   (evidence) supports a claim.
   But they have the same graphical representation, and
   we'll just call both relationships.
   They are shown as directed lines with a bigdot
   and an arrowhead pointing to the claim(s) or relationship being justified.
   SACM relationships (AssertRelationships) can do more,
   but we do not use the other forms.
5. *ArgumentPackage* aka *package*.
   An argument package is a grouping of argumention elements.
   This lets us break the information into multiple pages.
   We show this as a scroll; the official SACM graphical symbol is complicated
   and not supported by our drawing tool.
   It is equivalent to the GSN Module.
6. *asCited Claim*.
   An asCited Claim is a claim expanded elsewhere, that is, a cross-reference.
   Its description text shows its containing package, followed by the
   claim id in square brackets.
   This is represented as a bracketed rectangle.

The file `docs/sacm.svg` contains an older illustration of the SACM notation
drawn in LibreOffice; the verocase-generated Mermaid diagrams in this document
use the same logical notation with slightly different visual rendering.

The text shows an ID and colon (in bold), followed by whitespace and
its description.

The SACM graphical notation includes many other features (such as
contexts and other kinds of relationships) that we don't use.
In SACM these elements can have "notes" attached to them; the equivalent
to notes is the text in this document.
The notes may refer to added evidence and/or arguments.
We don't use many other constructs, such as SACM contexts.
The paper
"A Visual Notation for the Representation of Assurance Cases using SACM"
(2020) provides more information, but unfortunately that paper
is not publicly available.

In the rest of this document we will often use the term "argument"
for SACM’s ArgumentReasoning, and "evidence" for ArtifactReference,
because these are simpler terms.

### Conventions

Here are some conventions we use:

* Our convention is that the argument description completes the phrase
  "The claim is justified by these subclaims/evidence because (TEXT)".
* Where possible, the first or second word in the description
  is distinctive.  That makes it easier to see what is most important.
  We try to put phrases like "is secure" or "is countered" last;
  those aren't distinctive, since many
  claims are about security or about countering something.
* We structure this as primarily claims and subordinate subclaims,
  instead of as arguments and subordinate arguments, per 2020 feedback from
  MITRE. This is an improvement; since claims are each true/false statements,
  the relationship between them is usually much clearer doing it this way.

<!-- verocase-config element_level = 1 -->
<!-- verocase element Security -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-security"></a>
# Claim Security: The system is adequately secure against moderate threats

Referenced by: **[Package Security](#package-security)**

Supported by: **[Strategy Processes](#strategy-processes)**, [Claim Controls](#claim-controls)
<!-- end verocase -->

This document explains why the BadgeApp is adequately secure against moderate threats.
It covers all relevant software lifecycle processes to provide defense-in-breadth.
The following sections each address a specific lifecycle process or concern.

<!-- verocase-config element_level = 2 -->
<!-- verocase element Processes -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="strategy-processes"></a>
## Strategy Processes: Security is argued by examining all lifecycle processes

Referenced by: **[Package Security](#package-security)**

Supported by: **[Claim TechProcesses](#claim-techprocesses)**, [Claim NonTechnical](#claim-nontechnical)

Supports: **[Claim Security](#claim-security)**
<!-- end verocase -->

Security is argued by examining all lifecycle processes — both the software lifecycle
technical processes and the other lifecycle processes.
This ensures comprehensive coverage across the entire development and operation lifecycle.

<!-- verocase-config element_level = 2 -->
<!-- verocase element TechProcesses -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-techprocesses"></a>
## Claim TechProcesses: Technical lifecycle processes implement security

Referenced by: **[Package Security](#package-security)**

Supported by: **[Claim Requirements](#claim-requirements)**, [Claim Design](#claim-design), [Claim Implementation](#claim-implementation), [Claim Verification](#claim-verification), [Claim Deployment](#claim-deployment), [Claim Maintenance](#claim-maintenance)

Supports: **[Strategy Processes](#strategy-processes)**
<!-- end verocase -->

The software lifecycle technical processes (requirements, design, implementation,
verification, deployment, and maintenance) each implement security measures.
These are described in the following sections.

<!-- verocase-config element_level = 2 -->
<!-- verocase element Requirements -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-requirements"></a>
## Claim Requirements: Security requirements are identified and met

Referenced by: **[Package Requirements](#package-requirements)**, [Package Security](#package-security)

Supported by: **[Strategy SecTriad](#strategy-sectriad)**, [Claim Assets](#claim-assets)

Supports: [Claim TechProcesses](#claim-techprocesses)
<!-- end verocase -->

We believe the basic security requirements have been identified and met,
as described below.
The security requirements identified here were developed through our
requirements process, which merges
three related processes in ISO/IEC/IEEE 12207
(business or mission analysis, stakeholder needs and requirements definition,
and systems/software requirements definition).

Security requirements are often divided into three areas called the
"CIA triad": confidentiality, integrity, and availability.
We do the same here below, including a discussion of why we
believe those requirements are met.
These justifications depend on other processes
(e.g., that the design is sound, the implementation is not vulnerable,
verification is adequate), which we will justify later.
This is followed by a discussion of access control, and then
a discussion showing that the
the assets & threat actors have been identified & addressed.

See the design section for discussion about why we believe is not possible
to bypass the mechanisms discussed below.

<!-- verocase-config element_level = 3 -->
<!-- verocase element SecTriad -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="strategy-sectriad"></a>
### Strategy SecTriad: Security triad (CIA) and access control address the requirements

Referenced by: **[Package Requirements](#package-requirements)**

Supported by: **[Claim Confidentiality](#claim-confidentiality)**, [Claim Integrity](#claim-integrity), [Claim Availability](#claim-availability), [Claim AccessControl](#claim-accesscontrol)

Supports: **[Claim Requirements](#claim-requirements)**
<!-- end verocase -->

The security triad (Confidentiality, Integrity, Availability) plus Access Control
provides a framework for addressing the security requirements.
Each component is argued separately in the following sub-claims.

<!-- verocase-config element_level = 3 -->
<!-- verocase element Confidentiality -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-confidentiality"></a>
### Claim Confidentiality: Confidentiality is maintained

Referenced by: **[Package Confidentiality](#package-confidentiality)**, [Package Requirements](#package-requirements)

Supported by: **[Claim NonPublicData](#claim-nonpublicdata)**, [Claim UserPrivacy](#claim-userprivacy), [Claim MostDataPublic](#claim-mostdatapublic)

Supports: [Strategy SecTriad](#strategy-sectriad)
<!-- end verocase -->

We maintain confidentiality by limiting what data is publicly visible,
protecting non-public data in transit and at rest, and preserving
user privacy. These aspects are argued separately in the sub-claims below.

<!-- verocase-config element_level = 4 -->
<!-- verocase element UserPrivacy -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-userprivacy"></a>
#### Claim UserPrivacy: User privacy is maintained

Referenced by: **[Package Confidentiality](#package-confidentiality)**

Supported by: **[Claim SelfHostedAssets](#claim-selfhostedassets)**, [Evidence GravatarPrivacyEv](#evidence-gravatarprivacyev)

Supports: **[Claim Confidentiality](#claim-confidentiality)**
<!-- end verocase -->

One of our key requirements is to
"protect users and their privacy".
Here is a brief discussion on how we do that.

First, the basics.
We work hard to comply with the
EU General Data Protection Regulation (GDPR), which has many requirements
related to privacy.
We have a separate document that details how we
implement privacy in the CII Best Practices Badge site and comply with
the GDPR:
[Privacy in the CII Best Practices site, focusing on the GDPR](https://docs.google.com/document/d/1qarSkCJacjoMeu1k6p5JQXvPt-0xUqzKy3OW8zmGvpg).
As discussed later, non-public data is kept confidential
both at rest and in motion
(in particular, email addresses are protected).

Part of our privacy requirement is that we
"don't expose user activities to unrelated sites (including social media
sites) without that user's consent";
here is how we do that.

We must first define what we mean by an unrelated site.
A "related" site is a site that we are directly using to provide our service,
in particular our cloud provider (Heroku which runs on
Amazon's EC2 cloud-computing platform), CDN provider (Fastly),
authorization and avatar services provider (GitHub),
external avatar services (Gravatar),
and logging / intrusion detection service.
As a practical matter, related sites must (under various circumstances)
receive some information about the user (at least that the user
is trying to do something).
This is true for all websites, so it's true for our site as well.
In those cases we have selected partners we believe are trustworthy, and
we have some kind of relationship with them.

However, there is no reason unrelated sites
*must* see what our users are doing,
so we take many steps to prevent unrelated sites from
learning about our users' activities (and thus maintaining user privacy):

* We directly serve all our own assets ourselves,
  including JavaScript, images, and fonts.
  In particular, we do not have *any* embedded automatically-downloaded
  references (transclusions)
  in our web pages to external JavaScript or fonts.
  Since we serve these assets ourselves, and not via external
  third parties, external sites never receive any request from a user
  when they view our pages.
  As a result, user privacy is maintained: what a user views on our site
  is never revealed by our actions to unrelated sites.
  This also aids security; even if an attacker subverts some other site's
  JavaScript or font, that will not directly affect us because we do not embed
  references some other site's JavaScript or font in our web pages.
  Many sites don't do this and should probably consider it.
  This policy is enforced by our CSP policy.
* We do not serve ads and we plan to have no ads in the future.
  That said, if we ever did serve ads, we expect that we
  would also serve them from our site, just like any other asset, to
  ensure that third parties did not receive unauthorized information.
* We do not use any web analytics service that uses tracking codes or
  external assets.
  We log and store logs using only services we control or have a direct
  partnership with.
* The email we send is privacy-respecting.
  The email contents we send do not have img links (which might expose
  when an email is read). In some cases we have hyperlinks
  (e.g., to activate a local account), but those links go directly back
  to our site for that given purpose, and do not reveal information to
  anyone else.
  You need to configure the MTA used to send email before you can use it.
  We used to use SendGrid to send email; we have specifically configured the
  [SendGrid X-SMTPAPI header to disable all of its trackers we know of](https://sendgrid.com/docs/ui/account-and-settings/tracking/),
  which are clicktrack, ganalytics, subscriptiontrack, and opentrack.
  For example, we have never used ganalytics, but by expressly disabling it,
  it will stay disabled even if SendGrid decided to enable it by default
  in the future.
* We do have links to social media sites (e.g., from the home page), but we
  do this in a privacy-respecting manner.
  It would be easy to use techniques like embedding images
  from external (third party) social media sites,
  but we intentionally do not do that, because that would expose to an
  external unrelated site what our users are doing without their knowledge.
  We instead use the approach described in
  ["Responsible Social Share Links" by Jonathan Suh (March 26, 2015), specifically using share URLs](https://jonsuh.com/blog/social-share-links/#use-share-urls).
  In this approach, if a user does not press the link,
  the social media site never receives any information.
  Instead, a social media site
  *only* receives information when the user takes a direct action to
  request it (e.g., a click), and that site only receives information from
  the specific user who requested it.

Note that user avatar images are handled specially. We consider
the few avatar-serving domains that we use as related sites.
This issue may not be obvious, so here we'll explain it further.
A user can choose a representative avatar
(currently via GitHub or Gravatar).
Anyone who requests that user's information page will
receive an `img` reference to that user-selected avatar so that
the requestor can see it.
External avatar images are only shown from specific domains
('secure.gravatar.com' or 'avatars.githubusercontent.com'), they are
only included if the user has an avatar, and they are only shown to
others through this mechanism if that user's information was requested.
This functionality is useful, because these images can help others remember
who the user is.

We have considered ways to further limit information sharing with avatar
services even though they are related sites (and thus we do not *have*
to limit information sharing any further).
We have had some success, but current law and technology provide challenges.
We could download these images and re-serve them (such as via a proxy),
but copying or proxying the images
using our own site might be considered a copyright violation
and would also impose the need for significant extra resources.
Thus, since we do not serve avatars ourselves, we must direct requesters
to them, so at the very least the requestor's externally-visible IP address
must be visible to the external avatar service (so the image can be provided).
To provide additional privacy, we would like to also
limit requestor headers and third-party cookies when using third-party
avatar services
(since these are the primary mechanisms that reveal more information
about the requestor to the third party avatar service).
Here is our current state:

* We think we have a decent solution for limiting
  requestor headers from being sent to avatar services.
  We have added the `referrerpolicy="no-referrer"` attribute to the image
  as discussed in the
  [Mozilla img documentation](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/img).
  While this attribute is technically experimental,
  [the referrerpolicy attribute on images is widely supported](https://developer.mozilla.org/en-US/docs/Web/API/HTMLImageElement/referrerPolicy),
  including by Chrome, Firefox, and Opera.
* Unfortunately, we have not found a *good* way to prevent
  third-party cookies from being sent to avatar services.
  [There are discussions on how to disable third party cookies for img tags](https://stackoverflow.com/questions/51549390/how-to-disable-third-party-cookie-for-img-tags),
  but currently-known mechanisms are very complex, require inline CSS
  invocations, and have dubious reliability.
  We hope that future web standards will add the ability to easily
  prevent the unnecessary revelation of third-party cookies.

Note that we consider that things are very different
when a user actively clicks on a hypertext link to go to a different web site.
In this case, the user has *actively* selected to visit that different web site,
and thus expressly consented to the usual actions that occur when visiting
a different web site.
The different web site must know the IP address of the user anyway
(to send the data), and any cookie communications with that site involve
that other site.
We do allow referrer information to be sent in this case.
When a user actively selects a hypertext link, it is normal web behavior
for the receiving site to be provided with information on the referrer
via the "referer" (sic) HTTP header as specified in
[RFC 1945 (HTTP 1.0) from May 1996](https://tools.ietf.org/html/rfc1945#page-44).
This referrer information reports where the user "came from".
This information is useful for many circumstances, including notifying
recipients that people are discovering their site using our site.
It would be *possible* for us to
[disable sending referrer information](https://geekthis.net/post/hide-http-referer-headers/)
(e.g., by using `rel="noreferrer"` in hypertext links or
by setting a referrer policy via HTTP or the meta tag), but this
would inhibit normal default web behavior.
However, when users expressly choose to click on a link from our site,
there is express consent to visit the other site,
so we do not see this an issue.
In addition, users who do not want to share referrer information can
configure their browser to omit referrer information; this would
be a much better choice for users who do not want referrer information
to be shared.
Information on how to disable referrer heading information is
available from multiple sources, e.g.,
["How to Change Referer Header Settings: Why It’s Useful" by John Anthony](https://www.addictivetips.com/vpn/change-referer-header-settings/),
["Turn Referrer Headers On or Off in Firefox" by Mitch Bartlet](https://www.technipages.com/firefox-enable-disable-referrer),
and
["Why Should you Change your Referer Header settings & How to do it" by Douglas Crawford](https://proprivacy.com/guides/change-referer-header-settings).

Of course, to access any site on the Internet
the user must use various services and
computers, and some of those could be privacy-exposing.
For example, the user must make a request to a DNS service to find our
service, and user requests must transit multiple Internet routers.
We cannot control the systems that users choose to use; instead, we ensure that
users can choose what services and computers they will trust.
The BadgeApp does not filter out any particular source
(other than temporary blocks if the source becomes a source of attack).
Therefore, users who do not want their activities monitored
could choose to use a network and computer they trust,
a Virtual Private Network (VPN), or an anonymity network such as Tor
to provide additional privacy when they interact with the BadgeApp.

<!-- verocase element MostDataPublic -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-mostdatapublic"></a>
#### Claim MostDataPublic: Almost all data is not confidential

Referenced by: **[Package Confidentiality](#package-confidentiality)**

Supports: **[Claim Confidentiality](#claim-confidentiality)**
<!-- end verocase -->

We try to store as little confidential information as we reasonably can,
as this limits the impact of any confidentiality breach.
Almost all data we collect is considered public, e.g., all project data,
who owns the project information, and GitHub user names.
Therefore, we don't need to keep those confidential.

For each user account we store some other data.
Some we present to the public, such as claimed user name,
creation time, and edit times; we present these as we consider that
public information.
We do not present the user's preferred locale to the public, under the
theory that we don't know of a reason someone else would
have a legitimate reason to know that.
However, all of this is not considered sensitive data and it is certainly
not identifying information, so we would not consider it a breach
if someone else got this information (such as the preferred locale).

Non-public data is kept confidential.
In our case, the non-public data that must be kept confidential
are the user passwords, the "remember me" token (login nonce)
if the user has enabled the remember me function, and user email addresses.
We *do* consider this data higher-value and protect them specially.

<!-- verocase-config element_level = 4 -->
<!-- verocase element NonPublicData -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-nonpublicdata"></a>
#### Claim NonPublicData: Non-public data is kept confidential

Referenced by: **[Package Confidentiality](#package-confidentiality)**

Supported by: **[Claim ConfDataAtRest](#claim-confdataatrest)**, [Claim DataInMotion](#claim-datainmotion)

Supports: **[Claim Confidentiality](#claim-confidentiality)**
<!-- end verocase -->

Non-public data — specifically user passwords, "remember me" tokens, and
email addresses — is kept confidential both at rest and in motion.
The following sub-claims address each form of confidential data storage.

<!-- verocase element ConfDataAtRest -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-confdataatrest"></a>
#### Claim ConfDataAtRest: Confidential data at rest is protected

Referenced by: **[Package Confidentiality](#package-confidentiality)**

Supported by: **[Claim Passwords](#claim-passwords)**, [Claim RememberMe](#claim-rememberme), [Claim EmailSecured](#claim-emailsecured)

Supports: **[Claim NonPublicData](#claim-nonpublicdata)**
<!-- end verocase -->

Confidential data stored on the server is protected from exposure.
User passwords are stored only as bcrypt hashes, remember-me tokens
use bcrypt-stored nonces, and email addresses are encrypted at rest.

<!-- verocase element Passwords -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-passwords"></a>
#### Claim Passwords: User passwords stored securely (using bcrypt)

Referenced by: **[Package Confidentiality](#package-confidentiality)**

Supported by: **[Evidence PasswordsEv](#evidence-passwordsev)**

Supports: **[Claim ConfDataAtRest](#claim-confdataatrest)**
<!-- end verocase -->

User passwords for local accounts are only stored on the server as
iterated per-user salted hashes (using bcrypt), and thus cannot
be retrieved in an unencrypted form later on from a recorded database.

Any user password sent to the system is sent by the application router
to the "update" method of the user controller
(`app/controllers/users_controller.rb`).  The update method invokes the
"save" method of the user model (`app/models/user.rb`).
The user model includes the standards Rails
`has_secure_password` request, which tells the system to save
the password after it has been encrypted with bcrypt
(instead of storing it directly), and to later do comparisons using
only the bcrypted value.

Note that no normal request can later retrieve a password, because
it is immediately encrypted on change or check and the original
unencrypted password is discarded.
The unencrypted email address may remain for a while in server memory
until that memory is recycled, but we assume that the underlying
system will protect memory during the time before it is garbage-collected
and reused.

To help users avoid the *worst* passwords, we check proposed passwords
against a list of bad passwords and don't allow passwords to change to them.
This complies with NIST Special Publication 800-63B section 5.1.1.2.
That list is long, so for speed we keep this list in the database
(if we kept it in memory it would use a lot of memory).
We don't trust long-term storage, so it's vital that we *never* record
in logs a query that includes an unencrypted password.
Also, while we trust our database and its connections, we want to limit
privileges where we can. Thus, we take two steps to protect passwords
while we check them against the bad password list in the database:

1. We disable the bad password check if the log level is set to debug
   (which logs SQL queries) and we aren't running a test.
   It's better to disable the bad password check than to risk exposing
   a password. When this occurs, a warning it noted in the log.
   Note that the production environments settings do *not* use log level
   debug by default anyway, but we want to make sure it won't happen.
2. Instead of storing the bad passwords directly, we stored keyed HMAC
   values of them, and the new password must *also* be converted into a
   keyed HMAC for comparison. The key is a secret for the application.
   This means that even if an attacker gains control over the database
   and/or can read communications to it (which we assume they can't do),
   the attacker would have to use a brute-force to find the key
   (we recommend 512 bits), *then* use that key to compute HMACs to attempt
   to discover a user's password. Rekeying the bad password database
   is trivial, when desired. A new key can be set in `BADGEAPP_BADPWKEY`
   and then you can run `rake update_bad_password_db` (it takes a few minutes).
   We do this to protect passwords used for queries between the application
   and the database, to counter someone snooping it.
   We *never* store the HMAC of the password anywhere. We instead use
   bcrypt for stored passwords (it's designed for that).
   Strictly speaking using HMAC isn't necessary, since we don't store it,
   but providing another layer of protections for passwords seemed appropriate.
   Theoretically a user could choose another password that isn't
   on the bad password list but matches its HMAC; that's so astronomically
   unlikely that it won't happen, and even if it did, it would just mean
   that the user would have to choose a different password.

<!-- verocase element PasswordsEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-passwordsev"></a>
#### Evidence PasswordsEv: has_secure_password in user model stores passwords via bcrypt

Referenced by: **[Package Confidentiality](#package-confidentiality)**

Supports: **[Claim Passwords](#claim-passwords)**

External Reference: [../app/models/user.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../app/models/user.rb)
<!-- end verocase -->

`has_secure_password` in user model stores passwords via bcrypt. See [../app/models/user.rb](../app/models/user.rb).

<!-- verocase element RememberMe -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-rememberme"></a>
#### Claim RememberMe: Remember me token is secured

Referenced by: **[Package Confidentiality](#package-confidentiality)**

Supported by: **[Evidence RememberMeEv](#evidence-remembermeev)**

Supports: **[Claim ConfDataAtRest](#claim-confdataatrest)**
<!-- end verocase -->

Users may choose to "remember me" to automatically re-login on
that specific browser if they use a local account.
This is done by enabling the "remember me" checkbox when logging in to
a session.
If a user does enable "remember me" we implement automatic
login when the user makes later requests.  This is implemented using a
cryptographically random nonce stored in the user's web browser
cookie store as a permanent cookie.
Note that this nonce does not include the user's original password.
On the server side this nonce is encrypted via bcrypt just like
user passwords are stored.

Here is how we do this: Any attempt to login is routed to the
"new" method of the sessions controller in
`app/controllers/sessions_controller.rb`, which calls method
`local_login`, and if login is successful it
calls `local_login_procedure`.
If the user selected `remember_me`, the
`local_login_procedure` will call the `remember` method in
the user model (in `app/models/user.rb`) to create and store the
`remember_token` in the user's cookie store and the corresponding
bcrypted value on the server.
The user may log out later (often by having their log in session time out).

Whenever the system needs to determine who the current user is,
it calls method `current_user` (in `app/helpers/sessions_helper.rb`).
If the user is not logged in, but has a `remember_me` token that
matches the hashed token on the server, this method automatically
logs the user back in.
See the section on authentication for more information.

The system does not have the unencrypted `remember_token` for any
given user (only its bcrypted form), so the system cannot later reveal the
`remember_token` to anyone else.

In file `test/integration/users_login_test.rb` we verify that the
password is not stored as cleartext in the user cookie.

<!-- verocase element RememberMeEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-remembermeev"></a>
#### Evidence RememberMeEv: remember method in user model creates bcrypt-stored nonce; sessions controller and helper manage it; login test verifies cleartext not stored in cookie

Referenced by: **[Package Confidentiality](#package-confidentiality)**

Supports: **[Claim RememberMe](#claim-rememberme)**

External Reference: [../app/controllers/sessions_controller.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../app/controllers/sessions_controller.rb)
<!-- end verocase -->

`remember` method in user model creates bcrypt-stored nonce; sessions controller and helper manage it; login test verifies cleartext not stored in cookie. See [../app/controllers/sessions_controller.rb](../app/controllers/sessions_controller.rb).

<!-- verocase element EmailSecured -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-emailsecured"></a>
#### Claim EmailSecured: Email addresses are secured (encrypted and only accessible to admin & owner)

Referenced by: **[Package Confidentiality](#package-confidentiality)**

Supported by: **[Evidence EmailSecuredEv](#evidence-emailsecuredev)**

Supports: **[Claim ConfDataAtRest](#claim-confdataatrest)**
<!-- end verocase -->

Email addresses are only revealed to the owner of the email address and to
administrators.

We must store email addresses,
because we need those for various purposes.
In particular, we must be able to contact badge entry owners
to discuss badge issues (e.g., to ask for clarification).
We also user email addresses as the user id for "local" accounts.
Since we must store them,
we strive to not reveal user email addresses to others
(with the exception of administrators, who are trusted and thus
can see them).

Here are the only ways that user email addresses can be revealed
(use `grep -Ri 'user.*\.email' ./` to verify):

- Mailers (in `app/mailers/`).  The application sometimes sends email, and
  in all cases email is sent via mailers.  Unsurprisingly, we need destination
  email addresses to send email.  However, in all cases we only
  send emails to a single user, with possible "cc" or "bcc" to a
  (trusted) administrator.  That way, user email addresses cannot leak
  to other users via email.  This can be verified by examining the
  mailers in directory `app/mailers/` and their corresponding views in
  `app/views/*_mailer/`. Even the rake task `mass_email`
  (defined in file lib/tasks/default.rake),
  which can send a message such as "we have been breached" to
  all users, sends a separate email to each user using a mailer.
  A special case is when a user changes their email address: in that case,
  information is sent to both email addresses, but technically that is still
  an email to a single user, and this is only done when someone is logged
  in with authorization to change the user email address.
- The only *normal* way to display user email addresses is to invoke
  a view of a user or a list of users.  However, these invoke
  user views defined in `app/views/users/`, and all of these views only
  provide a user email address if the current user is the user
  being displayed
  or the current user is an administrator.  This is true for views in both
  HTML and JSON formats.
  In addition, while we directly display the email address when local users
  are editing it (we must, so that users can change it), when user
  records are shown (not edited) the email address is only available via
  a hypertext link, and not directly displayed on the screen, to reduce
  the risk of revealing an email address while using sharing a screen.
  The following automated tests verify that email addresses
  are not provided without authorization:
    - `should NOT show email address when not logged in`
    - `JSON should NOT show email address when not logged in`
    - `should NOT show email address when logged in as another user`
    - `JSON should NOT show email address when logged in as another user`
- The `reminders_summary` view in
  `app/views/projects/reminders_summary.html.erb`
  does display user email addresses, but this is only displayed when a
  request is routed to the `reminders_summary` method of the projects controller
  (`app/controllers/projects_controller.rb`), and this method only displays
  that view to administrators.
  This is verified by the automated test
  `Reminders path redirects for non-admin`.
- As a special case, a user email address is included as a hidden field in
  a local user password reset in `app/views/password_resets/edit.html.erb`.
  However, this is only displayed if the user is routed to the "edit"
  method of `app/controllers/password_resets_controller.rb` and successfully
  meets two criterion (configured using `before_action`):
  `require_valid_user` and `require_unexpired_reset`.
  The first criterion requires that the user be activated and provide the
  correct reset authentication token that was emailed to the user;
  anyone who can do this can already receive or intercept that user's email.
  The need for the correct authentication token
  is verified by the automated test `password resets`.

As documented in CONTRIBUTING.md, we forbid including email
addresses in server-side caches, so that accidentally sharing the
wrong cache won't reveal email addresses.
Most of the rest of this document describes the other
measures we take to prevent turning unintentional mistakes
into exposures of this data.

Note: As discussed further in the later section on "Encrypted email addresses",
we also encrypt the email addresses using AES with 256-bit keys in
GCM mode ('aes-256-gcm').  We also hash the email addresses, so they
can be indexed, using the hashed key algorithm PBKDF2-HMAC-SHA256.
These are strong, well-tested algorithms.
We encrypt email addresses, to provide protection for data at rest,
and never provide the keys to the database system
(so someone who can only see what the database handles, or can
get a copy of it, will not see sensitive data including
raw passwords and unencrypted email addresses).
These are considered additional hardening measures, and so are
discussed further in the section on hardening.

Password reset requests (for local users) trigger an email,
but that email is sent to the address as provided by the original account;
emails are *not* sent to whatever email address is provided by the
reset requestor (who might be an attacker).
These email addresses match in the sense of `find_by`, which is a
case-insensitive match, but since it is sometimes possible for an attacker
to create another email account that "matches" in a case-insensitive way
to an existing account, we always use the known-correct email address.
You can verify this by reviewing
`app/controllers/password_resets_controller.rb`.
This approach completely counters the attack described in
[Hacking GitHub with Unicode's dotless 'i'](https://eng.getwisdom.io/hacking-github-with-unicode-dotless-i/).

The presence or absence of an email address is not revealed by the
authentication system (countering enumeration or verification attacks):

1. Local account creation always reports that the account must be
   verified by checking the delivered email, whether or not the email
   account exists. Thus, attempting to create a local account won't
   reveal if the account exists to others.
2. Password reset requests do *not* vary depending
   on whether or not the email address is present as a local account.
3. Failed login requests for local accounts simply reports that
   the login failed; they do not indicate if the email address is present.

<!-- verocase element EmailSecuredEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-emailsecuredev"></a>
#### Evidence EmailSecuredEv: Views, mailers, and controllers restrict email address access to owners and admins; use grep -Ri 'user.*\.email' to verify

Referenced by: **[Package Confidentiality](#package-confidentiality)**

Supports: **[Claim EmailSecured](#claim-emailsecured)**

External Reference: [../app/views/users/](https://github.com/ossf/best-practices-badge/blob/main/docs/../app/views/users/)
<!-- end verocase -->

To verify that email addresses are only accessible to owners and admins:

- Run `grep -Ri 'user.*\.email' ./` to find all places where email addresses are accessed.
- Mailers in `app/mailers/` only send email to single users or to admins with cc/bcc.
- Views in `app/views/users/` only display the email address to the owner or an admin.
- The `reminders_summary` view in `app/views/projects/reminders_summary.html.erb` is only accessible to admins (enforced in `app/controllers/projects_controller.rb`).
- The `app/views/password_resets/edit.html.erb` only exposes an email address after `require_valid_user` and `require_unexpired_reset` checks pass in `app/controllers/password_resets_controller.rb`.
- Automated tests verify that email addresses are not displayed without authorization; see tests `should NOT show email address when not logged in`, `JSON should NOT show email address when not logged in`, `should NOT show email address when logged in as another user`, and `JSON should NOT show email address when logged in as another user`.

<!-- verocase element DataInMotion -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-datainmotion"></a>
#### Claim DataInMotion: Data in motion encrypted with HTTPS

Referenced by: **[Package Confidentiality](#package-confidentiality)**

Supported by: **[Evidence DataInMotionEv](#evidence-datainmotionev)**

Supports: **[Claim NonPublicData](#claim-nonpublicdata)**, [Claim Integrity](#claim-integrity)
<!-- end verocase -->

HTTPS (specifically the TLS protocol)
is used to encrypt all communications between users
and the application.
This protects the confidentiality and integrity of all data in motion,
and provides confidence to users that they are contacting the correct server.

We force the use of HTTPS by setting
`config.force_ssl` to `true` in the
`config/environments/production.rb` (the production configuration).
This enables a number of hardening mechanisms in Rails, including
TLS redirection (which redirects HTTP to HTTPS).
(There is a debug mode to disable this, `DISABLE_FORCE_SSL`,
but this is not normally set in production and can only be set by
a system administrators with deployment platform access.)

As discussed in the hardening section
"Force the use of HTTPS, including via HSTS" (below), we take a number of
additional steps to try to make users always use HTTPS.
We also use [online checkers](#online-checkers) (discussed below)
to verify that our TLS configuration is secure in production.

<!-- verocase element DataInMotionEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-datainmotionev"></a>
#### Evidence DataInMotionEv: config.force_ssl = true enforces HTTPS with TLS redirection and secure cookies in production

Referenced by: **[Package Confidentiality](#package-confidentiality)**

Supports: **[Claim DataInMotion](#claim-datainmotion)**

External Reference: [../config/environments/production.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../config/environments/production.rb)
<!-- end verocase -->

`config.force_ssl = true` enforces HTTPS with TLS redirection and secure cookies in production. See [../config/environments/production.rb](../config/environments/production.rb).

<!-- verocase-config element_level = 3 -->
<!-- verocase element Integrity -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-integrity"></a>
### Claim Integrity: Integrity is maintained

Referenced by: **[Package Requirements](#package-requirements)**

Supported by: **[Claim DataModAuth](#claim-datamodauth)**, [Claim AppModAuth](#claim-appmodauth), [Claim DataInMotion](#claim-datainmotion)

Supports: **[Strategy SecTriad](#strategy-sectriad)**
<!-- end verocase -->

As noted above,
HTTPS is used to protect the integrity of all communications between
users and the application, as well as to authenticate the server
to the user.

<!-- verocase-config element_level = 4 -->
<!-- verocase element DataModAuth -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-datamodauth"></a>
#### Claim DataModAuth: Data modification requires authorization

Referenced by: **[Package Requirements](#package-requirements)**

Supported by: **[Evidence DataModAuthEv](#evidence-datamodauthev)**

Supports: **[Claim Integrity](#claim-integrity)**
<!-- end verocase -->

Data modification requires authorization.

Here we describe how these authorization rules are enforced.
We first discuss how to modify data through the BadgeApp application,
and then note that data can also be modified by modifying it via the
underlying database and platform.
For more about the authorization rules themselves,
see the section on authorization.
Note that gaining authorization first requires logging in
(which in turn requires both identification and authentication).

The only kinds of data that can be modified involve a project or a user,
and this data can only be modified through the application as follows:

- Project:
  Any project edit or deletion request is routed to the appropriate
  method in the projects controller in
  `app/controllers/projects_controller.rb`.
  Users cannot invoke any other method to modify a project other than
  the four methods corresponding to the requests identified below, and
  these cannot be executed unless the appropriate authentication check
  has succeeded:
    - In the case of an `edit` or `update` request, there is a `before_action`
      that verifies that the request is authorized using the check method
      `can_edit_else_redirect`.
      (Note: technically only `update` needs authentication, since
      `edit` simply displays a form to fill out.  However, to reduce
      user confusion, we prevent *displaying* a form for editing data
      unless the user is authorized to later perform an update.)
      This inability to edit a project without authorization
      is verified by automated tests
      `should fail to update project if not logged in` and
      `should fail to update other users project`.
    - In the case of a `delete_form` or `destroy` request,
      there is a `before_action`
      that verifies that the request is authorized using the check method
      `can_control_else_redirect`.
      (Note: Again, technically only `destroy` needs authentication, but
      to reduce user confusion we will not even display the form for destroying
      a project unless the user is authorized to destroy it.)
      This inability to destroy a project without authorization
      is verified by automated tests
      `should not destroy project if no one is logged in` and
      `should not destroy project if logged in as different user`.
- User:
  Any user edit or deletion request is routed to the appropriate
  method in the user controller in
  `app/controllers/users_controller.rb`.
  These cannot be executed unless the appropriate authentication check
  has succeeded.
  In the case of an `edit` or `update` or `destroy` request,
  there is a `before_action`
  that verifies that the request is authorized using the check method
  `redir_unless_current_user_can_edit`.
  Users cannot invoke any other method to modify a user.
  This inability to edit or destroy a user without authorization
  is verified by these automated tests:
    - `should redirect edit when not logged in`
    - `should redirect edit when logged in as wrong user`
    - `should redirect update when not logged in`
    - `should redirect update when logged in as wrong user`
    - `should redirect destroy when not logged in`
    - `should redirect destroy when logged in as wrong non-admin user`

The `additional_rights` table, described below, is edited as
part of editing its corresponding project or deleting its
corresponding user, and so does not need to be discussed separately.
No other data can be modified by normal users.

It is also possible to directly modify the underlying database
that records the data.
However, only an administrator with deployment platform access
is authorized to do that, and few people have that privilege.
The deployment platform infrastructure verifies authentication and
authorization.

There is an odd special case involving the repository URL `repo_url`.
We are trying to counter subtle attacks where
a project tries to claim the good reputation or effort of another project
by constantly switching its `repo_url` to other projects and/or nonsense.
The underlying problem is that names/identities are hard; the `repo_url`
(when present) is the closest to an "identity" that we have for a project.
We have to allow it to change sometimes (because it sometimes does), but
it should be a rare "sticky" event.
There are various special cases, e.g., you can always set the `repo_url`
if it's nil, the setter is an admin, or if only the scheme is changed.
But otherwise normal users can't change the `repo_urls` in less than
`REPO_URL_CHANGE_DELAY` days (a constant set in the projects controller).
Allowing users to change `repo_urls`, but only
with large delays, reduces the administration effort required.
By doing this, we help protect the integrity of the overall database
from potentially-malicious authorized users.

<!-- verocase element DataModAuthEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-datamodauthev"></a>
#### Evidence DataModAuthEv: before_action guards can_edit_else_redirect and can_control_else_redirect protect all project modifications

Referenced by: **[Package Requirements](#package-requirements)**

Supports: **[Claim DataModAuth](#claim-datamodauth)**

External Reference: [../app/controllers/projects_controller.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../app/controllers/projects_controller.rb)
<!-- end verocase -->

`before_action` guards `can_edit_else_redirect` and `can_control_else_redirect` protect all project modifications. See [../app/controllers/projects_controller.rb](../app/controllers/projects_controller.rb).

<!-- verocase element AppModAuth -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-appmodauth"></a>
#### Claim AppModAuth: Application modification requires authorization

Referenced by: **[Package Requirements](#package-requirements)**

Supported by: **[Evidence AppModAuthEv](#evidence-appmodauthev)**

Supports: **[Claim Integrity](#claim-integrity)**
<!-- end verocase -->

Modifications to the official BadgeApp application require
authorization via GitHub.
We use GitHub for managing the source code and issue tracker; it
has an authentication and authorization system for this purpose.

<!-- verocase-config element_level = 3 -->
<!-- verocase element Availability -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-availability"></a>
### Claim Availability: Availability is maintained including limited DDoS resilience

Referenced by: **[Package Availability](#package-availability)**, [Package Requirements](#package-requirements)

Supported by: **[Claim CDNDDoS](#claim-cdnddos)**, [Claim Timeout](#claim-timeout), [Claim QuickRecovery](#claim-quickrecovery), [Claim LoginDisabled](#claim-logindisabled), [Claim Backups](#claim-backups), [Claim ScaleUp](#claim-scaleup)

Supports: [Strategy SecTriad](#strategy-sectriad)
<!-- end verocase -->

As with any publicly-accessible website,
we cannot prevent an attacker with significant
resources from temporarily overwhelming the system through
a distributed denial-of-service (DDos) attacks.
So instead, we focus on various kinds of resilience against DDoS attacks,
and use other measures (such as backups) to maximize availability.
Thus, even if the system is taken down temporarily, we expect to be
able to reconstitute it (including its data).

<!-- verocase-config element_level = 4 -->
<!-- verocase element CDNDDoS -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-cdnddos"></a>
#### Claim CDNDDoS: CDN counters DDoS attacks on specific resources

Referenced by: **[Package Availability](#package-availability)**

Supported by: **[Evidence FastlyCDNEv](#evidence-fastlycdnev)**

Supports: **[Claim Availability](#claim-availability)**
<!-- end verocase -->

We use the Fastly CDN, which provides some protection against DDoS attacks
on specific resources such as static assets.
The CDN absorbs or deflects traffic before it reaches our servers,
providing a layer of resilience for high-traffic attacks.

<!-- verocase element ScaleUp -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-scaleup"></a>
#### Claim ScaleUp: Cloud resources can be rapidly increased

Referenced by: **[Package Availability](#package-availability)**

Supported by: **[Evidence ScaleUpEv](#evidence-scaleupev)**

Supports: **[Claim Availability](#claim-availability)**
<!-- end verocase -->

We can quickly add more resources if more requests are made.
See the design section "availability through scalability" below
for more about how we handle scaling up.

<!-- verocase element Timeout -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-timeout"></a>
#### Claim Timeout: Timeout limits maximum request time

Referenced by: **[Package Availability](#package-availability)**

Supported by: **[Evidence TimeoutEv](#evidence-timeoutev)**

Supports: **[Claim Availability](#claim-availability)**
<!-- end verocase -->

All user requests have a timeout in production.
That way, the system is not permanently "stuck" on a request.
This is set by setting `Rack::Timeout.service_timeout`
in file `config/environments/production.rb`.

<!-- verocase element TimeoutEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-timeoutev"></a>
#### Evidence TimeoutEv: Rack::Timeout.service_timeout set in production configuration limits all request times

Referenced by: **[Package Availability](#package-availability)**

Supports: **[Claim Timeout](#claim-timeout)**

External Reference: [../config/environments/production.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../config/environments/production.rb)
<!-- end verocase -->

`Rack::Timeout.service_timeout` set in production configuration limits all request times. See [../config/environments/production.rb](../config/environments/production.rb).

<!-- verocase element QuickRecovery -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-quickrecovery"></a>
#### Claim QuickRecovery: Can return to operation quickly after DDoS ended

Referenced by: **[Package Availability](#package-availability)**

Supported by: **[Evidence QuickRecoveryEv](#evidence-quickrecoveryev)**

Supports: **[Claim Availability](#claim-availability)**
<!-- end verocase -->

The system can return to operation quickly after
a DDoS attack has ended.

<!-- verocase element LoginDisabled -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-logindisabled"></a>
#### Claim LoginDisabled: Logon disabled mode mitigates against some vulnerabilities

Referenced by: **[Package Availability](#package-availability)**

Supported by: **[Evidence LoginDisabledEv](#evidence-logindisabledev)**

Supports: **[Claim Availability](#claim-availability)**
<!-- end verocase -->

We have implemented a "login disabled mode"
(aka `BADGEAPP_DENY_LOGIN` mode) that we can quickly enable.

This mode is an intentionally degraded mode of operation
that prevents any changes by users (daily statistics
creates are unaffected).
More specifically, if this mode is enabled
then no one can log in to the BadgeApp application,
no one can create a new account (sign up),
and no one can do anything that requires being logged in
(users are always treated as if they are not logged in).

This mode is intended to make some services available
if there is a serious exploitable
security vulnerability that can only be exploited by users who are
logged in or can appear to be logged in.  Unlike *completely* disabling the
site, this mode allows people to see current information
(such as badge status, project data, and public user data).
This mode is useful because it can stop many attacks, while still providing
some services.

This mode is enabled by setting the
environmental variable `BADGEAPP_DENY_LOGIN` to a
non-blank value (`true` is recommended).
Note that application administrators cannot log in, or use their privileges,
when this mode is enabled.
Only hosting site administrators can turn this mode
on or off (since they're the only ones who can set environment variables).

This mode is checked on application startup by
`config/initializers/deny_login.rb` which sets the boolean variable
`Rails.application.config.deny_login`.
Its effects can be verified by running
`grep -R 'Rails.application.config.deny_login' app/`;
they are as follows:

* Users are never considered logged in, even if they already logged in.
  This is enforced in the `current_user` method in
  `app/helpers/sessions_helper.rb` - this always returns null (not logged in)
  when this deny mode is enabled.
  This is verified by test
  `current_user returns nil when deny_login`.
* Attempts to login are rejected via the `create` method
  of the session controller, per `app/controllers/sessions_controller.rb`.
  Technically this isn't necessary, since being logged in is ignored,
  but this rejection will alert users who start trying to log in before
  this mode was enabled.
  This is verified by test `local login fails if deny_login`.
* Attempts to create a new user account are rejected
  via the `create` method of the user controller, per
  `app/controllers/users_controller.rb`.
  We do not want the user database to change while this mode is in effect.
  This is verified by test
  `cannot create local user if login disabled`

Some views are also changed when this view is enabled.
These changes are not security-critical.
Instead, these changes provide users immediate feedback
to help them understand that this special mode has been enabled.

<!-- verocase element LoginDisabledEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-logindisabledev"></a>
#### Evidence LoginDisabledEv: deny_login initializer reads BADGEAPP_DENY_LOGIN env var to disable all logins

Referenced by: **[Package Availability](#package-availability)**

Supports: **[Claim LoginDisabled](#claim-logindisabled)**

External Reference: [../config/initializers/deny_login.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../config/initializers/deny_login.rb)
<!-- end verocase -->

`deny_login` initializer reads `BADGEAPP_DENY_LOGIN` env var to disable all logins. See [../config/initializers/deny_login.rb](../config/initializers/deny_login.rb).

<!-- verocase element Backups -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-backups"></a>
#### Claim Backups: Data corruption and loss are mitigated by multiple backups

Referenced by: **[Package Availability](#package-availability)**

Supported by: **[Evidence BackupsEv](#evidence-backupsev)**

Supports: **[Claim Availability](#claim-availability)**
<!-- end verocase -->

We routinely backup the database every day
and retain multiple versions of backups.
That way, if the project data is corrupted, we can restore the
database to a previous state.

#### See also

Later in this assurance case we'll note other
capabilities that also aid availability:

- As noted later in the hardening section, we also have rate limits on
  incoming requests, including the number of requests a
  client IP address can make in a given period.
  This provides a small amount of additional automated protection against
  being overwhelmed.
- As noted later in the "Recovery plan including backups",
  we have a recovery plan that builds on our multiple backups.

<!-- verocase-config element_level = 3 -->
<!-- verocase element AccessControl -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-accesscontrol"></a>
### Claim AccessControl: Access control is in place

Referenced by: **[Package Requirements](#package-requirements)**

Supported by: **[Claim AuthN](#claim-authn)**, [Claim AuthZ](#claim-authz)

Supports: **[Strategy SecTriad](#strategy-sectriad)**
<!-- end verocase -->

Many of the CIA triad requirements address "authorized" users,
and that requires knowing what "authorized" means.
Thus, like nearly all systems, we must address access control,
which we can divide into identification, authentication, and authorization.
Identity, authentication, and authorization are handled in a traditional
manner, as described below.

#### Identification

Normal users must must first identify themselves in one of two ways:
(1) as a GitHub user with their github account name, or
(2) as a custom "local" user with their email address.

The BadgeApp application runs on a deployment platform (Heroku),
which has its own login mechanisms.
Only those few administrators with deployment platform access have
authorization to log in there, and those are protected by the
deployment platform supplier (and thus we do not consider them further here).
The login credentials in these cases are protected.

<!-- verocase-config element_level = 4 -->
<!-- verocase element AuthN -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-authn"></a>
#### Claim AuthN: Users must identify and authenticate themselves

Referenced by: **[Package Requirements](#package-requirements)**

Supported by: **[Claim LocalAuthN](#claim-localauthn)**, [Claim RemoteAuthN](#claim-remoteauthn)

Supports: **[Claim AccessControl](#claim-accesscontrol)**
<!-- end verocase -->

As with most systems, it's critically
important that authentication work correctly.
Therefore, in this section we'll go into some detail about how
authentication works within the BadgeApp application.

This system implements two kinds of users: local and remote.
Local users log in using a password, but
user passwords are only stored on the server as
iterated salted hashes (using bcrypt).
Remote users use a remote system (we currently only support GitHub)
using the widely-used OAUTH protocol.
At the time the application was written, the recommendation
was to *not* use libraries like Devise, because they were not mature at
the time. Such libraries have become much more mature, but as of yet
there hasn't been a good reason to change.

The key code for initial authentication is the "sessions" controller file
`app/controllers/sessions_controller.rb`, and ongoing management is
performed by the application controller and the session helper.
In this section we only consider the login mechanism
built into the BadgeApp.  Heroku has its own login mechanisms, which must
be carefully controlled but are out of scope here.

##### Initial login

A user who views "/login" will be routed to GET sessions#new, which returns
the login page.  From there:

* A local user login will POST that information to /login, which is
  routed to session#create along with parameters such as session[email]
  and session[password].  If the bcrypt'ed hash of the password matches
  the stored hash, the user is accepted.
  If password doesn't match, the login is rejected.
  This is verified with these tests:
    - `Can login and edit using custom account`
    - `Cannot login with local username and wrong password`
    - `Cannot login with local username and blank password`
* A remote user login (pushing the "log in with GitHub" button) will
  invoke GET "/auth/github".  The application then begin an omniauth
  login, by redirecting the user to "https://github.com/login?"
  with URL parameters of `client_id` and `return_to`.
  When the GitHub login completes, then per the omniauth spec there's a
  redirect back to our site to /auth/github/callback, which is
  routed to session#create along with values such as
  the parameter session[provider] set to 'GitHub', which we then check
  by using the omniauth-github gem (this is the "callback phase").
  If we confirm that GitHub asserts that the user is authenticated,
  then we accept GitHub's ruling for that github user and log them in.
  This interaction with GitHub uses `GITHUB_KEY` and `GITHUB_SECRET`.
  For more information, see the documentation on omniauth-github.
  Note that we trust GitHub to verify a GitHub account (as we must).
  This is verified as part of the test `Has link to GitHub Login`.

The first thing that session#create does is run `counter_fixation`;
this counters session fixation attacks
(it also saves the forwarding url, in case we want to return to it).

Local users may choose to "remember me" to automatically re-login on
that specific browser if they use a local account.
This is implemented using a
cryptographically random nonce called `remember_token` that is
stored in the user's cookie store as a permanent cookie.
It's cryptographically random because it is created by the user model
method `self.new_token` which calls `SecureRandom.urlsafe_base64`.
This `remember_token` acts like a password, which is verified against a
`remember_digest` value stored in the server
that is an iterated salted hash (using bcrypt).
This "remember me" functionality cannot reveal the user's
original password, and if the server's user database is
compromised an attacker cannot easily determine the nonce used to log in.
The nonce is protected in transit by HTTPS (discussed elsewhere).
The `user_id` stored by the user is signed by the server.

As with any "remember me" system, this functionality has a
weakness: if the user's system is compromised, others can copy the
`remember_token` value and then log in as that user using the token
if they use it before it expires.
But this weakness is fundamental to any "remember me"
functionality, and users must opt in to enable "remember me"
(by default users must enter their password on each login,
and the login becomes invalid when the user logs out or when
the user exits the entire browser, because the cookie for login
is only a session cookie).
The "remember me" box was originally implemented
in commit e79decec67.
Note that GitHub users cannot use "remember me" tokens - they can only
authenticate using OAuth. This is enforced both in the user interface
(the "remember me" checkbox only appears in the local login form)
and in the code (the `User#remember` method raises an `ArgumentError`
if called on a GitHub user, and `try_remember_token_login` explicitly
rejects GitHub users even if they somehow have a remember cookie).
This separation is important because GitHub authentication requires
a fresh OAuth token, which cannot be stored in the database for
security reasons (OAuth tokens are session-scoped).

##### Managing sessions after login

A session is created for each user who successfully logs in.
Session data is stored in encrypted cookies managed by Rails.

Session state is managed through a two-tier architecture that
optimizes performance while maintaining security:

**Session Extraction and Validation** (`setup_authentication_state`):
On every request, before any controller action that uses data runs, the
`ApplicationController#setup_authentication_state` `before_action`
extracts and validates authentication state from the encrypted session cookie.
This is the *only* place where session authentication data is extracted.
It performs these critical security checks:

1. Extracts `session[:user_id]` and `session[:time_last_used]` from the
   encrypted session cookie (decrypting the cookie only once per request)
2. Validates the session timestamp - if missing or older than 48 hours
   (`SESSION_TTL`), the session is rejected and reset to prevent session
   tampering and enforce timeout
3. If no valid session exists, attempts to restore login using a
   remember token cookie (only for local users, as explained above)
4. Stores the validated authentication state in instance variables:
   `@session_user_id`, `@session_timestamp`, `@session_user_token`
   (GitHub OAuth token, if applicable), and `@session_github_name`

The `setup_authentication_state` method does
*not* query the database in the normal case,
making authentication checks extremely fast.
This is adequate for showing the GUI for logged-in users, as merely
showing the GUI doesn't give the user any special abilities if the
user account has since been deleted.

The `SessionsHelper#current_user` method lazily loads the full User record
from the database only when needed (e.g., to check admin status or
verify the user still exists).
It uses `@session_user_id` previously set by `setup_authentication_state` as
input and memoizes the result in `@current_user`.
This lazy-loading approach means:

- Simple authentication checks like `logged_in?` (which just checks
  `@session_user_id.present?`) require no database access
- Authorization checks that need user details automatically trigger
  only one database query, cached for the request duration
- Recently-deleted users are properly handled:
  their session claims they're logged in,
  but `current_user` returns nil, and authorization checks fail safely

**Session Timeout and Refresh**:
After each controller action, the `update_session_timestamp` after_action
checks if the session timestamp is older than 1 hour (`RESET_SESSION_TIMER`).
If so, it updates both `session[:time_last_used]` and `@session_timestamp`
to the current time. This dual update ensures:

1. The session cookie gets a fresh timestamp (preventing timeout)
2. The cached instance variable stays synchronized (preventing stale data
   from being used later in the same request)

The 1-hour threshold balances security (regular timestamp updates) with
performance (avoiding constant session cookie encryption on every request).

This architecture provides:

- **Session tampering prevention**: Sessions without timestamps or with
  expired timestamps are rejected.
- **Automatic timeout**: Inactive sessions expire after 48 hours, limiting
  the window for session hijacking
- **Minimal database load**: Authentication state is cached in instance
  variables, and database queries only occur when authorization checks
  require current user data
- **Defense in depth**: Multiple layers (session validation, timestamp checks,
  user existence verification) must all succeed for authorization to proceed
- **Clear separation**: Session validation in the controller is separated from
  user lookup in the helper, making the code easier to audit and test

<!-- verocase-config element_level = 5 -->
<!-- verocase element LocalAuthN -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-localauthn"></a>
##### Claim LocalAuthN: Local users must supply a password

Referenced by: **[Package Requirements](#package-requirements)**

Supported by: **[Evidence LocalAuthNEv](#evidence-localauthnev)**

Supports: **[Claim AuthN](#claim-authn)**
<!-- end verocase -->

Local users must supply a valid password to log in.
Passwords are verified by comparing the bcrypt hash stored on the server
against the provided password (see the [initial login](#initial-login) section).
The system enforces rejection on wrong or blank passwords,
as verified by the test suite.

<!-- verocase element RemoteAuthN -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-remoteauthn"></a>
##### Claim RemoteAuthN: Remote users are authenticated by a trusted remote service

Referenced by: **[Package Requirements](#package-requirements)**

Supported by: **[Evidence OAuthEv](#evidence-oauthev)**

Supports: **[Claim AuthN](#claim-authn)**
<!-- end verocase -->

Remote users are authenticated by GitHub via the OAuth protocol.
When a user clicks "Log in with GitHub", the application redirects to GitHub,
which authenticates the user and returns a callback.
We trust GitHub's authentication assertion for GitHub accounts,
using the omniauth-github gem (see the [initial login](#initial-login) section).

<!-- verocase-config element_level = 4 -->
<!-- verocase element AuthZ -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-authz"></a>
#### Claim AuthZ: Authorization to resources and actions is controlled

Referenced by: **[Package Requirements](#package-requirements)**

Supported by: **[Evidence AuthZEv](#evidence-authzev)**

Supports: **[Claim AccessControl](#claim-accesscontrol)**
<!-- end verocase -->

Users who have not authenticated themselves can only perform
actions allowed to anyone in the public (e.g., view the home page,
view the list of projects, and view the information about each project).
Once users are authenticated they are authorized to perform certain
additional actions depending on their permissions.

The permissions system is intentionally simple.
As noted above,
every user has an account, either a 'local' account or an external
system account (currently we support GitHub as an external account).
A user with role='admin' is an administrator;
few users are administrators, and only those with direct platform (Heroku)
access can set a user to be an administrator.

Anyone can create a normal user account.
Only that user, or an administrator, can edit or delete a user account.

A user can create as many project entries as desired.
Each project entry gets a new unique project id and is
owned by the user who created the project entry.

There are two kinds of rights over project data:
"control" rights and "edit" rights.

"Control" rights mean you can delete the project AND
change who else is allowed to edit (they control their projects'
entry in the `additional_rights` table). Anyone with control rights
also has edit rights.  The project owner has control
rights to the projects they own,
and admins have control rights over all projects.
This is determined by the method `can_control?`.

"Edit" rights mean you can edit the project entry. If you have
control rights over a project you also have edit rights.
In addition, fellow committers on GitHub for that project (if on GitHub),
and users in the `additional_rights` table
who have their `user_id` listed for that project, get edit rights
for that project.

If a GitHub user tries to edit a project on GitHub, and the user
is not the badge owner, we permit edits in the following cases:

1. The user is the repo owner. We can tell this because their login nickname
   matches the user name of the repo owner on GitHub.
2. GitHub reports that the user is allowed to edit the project.
   We determine this (as of 2020-04-16) by using the GitHub repos API
   https://api.github.com/:owner/:repo and checking the field "permissions".
   We consider a user with `push` permissions an editor of the project,
   and thus someone who can edit the badge entry.
   This request only lists the permissions for that one repo, so this works
   relatively quickly even if a GitHub user has many permissions.
   (At one time we asked for a list of all user permissions, but that
   times out if a user has many permissions, and we didn't really want
   most of that data anyway.)
   We trust GitHub to provide correct data if it provides this data,
   but asking for this data causes delay (as we wait for this response)
   and there's a small risk that GitHub might stop reporting this data
   (it is not well-documented).  We've countered those concerns with other
   steps. In particular, in most cases editors are either badge owners and/or
   the repo owner, and we check that first. This is faster, and in most
   cases editing will keep working even if GitHub stops reporting this
   data. In addition, the `additional_rights` table can always provide
   this functionality no matter what.

The `additional_rights` table adds support for groups so that they can
edit project entries in arbitrary cases
(e.g., when the project is not on GitHub or a user
is not on GitHub).
This is determined by the method `can_edit?`.

This means that
a project entry can only be edited (and deleted) by the entry creator,
an administrator, by others who can prove that they
can edit that GitHub repository (if it is on GitHub), and by those
authorized to edit via the `additional_rights` table.
Anyone can see the project entry results once they are saved.

We expressly include tests in our test suite
of our authorization system
to check that accounts cannot perform actions they are not authorized
to perform (e.g., edit a project that they do not have edit rights to,
or delete a project they do not control).
It's important to test that certain actions that *must* fail for
security reasons do indeed fail.
For more, see the earlier section justifying the claim that
"Data modification requires authorization".

<!-- verocase element AuthZEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-authzev"></a>
#### Evidence AuthZEv: can_edit? and can_control? methods implement role-based authorization; all access enforced server-side through controllers

Referenced by: **[Package Requirements](#package-requirements)**

Supports: **[Claim AuthZ](#claim-authz)**

External Reference: [../app/controllers/application_controller.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../app/controllers/application_controller.rb)
<!-- end verocase -->

`can_edit?` and `can_control?` methods implement role-based authorization; all access enforced server-side through controllers. See [../app/controllers/application_controller.rb](../app/controllers/application_controller.rb).

<!-- verocase-config element_level = 3 -->
<!-- verocase element Assets -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-assets"></a>
### Claim Assets: Assets & threat actors identified & addressed

Referenced by: **[Package Requirements](#package-requirements)**

Supported by: **[Claim AssetsIdentified](#claim-assetsidentified)**, [Claim ThreatsIdentified](#claim-threatsidentified)

Supports: **[Claim Requirements](#claim-requirements)**
<!-- end verocase -->

#### Assets

As should be clear from the basic requirements above, our assets are:

*   User passwords, especially for confidentiality.
    Unencrypted user passwords are the most critical
    to protect. As noted above, we protect these with bcrypt;
    we never store user passwords in an unencrypted or recoverable form.
*   The "remember me" nonce if a user requests it - we protect
    its confidentiality on the server side.
*   User email addresses, especially for confidentiality.
*   Project data, primarily for integrity and availability.
    We back these up to support availability.

#### Threat Agents

We have few insiders, and they are fully trusted to *not*
perform intentionally-hostile actions.

Thus, the threat agents we're primarily concerned about are outsiders,
and the most concerning ones fit in one of these categories:

*  people who enjoy taking over systems (without monetary benefit)
*  criminal organizations who want to take emails and/or passwords
   as a way to take over others' accounts (to break confidentiality).
   Note that our one-way iterated salted hashes counter easy access
   to passwords, so the most sensitive data is more difficult to obtain.
*  criminal organizations who want destroy all our data and hold it for
   ransom (i.e., "ransomware" organizations).  Note that our backups
   help counter this.

Criminal organizations may try to DDoS us for money, but there's no
strong reason for us to pay the extortion fee.
We expect that people will be willing to come back to the site later
if it's down, and we have scalability countermeasures to reduce their
effectiveness.  If the attack is ongoing, several of the services we use
would have a financial incentive to help us counter the attacks.
This makes the attacks themselves less likely
(since there would be no financial benefit to them).

Like many commercial sites,
we do not have the (substantial) resources necessary
to counter a state actor who decided to directly attack our site.
However, there's no reason a state actor would directly attack the site
(we don't store anything that valuable), so while many are very capable,
we do not expect them to be a threat to this site.

### Other Notes on Security Requirements

Here are a few other notes about the security requirements.

It is difficult to implement truly secure software.
One challenge is that BadgeApp must accept, store, and retrieve data from
untrusted (non-admin) users.
In addition, BadgeApp must also go out
to untrusted websites with untrusted contents,
using URLs provided by untrusted users,
to gather data about those projects (so it can automatically fill in data).
By "untrusted" we mean sites that might attempt to attack BadgeApp, e.g.,
by providing malicious data or by being unresponsive.
We have taken a number of steps to reduce the likelihood
of vulnerabilities, and to reduce the impact of vulnerabilities
where they exist.
In particular, retrieval of external information is subject to a timeout,
we use Ruby (a memory-safe language),
and exceptions halt automated processing for that entry (which merely
disables automated data gathering for that entry).

Here we have identified the key security requirements and why we believe
they've been met overall.  However, there is always the possibility that
a mistake could lead to failure to meet these requirements.
It is not possible to eliminate all possible risks; instead,
we focus on *managing* risks.
We manage our security risks by
implementing security in our software life cycle processes.
We also protect our development environment and choose people
who will help support this.
The following sections describe how we've managed our security-related risks.

<!-- verocase-config element_level = 2 -->
<!-- verocase element Design -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-design"></a>
## Claim Design: Security in design

Referenced by: **[Package Design](#package-design)**, [Package Security](#package-security)

Supported by: **[Claim SimpleDesign](#claim-simpledesign)**, [Claim STRIDE](#claim-stride), [Claim DesignPrinciples](#claim-designprinciples), [Claim Scalability](#claim-scalability), [Claim MemSafe](#claim-memsafe)

Supports: [Claim TechProcesses](#claim-techprocesses)
<!-- end verocase -->

We emphasize security in the architectural design.

We first present a brief summary of the high-level design,
followed by the results of threat modeling that are based on the design
(this entire document is the result of threat modeling in the
broader sense).
The then discuss approaches we are using in the design
to improve security:
using a simple design,
applying secure design principles,
limiting memory-unsafe language use, and
increasing availability through scalability.

The design, including the security-related items identified here,
were developed through our
design process, which merges
three related processes in ISO/IEC/IEEE 12207
(architecture definition process, design definition process, and
system analysis process).
In particular, the STRIDE analysis results (below) are the primary output
of our system analysis process.

### High-level Design

The following figure shows a high-level design of the implementation:

![Design](./design.png)

See the [implementation](./implementation.md) file to
see a more detailed discussion of the software design.

<!-- verocase-config element_level = 3 -->
<!-- verocase element STRIDE -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-stride"></a>
### Claim STRIDE: STRIDE threat model has been analyzed

Referenced by: **[Package Design](#package-design)**

Supported by: **[Evidence STRIDEEv](#evidence-strideev)**

Supports: **[Claim Design](#claim-design)**
<!-- end verocase -->

There are many approaches for threat (attack) modeling, e.g., a
focus on attackers, assets, or the design.
We have already discussed attackers and assets; here we focus on the design.

Here we have decided to apply a simplified version of
Microsoft's STRIDE approach for threat modeling.
As explained in
[The STRIDE Threat Model](https://msdn.microsoft.com/en-us/library/ee823878%28v=cs.20%29.aspx), each major design component is examined for:

*   Spoofing identity. An example of identity spoofing is illegally accessing and then using another user's authentication information, such as username and password.
*   Tampering with data. Data tampering involves the malicious modification of data. Examples include unauthorized changes made to persistent data, such as that held in a database, and the alteration of data as it flows between two computers over an open network, such as the Internet.
*   Repudiation. Repudiation threats are associated with users who deny performing an action without other parties having any way to prove otherwise - for example, a user performs an illegal operation in a system that lacks the ability to trace the prohibited operations. Non-repudiation refers to the ability of a system to counter repudiation threats. For example, a user who purchases an item might have to sign for the item upon receipt. The vendor can then use the signed receipt as evidence that the user did receive the package.
*   Information disclosure. Information disclosure threats involve the exposure of information to individuals who are not supposed to have access to it-for example, the ability of users to read a file that they were not granted access to, or the ability of an intruder to read data in transit between two computers.
*   Denial of service. Denial of service (DoS) attacks deny service to valid users-for example, by making a Web server temporarily unavailable or unusable. You must protect against certain types of DoS threats simply to improve system availability and reliability.
*   Elevation of privilege. In this type of threat, an unprivileged user gains privileged access and thereby has sufficient access to compromise or destroy the entire system. Elevation of privilege threats include those situations in which an attacker has effectively penetrated all system defenses and become part of the trusted system itself, a dangerous situation indeed.

The diagram shown earlier is not a data flow diagram
(DFD), but it can be interpreted as one by interpreting
the arrows as two-way data flows.
This is frankly too detailed for such a simple system, so we will
group rectangles together into a smaller set of processes as shown below.

#### Web server, Web App Interface, and Router

The web server and webapp interface accept untrusted data and deliver
it to the appropriate controller.

*   Spoofing identity. N/A, identity is irrelevant because it's untrusted.
*   Tampering with data. Data is only accepted by the web server via HTTPS.
*   Repudiation. N/A.
*   Information disclosure. These simply deliver untrusted data to components
    we trust to handle it properly.
*   Denial of service. We use scalability, caching, a CDN,
    and rapid recovery to help deal with denial of service attacks.
    Large denial of service attacks are hard to counter, and we don't claim
    to be able to prevent them.
*   Elevation of privilege. By itself these components provide no privilege.

#### Controllers, Models, Views

*   Spoofing identity. Identities are authenticated before they are used.
    Session values are sent back to the user, but stored in an encrypted
    container and only the server has the encryption key.
*   Tampering with data.
    User authorization is checked before changes are permitted.
*   Repudiation. N/A.
*   Information disclosure.  Sensitive data (passwords and email addresses)
    is not displayed in any view unless the user is an authorized admin.
    Our contributing documentation expressly forbids storing email addresses
    in the Rails cache; that way, if we accidentally display the wrong
    cache, no email address will be revealed.
*   Denial of service. See earlier comments on DoS.
*   Elevation of privilege.  These are written in a memory-safe language,
    and written defensively (since normal users are untrusted).
    There's no known way to use an existing
    privilege to gain more privileges.
    In addition, the application has no built-in mechanism
    for turning normal users into administrators; this must be done using
    the SQL interface that is only available to those who have admin rights
    to access the SQL database.  That's no guarantee of invulnerability,
    but it means that there's no pre-existing code that can be triggered
    to cause the change.

#### DBMS

There is no direct access for normal users to the DBMS;
in production, access requires special Heroku keys.

The DBMS does not know which user the BadgeApp
is operating on behalf of, and does not have separate privileges.
However, the BadgeApp uses ActiveRecord and parameterized statements,
making it unlikely that an attacker can use SQL injections to
insert malicious queries.

*   Spoofing identity. N/A, the database doesn't track identities.
*   Tampering with data. The BadgeApp is trusted to make correct requests.
*   Repudiation. N/A.
*   Information disclosure.  The BadgeApp is trusted to make correct requests.
*   Denial of service. See earlier comments on DoS.
*   Elevation of privilege.  N/A, the DBMS doesn't separate privileges.

#### Chief and Detectives

*   Spoofing identity. N/A, these simply collect data.
*   Tampering with data. These use HTTPS when provided HTTPS URLs.
*   Repudiation. N/A.
*   Information disclosure.  These simply retrieve and summarize
    information that is publicly available, using URLs provided by users.
*   Denial of service.  Timeouts are in place so that if the project
    isn't responsive, eventually the system automatically recovers.
*   Elevation of privilege.  These are written in a memory-safe language,
    and written defensively (since the project sites are untrusted).

#### Admin CLI

There is a command line interface (CLI) for admins.
This is the Heroku CLI.
Admins must use their unique credentials to log in.
[The channel between the admin and the Heroku site is encrypted using TLS](https://github.com/heroku/cli/blob/master/http.go).

*   Spoofing identity. Every admin has a unique credential.
*   Tampering with data. The communication channel is encrypted.
*   Repudiation. Admins have unique credentials.
*   Information disclosure.  The channel is encrypted in motion.
*   Denial of service.  Heroku has a financial incentive to keep this
    available, and takes steps to do so.
*   Elevation of privilege.  N/A; anyone allowed to use this is privileged.

#### Translation service and I18n text

This software is internationalized.

All text used for display is in the directory "config/locales"; on the figure
this is shown as I18n (internationalized) text.
The source text specific to the application is in English
in file config/locales/en.yml.
The "rake translation:sync" command, which is executed within the
*development* environment, transmits the current version of en.yml
to the site translation.io, and loads the current text from translation.io into
the various config/locales files.
Only authorized translators are given edit rights to translations on
translation.io.

We consider translation.io and our translators as trusted.
That said, we impose a variety of security safeguards as if they were not
trusted.  That way, if something happens (e.g., someone's account is
subverted), then the damage that can be done is limited.

Here are the key security safeguards:

* During "translation:sync" synchronization,
  the "en.yml" file downloaded from translation.io is erased, and
  the original "en.yml" is restored.  Thus, translation.io *cannot* modify
  the English source text.
* After synchronization, and on every test run (including deployment to a tier),
  *every* text segment (including English) is checked, including to
  ensure that *only* an allowlisted set of HTML tags
  and attributes (at most) are
  included in every text.  The tests will fail, and the system will not be
  deployed, if any other tags or attributes are used.
  This set does not include dangerous tags such as &lt;script&gt;.
  The test details are in `test/models/translations_test.rb`.
  Thus, while a translation can be wrong or be defaced,
  what it can include in the HTML (and thus attack users) is very limited.
  Although not relevant to security, it's worth noting that these tests
  also check for many errors in translation.  For example, only Latin
  lowercase letters are allowed after "&lt;" and "&lt;/"; these protect
  against following these sequences with whitespace or a Cyrillic "a".
* Synchronization simply transfers the updated translations to the
  directory config/locales.  This is then reviewed by a committer before
  committing, and goes through tiers as usual.

We don't want the text defaced, and take a number of steps to prevent it.
That said, what's more important is ensuring that defaced text is unlikely
to turn into an attack on our users, so we take *extra* cautions
to prevent that.

Given these safeguards, here is how we deal with STRIDE:

*   Spoofing identity. Every translator has a unique credential.
*   Tampering with data. Translators other than admins are only given edit
    rights for a particular locale.  The damage is limited, because
    the text must pass through an HTML sanitizer.
*   Repudiation. Those authorized on translation.io have unique credentials.
*   Information disclosure.  The channel is encrypted in motion, and in
    any case other than passwords this is all public information.
*   Denial of service.  Translation.io has a financial incentive to keep its
    service available, and takes steps to do so.
    At run-time the system uses its internal text copy, so if
    translation.io stops working for a while, our site can continue working.
    If it stayed down, we could switch to another service or do it ourselves.
*   Elevation of privilege.  A translator cannot edit the source text files
    by this mechanism.  Sanitization checks limit the damage that can be done.

<!-- verocase element SimpleDesign -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-simpledesign"></a>
### Claim SimpleDesign: Economy of mechanism: simple design is used

Referenced by: **[Package Design](#package-design)**

Supported by: **[Evidence SimpleDesignEv](#evidence-simpledesignev)**

Supports: **[Claim Design](#claim-design)**
<!-- end verocase -->

This web application has a simple design.
It is a standard Ruby on Rails design with models, views, and controllers.
In production it is accessed via a web server (Puma) and
builds on a relational database database system (PostgreSQL).
The software is multi-process and is intended to be multi-threaded
(see the [CONTRIBUTING.md](../CONTRIBUTING.md) file for more about this).
The database system itself is trusted, and the database managed
by the database system is not directly accessible by untrusted users.
The application runs on Linux kernel and uses some standard operating system
facilities and libraries (e.g., to provide TLS).
All interaction between the users and the web application go over
an encrypted channel using TLS.
There is some JavaScript served to the client,
but no security decisions depend on code that runs on the client.

The custom code has been kept as small as possible, in particular, we've
tried to keep it DRY (don't repeat yourself).

From a user's point of view,
users potentially create an id, then log in and enter data
about projects (as new or updated data).
Users can log in using a local account or by using their GitHub account.
Non-admin users are not trusted.
The entry of project data (and potentially periodically) triggers
an evaluation of data about the project, which automatically fills in
data about the project.
Projects that meet certain criteria earn a badge, which is displayed
by requesting a specific URL.
A "Chief" class and "Detective" classes attempt to get data about a project
and analyze that data; this project data is also untrusted
(in particular, filenames, file contents, issue tracker information and
contents, etc., are all untrusted).

<!-- verocase element DesignPrinciples -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-designprinciples"></a>
### Claim DesignPrinciples: Secure design principles are applied

Referenced by: **[Package DesignPrinciples](#package-designprinciples)**, [Package Design](#package-design)

Supported by: **[Claim EconomyMech](#claim-economymech)**, [Claim CompleteMed](#claim-completemed), [Claim FailSafe](#claim-failsafe), [Claim OpenDesign](#claim-opendesign), [Claim SepPriv](#claim-seppriv), [Claim LeastPriv](#claim-leastpriv), [Claim LeastCommon](#claim-leastcommon), [Claim PsychAccept](#claim-psychaccept), [Claim LimitedAttack](#claim-limitedattack), [Claim InputValid](#claim-inputvalid)

Supports: [Claim Design](#claim-design)
<!-- end verocase -->

Applying various secure design principles helps us avoid
security problems in the first place.
The most widely-used list of security design principles, and
one we build on, is the list developed by
[Saltzer and Schroeder](http://web.mit.edu/Saltzer/www/publications/protection/).

Here are a number of secure design principles and how we follow them,
including all 8 principles from
[Saltzer and Schroeder](http://web.mit.edu/Saltzer/www/publications/protection/):

* Economy of mechanism (keep the design as simple and small as practical,
  e.g., by adopting sweeping simplifications).
  We discuss this in more detail in the section
  "[simple design](#simple-design)".
* Fail-safe defaults (access decisions should deny by default):
  Access decisions are deny by default.
* Complete mediation (every access that might be limited must be
  checked for authority and be non-bypassable):
  Every access that might be limited is checked for authority and
  non-bypassable.  Security checks are in the controllers, not the router,
  because multiple routes can lead to the same controller
  (this is per Rails security guidelines).
  When entering data, JavaScript code on the client shows whether or not
  the badge has been achieved, but the client-side code is *not* the
  final authority (it's merely a convenience).  The final arbiter of
  badge acceptance is server-side code, which is not bypassable.
* Open design (security mechanisms should not depend on attacker
  ignorance of its design, but instead on more easily protected and
  changed information like keys and passwords):
  The entire program is open source software and subject to inspection.
  Keys are kept in separate files not included in the public repository.
* Separation of privilege (multi-factor authentication,
  such as requiring both a password and a hardware token,
  is stronger than single-factor authentication):
  We don't use multi-factor authentication because the risks from compromise
  are smaller compared to many other systems
  (it's almost entirely public data, and failures generally can be recovered
  through backups).
* Least privilege (processes should operate with the
  least privilege necessary): The application runs as a normal user,
  not a privileged user like "root".  It must have read/write access to
  its database, so it has that privilege.
* Least common mechanism (the design should minimize the mechanisms
  common to more than one user and depended on by all users,
  e.g., directories for temporary files):
  No shared temporary directory is used.  Each time a new request is made,
  new objects are instantiated; this makes the program generally thread-safe
  as well as minimizing mechanisms common to more than one user.
  The database is shared, but each table row has access control implemented
  which limits sharing to those authorized to share.
* Psychological acceptability
  (the human interface must be designed for ease of use,
  designing for "least astonishment" can help):
  The application presents a simple login and "fill in the form"
  interface, so it should be acceptable.
* Limited attack surface (the attack surface, the set of the different
  points where an attacker can try to enter or extract data, should be limited):
  The application has a limited attack surface.
  As with all Ruby on Rails applications, all access must go through the
  router to the controllers; the controllers then check for access permission.
  There are few routes, and few controller methods are publicly accessible.
  The underlying database is configured to *not* be publicly accessible.
  Many of the operations use numeric ids (e.g., which project), which are
  simply numbers (limiting the opportunity for attack because numbers are
  trivial to validate).
* Input validation with allowlists
  (inputs should typically be checked to determine if they are valid
  before they are accepted; this validation should use allowlists
  (which only accept known-good values),
  not denylists (which attempt to list known-bad values)):
  In data provided directly to the web application,
  input validation is done with allowlists through controllers and models.
  Parameters are first checked in the controllers using the Ruby on Rails
  "strong parameter" mechanism, which ensures that only an allowlisted set
  of parameters are accepted at all.
  Once the parameters are accepted, Ruby on Rails'
  [active record validations](http://guides.rubyonrails.org/active_record_validations.html)
  are used.
  All project parameters are checked by the model, in particular,
  status values (the key values used for badges) are checked against
  an allowlist of values allowed for that criterion.
  There are a number of freetext fields (name, license, and the
  justifications); since they are freetext these are the hardest
  to allowlist.
  That said, we even impose restrictions on freetext, in particular,
  they must be valid UTF-8, they must not include control characters
  (other than \\n and \\r), and they have maximum lengths.
  These checks by themselves cannot counter certain attacks;
  see the text on security in implementation for the discussion on
  how this application counters SQL injection, XSS, and CSRF attacks.
  URLs are also limited by length and an allowlisted regex, which counters
  some kinds of attacks.
  When project data (new or edited) is provided, all proposed status values
  are checked to ensure they are one of the legal criteria values for
  that criterion (Met, Unmet, ?, or N/A depending on the criterion).
  Once project data is received, the application tries to get some
  values from the project itself; this data may be malevolent, but the
  application is just looking for the presence or absence of certain
  data patterns, and never executes data from the project.

<!-- verocase-config element_level = 4 -->
<!-- verocase element EconomyMech -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-economymech"></a>
#### Claim EconomyMech: Economy of mechanism

Referenced by: **[Package DesignPrinciples](#package-designprinciples)**

Supported by: **[Evidence EconomyMechEv](#evidence-economymechev)**

Supports: **[Claim DesignPrinciples](#claim-designprinciples)**
<!-- end verocase -->

We keep the design simple and small to reduce the attack surface.
See the [Claim SimpleDesign](#claim-simpledesign) section for details;
the list of secure design principles above elaborates on this.

<!-- verocase element CompleteMed -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-completemed"></a>
#### Claim CompleteMed: Complete mediation

Referenced by: **[Package DesignPrinciples](#package-designprinciples)**

Supported by: **[Evidence CompleteMedEv](#evidence-completemedev)**

Supports: **[Claim DesignPrinciples](#claim-designprinciples)**
<!-- end verocase -->

Every access to every object is checked for authorization.
Server-side controllers and routers enforce this — client-side JavaScript
has no role in access control decisions.
See the secure design principles discussion above for details.

<!-- verocase element FailSafe -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-failsafe"></a>
#### Claim FailSafe: Fail-safe defaults

Referenced by: **[Package DesignPrinciples](#package-designprinciples)**

Supported by: **[Evidence FailSafeEv](#evidence-failsafeev)**

Supports: **[Claim DesignPrinciples](#claim-designprinciples)**
<!-- end verocase -->

Access decisions default to denial.
Unauthenticated users can only access publicly available resources.
All additional permissions must be explicitly granted.
See the secure design principles discussion above for details.

<!-- verocase element OpenDesign -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-opendesign"></a>
#### Claim OpenDesign: Open design

Referenced by: **[Package DesignPrinciples](#package-designprinciples)**

Supported by: **[Evidence OpenDesignEv](#evidence-opendesignev)**

Supports: **[Claim DesignPrinciples](#claim-designprinciples)**
<!-- end verocase -->

The application is open source (FLOSS), so the design can be reviewed by anyone.
We don't rely on security through obscurity.
See the secure design principles discussion above for details.

<!-- verocase element SepPriv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-seppriv"></a>
#### Claim SepPriv: Separation of privilege

Referenced by: **[Package DesignPrinciples](#package-designprinciples)**

Supported by: **[Evidence SepPrivEv](#evidence-sepprivev)**

Supports: **[Claim DesignPrinciples](#claim-designprinciples)**
<!-- end verocase -->

The application separates normal user privileges from admin privileges.
Admin functions require a separate admin role check.
See the secure design principles discussion above for details.

<!-- verocase element LeastPriv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-leastpriv"></a>
#### Claim LeastPriv: Least privilege

Referenced by: **[Package DesignPrinciples](#package-designprinciples)**

Supported by: **[Evidence LeastPrivEv](#evidence-leastprivev)**

Supports: **[Claim DesignPrinciples](#claim-designprinciples)**
<!-- end verocase -->

Users are granted only the permissions they need.
Normal users can only edit their own projects;
admin-only functionality is separately restricted.
See the secure design principles discussion above for details.

<!-- verocase element LeastCommon -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-leastcommon"></a>
#### Claim LeastCommon: Least common mechanism

Referenced by: **[Package DesignPrinciples](#package-designprinciples)**

Supported by: **[Evidence LeastCommonEv](#evidence-leastcommonev)**

Supports: **[Claim DesignPrinciples](#claim-designprinciples)**
<!-- end verocase -->

We minimize shared mechanisms between users.
Each request is processed independently, and session state is
stored in per-user encrypted cookies rather than shared server-side sessions.
See the secure design principles discussion above for details.

<!-- verocase element PsychAccept -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-psychaccept"></a>
#### Claim PsychAccept: Psychological acceptability

Referenced by: **[Package DesignPrinciples](#package-designprinciples)**

Supported by: **[Evidence PsychAcceptEv](#evidence-psychacceptev)**

Supports: **[Claim DesignPrinciples](#claim-designprinciples)**
<!-- end verocase -->

The security mechanisms are designed to be user-friendly.
For example, users can log in via GitHub OAuth to avoid
managing a separate password, and the "remember me" feature
reduces repeated logins.
See the secure design principles discussion above for details.

<!-- verocase element LimitedAttack -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-limitedattack"></a>
#### Claim LimitedAttack: Limited attack surface

Referenced by: **[Package DesignPrinciples](#package-designprinciples)**

Supported by: **[Evidence LimitedAttackEv](#evidence-limitedattackev)**

Supports: **[Claim DesignPrinciples](#claim-designprinciples)**
<!-- end verocase -->

We limit the attack surface by restricting input types, using a CDN,
enforcing HTTPS, and using a routing framework that only exposes
defined endpoints.
See the secure design principles and input validation discussion above for details.

<!-- verocase element InputValid -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-inputvalid"></a>
#### Claim InputValid: Input validation with whitelists

Referenced by: **[Package DesignPrinciples](#package-designprinciples)**

Supported by: **[Evidence InputValidEv](#evidence-inputvalidev)**

Supports: **[Claim DesignPrinciples](#claim-designprinciples)**
<!-- end verocase -->

All inputs are validated using allowlists.
The application validates user-submitted data, including URLs (via allowlisted regex),
project status values (restricted to legal criterion values),
and HTML content (only safe tags and attributes allowed).
See the secure design principles discussion above for details.

<!-- verocase-config element_level = 3 -->
<!-- verocase element Scalability -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-scalability"></a>
### Claim Scalability: Availability through scalability

Referenced by: **[Package Design](#package-design)**

Supported by: **[Evidence ScalabilityEv](#evidence-scalabilityev)**

Supports: **[Claim Design](#claim-design)**
<!-- end verocase -->

Availability is, as always, especially challenging.
Our primary approach is to ensure that the design scales.

As a Ruby on Rails application, it is designed so each request can
be processed separately on separate processes.
We use the 'puma' web server to serve multiple processes
(so attackers must have many multiple simultaneous requests to keep
them all busy),
and timeouts are used (once a request times out, the process is
automatically killed and the server can process a new request).
The system is designed to be easily scalable (just add more worker
processes), so we can quickly purchase additional computing resources
to handle requests if needed.

The system is currently deployed to Heroku, which imposes a hard
time limit for each request; thus, if a request gets stuck
(say during autofill by a malevolent actor who responds slowly),
eventually the timeout will cause the response to stop and the
system will become ready for another request.

We use a Content Delivery Network (CDN), specifically Fastly,
to provide cached values of badges.
These are the most resource-intense kind of request, simply because
they happen so often.
As long as the CDN is up, even if the application crashes the
then-current data will stay available until the system recovers.

The system is configured so all requests go through the CDN (Fastly),
then through Heroku; each provides us with some DDoS protections.
If the system starts up with Fastly configured, then the software
loads the set of valid Fastly IP addresses, and rejects any requests
from other IPs.  This prevents "cloud piercing".
This does use the value of the header X-Forwarded-For, which could
be provided by an attacker, but Heroku guarantees a particular order
so we only retrieve the value that we can trust (through Heroku).
This has been verified to work, because all of the following are rejected:

~~~~
curl https://master-bestpractices.herokuapp.com/
curl -H "X-Forwarded-For: 23.235.32.1" \
     https://master-bestpractices.herokuapp.com/
curl -H "X-Forwarded-For: 23.235.32.1,23.235.32.1" \
     https://master-bestpractices.herokuapp.com/
~~~~

[Systems that use CDNs can be vulnerable to the Cache Poisoned Denial of Service (CPDoS) family of vulnerabilities](https://cpdos.org/).
We do use a CDN (Fastly), but our brief research
suggests that this site is not vulnerable to CPDoS.
The resarchers of CPDoS posted what they found vulnerable, and their
"Fastly" column has empty rows for "Heroku" and "Rails".
Unfortunately they don't directly list Puma (our webserver),
but Puma is the recommended webserver by Heroku for Rails and
is the usual choice.

The system implements a variety of server-side caches, in particular,
it widely uses fragment caching.  This is primarily to improve performance,
but it also helps with availability against a DDoS, because
once a result has been cached it requires very little effort to
serve the same information again.

A determined attacker with significant resources could disable the
system through a distributed denial-of-service (DDoS) attack.
However, this site doesn't have any particular political agenda,
and taking it down is unlikely to provide monetary gain.
Thus, this site doesn't seem as likely a target for a long-term DDoS
attack, and there is not much else we can do to counter DDoS
by an attacker with significant resources without having
significant resources ourselves.

<!-- verocase element MemSafe -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-memsafe"></a>
### Claim MemSafe: Memory-safe languages are used

Referenced by: **[Package Design](#package-design)**

Supported by: **[Evidence MemSafeEv](#evidence-memsafeev)**

Supports: **[Claim Design](#claim-design)**
<!-- end verocase -->

All the code we have written (aka the custom code)
is written in memory-safe languages
(Ruby and JavaScript), so the vulnerabilities of memory-unsafe
languages (such as C and C++) cannot occur in the custom code.
This also applies to most of the code in the directly depended libraries.

Some lower-level reused components (e.g., the operating system kernel,
database management system, encryption library, and some of the Ruby gems)
do have C/C++, but these are widely used components where we have
good reason to believe that developers are directly working to mitigate
the problems from memory-unsafe languages.
See the section below on supply chain (reuse) for more.

<!-- verocase-config element_level = 2 -->
<!-- verocase element Implementation -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-implementation"></a>
## Claim Implementation: Security in implementation

Referenced by: **[Package Implementation](#package-implementation)**, [Package Security](#package-security)

Supported by: **[Strategy CommonVulns](#strategy-commonvulns)**, [Strategy HardeningStrat](#strategy-hardeningstrat), [Claim PubVulns](#claim-pubvulns)

Supports: [Claim TechProcesses](#claim-techprocesses)
<!-- end verocase -->

Most implementation vulnerabilities are due to common types
of implementation errors or common misconfigurations,
so countering them greatly reduces security risks.

To reduce the risk of security vulnerabilities in implementation we
have focused on countering the OWASP Top 10,
both the
[OWASP Top 10 (2013)](https://www.owasp.org/index.php/Top_10_2013-Top_10)
and
[OWASP Top 10 (2017)](https://www.owasp.org/index.php/Top_10-2017_Top_10).
To counter common misconfigurations, we apply the
[Ruby on Rails Security Guide](http://guides.rubyonrails.org/security.html).
We have also taken steps to harden the application.
Finally, we try to stay vigilant when new kinds of vulnerabilities are
reported that apply to this application, and make adjustments.
Below is how we've done each, in turn.

<!-- verocase-config element_level = 3 -->
<!-- verocase element CommonVulns -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="strategy-commonvulns"></a>
### Strategy CommonVulns: Most implementation vulnerabilities are due to common types of implementation errors or common misconfigurations, so countering them greatly reduces security risks

Referenced by: **[Package Implementation](#package-implementation)**

Supported by: **[Claim OWASPClaim](#claim-owaspclaim)**, [Claim MisconfigClaim](#claim-misconfigclaim), [Claim ReuseSec](#claim-reusesec)

Supports: **[Claim Implementation](#claim-implementation)**
<!-- end verocase -->

Most implementation vulnerabilities arise from common types of errors or
misconfigurations. By systematically countering these common categories,
we greatly reduce overall security risk.

<!-- verocase-config element_level = 3 -->
<!-- verocase element OWASPClaim -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-owaspclaim"></a>
### Claim OWASPClaim: All of the most common important implementation vulnerability types (weaknesses) countered

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**, [Package Implementation](#package-implementation)

Supported by: **[Strategy OWASPStrat](#strategy-owaspstrat)**

Supports: [Strategy CommonVulns](#strategy-commonvulns)
<!-- end verocase -->

The OWASP Top 10 is a broad industry consensus of the most critical
web application security risks. By systematically addressing each
category, we achieve comprehensive coverage of the implementation
attack surface. See the sub-claims below for the argument for each
OWASP category.

<!-- verocase-config element_level = 4 -->
<!-- verocase element OWASPStrat -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="strategy-owaspstrat"></a>
#### Strategy OWASPStrat: OWASP top 10 represents a broad consensus of the most critical web application security flaws

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supported by: **[Claim OWASP1013](#claim-owasp1013)**

Supports: **[Claim OWASPClaim](#claim-owaspclaim)**
<!-- end verocase -->

The OWASP Top 10 represents a broad consensus of the most critical web application
security flaws, providing a comprehensive baseline for addressing common
implementation vulnerabilities.

<!-- verocase element OWASP1013 -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-owasp1013"></a>
#### Claim OWASP1013: All OWASP top 10 (2013 & 2017) countered

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supported by: **[Claim OWASP1](#claim-owasp1)**, [Claim OWASP2](#claim-owasp2), [Claim OWASP3](#claim-owasp3), [Claim OWASP4](#claim-owasp4), [Claim OWASP5](#claim-owasp5), [Claim OWASP6](#claim-owasp6), [Claim OWASP7](#claim-owasp7), [Claim OWASP8](#claim-owasp8), [Claim OWASP9](#claim-owasp9), [Claim OWASP10](#claim-owasp10), [Claim OWASP11](#claim-owasp11), [Claim OWASP12](#claim-owasp12), [Claim OWASP13](#claim-owasp13)

Supports: **[Strategy OWASPStrat](#strategy-owaspstrat)**
<!-- end verocase -->

All OWASP Top 10 items from both the 2013 and 2017 lists are addressed.
The 2017 list adds XXE (A4), Insecure Deserialization (A8), and
Insufficient Logging and Monitoring (A10) beyond the 2013 items.
Each item is addressed individually in the sub-claims below.

The OWASP Top 10
([details](https://www.owasp.org/index.php/Category:OWASP_Top_Ten_Project))
represents "a broad consensus about what the most
critical web application security flaws are."
When this application was originally developed, the current version was
[OWASP Top 10 (2013)](https://www.owasp.org/index.php/Top_10_2013-Top_10).
Since that time the 2017 version, aka
[OWASP Top 10 (2017)](https://www.owasp.org/index.php/Top_10-2017_Top_10),
has become available.
We address all of the issues identified in both lists.
By ensuring that we address all of them,
we address all of the most critical and common flaws for
this we application.

Here are the OWASP top 10
and how we attempt to reduce their risks in BadgeApp.
We list them in order of the ten 2013 items, and then (starting at #11)
list the additional items added since 2013.

1. Injection.
   BadgeApp is implemented in Ruby on Rails, which has
   built-in protection against SQL injection.  SQL commands are generally
   not used directly, instead Rails includes ActiveRecord, which implements an
   Object Relational Mapping (ORM) with parameterized commands.
   In a few rare cases SQL commands (or fragments of them) are created directly,
   but these SQL commands never use unparameterized untrusted inputs.
   Any inputs to SQL commands are always parameterized, trusted, or both,
   typically using its parametrized mechanisms or similar mechanisms such as
   `sanitize_sql_like`.
   Note: Admin user search intentionally does NOT escape LIKE wildcards
   (% and _) to support GDPR compliance and legal requests requiring
   pattern matching. This is safe because only admin users can access
   this functionality (UsersController#search_name).
   The shell is not used to download or process file contents (e.g., from
   repositories), instead, various Ruby APIs acquire and process it directly.
2. Broken Authentication and Session Management.
   Sessions are created and destroyed through a common
   Rails mechanism, including an encrypted and signed cookie authentication
   value.
3. Cross-Site Scripting (XSS).
   We use Rails' built-in XSS
   countermeasures, in particular, its "safe" HTML mechanisms such
   as SafeBuffer.  By default, Rails always applies HTML escapes
   on strings displayed through views unless they are marked as safe.
   [SafeBuffers and Rails 3.0](http://yehudakatz.com/2010/02/01/safebuffers-and-rails-3-0/)
   discusses this in more detail.
   This greatly reduces the risk of mistakes leading to XSS vulnerabilities.
   We do process markdown, but markdown processing always checks to ensure
   that only specific safe balanced tags are allowed and only specific
   safe attributes are allowed, and it marks all external hrefs with
   "nofollow ugc noopener noreferrer" to clearly identify such links.
   In addition, we use a restrictive Content Security Policy (CSP).
   Our CSP, for example, tells web browsers to not execute any JavaScript
   included in HTML (JavaScript must be in separate JavaScript files).
   This makes limits damage even if an attacker gets something into
   the generated HTML.
4. Insecure Direct Object References.
   The only supported direct object references are for publicly available
   objects (stylesheets, etc.).
   All other requests go through routers and controllers,
   which determine what may be accessed.
5. Security Misconfiguration.
   See the section on [countering misconfiguration](#misconfiguration).
6. Sensitive Data Exposure.
   We generally do not store sensitive data; most of the data about projects
   is intended to be public.  We do store email addresses, and work to
   prevent them from exposure.
   The local passwords are potentially the most sensitive; stolen passwords
   allow others to masquerade as that user, possibly on other sites
   if the user reuses the password on other sites.
   Local passwords are encrypted with bcrypt
   (this is a well-known iterated salted hash algorithm) using a per-user salt.
   We don't store email addresses in the Rails cache, so if even if the
   wrong cache is used an email address won't be exposed.
   We use HTTPS to establish an encrypted link between the server and users,
   to prevent sensitive data (like passwords) from being disclosed in motion.
7. Missing Function Level Access Control.
   The system depends on server-side routers and controllers for
   access control.  There is some client-side JavaScript, but no
   access control depends on it.
8.  Cross-Site Request Forgery (CSRF or XSRF).
    We use the built-in Rails CSRF countermeasure, where csrf tokens
    are included in replies and checked on POST inputs.
    We also set cookies with SameSite=Lax, which automatically counters
    CSRF on supported browsers (such as Chrome).
    Our restrictive Content Security Policy (CSP) helps here, too.
    For more information, see the
    [Ruby on Rails Guide on Security (CSRF)](http://guides.rubyonrails.org/security.html#cross-site-request-forgery-csrf) and
    [ActionController request forgery protection](http://api.rubyonrails.org/classes/ActionController/RequestForgeryProtection.html).
    We can walk through various cases to show that this problem cannot occur
    with user Alice, attacker Mallory, and our server:
    * If Alice is not logged in, Alice has no currently-active
      privileges for CSRF to exploit.
    * We'll assume Alice knows that logging into Mallory's
      site is not the same as logging into our site,
      that our anti-spoofing ("frame busting") techniques work, and that
      TLS (with certificates) works correctly.
      Thus, Mallory can't just show a "login here" page that Alice will use.
      From here on, we'll assume that Alice is logged in normally through
      our website, and that Mallory will try to convince Alice to click
      on something on a website controlled by Mallory to create
      a CSRF attack (which tries to fool our site through Alice).
    * If Alice contacts Mallory's website, Alice won't send the session cookie
      (so Mallory can't directly spoof Alice's session).
      Mallory could create HTML (e.g., hyperlinks and forms) for Alice;
      if Alice selects something on Mallory's HTML,
      Alice will send a request to our server.
      That request from Alice using Mallory's data could be either a GET/HEAD
      or something else (such as POST).
      So now, let's consider those two sub-cases:
        * GET and HEAD are by design never dangerous requests;
          our server merely shows data that Alice is already allowed to see.
          So there is no problem in this case.
        * If the request is something else (such as POST),
          then there are two sub-sub-cases:
            - If the request is something else (such as POST),
              and Alice is using a browser with SameSite cookie support, Alice
              will not send the cookie data - and thus on this request it
              would be as if Alice was not logged in (which is safe).
            - If the request is something else (such as POST),
              and Alice is using
              a browser without SameSite=Lax support, our server will check to
              ensure that the form and cookie data provided by Alice match,
              and only allow actions if they match.
              In this final case, Mallory never got the cookie data,
              so Mallory cannot create a form to match it, foiling Mallory.
              Thus, our approach completely counters CSRF.
9. Using Components with Known Vulnerabilities.
   See the maintenance process.
10. Unvalidated Redirects and Forwards.
   Redirects and forwards are used sparingly, and they are validated.
11. XML External Entities (XXE). This was added in 2017 as "A4".
   Old versions of Rails were vulnerable to some XML external entity
   attacks, but the XML parameters parser was removed from core in Rails 4.0,
   and we do not re-add that optional feature.
   Since we do not accept XML input from untrusted sources, we
   cannot be vulnerable.
   We do *generate* XML (for the Atom feed), but that's different.
   One area where we may *appear* to be vulnerable, but we
   believe we are not, involves nokogiri, libxml2, and
   [CVE-2016-9318](https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2016-9318).
   The analysis of Nokogiri is further discussed below in the section
   on supply chain.
12. Insecure Deserialization. This was added in 2017 as "A8".
   This vulnerability would permit remote code execution or
   sensitive object manipulation on affected platforms.
   The application itself only accepts JSON and HTML fields (POST or GET).
   The JSON parser only deserializes to trusted standard objects
   which are never executed.
   A key component we use, Rails' Action Controller,
   [does implement hash and array parameters](http://guides.rubyonrails.org/action_controller_overview.html#hash-and-array-parameters),
   but these only generate hashes and arrays - there is no
   general deserializer that could lead to an insecurity.
13. Insufficient Logging and Monitoring. This was added in 2017 as "A10".
   We do logging and monitoring, as discussed elsewhere.

Broken Access Control was added in 2017 as "A5", but it's
really just a merge of the
2013's A4 (Insecure Direct Object References)
2013's A7 (Missing Function Level Access Control), which we've
covered as discussed above.
Thus, we don't list that separately.

We continue to cover the 2013 A8 (Cross-Site Request Forgery (CSRF))
and 2013 A10 (Unvalidated Redirects and Forwards), even thought they are
not listed in the 2017 edition of the OWASP top 10.

<!-- verocase-config element_level = 4 -->
<!-- verocase element OWASP1 -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-owasp1"></a>
#### Claim OWASP1: Injection (including SQL injection) countered

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supported by: **[Evidence OWASP1Ev](#evidence-owasp1ev)**

Supports: **[Claim OWASP1013](#claim-owasp1013)**
<!-- end verocase -->

SQL injection is countered by Rails' ActiveRecord ORM using parameterized queries.
Direct SQL is used only with trusted or parameterized inputs.
See item 1 in the [OWASP countering discussion](#claim-owaspclaim) above.

<!-- verocase element OWASP2 -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-owasp2"></a>
#### Claim OWASP2: Broken Authentication and Session Management countered

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supported by: **[Evidence OWASP2Ev](#evidence-owasp2ev)**

Supports: **[Claim OWASP1013](#claim-owasp1013)**
<!-- end verocase -->

Broken authentication is countered by Rails session management with
encrypted signed cookies, session timeout, and session fixation protection.
See item 2 in the [OWASP countering discussion](#claim-owaspclaim) above.

<!-- verocase element OWASP3 -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-owasp3"></a>
#### Claim OWASP3: Cross-site scripting (XSS) countered

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supported by: **[Evidence OWASP3Ev](#evidence-owasp3ev)**

Supports: **[Claim OWASP1013](#claim-owasp1013)**
<!-- end verocase -->

XSS is countered by Rails' SafeBuffer mechanism (HTML escaping by default),
a restrictive Content Security Policy, and safe markdown processing.
See item 3 in the [OWASP countering discussion](#claim-owaspclaim) above.

<!-- verocase element OWASP4 -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-owasp4"></a>
#### Claim OWASP4: Insecure Direct Object References countered

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supported by: **[Evidence OWASP4Ev](#evidence-owasp4ev)**

Supports: **[Claim OWASP1013](#claim-owasp1013)**
<!-- end verocase -->

Insecure direct object references are countered by routing all requests
through controllers that enforce access control.
See item 4 in the [OWASP countering discussion](#claim-owaspclaim) above.

<!-- verocase element OWASP5 -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-owasp5"></a>
#### Claim OWASP5: Security Misconfiguration countered

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supported by: **[Evidence OWASP5Ev](#evidence-owasp5ev)**

Supports: **[Claim OWASP1013](#claim-owasp1013)**
<!-- end verocase -->

Security misconfiguration is countered by following the Rails security guide
and using secure defaults.
See item 5 in the [OWASP countering discussion](#claim-owaspclaim) above and
the [MisconfigClaim](#claim-misconfigclaim) section.

<!-- verocase element OWASP6 -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-owasp6"></a>
#### Claim OWASP6: Sensitive Data Exposure countered

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supported by: **[Evidence OWASP6Ev](#evidence-owasp6ev)**

Supports: **[Claim OWASP1013](#claim-owasp1013)**
<!-- end verocase -->

Sensitive data exposure is minimized: most data is public,
email addresses are encrypted, passwords use bcrypt,
and HTTPS protects data in motion.
See item 6 in the [OWASP countering discussion](#claim-owaspclaim) above.

<!-- verocase element OWASP7 -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-owasp7"></a>
#### Claim OWASP7: Missing Access Control countered

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supported by: **[Evidence OWASP7Ev](#evidence-owasp7ev)**

Supports: **[Claim OWASP1013](#claim-owasp1013)**
<!-- end verocase -->

Missing access control is countered by server-side role-based authorization
checks in all controllers.
See item 7 in the [OWASP countering discussion](#claim-owaspclaim) above.

<!-- verocase element OWASP8 -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-owasp8"></a>
#### Claim OWASP8: CSRF countered

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supported by: **[Evidence OWASP8Ev](#evidence-owasp8ev)**

Supports: **[Claim OWASP1013](#claim-owasp1013)**
<!-- end verocase -->

CSRF is countered by per-form CSRF tokens, SameSite=Lax cookies,
and a restrictive Content Security Policy.
See item 8 in the [OWASP countering discussion](#claim-owaspclaim) above.

<!-- verocase element OWASP9 -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-owasp9"></a>
#### Claim OWASP9: Known Vulnerabilities countered

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supported by: **[Evidence OWASP9BundleEv](#evidence-owasp9bundleev)**, [Evidence OWASP9DependabotEv](#evidence-owasp9dependabotev)

Supports: **[Claim OWASP1013](#claim-owasp1013)**
<!-- end verocase -->

Known vulnerabilities in components are detected by bundle-audit and
GitHub Dependabot, with rapid update processes in place.
See item 9 in the [OWASP countering discussion](#claim-owaspclaim) above
and the [Maintenance](#claim-maintenance) section.

<!-- verocase element OWASP10 -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-owasp10"></a>
#### Claim OWASP10: Unvalidated Redirects and Forwards countered

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supported by: **[Evidence OWASP10Ev](#evidence-owasp10ev)**

Supports: **[Claim OWASP1013](#claim-owasp1013)**
<!-- end verocase -->

Unvalidated redirects and forwards are countered by using them sparingly
and always validating targets.
See item 10 in the [OWASP countering discussion](#claim-owaspclaim) above.

<!-- verocase element OWASP11 -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-owasp11"></a>
#### Claim OWASP11: XXE countered (2017 A4)

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supported by: **[Evidence OWASP11Ev](#evidence-owasp11ev)**

Supports: **[Claim OWASP1013](#claim-owasp1013)**
<!-- end verocase -->

XXE is countered by not accepting XML from untrusted sources;
the Rails XML parser was removed in Rails 4.0 and is not re-enabled.
See item 11 in the [OWASP countering discussion](#claim-owaspclaim) above.

<!-- verocase element OWASP12 -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-owasp12"></a>
#### Claim OWASP12: Insecure Deserialization countered (2017 A8)

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supported by: **[Evidence OWASP12Ev](#evidence-owasp12ev)**

Supports: **[Claim OWASP1013](#claim-owasp1013)**
<!-- end verocase -->

Insecure deserialization is countered by only accepting JSON and HTML fields,
with the JSON parser deserializing only to trusted standard objects.
See item 12 in the [OWASP countering discussion](#claim-owaspclaim) above.

<!-- verocase element OWASP13 -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-owasp13"></a>
#### Claim OWASP13: Insufficient Logging and Monitoring countered (2017 A10)

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supported by: **[Evidence OWASP13Ev](#evidence-owasp13ev)**

Supports: **[Claim OWASP1013](#claim-owasp1013)**
<!-- end verocase -->

Insufficient logging and monitoring is countered by our internal logging
and external monitoring (see [Claim Detection](#claim-detection)).
See item 13 in the [OWASP countering discussion](#claim-owaspclaim) above.

<!-- verocase-config element_level = 3 -->
<!-- verocase element MisconfigClaim -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-misconfigclaim"></a>
### Claim MisconfigClaim: All of the most common known security-relevant misconfiguration errors countered

Referenced by: **[Package Implementation](#package-implementation)**

Supported by: **[Claim RailsGuide](#claim-railsguide)**

Supports: **[Strategy CommonVulns](#strategy-commonvulns)**
<!-- end verocase -->

A common security problem with applications is misconfiguration;
here is how we reduce the risks from misconfiguration.

We take a number of steps to counter misconfiguration.
We have strived to enable secure defaults from the start.
We use a number of [external online checkers](#online-checkers)
to detect common HTTPS misconfiguration problems (see below).
We use Brakeman and CodeQL, which can detect
some misconfigurations in Rails applications.
We invoke static analysis tools (Brakeman and CodeQL) as part of
our continuous integration pipeline.

However, our primary mechanism for countering misconfigurations is by
identifying and apply ing the most-relevant security guide available.

This entire application is built on Ruby on Rails.
The Ruby on Rails developers provide a
[Ruby on Rails Security Guide](http://guides.rubyonrails.org/security.html),
which identifies what they believe are the most important areas to
check for securing such applications.
Since this guide is focused on the infrastructure we use, we think this is
the most important guide for us to focus on.

We apply the entire guide.
Here is a discussion on how we apply the entire guide, per its chapters
as of 2015-12-14:

1. *Introduction.* N/A.
2. *Sessions.*
   We use sessions, and use session cookies to store them
   because of their wide support and efficiency.
   We use the default Rails CookieStore mechanism to store sessions;
   it is both simple and much faster than alternatives.
   Rails implements an automatic cookie authentication mechanism (using a
   secret key referred to as `secret_key_base`)
   to ensure that clients cannot undetectably change
   these cookies; a changed value created without being re-authenticated
   is thrown away.
   Session cookies are encrypted with AES-256-GCM (authenticated
   encryption) using a key derived with SHA-256, providing both
   confidentiality and integrity protection against tampering.
   Rotating the `SECRET_KEY_BASE` environment variable immediately
   invalidates all existing sessions (a useful incident-response tool).
   Logged-in users have their user id stored in this authenticated cookie
   (There is also a `session_id`, not currently used.)
   Session data is intentionally kept small, because of the limited
   amount of data available in a cookie.
   To counteract session hijacking, we configure the production
   environment to always communicate over an encrypted channel using TLS
   (see file `config/environments/production.rb` which sets
   `config.force_ssl` to true).
   The design allows users to drop cookies at any time
   (at worse they may have to re-login to get another session cookie).
   One complaint about Rails' traditional CookieStore is that if someone
   gets a copy of a session cookie, they can log in as that user, even
   if the cookie is years old and the user logged out.
   (e.g., because someone got a backup copied).
   Our countermeasure is to time out inactive sessions, by
   also storing a `time_last_used` in the session
   cookie (the UTC time the cookie was last used).
   Once the time expires, then even if someone else later gets an old
   cookie value, it cannot be used to log into the system.
3. *Cross-Site Request Forgery (CSRF).*
   We use the standard REST operations with their standard meanings
   (GET, POST, etc., with the standard Rails method workaround).
   We have a CSRF required security token implemented using
   `protect_from_forgery` built into the application-wide controller
   `app/controllers/application_controller.rb`
   (we do not use cookies.permanent or similar, a contra-indicator).
   Also, we set cookies with SameSite=Lax; this is a useful hardening
   countermeasure in browsers that support it.
4. *Redirection and Files.*
   The application uses relatively few redirects; those that do involve
   the "id", which only works if it can find the value corresponding to
   the id first (which is an allowlist).
   Additionally, the framework is configured to raise an error on open
   redirects (`action_controller.action_on_open_redirect = :raise`,
   from `load_defaults 7.0`) and on relative-path redirects
   (`action_controller.action_on_path_relative_redirect = :raise`,
   from `load_defaults 8.1`), providing defense-in-depth at the Rails
   level against redirect-based attacks.
   File uploads aren't directly supported; the application does
   temporarily load some files (as part of autofill), but those filenames
   and contents are not directly made available to any other user
   (indeed, they're thrown away once autofill completes; caching may
   keep them, but that simply allows re-reading of data already acquired).
   The files aren't put into a filesystem, so there's no
   opportunity for executable code to be put into the filesystem this way.
   There is no arbitrary file downloading capability, and private files
   (e.g., with keys) are not in the docroot.
5. *Intranet and Admin Security.*
   Some users have 'admin' privileges, but these additional privileges
   simply let them edit other project records.
   Any other direct access requires logging in to the production system
   through a separate log in (e.g., to use 'rails console').
   Indirect access (e.g., to update the code the site runs)
   requires separately logging into
   GitHub and performing a valid git push (this must also pass through the
   continuous integration test suite).
   It's possible to directly push to the Heroku sites to deploy software,
   but this requires the credentials for directly logging into the
   relevant tier (e.g., production), and only authorized system administrators
   have those credentials.
6. *User management.*
   Local passwords have a minimum length (8) and cannot be
   a member of a set of known-bad passwords.  We allow much longer passwords.
   This complies with NIST Special Publication 800-63B,
   "Digital Authentication Guideline: Authentication and Lifecycle Management"
   <https://pages.nist.gov/800-63-3/sp800-63b.html> section 5.1.1.2.
   We expect users to
   protect their own passwords; we do not try to protect users from themselves.
   The system is not fast enough for a naive password-guesser to succeed
   guessing local passwords via network access (unless the password
   is really bad).
   The forgotten-password system for local accounts
   uses email; that has its weaknesses,
   but the data is sufficiently low value, and there aren't
   good alternatives for low value data like this.
   This isn't as bad as it might appear, because we prefer encrypted
   channels for transmitting all emails.
   Historically our application attempts to send
   messages to its MTA using TLS (using `enable_starttls_auto: true`),
   and that MTA then attempts to transfer the email the rest
   of the way using TLS if the recipient's email system supports it
   (see <https://sendgrid.com/docs/Glossary/tls.html>).
   This is good protection against passive attacks, and is relatively decent
   protection against active attacks if the user chooses an email system
   that supports TLS (an active attacker has to get between the email
   MTAs, which is often not easy).
   More recently we're using `enable_starttls: true` which *forces* email to be
   encrypted point-to-point.
   If users don't like that, they can log in via GitHub and use GitHub's
   system for dealing with forgotten passwords.
   The file `config/initializers/filter_parameter_logging.rb`
   intentionally filters passwords so that they are not included in the log.
   We require that local user passwords have a minimum length
   (see the User model), and this is validated by the server
   (in some cases the minimum length is also checked by the web client,
   but this is not depended on).
   Ruby's regular expression (regex) language oddly interprets "^" and "$",
   which can lead to defects (you're supposed to use \A and \Z instead).
   However, Ruby's format validator and the "Brakeman" tool both detect
   this common mistake with regexes, so this should be unlikely.
   We also set `Regexp.timeout = 1` second (via `load_defaults 8.0`),
   which limits regular expression evaluation time and provides a
   defense against ReDoS (Regular Expression Denial of Service) attacks,
   where specially crafted input causes catastrophic backtracking.
   Since the project data is public, manipulating the 'id' cannot reveal
   private public data.  We don't consider the list of valid users
   private either, so again, manipulating 'id' cannot reveal anything private.
7. *Injection.*
   We use allowlists to validate project data entered into the system.
   When acquiring data from projects during autofill, we do only for the
   presence or absence of patterns; the data is not stored (other than caching)
   and the data is not used in command interpreters (such as SQL or shell).
   SQL injection is countered by Rails' built-in database query mechanisms,
   we primarily use specialized routines like find() that counter
   SQL injection, but parameterized queries are also allowed for untrusted data
   (and also counter SQL injection).
   XSS, CSS injection, and Ajax injection are
   countered using Rails' HTML sanitization
   (by default strings are escaped when generating HTML)
   and our markdown generator.
   The program doesn't call out to the command line or use a routine
   that directly does so, e.g., there's no call
   to system()... so command injection won't work either.
   The software resists header injection including response splitting;
   headers are typically not dynamically generated, most redirections
   (using `redirect_to`) are to static locations, and the rest are based
   on filtered locations.
   We use a restrictive CSP setting to limit damage if all those fail.
8. *Unsafe Query Generation.*
   We use the default Rails behavior, in particular, we leave
   `deep_munge` at its default value
   (this default value counters a number of vulnerabilities).
9. *Default Headers.*
   We use at least the default security HTTP headers,
   which help counter some attacks.
   We harden the headers further, in particular via the
   [`secure_headers`](https://github.com/twitter/secureheaders) gem.
   For example, we use a restrictive Content Security Policy (CSP) header.
   For more information, see the hardening section.

The
[Ruby on Rails Security Guide](http://guides.rubyonrails.org/security.html)
is the official Rails guide, so it is the primary guide we consult.
That said, we do look for other sources for recommendations,
and consider them where they make sense.

In particular, the
[`ankane/secure_rails`](https://github.com/ankane/secure_rails) guide
has some interesting tips.
Most of them were were already doing, but an especially interesting
tip was to
"Prevent host header injection -
add the following to config/environments/production.rb":

~~~~ruby
config.action_controller.default_url_options = {host: "www.yoursite.com"}
config.action_controller.asset_host = "www.yoursite.com"
~~~~

We already did the first one, but we also added the second.

In many Rails configurations this is a critically-required configuration,
and failing to follow these steps could lead in part
to a potential compromise.
In our particular configuration the host value is set
by a trusted entity (Heroku), so we were never vulnerable,
but there is no reason to depend on the value Heroku provides.
We know the correct values, so we forcibly set them.
This ensures that even if a user provides a "host" value,
and for some reason Heroku allows it to pass through or we
switch to a different computation engine provider,
we will not use this value; we will instead use a preset trusted value.

<!-- verocase-config element_level = 4 -->
<!-- verocase element RailsGuide -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-railsguide"></a>
#### Claim RailsGuide: Entire most-relevant security guide applied

Referenced by: **[Package Implementation](#package-implementation)**

Supported by: **[Evidence RailsGuideEv](#evidence-railsguideev)**

Supports: **[Claim MisconfigClaim](#claim-misconfigclaim)**
<!-- end verocase -->

We apply the entire
[Ruby on Rails Security Guide](https://guides.rubyonrails.org/security.html),
which is the most relevant security guide for this application.
The misconfiguration discussion above walks through the guide's key sections
and explains how each is addressed.

<!-- verocase-config element_level = 3 -->
<!-- verocase element HardeningStrat -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="strategy-hardeningstrat"></a>
### Strategy HardeningStrat: Hardening can reduce or eliminate the impact of defects in some cases

Referenced by: **[Package Implementation](#package-implementation)**

Supported by: **[Claim Hardening](#claim-hardening)**

Supports: **[Claim Implementation](#claim-implementation)**
<!-- end verocase -->

Hardening can reduce or eliminate the impact of defects. Even if the system
has a vulnerability, hardening measures can thwart or slow attackers,
providing additional defense in depth.

<!-- verocase-config element_level = 3 -->
<!-- verocase element Hardening -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-hardening"></a>
### Claim Hardening: Hardening is applied

Referenced by: **[Package Hardening](#package-hardening)**, [Package Implementation](#package-implementation)

Supported by: **[Claim HardenHTTPS](#claim-hardenhttps)**, [Claim HardenCSP](#claim-hardencsp), [Claim HardenCookies](#claim-hardencookies), [Claim HardenCSRF](#claim-hardencsrf), [Claim HardenRateIn](#claim-hardenratein), [Claim HardenRateOut](#claim-hardenrateout), [Claim HardenEmailEnc](#claim-hardenemailenc), [Claim HardenGravatar](#claim-hardengravatar)

Supports: [Strategy HardeningStrat](#strategy-hardeningstrat)
<!-- end verocase -->

We also use various mechanisms to harden the system against attack.
These attempt to thwart or slow attack even if the system has a vulnerability
not countered by the main approaches described elsewhere in this document.

<!-- verocase-config element_level = 4 -->
<!-- verocase element HardenHTTPS -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-hardenhttps"></a>
#### Claim HardenHTTPS: HTTPS use enforced (including by HSTS)

Referenced by: **[Package Hardening](#package-hardening)**

Supported by: **[Evidence HardenHTTPSEv](#evidence-hardenhttpsev)**

Supports: **[Claim Hardening](#claim-hardening)**
<!-- end verocase -->

We take a number of steps to force the use of HTTPS instead of HTTP.

The "coreinfrastructure.org" domain is included in
[Chrome's HTTP Strict Transport Security (HSTS) preload list](https://hstspreload.org/?domain=coreinfrastructure.org).
This is a list of sites that are hardcoded into Chrome as being HTTPS only
(some other browsers also use this list), so in many cases browsers
will automatically use HTTPS (even if HTTP is requested).

If the web browser uses HTTP anyway,
our CDN (Fastly) is configured to redirect HTTP to HTTPS.
If our CDN is misconfigured or skipped for some reason, the application
will also redirect the user from HTTP to HTTPS if queried directly.
This is because in production `config.force_ssl` is set to true,
which enables a number of hardening mechanisms in Rails, including
TLS redirection (which redirects HTTP to HTTPS), secure cookies,
and HTTP Strict Transport Security (HSTS).
HSTS tells browsers to always use HTTPS in the future for this site,
so once the user contacts the site once, it will use HTTPS in the future.
See
["Rails, Secure Cookies, HSTS and friends" by Ilija Eftimov (2015-12-14)](http://eftimov.net/rails-tls-hsts-cookies)
for more about the impact of `force_ssl`.

<!-- verocase element HardenHTTPSEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-hardenhttpsev"></a>
#### Evidence HardenHTTPSEv: config.force_ssl enables TLS redirection, secure cookies, and HSTS; domain in Chrome HSTS preload list

Referenced by: **[Package Hardening](#package-hardening)**

Supports: **[Claim HardenHTTPS](#claim-hardenhttps)**

External Reference: [../config/environments/production.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../config/environments/production.rb)
<!-- end verocase -->

`config.force_ssl` enables TLS redirection, secure cookies, and HSTS; domain in Chrome HSTS preload list. See [../config/environments/production.rb](../config/environments/production.rb).

<!-- verocase element HardenCSP -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-hardencsp"></a>
#### Claim HardenCSP: Outgoing HTTP headers hardened including restrictive CSP

Referenced by: **[Package Hardening](#package-hardening)**

Supported by: **[Evidence HardenCSPEv](#evidence-hardencspev)**

Supports: **[Claim Hardening](#claim-hardening)**
<!-- end verocase -->

We harden the outgoing HTTP headers, in particular, we use a
restrictive Content Security Policy (CSP) header with just
"normal sources" (`normal_src`).  We do send a
Cross-Origin Resource Sharing (CORS) header when an origin is specified,
but the CORS header does *not* share credentials.

CSP is perhaps one of the most important hardening items,
since it prevents execution of injected JavaScript).
The HTTP headers are hardened via the
[`secure_headers`](https://github.com/twitter/secureheaders) gem,
developed by Twitter to enable a number of HTTP headers for hardening.
We check that the HTTP headers are hardened in the test file
`test/integration/project_get_test.rb`; that way, when we upgrade
the `secure_headers` gem, we can be confident that the headers continue to
be restrictive.
The test checks for the HTTP header values when loading a project entry,
since that is the one most at risk from user-provided data.
That said, the hardening HTTP headers are basically the same for all
pages except for `/project_stats`, and that page doesn't display
any user-provided data.
We have separately checked the CSP values we use with
<https://csp-evaluator.withgoogle.com/>;
the only warning it mentioned is that the our "default-src" allows 'self',
and it notes that
"'self' can be problematic if you host JSONP, Angular
or user uploaded files."  That is true, but irrelevant, because we don't
host any of them.

The HTTP headers *do* include a
Cross-Origin Resource Sharing (CORS) header when an origin is specified.
We do this so that client-side JavaScript served by other systems can
acquire data directly from our site (e.g., to download JSON data to
extract and display).
CORS disables the usual shared-origin policy, which is always a concern.
However, the CORS header expressly does *not* share credentials, and
our automated tests verify this (both when an origin is sent, and when
one is not).  The CORS header *only* allows GET; while an attacker *could*
set the method= attribute, that wouldn't have any useful effect, because
the attacker won't have credentials (except for themselves, and
attackers can always change the data they legitimately have rights to
on the BadgeApp).
A CORS header does make it *slightly* easier to perform
a DDoS attack (since JavaScript clients can make excessive data demands),
but a DDoS attack can be performed without it, and our usual DDoS
protection measures (including caching and scaling) still apply.

<!-- verocase element HardenCSPEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-hardencspev"></a>
#### Evidence HardenCSPEv: secure_headers gem enforces CSP and security headers; integration test verifies header values

Referenced by: **[Package Hardening](#package-hardening)**

Supports: **[Claim HardenCSP](#claim-hardencsp)**

External Reference: [../test/integration/project_get_test.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../test/integration/project_get_test.rb)
<!-- end verocase -->

`secure_headers` gem enforces CSP and security headers; integration test verifies header values. See [../test/integration/project_get_test.rb](../test/integration/project_get_test.rb).

<!-- verocase element HardenCookies -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-hardencookies"></a>
#### Claim HardenCookies: Cookies limited

Referenced by: **[Package Hardening](#package-hardening)**

Supported by: **[Evidence HardenCookiesEv](#evidence-hardencookiesev)**

Supports: **[Claim Hardening](#claim-hardening)**
<!-- end verocase -->

Cookies have various restrictions (also via the
[`secure_headers`](https://github.com/twitter/secureheaders) gem).
They have httponly=true (which counters many JavaScript-based attacks),
secure=true (which is irrelevant because we always use HTTPS but it
can't hurt), and SameSite=Lax (which counters CSRF attacks on
web browsers that support it).

Session and signed cookies are encrypted with AES-256-GCM
(authenticated encryption) using SHA-256 key derivation,
providing confidentiality and integrity protection stronger than
the AES-256-CBC with SHA-1 used by older Rails applications.
Expiry information is also embedded in cookie values, making it
harder to exploit old or captured cookies.
See
[expiry in signed or encrypted cookie is now embedded in the cookies values](https://edgeguides.rubyonrails.org/upgrading_ruby_on_rails.html#expiry-in-signed-or-encrypted-cookie-is-now-embedded-in-the-cookies-values).

<!-- verocase element HardenCookiesEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-hardencookiesev"></a>
#### Evidence HardenCookiesEv: secure_headers gem sets httponly, secure, and SameSite=Lax cookie attributes; session cookies use AES-256-GCM

Referenced by: **[Package Hardening](#package-hardening)**

Supports: **[Claim HardenCookies](#claim-hardencookies)**

External Reference: [../Gemfile](https://github.com/ossf/best-practices-badge/blob/main/docs/../Gemfile)
<!-- end verocase -->

`secure_headers` gem sets httponly, secure, and SameSite=Lax cookie attributes; session cookies use AES-256-GCM. See [../Gemfile](../Gemfile).

<!-- verocase element HardenCSRF -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-hardencsrf"></a>
#### Claim HardenCSRF: CSRF tokens hardened

Referenced by: **[Package Hardening](#package-hardening)**

Supported by: **[Evidence HardenCSRFEv](#evidence-hardencsrfev)**

Supports: **[Claim Hardening](#claim-hardening)**
<!-- end verocase -->

We use two additional CSRF token hardening techniques
to further harden the system against CSRF attacks,
both enabled as framework defaults via `config.load_defaults`:

* Per-form CSRF tokens
  (`action_controller.per_form_csrf_tokens`):
  each form gets a unique token bound to that specific action,
  so a token captured from one form cannot be replayed against another.
* Origin-header CSRF check
  (`action_controller.forgery_protection_origin_check`):
  the HTTP `Origin` request header is validated against the host,
  providing an additional layer of CSRF defense independent of the token.

These help counter CSRF, in addition to our other measures.

<!-- verocase element HardenCSRFEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-hardencsrfev"></a>
#### Evidence HardenCSRFEv: protect_from_forgery with per-form tokens and origin-header check, enabled via load_defaults

Referenced by: **[Package Hardening](#package-hardening)**

Supports: **[Claim HardenCSRF](#claim-hardencsrf)**

External Reference: [../app/controllers/application_controller.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../app/controllers/application_controller.rb)
<!-- end verocase -->

`protect_from_forgery` with per-form tokens and origin-header check, enabled via `load_defaults`. See [../app/controllers/application_controller.rb](../app/controllers/application_controller.rb).

<!-- verocase element HardenRateIn -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-hardenratein"></a>
#### Claim HardenRateIn: Incoming rate limits enforced

Referenced by: **[Package Hardening](#package-hardening)**

Supported by: **[Evidence HardenRateInEv](#evidence-hardenrateinev)**

Supports: **[Claim Hardening](#claim-hardening)**
<!-- end verocase -->

Rate limits provide an automated partial
countermeasure against denial-of-service and password-guessing attacks.
These are implemented by Rack::Attack and have two parts, a
"LIMIT" (maximum count) and a "PERIOD" (length of period of time,
in seconds, where that limit is not to be exceeded).
If unspecified they have the default values specified in
`config/initializers/rack_attack.rb`.  These settings are
(where "IP" or "ip" means "client IP address", and "req" means "requests"):

- req/ip
- logins/ip
- logins/email
- signup/ip

We also have a set of simple FAIL2BAN settings that temporarily
bans an IP address if it makes too many "suspicious" requests.
The exact production settings are not documented here, since we
don't want to tell attackers what we look for.
This isn't the same thing as having a *real*
web application firewall, but it's simple and counters some
trivial attacks.

To determine the remote client IP address (for our purposes) we use the
the next-to-last value of the comma-space-separated value
`HTTP_X_FORWARDED_FOR` (from the HTTP header X-Forwarded-For).
That's because the last value of `HTTP_X_FORWARDED_FOR`
is always our CDN (which intercepts it first), and the previous
value is set by our CDN to whatever IP address the CDN got.
The web server is configured so it will only accept connections from the
CDN - this prevents web piercing, and means that we can trust that the
client IP value we receive is only from the CDN (which we trust for
this purpose).
A client can always set X-Forwarded-For and try to spoof something,
but those entries are always earlier in the list
(so we can easily ignore them).

<!-- verocase element HardenRateInEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-hardenrateinev"></a>
#### Evidence HardenRateInEv: Rack::Attack rate limits on requests, logins, and signups by client IP address

Referenced by: **[Package Hardening](#package-hardening)**

Supports: **[Claim HardenRateIn](#claim-hardenratein)**

External Reference: [../config/initializers/rack_attack.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../config/initializers/rack_attack.rb)
<!-- end verocase -->

`Rack::Attack` rate limits on requests, logins, and signups by client IP address. See [../config/initializers/rack_attack.rb](../config/initializers/rack_attack.rb).

<!-- verocase element HardenRateOut -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-hardenrateout"></a>
#### Claim HardenRateOut: Outgoing email rate limits enforced

Referenced by: **[Package Hardening](#package-hardening)**

Supported by: **[Evidence HardenRateOutEv](#evidence-hardenrateoutev)**

Supports: **[Claim Hardening](#claim-hardening)**
<!-- end verocase -->

We enable rate limits on outgoing reminder emails.
We send reminder emails to projects that have not updated their
badge entry in a long time. The detailed algorithm that prioritizes projects
is in `app/models/project.rb` class method `self.projects_to_remind`.
It sorts by reminder date, so we always cycle through before returning to
a previously-reminded project.

We have a hard rate limit on the number of emails we will send out each
time; this keeps us from looking like a spammer.

<!-- verocase element HardenRateOutEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-hardenrateoutev"></a>
#### Evidence HardenRateOutEv: projects_to_remind class method and hard limit on outgoing reminder email count

Referenced by: **[Package Hardening](#package-hardening)**

Supports: **[Claim HardenRateOut](#claim-hardenrateout)**

External Reference: [../app/models/project.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../app/models/project.rb)
<!-- end verocase -->

`projects_to_remind` class method and hard limit on outgoing reminder email count. See [../app/models/project.rb](../app/models/project.rb).

<!-- verocase element HardenEmailEnc -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-hardenemailenc"></a>
#### Claim HardenEmailEnc: Email addresses encrypted

Referenced by: **[Package Hardening](#package-hardening)**

Supported by: **[Evidence HardenEmailEncEv](#evidence-hardenemailencev)**

Supports: **[Claim Hardening](#claim-hardening)**
<!-- end verocase -->

We encrypt email addresses within the database, and never
send the decryption or index keys to the database system.
This provides protection of this data at rest, and also means that
even if an attacker can view the data within the database, that attacker
will not receive sensitive information.
Email addresses are encrypted as described here, and almost all other
data is considered public or at least not sensitive
(the exception are passwords, which are
specially encrypted as described above).

A little context may be useful here.
We work hard to comply with various privacy-related regulations,
including the European General Data Protection Regulation (GDPR).
We do not believe that encrypting email addresses is strictly
required by the GDPR.
Still, we want to not just meet requirements, we want to exceed them.
Encrypting email addresses makes it even harder for attackers to get this
information, because it's encrypted at rest and not available by extracting
data from the database system.

First, it is useful to note why we encrypt just email addresses
(and passwords), and not all data.
Most obviously, almost all data we manage is public anyway.
In addition,
the easy ways to encrypt data aren't available to us. Transparent Data
Encryption (TDE) is not a capability of PostgreSQL. Whole-database
encryption can be done with other tricks but it is extremely expensive
on Heroku.
Therefore, we encrypt data that is more sensitive, instead of
encrypting everything.

We encrypt email addresses using the Rails-specific approach outlined in
["Securing User Emails in Rails" by Andrew Kane (May 14, 2018)](https://shorts.dokkuapp.com/securing-user-emails-in-rails/).
We use the gem `attr_encrypted` to encrypt email addresses, and
gem `blind_index` to index encrypted email addresses.
This approach builds on standard general-purpose approaches for
encrypting data and indexing the data, e.g., see
["How to Search on Securely Encrypted Database Fields" by Scott Arciszewski](https://www.sitepoint.com/how-to-search-on-securely-encrypted-database-fields/).
The important aspect here is that we encrypt the data (so it cannot be
revealed by those without the encryption key),
and we also create cryptographic keyed hashes of the data (so
we can search on the data if we have the hash key).
The latter value is called a "blind index".

We encrypt the email addresses using AES with 256-bit keys in
GCM mode ('aes-256-gcm').  AES is a well-accepted widely-used
encryption algorithm.  A 256-bit key is especially strong.
The GCM mode is a widely-used strong encryption mode; it provides
an integrity ("authentication") mechanism.
Each separate encryption uses a separate long initialization vector (IV)
created using a cryptographically-strong random number generator.

We also hash the email addresses, so they can be indexed.
Indexing is necessary so that we can quickly find matching email addresses
(e.g., for local user login).
We hash them using the hashed key algorithm PBKDF2-HMAC-SHA256.
SHA-256 is a widely-used cryptographic hash algorithm (in the SHA-2 family),
and unlike SHA-1 it is not broken.
Using sha256 directly would be vulnerable to a length extension attack.
A length extension attack is probably irrelevant in this circumstance,
but just in case, we counter that anyway.
We counter the length extension problem by using HMAC and PBKDF2.
HMAC is defined in RFC 2104, which is the algorithm
H(K XOR opad, H(K XOR ipad, text)).
This enables us to use a private key on the hash, counters length
extension, and is very well-studied.
We also use PBKDF2 for key extension.  This is another well-studied
and widely-accepted algorithm.
For our purposes we believe PBKDF2-HMAC-SHA256 is
far stronger than needed, and thus is quite sufficient
to protect the information.
The hashes are of email addresses after they've been downcased;
this supports case-insensitive searching for email addresses.

The two keys used for email encryption are
`EMAIL_ENCRYPTION_KEY` and `EMAIL_BLIND_INDEX_KEY`.
Both are 256 bits long (aka 64 hexadecimal digits long).
The production values for both keys were independently created as
cryptographically random values using `rails secret`.

Implementation note: the indexes created by `blind_index` always
end in a newline.  That doesn't matter for security, but it can cause
debugging problems if you weren't expecting that.

Note that `attr_encrypted` depends on the gem `encryptor`.
Encryptor version 2.0.0 had a
[major security bug when using AES-\*-GCM algorithms](https://github.com/attr-encrypted/encryptor/pull/22).
We do not use that version, but instead use
a newer version that does not have that vulnerability.
Some old documentation recommends using
`attr_encryptor` instead because of this vulnerability, but the
vulnerability has since been fixed and
`attr_encryptor` is no longer maintained.
Vulnerabilities are never a great sign, but we do take it as a good sign
that the developers of encryptor were willing to make a breaking change
to fix a security vulnerabilities.

We could easily claim this as a way to support confidentiality,
instead of simply as a hardening measure.
We only claim email encryption
as a hardening measure because we must still support
two-way encryption and decryption, and the keys must remain available
to the application.
As a result, email encryption only counters some specific attack methods.
That said, we believe this encryption adds an additional layer of defense
to protect email addresses from being revealed.

<!-- verocase element HardenEmailEncEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-hardenemailencev"></a>
#### Evidence HardenEmailEncEv: attr_encrypted and blind_index gems encrypt email addresses with AES-256-GCM and PBKDF2-HMAC-SHA256 index

Referenced by: **[Package Hardening](#package-hardening)**

Supports: **[Claim HardenEmailEnc](#claim-hardenemailenc)**

External Reference: [../app/models/user.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../app/models/user.rb)
<!-- end verocase -->

`attr_encrypted` and `blind_index` gems encrypt email addresses with AES-256-GCM and PBKDF2-HMAC-SHA256 index. See [../app/models/user.rb](../app/models/user.rb).

<!-- verocase element HardenGravatar -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-hardengravatar"></a>
#### Claim HardenGravatar: Gravatar restricted

Referenced by: **[Package Hardening](#package-hardening)**

Supported by: **[Evidence HardenGravatarEv](#evidence-hardengravatarev)**

Supports: **[Claim Hardening](#claim-hardening)**
<!-- end verocase -->

We use gravatar to provide user icons for local (custom) accounts.
Many users have created gravatar icons, and those who have
created those icons have clearly consented to their use for them.

However, accessing gravatar icons requires the MD5 cryptographic
hash of downcased email addresses.
Users who have created gravatar icons have already consented to
this, but we want to hide even the MD5 cryptographic hashes of
those who have not so consented.

Therefore, we track for each user whether or not they should
use a gravatar icon, as the boolean field `use_gravatar`.
Currently this is can only be true for
local users (for GitHub users we use their GitHub icon).
Whenever a new local user account is created or changed,
we check if there is an active gravatar icon, and set use_gravatar
accordingly.  We also intend to occasionally iterate through
local users to reset this (so that users won't need to remember
to manipulate their BadgeApp user account).
We will then only use the gravatar MD5 when there is an
actual gravatar icon to refer to; otherwise, we use a bogus
MD5 value.
Thus, local users who do not have a gravatar account will not
even have the MD5 of their email address revealed.

This is almost certainly not required by regulations such as the GDPR,
since without this measure we would only expose MD5s of email addresses,
and only in certain cases.  But we want to exceed expectations,
and this is one way we do that.

<!-- verocase element HardenGravatarEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-hardengravatarev"></a>
#### Evidence HardenGravatarEv: use_gravatar boolean controls whether gravatar MD5 hash is revealed for each local user

Referenced by: **[Package Hardening](#package-hardening)**

Supports: **[Claim HardenGravatar](#claim-hardengravatar)**

External Reference: [../app/models/user.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../app/models/user.rb)
<!-- end verocase -->

`use_gravatar` boolean controls whether gravatar MD5 hash is revealed for each local user. See [../app/models/user.rb](../app/models/user.rb).

<!-- verocase element PubVulns -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-pubvulns"></a>
#### Claim PubVulns: Public vulnerability information monitored

Referenced by: **[Package Implementation](#package-implementation)**

Supported by: **[Evidence PubVulnsBundleEv](#evidence-pubvulnsbundleev)**, [Evidence PubVulnsDependabotEv](#evidence-pubvulnsdependabotev)

Supports: **[Claim Implementation](#claim-implementation)**
<!-- end verocase -->

We want to counter all common vulnerabilities, not just those
listed in the OWASP top 10 or those mentioned in the configuration guide.
Therefore, we monitor information to learn about new types of vulnerabilities,
and make adjustments as necessary.

For example, a common vulnerability not reported in the 2013 OWASP top 10
is the use of `target=` in the "a" tag that does not have `_self`
as its value.
This is discussed in, for example,
["Target="\_blank" - the most underestimated vulnerability ever" by Alex Yumashev, May 4, 2016](https://www.jitbit.com/alexblog/256-targetblank---the-most-underestimated-vulnerability-ever/).
This was not noted in the OWASP top 10 of 2013,
which is unsurprising, since the problem with target=
was not widely known until 2016.
Note that no one had to report the vulnerability about this particular
application; we noticed it on our own.

Today we discourage the use of target=, because removing target= completely
eliminates the vulnerability.  When target= is used,
which is sometimes valuable to avoid the risk of user data loss,
we require that `rel="noopener"` always be used with `target=`
(this is the standard mitigation for `target=`).

We learned about this type of vulnerability after the application was
originally developed, through our monitoring of sites that discuss
general vulnerabilities.
To address the `target=` vulnerability, we:

* modified the application to counter the vulnerability,
* documented in CONTRIBUTING.md that it's not acceptable to have bare target=
  values (we discourage their use, and when they need to be used, they
  must be used with rel="noopener")
* modified the translation:sync routine to automatically insert the
  `rel="noopener"` mitigations for all target= values when they aren't
  already present
* modified the test suite to try to detect unmitigated uses of target=
  in key pages (the home page, project index, and single project page)
* modified the test suit to examine all text managed by config/locales
  (this is nearly all text) to detect use of target= with an immediate
  termination (this is the common failure mode, since rel=... should
  instead follow it).

While this doesn't *guarantee* there is no vulnerability, this certainly
reduces the risks.

<!-- verocase-config element_level = 3 -->
<!-- verocase element ReuseSec -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-reusesec"></a>
### Claim ReuseSec: Reused software is secure

Referenced by: **[Package ReuseSec](#package-reusesec)**, [Package Implementation](#package-implementation)

Supported by: **[Strategy ReuseStrat](#strategy-reusestrat)**, [Claim KnownVulns](#claim-knownvulns)

Supports: [Strategy CommonVulns](#strategy-commonvulns)
<!-- end verocase -->

We reuse well-vetted, widely-used components and actively monitor
for known vulnerabilities in those components. Reusing mature
libraries reduces the amount of security-sensitive code we must
write and maintain ourselves.

<!-- verocase-config element_level = 4 -->
<!-- verocase element ReuseStrat -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="strategy-reusestrat"></a>
#### Strategy ReuseStrat: Reuse is often appropriate and can be done securely

Referenced by: **[Package ReuseSec](#package-reusesec)**

Supported by: **[Claim ReuseReview](#claim-reusereview)**, [Claim ReuseAuth](#claim-reuseauth), [Claim PkgMgr](#claim-pkgmgr), [Claim SpecialAnalysis](#claim-specialanalysis)

Supports: **[Claim ReuseSec](#claim-reusesec)**
<!-- end verocase -->

Reusing well-tested components is often more secure than writing equivalent
custom code, provided the components are reviewed, authentic, and kept up to date
with security patches.

Like all modern software, we reuse components developed by others.
We can't eliminate all risks, and
if we rewrote all the software (instead of reusing software)
we would risk creating vulnerabilities in own code.
See [CONTRIBUTING.md](../CONTRIBUTING.md) for more about how we
reduce the risks of reused code.

<!-- verocase-config element_level = 4 -->
<!-- verocase element ReuseReview -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-reusereview"></a>
#### Claim ReuseReview: Reused software is reviewed before use

Referenced by: **[Package ReuseSec](#package-reusesec)**

Supported by: **[Evidence ReuseReviewEv](#evidence-reusereviewev)**

Supports: **[Strategy ReuseStrat](#strategy-reusestrat)**
<!-- end verocase -->

We consider the code we reuse
(e.g., libraries and frameworks) before adding them, to reduce
the risk of unintentional and intentional vulnerabilities from them.
In particular:

* We look at the website of any component we intend to add to our
  direct dependencies to see if it appears to be relatively low risk
  (does it have clear documentation, is there evidence of serious
  security concerns, does it have multiple developers, who is the lead, etc.).
* We prefer the use of popular components (where problems
  are more likely to be identified and addressed).
* We prefer software that self-proclaims a version number of 1.0 or higher.
* We strongly prefer software that does not bring in a large number
  of new dependencies (as determined by bundler).
  If it is a large number, we consider even more carefully
  and/or suggest that the developer reduce their dependencies
  (often the dependencies are only for development and test).
* In some cases we review the code ourselves.  This primarily happens
  when there are concerns raised by one of the previous steps.

We require that all components that are *required* for use
have FLOSS licenses.  This enables review by us and by others.
We prefer common FLOSS licenses.
A FLOSS component with a rarely-used license, particularly a
GPL-incompatible one, is less likely to be reviewed by others because
in most cases fewer people will contribute to it.
We use `license_finder` to ensure that the licenses are what we expect,
and that the licenses do not change to an unusual license
in later versions.

<!-- verocase-config element_level = 3 -->
<!-- verocase element ReuseAuth -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-reuseauth"></a>
### Claim ReuseAuth: Reused software is authentic

Referenced by: **[Package ReuseSec](#package-reusesec)**

Supported by: **[Evidence ReuseAuthEv](#evidence-reuseauthev)**

Supports: **[Strategy ReuseStrat](#strategy-reusestrat)**
<!-- end verocase -->

We work to ensure that we are getting the authentic version of the software.
We counter man-in-the-middle (MITM) attacks when downloading gems
because the Gemfile configuration uses an HTTPS source to the
standard place for loading gems (<https://rubygems.org>).
We double-check names before we add them to the Gemfile to counter
typosquatting attacks.

<!-- verocase element PkgMgr -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-pkgmgr"></a>
### Claim PkgMgr: Package managers used

Referenced by: **[Package ReuseSec](#package-reusesec)**

Supported by: **[Evidence PkgMgrEv](#evidence-pkgmgrev)**

Supports: **[Strategy ReuseStrat](#strategy-reusestrat)**
<!-- end verocase -->

We use package managers, primarily bundler, to download and track
software with the correct version numbers.
This makes it much easier to maintain the software later
(see the maintenance process discussion).

<!-- verocase element PkgMgrEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-pkgmgrev"></a>
### Evidence PkgMgrEv: Gemfile and Gemfile.lock manage all gem dependencies via bundler

Referenced by: **[Package ReuseSec](#package-reusesec)**

Supports: **[Claim PkgMgr](#claim-pkgmgr)**

External Reference: [../Gemfile](https://github.com/ossf/best-practices-badge/blob/main/docs/../Gemfile)
<!-- end verocase -->

`Gemfile` and `Gemfile.lock` manage all gem dependencies via bundler. See [../Gemfile](../Gemfile).

<!-- verocase element SpecialAnalysis -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-specialanalysis"></a>
### Claim SpecialAnalysis: Special analysis justifies exceptions

Referenced by: **[Package ReuseSec](#package-reusesec)**

Supported by: **[Claim XXESafe](#claim-xxesafe)**, [Claim ErubisSafe](#claim-erubissafe), [Claim LocalSecretSafe](#claim-localsecretsafe), [Claim ActionCableSafe](#claim-actioncablesafe)

Supports: **[Strategy ReuseStrat](#strategy-reusestrat)**
<!-- end verocase -->

Sometimes tools or reports suggest we may have vulnerabilities
in how we reuse components.
We are grateful for those tools and reports that help us identify
places to us to examine further!
Below are specialized analysis justifying why we believe we do not
have vulnerabilities in these areas.

#### XXE from Nokogiri / libxml2

One area where we may *appear* to be vulnerable, but we
believe we are not, involves nokogiri, libxml2, and
[CVE-2016-9318](https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2016-9318).
This was identified as a potential issue in an
[analysis by Snyk](https://snyk.io/test/github/ossf/best-practices-badge?severity=high&severity=medium&severity=low).
Here is our analysis justifying why we believe our use of
nokogiri and libxml2 are not a vulnerability in our application.

The Nokogiri gem is able to do analysis on HTML and XML documents.
As noted in
[Nokogiri #1582](https://github.com/sparklemotion/nokogiri/issues/1582),
"applications using Nokogiri 1.5.4 (circa June 2012) and later
are not vulnerable to this CVE (CVE-2016-9318)
unless opting into the DTDLOAD option and opting out of the NONET option.
Note that by default, Nokogiri turns off both DTD loading and
network access, treating all docs as untrusted docs. This behavior
is independent of the version of libxml2 used."

Like practically all Rails applications, we use
rails-html-sanitizer, which uses loofah, which uses nokogiri,
which uses libxml.
So we *do* use Nokogiri in production to process untrusted data.
However, we do *not* use Nokogiri in production to process incoming XML,
which is the only way this vulnerability can occur.
In addition, loofah version 2.1.1 has been checked and it never opts
into DTDLOAD nor does it opt out of NONET
(as confirmed using "grep -Ri NONET" and "grep -Ri DTDLOAD" on
the loofah source directory), so nokogiri is never configured in
production in a way that could be vulnerable anyway.

All other uses of nokogiri (as confirmed by checking Gemfile.lock)
are only for the automated test suite
(capybara, chromedriver-helper, rails-dom-testing, and xpath which in
turn is only used by capybara).
Nokogiri is extensively used by our automated testing system,
but in that case we provide the test data to ourselves (so it is trusted).

#### XSS from erubis / pronto-rails_best_practices

The "erubis" module was identified as potentially vulnerable to
cross-site scripting (XSS) as introduced through
`pronto-rails_best_practices`.
This was identified as a potential issue in an
[analysis by Snyk](https://snyk.io/test/github/ossf/best-practices-badge?severity=high&severity=medium&severity=low).

However, rails_best_practices is only run in development and test,
where the environment and input data are trusted,
so we believe this is not a real vulnerability.

#### Checked-in `tmp/local_secret.txt` appears to have a secret

The file `tmp/local_secret.txt` may appear to be a security vulnerability.
That's because it's a key (it's the value of `secret_key_base` for
development and test environments) whose value is checked into a public
version-controlled repository.

However, it is not a vulnerability. This value is *only* used during
test and development. The fact that its value is public is
irrelevant, since those systems are not publicly accessible, or don't
have any real secrets, or both.

We set this file for the following reasons;

1. It's convenient to have a *constant* value of
   `secret_key_base`, because it means it's much easier to halt and
   restart during development and test. Having it change on every restart
   makes development and test much harder.
2. It eliminates occasional test failures in parallelized testing.
   At the time of this writing, when Rails needs a value for `secret_key_base`
   and cannot find it in the environment variable `SECRET_KEY_BASE` or a file,
   it creates a new value for `secret_key_base` and stores it in the file
   `tmp/local_secret.txt`.
   [A race condition results](https://github.com/rails/rails/issues/53661),
   because if tests are running in parallel, other tests may try to load the
   file before it's been created by another process.
   We've verified in the Rails code that if this file exists,
   its content is used.

In the staging and production environments we provide a truly secret value for
the environment variable `SECRET_KEY_BASE`. When this environment variable
is set, it is used instead. Their values are the ones
we actually need to keep private. We do *not* check in their values.

For more information:

* <https://apidock.com/rails/Rails/Application/secret_key_base>
* <https://apidock.com/rails/v7.1.3.2/Rails/Application/generate_local_secret>

#### Information Exposure from actioncable

The "actioncable" module was identified as potentially vulnerable to
information exposure.
This module is introduced by rails and traceroute.
This was identified as a potential issue in an
[analysis by Snyk](https://snyk.io/test/github/ossf/best-practices-badge?severity=high&severity=medium&severity=low).

Actioncable structures channels over a single WebSocket connection,
however, there is
[no way to filter out any sensitive data from the logs](https://github.com/rails/rails/issues/25088).

We don't currently use actioncable, and since we don't use it, there's
no sensitive data going over it to worry about.

We could remove actioncable as a dependency, but that turns out to be
annoying.
The solution would be to replace the "rails" dependency with a large set
of its transitive dependencies and then removing actioncable.
Traceroute could be requested in the development group, and then
the development group could re-require rails.
This would make later maintenance a little more difficult, with no
obvious gain, so we have not done this.

<!-- verocase-config element_level = 4 -->
<!-- verocase element KnownVulns -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-knownvulns"></a>
#### Claim KnownVulns: Known vulnerabilities in reused components are detected

Referenced by: **[Package ReuseSec](#package-reusesec)**

Supported by: **[Evidence KnownVulnsBundleEv](#evidence-knownvulnsbundleev)**, [Evidence KnownVulnsDependabotEv](#evidence-knownvulnsdependabotev)

Supports: **[Claim ReuseSec](#claim-reusesec)**
<!-- end verocase -->

Known vulnerabilities in reused software are detected using automated tools.
See the [Maintenance](#claim-maintenance) section for details on bundle-audit
and GitHub Dependabot, which automatically flag known vulnerabilities.

<!-- verocase-config element_level = 2 -->
<!-- verocase element Verification -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-verification"></a>
## Claim Verification: Security in integration & verification

Referenced by: **[Package Verification](#package-verification)**, [Package Security](#package-security)

Supported by: **[Strategy VerifStrat](#strategy-verifstrat)**

Supports: [Claim TechProcesses](#claim-techprocesses)
<!-- end verocase -->

When software is modified, it is reviewed by the
'rake' process, which performs a number of checks and tests.
Modifications integrated into the master branch
are further automatically checked.
See [CONTRIBUTING.md](../CONTRIBUTING.md) for more information.

The following is a brief summary of part of our verification process,
and how it helps make the software more secure:

* Style checking tools.
  We intentionally make the code relatively short and clean to ease review
  by both humans and other tools.
  We use rubocop (a Ruby code style checker), rails_best_practices
  (a style checker specific to Rails), and ESLint
  (a style checker for JavaScript).
  We work to have no warnings in the code,
  typically by fixing the problem, though in some cases we will annotate
  in the code that we're allowing an exception.
  These style tools help us avoid more problematic constructs (in some cases
  avoiding defects that might lead to vulnerabilities), and
  also make the code easier to review
  (by both humans and other programs).
  Our style checking tools detect misleading indentation;
  <a href="http://www.dwheeler.com/essays/apple-goto-fail.html#indentation">this
  counters the mistake in the Apple goto fail vulnerability</a>.
* Source code weakness analyzers (for finding vulnerabilities in custom code).
  A source code weakness analyzer, also known as a security vulnerability
  scanner, examines the source code to identify vulnerabilities.
  This is one of many kinds of "static analysis" tools, that is, a tool
  that doesn't run the code (and thus is not limited to examining only the
  cases of specific inputs).
  We use Brakeman, a source code weakness analyzer that focuses
  on finding security issues in Ruby on Rails applications.
  We also use CodeQL, another source code weakness analyzer that's
  general-purpose and reviews both the Ruby and JavaScript code.
  Note that this is all separate from the automatic detection of
  third-party components with publicly-known vulnerabilities;
  see the [supply chain](#supply-chain) section for how we counter those.
* FLOSS.  Reviewability is important for security.
  All the required reused components are FLOSS, and our
  custom software is released as Free/Libre and open source software (FLOSS)
  using a well-known FLOSS license (MIT).
* Negative testing.
  The test suite specifically includes tests that should fail for
  security reasons, an approach sometimes called "negative testing".
  A widespread mistake in test suites is to only test "things that should
  succeed", and neglecting to test "things that should fail".
  This is especially important in security, since for security it's
  often more important to ensure that certain requests *fail* than to ensure
  that certain requests *succeed*.
  For an example of the need for negative testing, see
  ["The Apple goto fail vulnerability: lessons learned" by David A. Wheeler](https://www.dwheeler.com/essays/apple-goto-fail.html).
  Missing negative tests are also problematic because
  statement and branch coverage test coverage requirements
  cannot detect *missing* code, and "failure to fail" is often caused
  by *missing* code (this wasn't the case for "goto fail", but it does happen
  in other cases).
  We do positive testing too, of course, but that's not usually forgotten.
  For negative testing, we focus on ensuring that incorrect logins will
  fail, that timeouts cause timeouts, that projects and users cannot be
  edited by those unauthorized to do so, and that email addresses are not
  revealed to unauthorized individuals.
  Here are important examples of our negative testing:
    - local logins with wrong or unfilled passwords will lead to login failure
      (see `test/system/login_test.rb`).
    - projects cannot be edited ("patched") by a timed-out session
      or a session lacking a signed timeout value
      (see `test/controllers/projects_controller_test.rb`)
    - projects cannot be edited if the user is not logged in, or
      by logged-in normal users
      if they aren't authorized to edit that project
      (see `test/controllers/projects_controller_test.rb`)
    - projects can't be destroyed (deleted) if the user isn't logged in,
      or is logged as a user who does not control the project
      (see `test/controllers/projects_controller_test.rb`)
    - user data cannot be edited ("patched") if the user isn't logged in,
      or is logged in as another non-admin user
      (see `test/controllers/users_controller_test.rb`)
    - users can't be destroyed if the user isn't logged in, or is logged
      in as another non-admin user
      (see `test/controllers/users_controller_test.rb`)
    - a request to show the edit user page is redirected away
      if the user isn't logged in, or is logged as another non-admin user -
      this prevents any information leak from the edit page
      (see `test/controllers/users_controller_test.rb`)
    - a user page does not display its email address when the user is
      either (1) not logged in or (2) is logged in but not as an admin.
      (see `test/controllers/users_controller_test.rb`)
    - a user page does not display if the user is an admin if
      the user isn't logged in, or is logged in as a non-admin user
      (see `test/controllers/users_controller_test.rb`).
      This makes it slightly harder for attackers to figure out
      the individuals to target (they have additional privileges), while
      still allowing *administrators* to easily see if a user has
      administrator privileges.
* The software has a strong test suite; our policy requires
  at least 90% statement coverage.
  In practice our autoamted test suite coverage is much higher; it has achieved
  100% statement coverage for a long time.
  You can verify this by looking at the "CodeCov" value at the
  [BadgeApp repository](https://github.com/ossf/best-practices-badge).
  This strong test suite
  makes it easier to update components (e.g., if a third-party component
  has a publicly disclosed vulnerability).
  The test suite also makes it easier to make other fixes (e.g., to harden
  something) and have fairly high
  confidence that the change did not break functionality.
  It can also counter some vulnerabilities, e.g.,
  <a href="http://www.dwheeler.com/essays/apple-goto-fail.html#coverage">Apple's
  goto fail vulnerability would have been detected had they
  checked statement coverage</a>.

We have briefly experimented with using the "dawnscanner" security scanner.
We have decided to *not* add dawnscanner to the set of scanners that we
routinely use, because it doesn't really add any value in our particular
situation.
See the [dawnscanner.md](./dawnscanner.md) file for more information.

These steps cannot *guarantee* that there are no vulnerabilities,
but we think they greatly reduce the risks.

<!-- verocase-config element_level = 3 -->
<!-- verocase element VerifStrat -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="strategy-verifstrat"></a>
### Strategy VerifStrat: Static & dynamic verifications are performed and enforced on all integrations, reducing risk

Referenced by: **[Package Verification](#package-verification)**

Supported by: **[Claim VerifSteps](#claim-verifsteps)**, [Claim CIRequired](#claim-cirequired)

Supports: **[Claim Verification](#claim-verification)**
<!-- end verocase -->

Static and dynamic verifications are performed and enforced on all integrations.
By combining multiple verification approaches and requiring CI to pass before
deployment, we systematically reduce the risk of introducing vulnerabilities.

<!-- verocase-config element_level = 3 -->
<!-- verocase element VerifSteps -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-verifsteps"></a>
### Claim VerifSteps: Verification steps reduce risk

Referenced by: **[Package Verification](#package-verification)**

Supported by: **[Claim StaticVerif](#claim-staticverif)**, [Claim DynamicVerif](#claim-dynamicverif)

Supports: **[Strategy VerifStrat](#strategy-verifstrat)**
<!-- end verocase -->

Multiple verification steps are performed on every change.
See the [Claim Verification](#claim-verification) section for the full list,
including static analysis, FLOSS checking, automated testing, and negative testing.

<!-- verocase element StaticVerif -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-staticverif"></a>
### Claim StaticVerif: Static verifications are performed

Referenced by: **[Package Verification](#package-verification)**

Supported by: **[Claim StyleChecks](#claim-stylechecks)**, [Claim WeaknessAnalysis](#claim-weaknessanalysis), [Claim FLOSSVerif](#claim-flossverif)

Supports: **[Claim VerifSteps](#claim-verifsteps)**
<!-- end verocase -->

Static verifications — style checks, source code weakness analysis, and FLOSS
verification — are run on every commit.
See [Claim Verification](#claim-verification) for details on the specific tools.

<!-- verocase-config element_level = 4 -->
<!-- verocase element StyleChecks -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-stylechecks"></a>
#### Claim StyleChecks: Style checks pass

Referenced by: **[Package Verification](#package-verification)**

Supported by: **[Evidence StyleEv](#evidence-styleev)**

Supports: **[Claim StaticVerif](#claim-staticverif)**
<!-- end verocase -->

Style checks (rubocop, rails_best_practices, ESLint) are run to maintain code
quality, catch problematic constructs, and detect misleading indentation.
See the style checking bullet in [Claim Verification](#claim-verification).

<!-- verocase element StyleEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-styleev"></a>
#### Evidence StyleEv: Style checkers as pronto runners in Gemfile: eslint, rails_best_practices, rubocop

Referenced by: **[Package Verification](#package-verification)**

Supports: **[Claim StyleChecks](#claim-stylechecks)**

External Reference: [../.circleci/config.yml](https://github.com/ossf/best-practices-badge/blob/main/docs/../.circleci/config.yml)
<!-- end verocase -->

Style checkers as pronto runners in Gemfile: eslint, rails_best_practices, rubocop. See [../.circleci/config.yml](../.circleci/config.yml).

<!-- verocase element WeaknessAnalysis -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-weaknessanalysis"></a>
#### Claim WeaknessAnalysis: Source code analyzed for weaknesses & all issues resolved

Referenced by: **[Package Verification](#package-verification)**

Supported by: **[Evidence BrakemanEv](#evidence-brakemanev)**

Supports: **[Claim StaticVerif](#claim-staticverif)**
<!-- end verocase -->

Source code weakness analyzers (Brakeman, CodeQL) scan for security
vulnerabilities in the custom Ruby and JavaScript code.
See the source code weakness analyzer bullet in [Claim Verification](#claim-verification).

<!-- verocase element BrakemanEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-brakemanev"></a>
#### Evidence BrakemanEv: Brakeman source code weakness analyzer

Referenced by: **[Package Verification](#package-verification)**

Supports: **[Claim WeaknessAnalysis](#claim-weaknessanalysis)**

External Reference: [../.github/workflows/main.yml](https://github.com/ossf/best-practices-badge/blob/main/docs/../.github/workflows/main.yml)
<!-- end verocase -->

Brakeman source code weakness analyzer. See [../.github/workflows/main.yml](../.github/workflows/main.yml).

<!-- verocase element FLOSSVerif -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-flossverif"></a>
#### Claim FLOSSVerif: All reused components are verified as FLOSS

Referenced by: **[Package Verification](#package-verification)**

Supported by: **[Evidence LicenseFinderEv](#evidence-licensefinderev)**, [Evidence FOSSAEv](#evidence-fossaev)

Supports: **[Claim StaticVerif](#claim-staticverif)**
<!-- end verocase -->

All required reused components are verified as Free/Libre and Open Source Software
(FLOSS) using license_finder and FOSSA.
See the FLOSS bullet in [Claim Verification](#claim-verification).

<!-- verocase element LicenseFinderEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-licensefinderev"></a>
#### Evidence LicenseFinderEv: license_finder

Referenced by: **[Package Verification](#package-verification)**

Supports: **[Claim FLOSSVerif](#claim-flossverif)**

External Reference: [../.circleci/config.yml](https://github.com/ossf/best-practices-badge/blob/main/docs/../.circleci/config.yml)
<!-- end verocase -->

`license_finder`. See [../.circleci/config.yml](../.circleci/config.yml).

<!-- verocase element FOSSAEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-fossaev"></a>
#### Evidence FOSSAEv: FOSSA check

Referenced by: **[Package Verification](#package-verification)**

Supports: **[Claim FLOSSVerif](#claim-flossverif)**

External Reference: [https://github.com/ossf/best-practices-badge/settings/](https://github.com/ossf/best-practices-badge/settings/)
<!-- end verocase -->

FOSSA check. See [https://github.com/ossf/best-practices-badge/settings/](https://github.com/ossf/best-practices-badge/settings/).

<!-- verocase-config element_level = 3 -->
<!-- verocase element DynamicVerif -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-dynamicverif"></a>
### Claim DynamicVerif: Dynamic verifications are performed

Referenced by: **[Package Verification](#package-verification)**

Supported by: **[Claim TestCoverage](#claim-testcoverage)**, [Claim NegTests](#claim-negtests)

Supports: **[Claim VerifSteps](#claim-verifsteps)**
<!-- end verocase -->

Dynamic verifications — automated tests and negative testing — are run
on every commit. See [Claim Verification](#claim-verification) for details.

<!-- verocase-config element_level = 4 -->
<!-- verocase element TestCoverage -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-testcoverage"></a>
#### Claim TestCoverage: Automated testing performed with excellent statement coverage

Referenced by: **[Package Verification](#package-verification)**

Supported by: **[Evidence CITestEv](#evidence-citestev)**

Supports: **[Claim DynamicVerif](#claim-dynamicverif)**
<!-- end verocase -->

The automated test suite achieves 100% statement coverage (policy requires ≥90%).
This strong coverage makes it easier to update components and detect regressions.
See the test coverage bullet in [Claim Verification](#claim-verification).

<!-- verocase element CITestEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-citestev"></a>
#### Evidence CITestEv: Automated tests run by CI

Referenced by: **[Package Verification](#package-verification)**

Supports: **[Claim TestCoverage](#claim-testcoverage)**

External Reference: [https://codecov.io/gh/ossf/best-practices-badge](https://codecov.io/gh/ossf/best-practices-badge)
<!-- end verocase -->

Automated tests run by CI. See [https://codecov.io/gh/ossf/best-practices-badge](https://codecov.io/gh/ossf/best-practices-badge).

<!-- verocase element NegTests -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-negtests"></a>
#### Claim NegTests: Negative tests failed as desired

Referenced by: **[Package Verification](#package-verification)**

Supported by: **[Evidence NegTestsEv](#evidence-negtestsev)**

Supports: **[Claim DynamicVerif](#claim-dynamicverif)**
<!-- end verocase -->

Negative tests verify that unauthorized actions correctly fail,
covering wrong passwords, unauthorized project edits, and email address leaks.
See the negative testing bullet in [Claim Verification](#claim-verification).

<!-- verocase element NegTestsEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-negtestsev"></a>
#### Evidence NegTestsEv: Negative test suite

Referenced by: **[Package Verification](#package-verification)**

Supports: **[Claim NegTests](#claim-negtests)**

External Reference: [../test/](https://github.com/ossf/best-practices-badge/blob/main/docs/../test/)
<!-- end verocase -->

Negative test suite. See [../test/](../test/).

<!-- verocase-config element_level = 3 -->
<!-- verocase element CIRequired -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-cirequired"></a>
### Claim CIRequired: Successful verification required by continuous integration before deployment

Referenced by: **[Package Verification](#package-verification)**

Supported by: **[Evidence CIConfigEv](#evidence-ciconfigev)**

Supports: **[Strategy VerifStrat](#strategy-verifstrat)**
<!-- end verocase -->

All changes must pass continuous integration checks before being deployed.
The CI system runs the full verification suite (static analysis, tests, etc.)
on every integration to the master branch.
See the CI configuration file `../.circleci/config.yml`.

<!-- verocase element CIConfigEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-ciconfigev"></a>
### Evidence CIConfigEv: CI configuration

Referenced by: **[Package Verification](#package-verification)**

Supports: **[Claim CIRequired](#claim-cirequired)**

External Reference: [../.circleci/config.yml](https://github.com/ossf/best-practices-badge/blob/main/docs/../.circleci/config.yml)
<!-- end verocase -->

CI configuration. See [../.circleci/config.yml](../.circleci/config.yml).

<!-- verocase element Deployment -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-deployment"></a>
### Claim Deployment: Security in transition & operation

Referenced by: **[Package Deployment](#package-deployment)**, [Package Security](#package-security)

Supported by: **[Claim DeployProvider](#claim-deployprovider)**, [Claim Detection](#claim-detection), [Claim OnlineCheckers](#claim-onlinecheckers), [Claim RecoveryPlan](#claim-recoveryplan)

Supports: [Claim TechProcesses](#claim-techprocesses)
<!-- end verocase -->

To be secure, the software has to be secure as actually transitioned
(deployed) and operated securely.

Our transition process has software normally go through tiers.
At this time there are two deployed tiers: staging and production.
At one time we also had a "main" aka "master" tier; that ran
the software at the HEAD of the main (formerly master) branch,
but to reduce costs we no longer have a tier that deploys the main branch.
At any time software can be promoted from the main branch
to the staging tier (using `rake deploy_staging`). Software that
runs fine on the staging branch is promoted to production (the "real" system).
In an emergency we can skip tiers or promote to them in parallel, but
doing that is rare.

Our operations process has a number of security measures.
Our deployment provider and CDN provider take steps to be secure.
Online checkers of our deployed site suggest that we have
a secure site.
In addition, we have detection and recovery processes
that help us limit damage.

<!-- verocase-config element_level = 3 -->
<!-- verocase element DeployProvider -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-deployprovider"></a>
### Claim DeployProvider: Deployment provider maintains security

Referenced by: **[Package Deployment](#package-deployment)**

Supported by: **[Evidence HerokuSecEv](#evidence-herokusecev)**

Supports: **[Claim Deployment](#claim-deployment)**
<!-- end verocase -->

We deploy via a cloud provider who takes a number of steps
to keep our system secure.
We currently use Heroku for deployment; see the
[Heroku security policy](https://www.heroku.com/policy/security)
for some information on how they manage security
(including physical security and environmental safeguards).
Normal users cannot directly access the database management system (DBMS),
which on the production system is Postgres.
Anyone can create a Heroku application and run it on Heroku, however,
at that point we trust the Postgres developers and the Heroku administrators
to keep the databases separate.

People can log in via GitHub accounts; in those cases we depend
on GitHub to correctly authenticate users.
[GitHub takes steps to keep itself secure](https://help.github.com/articles/github-security/).

<!-- verocase element HerokuSecEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-herokusecev"></a>
### Evidence HerokuSecEv: Heroku security policy describes physical and environmental safeguards

Referenced by: **[Package Deployment](#package-deployment)**

Supports: **[Claim DeployProvider](#claim-deployprovider)**

External Reference: [https://www.heroku.com/policy/security](https://www.heroku.com/policy/security)
<!-- end verocase -->

Heroku security policy describes physical and environmental safeguards. See [https://www.heroku.com/policy/security](https://www.heroku.com/policy/security).

<!-- verocase element OnlineCheckers -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-onlinecheckers"></a>
### Claim OnlineCheckers: Online security checkers are used

Referenced by: **[Package Deployment](#package-deployment)**

Supported by: **[Evidence OnlineCheckersEv](#evidence-onlinecheckersev)**

Supports: **[Claim Deployment](#claim-deployment)**
<!-- end verocase -->

Various online checkers give us an overall clean bill of health.
Most of the checkers test our HTTPS (TLS) configuration and
if common hardening mechanisms are enabled.

For the main bestpractices.coreinfrastructure.org site we have:

* An "A+" rating from the
  <a href="https://www.ssllabs.com/ssltest/analyze.html?d=bestpractices.coreinfrastructure.org">Qualys SSL labs check of our TLS configuration</a>
  on 2017-01-14.
* An "A+" rating from the
  <a href="https://securityheaders.io/?q=https%3A%2F%2Fbestpractices.coreinfrastructure.org">securityheaders.io check of our HTTP security headers</a>
  on 2018-01-25.
  Back in 2017-01-14 securityheaders.io
  gave us a slightly lower score ("A") because we do not include
  "Public-Key-Pins".  This simply notes that
  we are do not implement HTTP Public Key Pinning (HPKP).
  HPKP counters rogue certificate authorities (CAs), but it also has risks.
  HPKP makes it harder to switch CAs *and* any error in its configuration,
  at any time, risks serious access problems that are unfixable -
  making HPKP somewhat dangerous to use.
  Many others have come to the same conclusion, and securityheaders.io
  has stopped using HPKP as a grading criterion.
* An all-pass report from the
  <a href="https://www.sslshopper.com/ssl-checker.html#hostname=bestpractices.coreinfrastructure.org">SSLShopper SSL checker</a>
  on 2017-01-14.
* An "A+" rating from the [Mozilla Observatory](https://observatory.mozilla.org/analyze.html?host=bestpractices.coreinfrastructure.org) scan summary
  on 2017-01-14.
* A 96% result from <a href="https://www.wormly.com/test_ssl/h/bestpractices.coreinfrastructure.org/i/157.52.75.7/p/443">Wormly</a>.
  The only item not passed was the "SSL Handshake Size" test; the live site
  provides 5667 bytes, and they consider values beyond 4K (with unclear
  units) to be large. This is not a security issue, at most this will
  result in a slower initial connection.  Thus, we don't plan to worry
  about the missing test.

<!-- verocase element Detection -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-detection"></a>
### Claim Detection: Threats and anomalies are detected

Referenced by: **[Package Deployment](#package-deployment)**

Supported by: **[Claim ExtMonitor](#claim-extmonitor)**, [Claim IntLogging](#claim-intlogging)

Supports: **[Claim Deployment](#claim-deployment)**
<!-- end verocase -->

We have various detection mechanisms to detect problems.
There are two approaches to detection:

* internal (which has access to our internal information, such as logs)
* external (which does not have access to internal information)

We use *both* detection approaches.
We tend to focus on the internal approach, which has more information
available to it.
The external approaches do not have access
to as much information, but they see the site as a "typical" user
would, so combining these approaches has its advantages.

<!-- verocase-config element_level = 4 -->
<!-- verocase element IntLogging -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-intlogging"></a>
#### Claim IntLogging: Internal logging and anomaly detection is in place

Referenced by: **[Package Deployment](#package-deployment)**

Supported by: **[Evidence IntLoggingEv](#evidence-intloggingev)**

Supports: **[Claim Detection](#claim-detection)**
<!-- end verocase -->

This is a [12 factor app](https://12factor.net/); as such,
events are streamed to standard out for logging.
Rails is configured to send all logs to
standard out, and we use standard logging mechanisms.
The logs then go out to other components for further analysis.

System logs are expressly *not* publicly available.
They are only shared with a small number of people authorized by the
Linux Foundation, and are protected information.
You must have administrator access to our Heroku site or our
logging management system to gain access to the logs.
That is because our system logs must include detailed information so that we
can identify and fix problems (including attacks).
For example, log entries record the IP address of the requestor,
email addresses when we send email,
and the user id (uid) making a request (if the user is logged in).
We record this information so we can keep the system running properly.
We also need to keep it for a period of time so we can identify trends,
including slow-moving attacks.
For more information, see the
[Linux Foundation privacy policy](https://www.linuxfoundation.org/privacy).

As an additional protection measure, we take steps to *not* include
passwords in logs.
That's because people sometimes reuse passwords, so we try to be
especially careful with passwords.
File `config/initializers/filter_parameter_logging` expressly
filters out the "password" field.

We intentionally omit here, in this public document, details about
how logs are stored and how anomaly detection is done to
detect and counter things.

<!-- verocase element IntLoggingEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-intloggingev"></a>
#### Evidence IntLoggingEv: filter_parameter_logging.rb excludes passwords from logs; events stream to stdout per 12-factor app

Referenced by: **[Package Deployment](#package-deployment)**

Supports: **[Claim IntLogging](#claim-intlogging)**

External Reference: [../config/initializers/filter_parameter_logging.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../config/initializers/filter_parameter_logging.rb)
<!-- end verocase -->

`filter_parameter_logging.rb` excludes passwords from logs; events stream to stdout per 12-factor app. See [../config/initializers/filter_parameter_logging.rb](../config/initializers/filter_parameter_logging.rb).

<!-- verocase element ExtMonitor -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-extmonitor"></a>
#### Claim ExtMonitor: External monitoring is in place

Referenced by: **[Package Deployment](#package-deployment)**

Supported by: **[Evidence ExtMonitorEv](#evidence-extmonitorev)**

Supports: **[Claim Detection](#claim-detection)**
<!-- end verocase -->

We are also alerted if the website goes down.

One of those mechanisms is uptime robot:
<https://uptimerobot.com/dashboard>

<!-- verocase element ExtMonitorEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-extmonitorev"></a>
#### Evidence ExtMonitorEv: UptimeRobot provides external alerting when the website goes down

Referenced by: **[Package Deployment](#package-deployment)**

Supports: **[Claim ExtMonitor](#claim-extmonitor)**

External Reference: [https://uptimerobot.com/dashboard](https://uptimerobot.com/dashboard)
<!-- end verocase -->

UptimeRobot provides external alerting when the website goes down. See [https://uptimerobot.com/dashboard](https://uptimerobot.com/dashboard).

<!-- verocase-config element_level = 3 -->
<!-- verocase element RecoveryPlan -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-recoveryplan"></a>
### Claim RecoveryPlan: Recovery plan including backups is in place

Referenced by: **[Package Deployment](#package-deployment)**

Supported by: **[Evidence RecoveryPlanEv](#evidence-recoveryplanev)**

Supports: **[Claim Deployment](#claim-deployment)**
<!-- end verocase -->

Once we detect that there is a problem, we have plans
and mechanisms in place to help us recover,
including backups.

Once we determine that there is a problem, we must
determine to a first order the scale of the problem,
what to do immediately, and what to do over time.

If there is an ongoing security issue, we have a few immediate options
(other than just leaving the system running).
We can shut down the system,
disable internet access to it, or enable the
application's `BADGEAPP_DENY_LOGIN` mode.
The `BADGEAPP_DENY_LOGIN` mode is a special degraded mode
we have pre-positioned that enables key functionality while
countering some attacks.

We will work with the LF data controller to determine if there has been
a personal data breach, and help the data controller alert the
supervisory authority where appropriate.
The General Data Protection Regulation (GDPR) section 33 requires that
in the case of a personal data breach, the controller shall
"without undue delay, and, where feasible, not later than 72 hours
after having become aware of it, notify the personal data breach to the
supervisory authority... unless the personal data breach is unlikely to
result in a risk to the rights and freedoms of natural persons."

Once we have determined the cause, we would work to quickly determine
how to fix the software and/or change the configuration to
address the attack (at least to ensure that integrity and confidentiality
are maintained).
As shown elsewhere, we have a variety of tools and tests that help us
rapidly update the software with confidence.

Once the system is fixed, we might need to alert users.
We have a pre-created rake task `mass_email` that lets us quickly
send email to the users (or a subset) if it strictly necessary.

We might also need to re-encrypt the email addresses with a new key.
We have pre-created a rake task "rekey" that performs rekeying of
email addresses should that be necessary.

Finally, we might need to restore from backups.
We use the standard Rails and PostgreSQL mechanisms for loading backups.
We backup the database daily, and archive many versions so
we can restore from them.
See the [Heroku site](https://devcenter.heroku.com/articles/heroku-postgres-backups#scheduled-backups-retention-limits) for retention times.

The update process to the "staging" site backs up the production site
to the staging site.  This provides an additional backup, and also
serves as a check to make sure the backup and restore processes are working.

<!-- verocase-config element_level = 2 -->
<!-- verocase element Maintenance -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-maintenance"></a>
## Claim Maintenance: Security in maintenance

Referenced by: **[Package Maintenance](#package-maintenance)**, [Package Security](#package-security)

Supported by: **[Claim AutoDetect](#claim-autodetect)**, [Claim RapidUpdate](#claim-rapidupdate)

Supports: [Claim TechProcesses](#claim-techprocesses)
<!-- end verocase -->

What many call the "maintenance" or "sustainment" process is simply
continuous execution of all our processes.

However, there is a special case related to security:
detecting when publicly known vulnerabilities are reported in the
components we use (in our direct or indirect dependencies),
and then speedily fixing that (usually by updating the component).
A component could have no publicly-known vulnerabilities when we selected it,
yet one could be found later.

We use a variety of techniques to detect vulnerabilities that have
been newly reported to the public, and have a process for
rapidly responding to them, as described below.
In some cases a reused component might appear vulnerable but is not;
for more discussion, including specific examples, see the
section on [reuse](#reuse).

<!-- verocase-config element_level = 3 -->
<!-- verocase element AutoDetect -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-autodetect"></a>
### Claim AutoDetect: Vulnerabilities are auto-detected when publicly reported

Referenced by: **[Package Maintenance](#package-maintenance)**

Supported by: **[Evidence AutoDetectBundleEv](#evidence-autodetectbundleev)**, [Evidence AutoDetectGitHubEv](#evidence-autodetectgithubev)

Supports: **[Claim Maintenance](#claim-maintenance)**
<!-- end verocase -->

We use multiple processes for automatically detecting when the components we
use have publicly known vulnerabilities.
We specifically focus on detecting all components with any publicly known
vulnerability, both in our direct and indirect dependencies.

We detect components with publicly known vulnerabilities
using 2 different mechanisms: bundle-audit and GitHub.
Each approach has its advantages, and using multiple mechanisms
increases the likelihood that we will be alerted quickly.
These both use the `Gemfile*` files and the
National Vulnerability Database aka NVD (the NVD is
a widely-used database of known vulnerabilities):

* bundle-audit compares the entire set of gems (libraries),
  both direct and indirect dependencies, to a database
  of versions with known vulnerabilities.
  The default 'rake' task invokes bundle-audit, so every time we run
  "rake" (as part of our build or deploy process)
  we are alerted about publicly known vulnerabilities in the
  components we depend on (directly or not).
  In particular, this is part of our continuous integration test suite.
* GitHub sends alerts to us for known security vulnerabilities found in
  dependencies.  This is a GitHub configuration setting
  (under settings, options, data services).
  This provides us with an immediate warning of a vulnerability,
  even if we are not currently modifying the system.
  This analyzes both Gemfile (direct) and Gemfile.lock
  (indirect) dependencies in Ruby.
  GitHub also includes dependabot, a service that automatically
  creates pull requests to fix vulnerable dependencies.
  These automatically-generated pull requests go through our CI pipeline,
  as would any pull request, so the pull requests go through many checks
  (including our test suite). Presuming they pass, we can accept the
  pull request, speeding our response to any vulnerabilities in components
  we use.
  For more information, see the
  [GitHub page About Security Alerts for Vulnerable Dependencies](https://help.github.com/en/github/managing-security-vulnerabilities/about-security-alerts-for-vulnerable-dependencies).

At one time we also used Gemnasium, but the service we used
closed in May 2018.  We have two other services, so that loss did not
substantively impact us.

This approach has a complicated false positive with `omniauth`
which we've had to specially handle.
Library `omniauth` has a publicly-known vulnerability CVE-2015-9284.
We have chosen to counter vulnerability CVE-2015-9284 by installing a
third-party countermeasure, `omniauth-rails_csrf_protection` and ensuring
that our configuration counters the problem.
This is the
[recommended approach on the omniauth wiki](https://github.com/omniauth/omniauth/wiki/Resolving-CVE-2015-9284)
given discussion on
[pull request 809](https://github.com/omniauth/omniauth/pull/809).
The omniauth developers have been reluctant to fix this within the
component they develop because it's (1) a
breaking (interface) change and (2) code available to fix it is Rails-specific,
yet their library can be used in other situations.
We reviewed the third-party countermeasure's code and it looks okay.
See our commit `ccdd0e007ee7d6aa` for details.
This is not ideal, but it's a real-world situation, and we believe
this approach completely counters the vulnerability.

<!-- verocase element AutoDetectBundleEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-autodetectbundleev"></a>
### Evidence AutoDetectBundleEv: bundle-audit checks all gem versions against NVD vulnerability database on every rake run

Referenced by: **[Package Maintenance](#package-maintenance)**

Supports: **[Claim AutoDetect](#claim-autodetect)**

External Reference: [../Gemfile.lock](https://github.com/ossf/best-practices-badge/blob/main/docs/../Gemfile.lock)
<!-- end verocase -->

`bundle-audit` checks all gem versions against NVD vulnerability database on every rake run. See [../Gemfile.lock](../Gemfile.lock).

<!-- verocase element AutoDetectGitHubEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-autodetectgithubev"></a>
### Evidence AutoDetectGitHubEv: GitHub Dependabot alerts and automated pull requests for vulnerable dependencies

Referenced by: **[Package Maintenance](#package-maintenance)**

Supports: **[Claim AutoDetect](#claim-autodetect)**

External Reference: [../.github/dependabot.yml](https://github.com/ossf/best-practices-badge/blob/main/docs/../.github/dependabot.yml)
<!-- end verocase -->

GitHub Dependabot alerts and automated pull requests for vulnerable dependencies. See [../.github/dependabot.yml](../.github/dependabot.yml).

<!-- verocase element RapidUpdate -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-rapidupdate"></a>
### Claim RapidUpdate: Rapid update process is in place

Referenced by: **[Package Maintenance](#package-maintenance)**

Supported by: **[Evidence RapidUpdateEv](#evidence-rapidupdateev)**

Supports: **[Claim Maintenance](#claim-maintenance)**
<!-- end verocase -->

We also have a process for quickly responding to alerts
of publicly known vulnerabilities, so that we can quickly update,
automatically test, and ship to production once we've been
alerted to a problem.  If a component we use has a known vulnerability
we normally simply update and deploy quickly, instead of trying to determine
if the vulnerability is exploitable in our system, because determining
exploitability usually takes more effort than
simply using our highly-automated update process.

The list of libraries we use (transitively) is managed by bundler, so
updating libraries or sets of libraries can be done quickly.
Bundler is a Ruby package manager, and it uses the Node Package Manager (NPM)
to manage JavaScript libraries.
As noted earlier, our strong automated test suite makes it easy to test this
updated set, so we can rapidly update libraries, test the result, and
deploy it.

We have also optimized the component update process through
using the package manager (bundler) and high test coverage.
The files Gemfile and Gemfile.lock
identify the current versions of Ruby gems (Gemfile identifies direct
dependencies; Gemfile.lock includes all transitive dependencies and
the exact version numbers).  We can rapidly update libraries by
updating those files, running "bundle install", and then using "rake"
to run various automated checks including a robust test suite.
Once those pass, we can immediately field the results.

This approach is known to work.
Commit fdb83380aa71352
on 2015-11-26 updated nokogiri, in response to a bundle-audit
report on advisory CVE-2015-1819, "Nokogiri gem contains
several vulnerabilities in libxml2 and libxslt".
When it was publicly reported we were alerted.
In less than an hour from the time the vulnerability
was publicly reported we were alerted,
updated the library, ran the full test suite, and deployed the fixed version
to our production site.

This automatic detection and remediation
process does *not* cover the underlying execution
platform (e.g., kernel, system packages such as the C and Ruby runtime,
and the database system (PostgreSQL)).
We depend on the underlying platform provider (Heroku)
to update those components and restart as necessary when
a vulnerability in those components is discovered
(that service is one of the key reasons we pay them!).

<!-- verocase-config element_level = 2 -->
<!-- verocase element NonTechnical -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-nontechnical"></a>
## Claim NonTechnical: Security implemented by other life cycle processes

Referenced by: **[Package NonTechnical](#package-nontechnical)**, [Package Security](#package-security)

Supported by: **[Claim AgreementProc](#claim-agreementproc)**, [Claim OrgProc](#claim-orgproc), [Claim TechMgmt](#claim-techmgmt)

Supports: [Strategy Processes](#strategy-processes)
<!-- end verocase -->

Security is also implemented through non-technical lifecycle processes.
Following ISO/IEC/IEEE 12207, this includes agreement processes
(acquisition), organizational project-enabling processes (infrastructure
and human resources), and technical management processes
(planning, risk, configuration management, and QA).

<!-- verocase element AgreementProc -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-agreementproc"></a>
## Claim AgreementProc: Agreement processes implement security

Referenced by: **[Package NonTechnical](#package-nontechnical)**

Supported by: **[Claim Acquisition](#claim-acquisition)**

Supports: **[Claim NonTechnical](#claim-nontechnical)**
<!-- end verocase -->

Agreement processes (contracts with external providers) implement security
by establishing security responsibilities with our deployment provider (Heroku)
and CDN (Fastly).

<!-- verocase element OrgProc -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-orgproc"></a>
## Claim OrgProc: Organizational project-enabling processes implement security

Referenced by: **[Package NonTechnical](#package-nontechnical)**

Supported by: **[Claim Infrastructure](#claim-infrastructure)**, [Claim HumanRes](#claim-humanres)

Supports: **[Claim NonTechnical](#claim-nontechnical)**
<!-- end verocase -->

Organizational project-enabling processes implement security through
infrastructure management (securing development and test environments)
and human resource management (ensuring developers have security expertise).

<!-- verocase-config element_level = 2 -->
<!-- verocase element Acquisition -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-acquisition"></a>
## Claim Acquisition: Acquisition process implements security

Referenced by: **[Package NonTechnical](#package-nontechnical)**

Supported by: **[Claim Contracts](#claim-contracts)**

Supports: **[Claim AgreementProc](#claim-agreementproc)**
<!-- end verocase -->

The system depends on a deployment provider (Heroku) and
content distribution network (CDN) (Fastly).
We have contracts with them, which provide us with some leverage
should they fail to do what they say and/or don't quickly fix
security-related problems.

<!-- verocase-config element_level = 3 -->
<!-- verocase element Contracts -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-contracts"></a>
### Claim Contracts: Contracts with deployment and CDN provider address security

Referenced by: **[Package NonTechnical](#package-nontechnical)**

Supported by: **[Evidence ContractsEv](#evidence-contractsev)**

Supports: **[Claim Acquisition](#claim-acquisition)**
<!-- end verocase -->

We have contracts with our deployment provider (Heroku) and CDN (Fastly)
that address security responsibilities.
These contracts include security policy commitments (such as
[Heroku's security policy](https://www.heroku.com/policy/security))
and provide us recourse if they fail to address security-related problems promptly.

<!-- verocase-config element_level = 2 -->
<!-- verocase element Infrastructure -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-infrastructure"></a>
## Claim Infrastructure: Infrastructure management implements security

Referenced by: **[Package NonTechnical](#package-nontechnical)**

Supported by: **[Claim DevEnvSec](#claim-devenvsec)**, [Claim CINoData](#claim-cinodata)

Supports: **[Claim OrgProc](#claim-orgproc)**
<!-- end verocase -->

A compromised development or CI/CD environment could inject malicious
code without detection. We protect the development environment and
ensure the CI/CD pipeline operates on clean, controlled data.

<!-- verocase-config element_level = 3 -->
<!-- verocase element DevEnvSec -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-devenvsec"></a>
### Claim DevEnvSec: Development & test environments are protected from attack

Referenced by: **[Package NonTechnical](#package-nontechnical)**

Supported by: **[Evidence DevEnvSecEv](#evidence-devenvsecev)**

Supports: **[Claim Infrastructure](#claim-infrastructure)**
<!-- end verocase -->

Subversion of the development environment can easily lead to
a compromise of the resulting system.
The key developers use development environments
specifically configured to be secure.

Anyone who has direct commit rights to the repository
*must not* allow other untrusted local users on the same (virtual) machine.
This counters local vulnerabilities.
E.g., the Rubocop vulnerability
CVE-2017-8418 is /tmp file vulnerability, in which
"Malicious local users could exploit this to tamper
with cache files belonging to other users."
Since we do not allow other untrusted local users on the (virtual) machine
that has commit rights, a vulnerability cannot be easily exploited
this way.  If someone without commit rights submits a proposal, we can
separately review that change.

As noted earlier, we are cautious about the components we use.
The source code is managed on GitHub;
[GitHub takes steps to keep itself secure](https://help.github.com/articles/github-security/).

The installation process, as described in the INSTALL.md file,
includes a few steps to counter some attacks.
In particular,
we use the git integrity recommendations from Eric Myhre that check all
git objects transferred from an external site into our development environment.
This sets "fsckObjects = true" for transfer (thus also for fetch and receive).

<!-- verocase element CINoData -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-cinodata"></a>
### Claim CINoData: CI automated test environment does not contain protected data

Referenced by: **[Package NonTechnical](#package-nontechnical)**

Supported by: **[Evidence CINoDataEv](#evidence-cinodataev)**

Supports: **[Claim Infrastructure](#claim-infrastructure)**
<!-- end verocase -->

The continuous integration (CI) test environment runs on CircleCI,
and does *not* have direct access to the real-world data.
Thus, if someone can see the data available on the test environment,
that does *not* mean that they will have access to the protected data.

### CI/CD pipeline input validation and sanitization

Our CI/CD pipelines implement baseline security requirements to prevent
injection attacks through pipeline parameters and branch names.
Specifically, we implement:

* **OSPS-BR-01.01** (Input parameter sanitization): Our CI/CD pipelines
  do not accept explicit user-provided input parameters. All inputs come
  from trusted sources (CI/CD system context variables, environment
  variables from secure contexts, or hardcoded configuration values).
  This is implemented in `.circleci/config.yml` (CircleCI) and
  `.github/workflows/*.yml` (GitHub Actions).

* **OSPS-BR-01.02** (Branch name sanitization and validation): Before using
  branch names in any pipeline operations, we validate them using the
  centralized script `script/validate_branch_name`, which uses
  POSIX-compliant shell code to ensure they contain only safe characters
  (alphanumeric, hyphens, underscores, dots, plus signs, and forward slashes)
  and have an appropriate length (more than 0, no more than 200 characters).
  We also reject branch names starting with `-` (hyphen) because they could
  be confused as command-line option flags, and reject branch names containing
  `..` to prevent directory traversal attempts.
  This prevents command injection and cache poisoning attacks.
  The validation script is called from:

    * `.circleci/config.yml`: Validates branch names in both the build job
      (which runs on all branches) and the deploy job (which also validates
      against a staging/production allow-list)
    * `.github/workflows/main.yml`: Validates branch names in the main CI workflow
    * `.github/workflows/codespell.yml`: Validates branch names in the
      codespell workflow
    * `.github/workflows/scorecard.yml`: Branch name validation is
      intentionally omitted here. Scorecard's `publish_results: true` mode
      prohibits `run:` steps in the workflow (only approved actions may be
      used). This is acceptable because this workflow does not use branch
      names in any shell commands, so there is no injection risk.

These validations provide defense in depth by ensuring that even if
workflow-level filters were bypassed or misconfigured, the pipeline
would fail fast and refuse to execute with potentially malicious input.
The use of POSIX-compliant code (avoiding bash-specific extensions)
ensures maximum portability and standards compliance.

### GitHub Actions workflow hardening

Our GitHub Actions workflows implement multiple layers of defense
against supply chain attacks and privilege abuse:

* **No dangerous triggers**: All workflows use the `pull_request` trigger
  (or `push`/`schedule`), never `pull_request_target`.
  The `pull_request_target` trigger runs with repository secrets and
  elevated write permissions and can execute code from untrusted forks —
  a primary vector for supply chain compromise. We do not use it.

* **All third-party actions pinned to commit SHAs**: Every GitHub Action
  referenced in our three workflows (`main.yml`, `scorecard.yml`,
  `codespell.yml`) uses a full commit SHA rather than a mutable tag name
  (e.g., `@v2`). Tags can be silently moved to point to different commits,
  including malicious ones; a commit SHA is immutable.
  Each pinned SHA is annotated with the corresponding human-readable
  version tag in a comment for maintainability.

* **Explicit minimal `permissions:` on every workflow**: All three
  workflows declare explicit `permissions:` blocks at the workflow level,
  restricting `GITHUB_TOKEN` to the minimum required access.
  Any permission not explicitly listed is set to `none`.
  No workflow grants write access to `contents`, `pull-requests`, or
  `packages` beyond what is strictly necessary.

* **`step-security/harden-runner`**: The main CI workflow uses
  `step-security/harden-runner` (pinned by SHA) with
  `egress-policy: audit`, which monitors and logs all outbound network
  connections during the workflow. This provides visibility into
  unexpected network calls (e.g., credential exfiltration attempts)
  and can be tightened to `block` mode once the expected egress
  pattern is fully characterized.

* **`persist-credentials: false`**: The `scorecard.yml` workflow sets
  `persist-credentials: false` during checkout, preventing the
  `GITHUB_TOKEN` from being stored in the git credential store
  where it could be accessed by subsequent steps.

* **No user-controlled data in shell commands**: None of our workflows
  interpolate user-controlled values (PR titles, branch names in
  untrusted contexts, issue body text) directly into shell commands
  or action inputs, preventing script injection attacks.

### Mandatory review for security-sensitive changes

We use `.github/CODEOWNERS` to enforce mandatory review by designated
security-focused maintainers before any pull request that touches
security-sensitive files can be merged into the main branch.
The following paths require explicit approval from the designated
code owners:

* `.github/workflows/` — CI/CD pipeline definitions; changes here
  determine what code runs during automated workflows and what
  credentials are accessible
* `.circleci/` — CircleCI pipeline configuration and deployment scripts
* `SECURITY.md` — security policy and vulnerability disclosure process
* `docs/assurance-case.md` — this security assurance case
* `.github/dependabot.yml` — dependency update automation configuration
* `Gemfile` and `Gemfile.lock` — Ruby dependency declarations and
  lockfile

This requirement, combined with GitHub branch protection rules that
enforce "Require review from Code Owners" on the `main` branch, ensures
that no single contributor can unilaterally modify these files without
security-focused review.

### Heroku CLI supply chain protection

The CircleCI deployment pipeline uses the Heroku CLI to control
maintenance mode and securely push the application to Heroku.

The Heroku CLI is installed by downloading the tarball directly from
the npm registry at a pinned version and verifying its SHA-512 hash
against a value hardcoded in the CI configuration before installation
proceeds.
This provides two independent protections:

* **Version pin**: only the exact pinned release is accepted.
* **Hardcoded SHA-512 hash**: the SRI-format SHA-512 of the tarball
  is recorded in the CI config at the time the pin is set, from a
  registry we currently trust.
  Even if the npm registry were later compromised and replaced both
  the tarball *and* its own recorded hash in the manifest, our
  independently-stored hash would detect the mismatch and fail the
  build loudly.
  A plain `npm install` trusts only the registry's own hash and
  would not catch this scenario.

When the Heroku CLI is upgraded, both the version pin and the
hardcoded hash are updated together as a deliberate code change,
which is subject to code review enforced by CODEOWNERS on the
`.circleci/` path.

Node.js (and therefore npm) is guaranteed to be present in the
CircleCI Docker image: the image is tagged as a browsers variant
with Node.js 22, and `node -v` is verified at the start of the
deploy step. npm is bundled with every official Node.js distribution
and cannot be absent when Node.js is available.

This CLI is used only as a deployment tool to transfer the final
build artifact to Heroku; it is not part of the deployed application
itself, which limits the impact of any hypothetical compromise.

### Deployment credential isolation

This section documents how we satisfy
**OSPS-BR-01.03**: *"When a CI/CD pipeline operates on untrusted code
snapshots, it MUST prevent access to privileged CI/CD credentials and
assets."*

The primary privileged credential in our pipeline is `HEROKU_API_KEY`,
which authorizes pushes to the Heroku staging and production
environments.
We isolate it from untrusted code through several interlocking controls:

* **Credential stored in a scoped CircleCI context, not a
  project-level variable.**
  `HEROKU_API_KEY` is stored exclusively in the CircleCI context named
  `heroku-deploy`.
  Project-level environment variables in CircleCI are injected into
  every job; context variables are only injected into jobs that
  explicitly reference the context by name.
  Because the credential is not a project-level variable, the `build`
  job has no access to it whatsoever.

* **Context referenced only by the `deploy` job.**
  In `.circleci/config.yml`, the `context: heroku-deploy` key appears
  only on the `deploy` job in the workflow definition.
  The `build` job carries no `context:` key and therefore never
  receives the credential, even though the `build` job runs on every
  branch including unreviewed pull requests.

* **Deploy job restricted to protected branches.**
  The workflow filter `branches: only: [staging, production]` prevents
  the `deploy` job from running on any other branch.
  Code reaches the `staging` or `production` branches only through a
  reviewed and approved pull request; it cannot arrive there directly
  from an untrusted contributor.

* **An explicit allowlist check inside the deploy job itself.**
  As defense in depth, the `deploy` job contains a shell-level
  `case` statement that exits with an error if `$CIRCLE_BRANCH` is
  anything other than `staging` or `production`.
  This catches any accidental misconfiguration of the workflow-level
  filter.

* **CI/CD configuration protected by CODEOWNERS.**
  The `/.circleci/` path is covered by `.github/CODEOWNERS`, so any
  change to the pipeline configuration — including any attempt to add
  `context: heroku-deploy` to the `build` job or widen the branch
  filter — requires explicit approval from designated code owners
  before it can be merged.

Together these controls ensure that `HEROKU_API_KEY` is never present
in the environment of any job that executes unreviewed code, and that
the configuration enforcing this isolation cannot itself be changed
without security-focused review.

<!-- verocase-config element_level = 2 -->
<!-- verocase element HumanRes -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-humanres"></a>
## Claim HumanRes: Human resource management implements security

Referenced by: **[Package NonTechnical](#package-nontechnical)**

Supported by: **[Claim DevKnowledge](#claim-devknowledge)**

Supports: **[Claim OrgProc](#claim-orgproc)**
<!-- end verocase -->

ISO/IEC/IEEE 12207 has a "human resource management" process;
this is the process that focuses on the people involved.
Of course, it's important to have developers who know how to develop software,
with at least someone in the group who knows how to develop secure software.

The lead software developer,
[David A. Wheeler](http://www.dwheeler.com/), is an expert in the area
of developing secure software.
He has a PhD in Information Technology, a Master's degree in Computer Science,
a certificate in Software Engineering, a certificate in
Information Systems Security, and a BS in Electronics Engineering,
all from George Mason University (GMU).
He wrote the book
[Secure Programming HOWTO](http://www.dwheeler.com/secure-programs/)
and teaches a graduate course at George Mason University (GMU) on
how to design and implement secure software.
Dr. Wheeler's doctoral dissertation,
[Fully Countering Trusting Trust through Diverse Double-Compiling](http://www.dwheeler.com/trusting-trust/),
discusses how to counter malicious compilers.

Sam Khakimov was greatly involved in its earlier development.
He has been developing software for a number of years,
in a variety of languages.
He has a Bachelor of Business Admin in Finance and Mathematics
(CUNY Baruch College Summa Cum Laude Double Major) and a
Master of Science in Mathematics (New York University) with
additional coursework in Cyber Security.

[Dan Kohn](http://www.dankohn.com/bio.html)
received a bachelor's degree in Economics and Computer Science
from the Honors program of Swarthmore College.
He has long expertise in Ruby on Rails.

Jason Dossett has a PhD in Physics from The University of Texas at Dallas,
and has been involved in software development for many years.
He has reviewed and is familiar with the security assurance case
provided here.

<!-- verocase-config element_level = 3 -->
<!-- verocase element DevKnowledge -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-devknowledge"></a>
### Claim DevKnowledge: Key developers know how to develop secure software

Referenced by: **[Package NonTechnical](#package-nontechnical)**

Supported by: **[Evidence DevKnowledgeEv](#evidence-devknowledgeev)**

Supports: **[Claim HumanRes](#claim-humanres)**
<!-- end verocase -->

The key developers have relevant qualifications in secure software development,
as described in the [HumanRes](#claim-humanres) section above.
The lead developer (David A. Wheeler) wrote the book
[Secure Programming HOWTO](http://www.dwheeler.com/secure-programs/) and
teaches a graduate course on developing secure software.

<!-- verocase-config element_level = 2 -->
<!-- verocase element TechMgmt -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-techmgmt"></a>
## Claim TechMgmt: Technical management processes implement security

Referenced by: **[Package NonTechnical](#package-nontechnical)**

Supported by: **[Claim ProjectPlanning](#claim-projectplanning)**, [Claim RiskMgmt](#claim-riskmgmt), [Claim ConfigMgmt](#claim-configmgmt), [Claim QA](#claim-qa)

Supports: **[Claim NonTechnical](#claim-nontechnical)**
<!-- end verocase -->

Technical management processes (project planning, risk management, configuration
management, and quality assurance) implement security at the project level.
These processes ensure security is planned for, risks are tracked, configuration
is controlled, and quality is maintained.

<!-- verocase element ProjectPlanning -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-projectplanning"></a>
## Claim ProjectPlanning: Project planning addresses security

Referenced by: **[Package NonTechnical](#package-nontechnical)**

Supported by: **[Evidence ProjectPlanningEv](#evidence-projectplanningev)**

Supports: **[Claim TechMgmt](#claim-techmgmt)**
<!-- end verocase -->

We plan development, and always consider security as we develop new plans.

<!-- verocase element RiskMgmt -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-riskmgmt"></a>
## Claim RiskMgmt: Risk management addresses security

Referenced by: **[Package NonTechnical](#package-nontechnical)**

Supported by: **[Evidence RiskMgmtEv](#evidence-riskmgmtev)**

Supports: **[Claim TechMgmt](#claim-techmgmt)**
<!-- end verocase -->

The primary risk we're concerned about is security, so we have developed
the assurance case here to determine how to counter that risk.

<!-- verocase element QA -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-qa"></a>
## Claim QA: Quality assurance addresses security

Referenced by: **[Package NonTechnical](#package-nontechnical)**

Supported by: **[Evidence QAEv](#evidence-qaev)**

Supports: **[Claim TechMgmt](#claim-techmgmt)**
<!-- end verocase -->

We continuously review our processes and their results to see if there
are systemic problems, and if so, try to address them.
In particular, we try to maximize automation, including automated tests
and automated security analysis, to reduce the risk that the deployed
system will produce incorrect results or will be insecure.

<!-- verocase element ConfigMgmt -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-configmgmt"></a>
## Claim ConfigMgmt: Configuration management addresses security

Referenced by: **[Package NonTechnical](#package-nontechnical)**

Supported by: **[Evidence ConfigMgmtEv](#evidence-configmgmtev)**

Supports: **[Claim TechMgmt](#claim-techmgmt)**
<!-- end verocase -->

See the [governance](./governance.md) document
for information on how the project is governed, including
how important changes are controlled.

For version control we use git, a widely-used
distributed version control system.

As noted in the requirements section,
modifications to the official BadgeApp application require
authentication via GitHub.
We use GitHub for managing the source code and issue tracker; it
has an authentication system for this purpose.

<!-- verocase element ConfigMgmtEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-configmgmtev"></a>
## Evidence ConfigMgmtEv: Git version control via GitHub with authenticated access; governance documented

Referenced by: **[Package NonTechnical](#package-nontechnical)**

Supports: **[Claim ConfigMgmt](#claim-configmgmt)**

External Reference: [../governance.md](https://github.com/ossf/best-practices-badge/blob/main/docs/../governance.md)
<!-- end verocase -->

Git version control via GitHub with authenticated access; governance documented. See [../governance.md](../governance.md).

<!-- verocase element Controls -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-controls"></a>
## Claim Controls: Certifications & controls provide confidence in operating results

Referenced by: **[Package Controls](#package-controls)**, [Package Security](#package-security)

Supported by: **[Claim CIIBadge](#claim-ciibadge)**

Supports: [Claim Security](#claim-security)
<!-- end verocase -->

External certifications and internal controls give us and our users
confidence that the system meets its security goals. Earning the
OpenSSF Best Practices Badge itself requires us to satisfy independently
verified security criteria.

<!-- verocase-config element_level = 3 -->
<!-- verocase element CIIBadge -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-ciibadge"></a>
### Claim CIIBadge: CII Best Practices Badge certification is obtained

Referenced by: **[Package Controls](#package-controls)**

Supported by: **[Evidence CIIBadgeEv](#evidence-ciibadgeev)**

Supports: **[Claim Controls](#claim-controls)**
<!-- end verocase -->

One way to increase confidence in an application is to pass
relevant certifcations.  In our case, the BadgeApp is the result
of an OSS project, so a useful measure is to receive our own
CII best practices badge.

The CII best practices badging project was established to identify
best practices that can lead to more secure software.
The BadgeApp application achieves its own badge.
This is evidence that the BadgeApp application is
applying practices expected in a well-run FLOSS project.

You can see the
[CII Best Practices Badge entry for the BadgeApp](https://bestpractices.coreinfrastructure.org/en/projects/1/0).
Note that we achieve a gold badge.

<!-- verocase element CIIBadgeEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-ciibadgeev"></a>
### Evidence CIIBadgeEv: BadgeApp achieves gold CII Best Practices Badge

Referenced by: **[Package Controls](#package-controls)**

Supports: **[Claim CIIBadge](#claim-ciibadge)**

External Reference: [https://bestpractices.coreinfrastructure.org/en/projects/1](https://bestpractices.coreinfrastructure.org/en/projects/1)
<!-- end verocase -->

BadgeApp achieves gold CII Best Practices Badge. See [https://bestpractices.coreinfrastructure.org/en/projects/1](https://bestpractices.coreinfrastructure.org/en/projects/1).

### Organizational Controls

The
[Center for Internet Security (CIS) Controls](https://www.cisecurity.org/controls/)
are a "prioritized set of actions to protect your organization and data
from known cyber attack vectors."
They are used and supported in many places, e.g.,
[SANS Supports the CIS Critical Security Controls](https://www.sans.org/critical-security-controls)
through a number of resources and information security courses.

Here we compare the CIS controls to the deployed BadgeApp application.
The CIS controls are intended for an entire organization,
while we are focusing on deployment of a single application,
so many controls don't make sense in our context.
Still, it's still useful to go through a set of
controls to make sure we are covering what's important.

For now we only examine the "first 5 CIS controls", as these
"eliminate the vast majority of your organization's vulnerabilities".

Here are the top CIS controls:

1. Inventory of Authorized and Unauthorized Devices.
   The application is deployed on Heroku, who perform the task to
   actively manage (inventory, track, and correct)
   all hardware devices on the network.
2. Inventory of Authorized and Unauthorized Software.
   The deployed system only has one main authorized program, and only
   authorized administrators can deploy or change software on the system.
   The operating system (including kernel and utilities) and
   database system are managed by Heroku.
   We manage the application; its subcomponents are managed by
   package managers.
   We do not use an allowlisting mechanism because it would be pointless;
   at no time does the running system download software to run
   (not even JavaScript), and only administrators can install software on it.
3. Secure Configurations for Hardware and Software on
   Mobile Devices, Laptops, Workstations, and Servers.
   The hardware and the operating system (including kernel and utilities)
   by Heroku; see [Heroku security](https://www.heroku.com/policy/security).
   For the rest we follow strict configuration management processes;
   images (builds) are created using CircleCI and deployed to Heroku
   over an authenticated and encrypted channel.
   These configurations are extensively hardened as described above, and we
   use package management systems to rigorously manage and control updates.
4. Continuous Vulnerability Assessment and Remediation.
   We use automated vulnerability scanning tools to
   alert us to publicly-known vulnerabilities in third-party
   components via multiple mechanisms, as described above.
   We remediate and minimize the opportunity for attack by using
   package managers to rapidly perform controlled updates, combined
   with a large automated test suite to rapidly check that the system
   continues to work.
   These scans focus on the reused software components in our application.
   CIS recommends that you use a
   [SCAP-validated vulnerability scanner](https://nvd.nist.gov/scap/validated-tools)
   that looks for both code-based vulnerabilities (such as those described by
   Common Vulnerabilities and Exposures entries) and configuration-based
   vulnerabilities (as enumerated by the Common Configuration Enumeration
   Project).  Our system runs on the widely-used Ubuntu OS,
   and [Open SCAP](https://www.open-scap.org) is the only OSS scanner
   of that kind that we know of - and it is only SCAP-validated
   for Red Hat.  In addition, we do not control the operating system
   (Heroku does), so it's not clear that such scanners would do us much good.
   However, in the future, we may attempt to try to use Open SCAP
   as an additional tool.
5. Controlled Use of Administrative Privileges.
   We minimize administrative privileges and only use administrative
   accounts when they are required.
   Administrative privileges are strictly limited to a very few
   people who are authorized to do so.
   We do not have "root" privileges on Heroku (Heroku handles that),
   so we cannot give those privileges away, and that greatly reduces the
   need to "implement focused auditing on the use of
   administrative privileged functions and monitor for anomalous behavior."
   We do not use automated tools to inventory all administrative
   accounts and validate each person.
   We have a single production system, with only a few administrators,
   so automation is not useful in this situation.

## Residual risks

It is not possible to eliminate all risks.
Here are a few of the more-prominent residual risks, and why we
believe they are acceptable:

*   *External service dependencies.*
    We depend on several external services, and if they are subverted
    (externally or by an insider) then our service might be subverted as well.
    The most obvious services we depend on are GitHub, Heroku, and
    Amazon Web Services.
    We use GitHub to maintain the code, and we depend on GitHub to
    authenticate GitHub users.  The website itself runs on Heroku, and
    Heroku in turn depends on Amazon Web Services.
    However, these services have generally good reputations, are
    professionally-managed, and have a history of careful monitoring and
    rapid response to any issue.  It's not obvious that we would do
    better if we did it ourselves.
*   *Third party components.*
    As discussed earlier, like all real systems we depend on a large number
    of third party components we did not develop.  These components
    could have unintentional or even intentional vulnerabilities.
    However, recreating them would cost far more time, and since we can make
    mistakes too it's unlikely that the result would be better. Instead,
    as discussed above, we apply a variety of techniques to manage our risks.
    For example, we check any direct dependency we might add before adding it,
    we auto-detect vulnerabilities (that have become publicly known), and
    have a process that supports rapid update.
*   *DDoS.*
    We use a variety of techniques to reduce the impact of DDoS attacks.
    These include using a scalable cloud service,
    using a Content Delivery Network (CDN), and requiring
    the system to return to operation quickly after
    a DDoS attack has ended.
    For more information, see the discussion on availability
    in the requirements section (above).
    However, DDoS attacks are fundamentally resource-on-resource attacks,
    so if an attack is powerful enough, we can only counter it by also
    pouring in lots of resources (which is expensive).
    The same is true for almost any other website.
*   *Keys are stored in environment variables and processed by the application.*
    We use the very common approach of storing keys
    (such as encryption keys) in environment variables, and use
    the application software to apply them.
    This means that an attacker who subverts the entire application or
    underlying system could acquire copies of the keys.
    This includes an attacker who could get a raw copy of a memory dump -
    in such a case, the attacker could see the keys.
    A stronger countermeasure would be to store keys in hardware devices,
    or at least completely separate isolated applications, and then do
    processing with keys in that separate execution environment.
    However, this is more complex to deal with, and we've decided it
    just isn't necessary in our circumstance.  We do partly counter this
    by making it easy for us to change keys.
*   *A vulnerability we missed.*
    Perfection is hard to achieve.
    We have considered security throughout system development,
    analyzed it for security issues, and documented what we've determined
    in this assurance case.
    That said, we could still have missed a vulnerability.
    We have released the information so that others can review it,
    and published a vulnerability report handling process so that
    security analysts can report findings to us.
    We believe we've addressed security enough to deploy the system.

## Vulnerability report handling process

As noted in CONTRIBUTING.md, if anyone finds a
significant vulnerability, or evidence of one, we ask that they
send that information to at least one of the security contacts.
The CONTRIBUTING.md file explains how to report a vulnerability;
below we describe what happens once vulnerability is reported.

Whoever receives that report will share that information with the
other security contacts, and one of them will analyze it:

* If is not valid, one of the security contacts will reply back to
  the reporter to explain that (if this is a misunderstanding,
  the reporter can reply and start the process again).
* If it is a bug but not security vulnerability, the security contact
  will create an issue as usual for repair.
* If it is a security vulnerability, one of the security contacts will
  fix it in a *local* git repository and *not* share it with the world
  until the fix is ready.  An issue will *not* be filed, since those
  are public.  If it needs review, the review will not be public.
  Discussions will be held, as much as practical, using encrypted
  channels (e.g., using email systems that support hop-to-hop encryption).
  Once the fix is ready, it will be quickly moved through all tiers.
  The goal is to minimize the risk of attackers exploiting the problem
  before it is fixed.  Our goal is to fix any real vulnerability within
  two calendar weeks of a report (and do it faster if practical);
  the actual time will depend on the difficulty of repair.

Once the fix is in the final production system, credit will be
publicly given to the vulnerability reporter (unless the reporter
requested otherwise).

## History: Previous LibreOffice-based approach

Originally we used
[Claims- Arguments- Evidence (CAE) notation](https://www.adelard.com/asce/choosing-asce/cae.html),
CAE notation is wonderfully simple:
Claims (including subclaims) are ovals,
arguments are rounded rectangles, and evidence (references) are rectangles.
The GSN alternative was too complex (it uses many more symbols) and confusing
to non-experts (e.g., it uses terms like "Strategy" for an argument).
In addition, when we started the SACM graphical notation did not exist
(it was not released until 2020).

Historically the
[Object Management Group (OMG) Structured Assurance Case Metamodel (SACM) specification](https://www.omg.org/spec/SACM/About-SACM/)
specification has focused on defining a standard interchange
format for assurance case data.
[Mappings are available between other notations and the SACM data structures](https://www.adelard.com/asce/choosing-asce/standardisation.html),
However, we currently aren’t trying to exchange with other systems.
So while we didn't know of anything intrinsically wrong with SACM,
historically the SACM specification wasn’t
focused on solving any problems we’re trying to solve.
In addition, we don’t know of any mature OSS tools that directly
support the SACM data format.
By policy, any tools we *depend* on must be OSS, and when we modify the
code or configuration we must be able to update the assurance case.

However, in 2020 version 2.1 of SACM added a new graphical notation.
Claims (including subclaims) are rectangles, ArgumentReasoning (aka
arguments) are open rectangles, ArtifactCitations (used for evidence)
are shadowed rectangles, and a connection showing an AssertedRelationship
use intermediate symbols such as "big dots".

After comparing the notations, we have found that the SACM
graphical notation has many advantages over CAE graphical notation:

1. CAE Claim vs. SACM Claim. CAE uses ovals, while SACM uses
   rectangles. SACM has a *BIG* win here: Rectangles use MUCH less
   space, so complex diagrams are much easier to create & easier to
   understand.
2. CAE Argument vs. SACM ArgumentReasoning. CAE uses rounded
   rectangles, while SACM uses a shape I’ll call an "open rectangle”.
   CAE’s rounded rectangles are not very distinct from its evidence
   rectangles, which is a minor negative for the CAE notation. SACM
   initially presented some challenges when using our drawing tool
   (LibreOffice Draw), but we overcame them:
  - SACM’s half-rectangle initially presented a problem:
    that is *NOT* a built-in shape for the drawing tool we were using
    (LibreOffice Draw). We suspect it’s not a built-in symbol in many
    tools. We worked around this by creating a polygon (many
    drawing tools support this, and this is a very easy polygon to
    make). It took a little tweaking, but we created a simple
    polygon with embedded text. In the longer term, the SACM community
    should work to get this easy icon into other drawing tools, to
    simplify its use.
  - SACM’s half-rectangle is VERY hard to visually distinguish
    if both it and claims are filled with color. We use color fills
    to help the eye notice type differences. Our solution was simple:
    color fill everything *except* the half-rectangle; this makes
    them all visually distinct.
3. CAE Evidence vs. SACM ArtifactReference.
   In CAE this is a simple rectangle. In SACM this is a shadowed
   rectangle with an arrow; the arrow is hard to add with simple
   drawing tools, but the shadow is trivial to add with a “shadow”
   property in LibreOffice (and many other drawing tools), and we
   think just the shadow is adequate. The shadow adds slightly more
   space (but MUCH less than ovals), and it takes a moment to draw
   by hand, but we think that’s a reasonable trade-off to ensure
   that they are visually distinct. In addition: we tend to record
   evidence / ArtifactReferences in *only* text, not in the diagrams,
   because diagrams are time-consuming to maintain. So making
   *claims* simple to draw, and making evidence/ArtifactReferences
   slightly more complex to draw, is exactly the right tradeoff.
4. Visual distinctiveness. In *general* the CAE icons
   for Claim/Argument/Evidence are not as visually distinct as
   SACM’s Claim/ArgumentReasoning/ArtifactReference, especially
   when they get shaped to the text contents. That’s an overall
   advantage for the SACM graphical notation.
5. SACM’s “bigdot”.
   The bigdot, e.g., in AssertedInference, make the diagrams simpler
   by making it easy to move an argument / ArgumentReasoning icon
   away from the flow from supporting claims/evidence to a higher
   claim. It also makes the arrows clearer (you merge flows earlier)
   and that merging makes combinations easier to follow.
   You could also informally do that with CAE, but it’s clearly a part of SACM.
6. It has an asCited notation that a claim in one location is described
   elsewhere, a rectangle in another (an asCited Claim). We previously used "See..."
   as text instead.

In our SACM diagrams we've sometimes omitted the bigdot when there is a
single connection from one element to another.
This is not strictly compliant.
One advantage of using “bigdot” even in these
cases would be that it would make it much easier to add
an ArgumentReasoning later.
However, adding the bigdot in those cases is nontrivial
extra work when using our basic drawing tools (because we must draw
the bigdot, two connectors, and connect them all up,
instead of using a simple direct connection).

We don't have an easy way to display SACM's ArgumentPackage and related
symbols. We just use a "scroll" icon in that case to indicate
each diagram package.

At first it appeared that there was a problem with
SACM’s ArgumentReasoning symbol, rectangle open on one side.
While it’s easy to connect on the
left/top/bottom, it’s somewhat unclear when trying to connect from
its bare right-hand-side in its presented orientation
(because the lines are not visibly connected to another symbol).
My thanks to Scott Ankrum for pointing this out!
This not an unusual problem; in data flow diagrams, the "data store"
symbol is open on both the left and right edges
(resulting in the same problem).
One solution, without changing anything, is to prefer to put
this icon on the right-hand-side of what it connects to.
Another solution would have been to use another symbol, e.g., an
an uneven pentagon (“pointer”) or callout symbol (with the little tail).
However, the paper
"A Visual Notation for the Representation of Assurance Cases using SACM"
suggests a simpler solution was intended: horizontally flip the
rectangle open on one side.

## Future work

["Evaluating and Mitigating Software Supply Chain Security Risks" by Ellison et al, May 2020](https://resources.sei.cmu.edu/asset_files/TechnicalNote/2010_004_001_15176.pdf) has an assurance case focusing on
supply chain security risks, as well as other information.
We intend to review it for future ideas.

## Your help is welcome!

Security is hard; we welcome your help.
We welcome hardening in general, particularly pull requests
that actually do the work of hardening.
We thank many, including Reg Meeson, for reviewing and providing feedback
on this assurance case.

Please report potential vulnerabilities you find; see
[CONTRIBUTING.md](../CONTRIBUTING.md) for how to submit a vulnerability report.

## See also

Project participation and interface:

* [CONTRIBUTING.md](../CONTRIBUTING.md) - How to contribute to this project
* [INSTALL.md](INSTALL.md) - How to install/quick start
* [governance.md](governance.md) - How the project is governed
* [roadmap.md](roadmap.md) - Overall direction of the project
* [background.md](background.md) - Background research
* [api](api.md) - Application Programming Interface (API), inc. data downloads

Criteria:

* [Criteria for passing badge](https://bestpractices.coreinfrastructure.org/criteria/0)
* [Criteria for all badge levels](https://bestpractices.coreinfrastructure.org/criteria)

Development processes and security:

* [requirements.md](requirements.md) - Requirements (what's it supposed to do?)
* [design.md](design.md) - Architectural design information
* [implementation.md](implementation.md) - Implementation notes
* [testing.md](testing.md) - Information on testing
* [assurance-case.md](assurance-case.md) - Why it's adequately secure (assurance case)

<!-- verocase element QAEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-qaev"></a>
### Evidence QAEv: CI pipeline runs rubocop, eslint, rails_best_practices, whitespace checks, and full test suite on every commit, enforcing quality and security standards

Referenced by: **[Package NonTechnical](#package-nontechnical)**

Supports: **[Claim QA](#claim-qa)**

External Reference: [../.circleci/config.yml](https://github.com/ossf/best-practices-badge/blob/main/docs/../.circleci/config.yml)
<!-- end verocase -->

See the [parent claim section](#claim-qa) for details.

<!-- verocase element RiskMgmtEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-riskmgmtev"></a>
### Evidence RiskMgmtEv: Continuous threat modeling implemented via this assurance case; regular dependency audits, static analysis, and security-focused development practices address identified risks

Referenced by: **[Package NonTechnical](#package-nontechnical)**

Supports: **[Claim RiskMgmt](#claim-riskmgmt)**

External Reference: [../docs/case.md](https://github.com/ossf/best-practices-badge/blob/main/docs/../docs/case.md)
<!-- end verocase -->

See the [parent claim section](#claim-riskmgmt) for details.

<!-- verocase element ProjectPlanningEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-projectplanningev"></a>
### Evidence ProjectPlanningEv: Project roadmap and governance prioritize security; long-term security maintenance documented as a goal

Referenced by: **[Package NonTechnical](#package-nontechnical)**

Supports: **[Claim ProjectPlanning](#claim-projectplanning)**

External Reference: [../governance.md](https://github.com/ossf/best-practices-badge/blob/main/docs/../governance.md)
<!-- end verocase -->

See the [parent claim section](#claim-projectplanning) for details.

<!-- verocase element DevKnowledgeEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-devknowledgeev"></a>
### Evidence DevKnowledgeEv: Key developers have demonstrated expertise in secure software development including creation of OpenSSF Best Practices criteria, academic research on secure programming, and security-focused professional work

Referenced by: **[Package NonTechnical](#package-nontechnical)**

Supports: **[Claim DevKnowledge](#claim-devknowledge)**

External Reference: [../docs/background.md](https://github.com/ossf/best-practices-badge/blob/main/docs/../docs/background.md)
<!-- end verocase -->

See the [parent claim section](#claim-devknowledge) for details.

<!-- verocase element CINoDataEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-cinodataev"></a>
### Evidence CINoDataEv: CircleCI environment uses separate test database with no production data; production credentials never present in CI context; test database seeded only with synthetic test fixtures

Referenced by: **[Package NonTechnical](#package-nontechnical)**

Supports: **[Claim CINoData](#claim-cinodata)**

External Reference: [../.circleci/config.yml](https://github.com/ossf/best-practices-badge/blob/main/docs/../.circleci/config.yml)
<!-- end verocase -->

See the [parent claim section](#claim-cinodata) for details.

<!-- verocase element DevEnvSecEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-devenvsecev"></a>
### Evidence DevEnvSecEv: Development uses local git repositories; GitHub requires authenticated access; no production secrets stored in development environments; CI/CD pipeline validates branch names before use

Referenced by: **[Package NonTechnical](#package-nontechnical)**

Supports: **[Claim DevEnvSec](#claim-devenvsec)**

External Reference: [../CONTRIBUTING.md](https://github.com/ossf/best-practices-badge/blob/main/docs/../CONTRIBUTING.md)
<!-- end verocase -->

See the [parent claim section](#claim-devenvsec) for details.

<!-- verocase element ContractsEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-contractsev"></a>
### Evidence ContractsEv: Heroku Data Processing Addendum and security policy cover deployment environment; Fastly service agreement covers CDN security

Referenced by: **[Package NonTechnical](#package-nontechnical)**

Supports: **[Claim Contracts](#claim-contracts)**

External Reference: [https://www.heroku.com/policy/security](https://www.heroku.com/policy/security)
<!-- end verocase -->

See the [parent claim section](#claim-contracts) for details.

<!-- verocase element RapidUpdateEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-rapidupdateev"></a>
### Evidence RapidUpdateEv: Bundler enables library updates in one command; high test coverage enables rapid verify-and-deploy; CI/CD pipeline deploys to Heroku automatically on passing tests

Referenced by: **[Package Maintenance](#package-maintenance)**

Supports: **[Claim RapidUpdate](#claim-rapidupdate)**

External Reference: [../.circleci/config.yml](https://github.com/ossf/best-practices-badge/blob/main/docs/../.circleci/config.yml)
<!-- end verocase -->

See the [parent claim section](#claim-rapidupdate) for details.

<!-- verocase element RecoveryPlanEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-recoveryplanev"></a>
### Evidence RecoveryPlanEv: Recovery procedures documented including database restoration from Heroku Postgres backups, BADGEAPP_DENY_LOGIN degraded mode, and mass_email and rekey rake tasks

Referenced by: **[Package Deployment](#package-deployment)**

Supports: **[Claim RecoveryPlan](#claim-recoveryplan)**

External Reference: [../docs/case.md](https://github.com/ossf/best-practices-badge/blob/main/docs/../docs/case.md)
<!-- end verocase -->

See the [parent claim section](#claim-recoveryplan) for details.

<!-- verocase element OnlineCheckersEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-onlinecheckersev"></a>
### Evidence OnlineCheckersEv: Mozilla Observatory, Security Headers, and similar online tools verify HTTP response headers and flag misconfiguration

Referenced by: **[Package Deployment](#package-deployment)**

Supports: **[Claim OnlineCheckers](#claim-onlinecheckers)**

External Reference: [https://observatory.mozilla.org/analyze/www.bestpractices.dev](https://observatory.mozilla.org/analyze/www.bestpractices.dev)
<!-- end verocase -->

See the [parent claim section](#claim-onlinecheckers) for details.

<!-- verocase element PubVulnsDependabotEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-pubvulnsdependabotev"></a>
### Evidence PubVulnsDependabotEv: GitHub Dependabot alerts and automated pull requests for vulnerable dependencies

Referenced by: **[Package Implementation](#package-implementation)**

Supports: **[Claim PubVulns](#claim-pubvulns)**

External Reference: [../.github/dependabot.yml](https://github.com/ossf/best-practices-badge/blob/main/docs/../.github/dependabot.yml)
<!-- end verocase -->

See the [parent claim section](#claim-pubvulns) for details.

<!-- verocase element PubVulnsBundleEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-pubvulnsbundleev"></a>
### Evidence PubVulnsBundleEv: bundle-audit checks all gem versions against NVD vulnerability database on every rake run

Referenced by: **[Package Implementation](#package-implementation)**

Supports: **[Claim PubVulns](#claim-pubvulns)**

External Reference: [../Gemfile.lock](https://github.com/ossf/best-practices-badge/blob/main/docs/../Gemfile.lock)
<!-- end verocase -->

See the [parent claim section](#claim-pubvulns) for details.

<!-- verocase element ReuseAuthEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-reuseauthev"></a>
### Evidence ReuseAuthEv: Gemfile.lock records exact versions and SHA-512 checksums for all gems, ensuring reproducible authenticated builds

Referenced by: **[Package ReuseSec](#package-reusesec)**

Supports: **[Claim ReuseAuth](#claim-reuseauth)**

External Reference: [../Gemfile.lock](https://github.com/ossf/best-practices-badge/blob/main/docs/../Gemfile.lock)
<!-- end verocase -->

See the [parent claim section](#claim-reuseauth) for details.

<!-- verocase element ReuseReviewEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-reusereviewev"></a>
### Evidence ReuseReviewEv: New gem dependencies reviewed for purpose, maintenance, and security before addition; CONTRIBUTING.md documents review expectations

Referenced by: **[Package ReuseSec](#package-reusesec)**

Supports: **[Claim ReuseReview](#claim-reusereview)**

External Reference: [../CONTRIBUTING.md](https://github.com/ossf/best-practices-badge/blob/main/docs/../CONTRIBUTING.md)
<!-- end verocase -->

See the [parent claim section](#claim-reusereview) for details.

<!-- verocase element RailsGuideEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-railsguideev"></a>
### Evidence RailsGuideEv: Rails security guide reviewed and countermeasures applied for sessions, CSRF, XSS, injection, and other Rails-specific issues

Referenced by: **[Package Implementation](#package-implementation)**

Supports: **[Claim RailsGuide](#claim-railsguide)**

External Reference: [https://guides.rubyonrails.org/security.html](https://guides.rubyonrails.org/security.html)
<!-- end verocase -->

See the [parent claim section](#claim-railsguide) for details.

<!-- verocase element OWASP13Ev -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-owasp13ev"></a>
### Evidence OWASP13Ev: filter_parameter_logging excludes passwords from logs; events stream to stdout per 12-factor app; UptimeRobot monitors availability externally

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supports: **[Claim OWASP13](#claim-owasp13)**

External Reference: [../config/initializers/filter_parameter_logging.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../config/initializers/filter_parameter_logging.rb)
<!-- end verocase -->

See the [parent claim section](#claim-owasp13) for details.

<!-- verocase element OWASP12Ev -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-owasp12ev"></a>
### Evidence OWASP12Ev: Rails session data stored in signed encrypted cookies; no untrusted object deserialization; JSON used for API data

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supports: **[Claim OWASP12](#claim-owasp12)**

External Reference: [../config/initializers/session_store.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../config/initializers/session_store.rb)
<!-- end verocase -->

See the [parent claim section](#claim-owasp12) for details.

<!-- verocase element OWASP11Ev -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-owasp11ev"></a>
### Evidence OWASP11Ev: Nokogiri configured to disable external entity processing; XML parsing restricted to safe subset; SpecialAnalysis documents this exception

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supports: **[Claim OWASP11](#claim-owasp11)**

External Reference: [../docs/case.md](https://github.com/ossf/best-practices-badge/blob/main/docs/../docs/case.md)
<!-- end verocase -->

See the [parent claim section](#claim-owasp11) for details.

<!-- verocase element OWASP10Ev -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-owasp10ev"></a>
### Evidence OWASP10Ev: Redirect destinations validated against allowlists; no open redirect vulnerabilities; after-login redirect uses stored path validated server-side

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supports: **[Claim OWASP10](#claim-owasp10)**

External Reference: [../app/controllers/sessions_controller.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../app/controllers/sessions_controller.rb)
<!-- end verocase -->

See the [parent claim section](#claim-owasp10) for details.

<!-- verocase element OWASP9DependabotEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-owasp9dependabotev"></a>
### Evidence OWASP9DependabotEv: GitHub Dependabot alerts on vulnerable dependencies and opens PRs to update them

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supports: **[Claim OWASP9](#claim-owasp9)**

External Reference: [../.github/dependabot.yml](https://github.com/ossf/best-practices-badge/blob/main/docs/../.github/dependabot.yml)
<!-- end verocase -->

See the [parent claim section](#claim-owasp9) for details.

<!-- verocase element OWASP9BundleEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-owasp9bundleev"></a>
### Evidence OWASP9BundleEv: bundle-audit checks all gems against NVD vulnerability database on every rake run

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supports: **[Claim OWASP9](#claim-owasp9)**

External Reference: [../Gemfile.lock](https://github.com/ossf/best-practices-badge/blob/main/docs/../Gemfile.lock)
<!-- end verocase -->

See the [parent claim section](#claim-owasp9) for details.

<!-- verocase element OWASP8Ev -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-owasp8ev"></a>
### Evidence OWASP8Ev: protect_from_forgery with per-form tokens and origin-header check, enabled via load_defaults

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supports: **[Claim OWASP8](#claim-owasp8)**

External Reference: [../app/controllers/application_controller.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../app/controllers/application_controller.rb)
<!-- end verocase -->

See the [parent claim section](#claim-owasp8) for details.

<!-- verocase element OWASP7Ev -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-owasp7ev"></a>
### Evidence OWASP7Ev: can_edit? and can_control? enforced server-side on all mutating actions; no security decisions made client-side

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supports: **[Claim OWASP7](#claim-owasp7)**

External Reference: [../app/controllers/application_controller.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../app/controllers/application_controller.rb)
<!-- end verocase -->

See the [parent claim section](#claim-owasp7) for details.

<!-- verocase element OWASP6Ev -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-owasp6ev"></a>
### Evidence OWASP6Ev: Email encrypted with AES-256-GCM; passwords stored via bcrypt; all data in transit protected by TLS; filter_parameter_logging excludes sensitive fields from logs

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supports: **[Claim OWASP6](#claim-owasp6)**

External Reference: [../config/initializers/filter_parameter_logging.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../config/initializers/filter_parameter_logging.rb)
<!-- end verocase -->

See the [parent claim section](#claim-owasp6) for details.

<!-- verocase element OWASP5Ev -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-owasp5ev"></a>
### Evidence OWASP5Ev: secure_headers gem enforces HTTP security headers; Rails secrets managed via environment variables; CI runs security checks on every commit

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supports: **[Claim OWASP5](#claim-owasp5)**

External Reference: [../config/initializers/secure_headers.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../config/initializers/secure_headers.rb)
<!-- end verocase -->

See the [parent claim section](#claim-owasp5) for details.

<!-- verocase element OWASP4Ev -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-owasp4ev"></a>
### Evidence OWASP4Ev: All project access goes through can_edit? and can_control? authorization checks; no direct object references exposed without authorization

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supports: **[Claim OWASP4](#claim-owasp4)**

External Reference: [../app/controllers/projects_controller.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../app/controllers/projects_controller.rb)
<!-- end verocase -->

See the [parent claim section](#claim-owasp4) for details.

<!-- verocase element OWASP3Ev -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-owasp3ev"></a>
### Evidence OWASP3Ev: Rails SafeBuffer escapes all template output by default; markdown processing whitelists safe tags and attributes; CSP enforced via secure_headers gem

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supports: **[Claim OWASP3](#claim-owasp3)**

External Reference: [../config/initializers/secure_headers.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../config/initializers/secure_headers.rb)
<!-- end verocase -->

See the [parent claim section](#claim-owasp3) for details.

<!-- verocase element OWASP2Ev -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-owasp2ev"></a>
### Evidence OWASP2Ev: Sessions use encrypted signed cookies; has_secure_password enforces bcrypt; remember-me uses bcrypt-stored nonce; session_store.rb configures secure cookie settings

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supports: **[Claim OWASP2](#claim-owasp2)**

External Reference: [../config/initializers/session_store.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../config/initializers/session_store.rb)
<!-- end verocase -->

See the [parent claim section](#claim-owasp2) for details.

<!-- verocase element OWASP1Ev -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-owasp1ev"></a>
### Evidence OWASP1Ev: ActiveRecord ORM uses parameterized queries by default; direct SQL uses sanitize_sql_like or bound parameters; shell is never used to process untrusted content

Referenced by: **[Package OWASPClaim](#package-owaspclaim)**

Supports: **[Claim OWASP1](#claim-owasp1)**

External Reference: [../app/models/project.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../app/models/project.rb)
<!-- end verocase -->

See the [parent claim section](#claim-owasp1) for details.

<!-- verocase element MemSafeEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-memsafeev"></a>
### Evidence MemSafeEv: All custom application code is written in Ruby and JavaScript, both memory-managed languages; buffer overflows and memory corruption cannot occur in custom code

Referenced by: **[Package Design](#package-design)**

Supports: **[Claim MemSafe](#claim-memsafe)**

External Reference: [../Gemfile](https://github.com/ossf/best-practices-badge/blob/main/docs/../Gemfile)
<!-- end verocase -->

See the [parent claim section](#claim-memsafe) for details.

<!-- verocase element ScalabilityEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-scalabilityev"></a>
### Evidence ScalabilityEv: Heroku dyno-based deployment enables horizontal scaling; Fastly CDN offloads static asset and badge requests from origin server

Referenced by: **[Package Design](#package-design)**

Supports: **[Claim Scalability](#claim-scalability)**

External Reference: [../Procfile](https://github.com/ossf/best-practices-badge/blob/main/docs/../Procfile)
<!-- end verocase -->

See the [parent claim section](#claim-scalability) for details.

<!-- verocase element InputValidEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-inputvalidev"></a>
### Evidence InputValidEv: Project and User models use Rails validators to enforce field constraints; controllers use strong parameters (permit) to whitelist allowed input fields

Referenced by: **[Package DesignPrinciples](#package-designprinciples)**

Supports: **[Claim InputValid](#claim-inputvalid)**

External Reference: [../app/models/project.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../app/models/project.rb)
<!-- end verocase -->

See the [parent claim section](#claim-inputvalid) for details.

<!-- verocase element LimitedAttackEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-limitedattackev"></a>
### Evidence LimitedAttackEv: Restrictive CSP limits script execution sources; routes.rb exposes only necessary endpoints; Rack::Attack blocks abusive IPs

Referenced by: **[Package DesignPrinciples](#package-designprinciples)**

Supports: **[Claim LimitedAttack](#claim-limitedattack)**

External Reference: [../config/initializers/rack_attack.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../config/initializers/rack_attack.rb)
<!-- end verocase -->

See the [parent claim section](#claim-limitedattack) for details.

<!-- verocase element PsychAcceptEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-psychacceptev"></a>
### Evidence PsychAcceptEv: Standard web authentication UX (email/password or GitHub OAuth login); badge criteria presented in plain language; security controls do not impose undue burden on legitimate use

Referenced by: **[Package DesignPrinciples](#package-designprinciples)**

Supports: **[Claim PsychAccept](#claim-psychaccept)**

External Reference: [../app/views/projects/](https://github.com/ossf/best-practices-badge/blob/main/docs/../app/views/projects/)
<!-- end verocase -->

See the [parent claim section](#claim-psychaccept) for details.

<!-- verocase element LeastCommonEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-leastcommonev"></a>
### Evidence LeastCommonEv: Per-request processing; session state stored in per-user encrypted client-side cookies, not shared server-side sessions

Referenced by: **[Package DesignPrinciples](#package-designprinciples)**

Supports: **[Claim LeastCommon](#claim-leastcommon)**

External Reference: [../config/initializers/session_store.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../config/initializers/session_store.rb)
<!-- end verocase -->

See the [parent claim section](#claim-leastcommon) for details.

<!-- verocase element LeastPrivEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-leastprivev"></a>
### Evidence LeastPrivEv: can_edit? grants edit access only to project owner or admins; additional_rights table enables explicit narrow collaborator grants

Referenced by: **[Package DesignPrinciples](#package-designprinciples)**

Supports: **[Claim LeastPriv](#claim-leastpriv)**

External Reference: [../app/controllers/application_controller.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../app/controllers/application_controller.rb)
<!-- end verocase -->

See the [parent claim section](#claim-leastpriv) for details.

<!-- verocase element SepPrivEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-sepprivev"></a>
### Evidence SepPrivEv: admin? method in User model separates admin role from normal user; admin-only actions checked explicitly and separately from ownership

Referenced by: **[Package DesignPrinciples](#package-designprinciples)**

Supports: **[Claim SepPriv](#claim-seppriv)**

External Reference: [../app/models/user.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../app/models/user.rb)
<!-- end verocase -->

See the [parent claim section](#claim-seppriv) for details.

<!-- verocase element OpenDesignEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-opendesignev"></a>
### Evidence OpenDesignEv: Full source code publicly available; security does not depend on keeping implementation secret

Referenced by: **[Package DesignPrinciples](#package-designprinciples)**

Supports: **[Claim OpenDesign](#claim-opendesign)**

External Reference: [https://github.com/ossf/best-practices-badge](https://github.com/ossf/best-practices-badge)
<!-- end verocase -->

See the [parent claim section](#claim-opendesign) for details.

<!-- verocase element FailSafeEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-failsafeev"></a>
### Evidence FailSafeEv: can_edit_else_redirect and can_control_else_redirect redirect unauthenticated or unauthorized requests; default deny enforced server-side

Referenced by: **[Package DesignPrinciples](#package-designprinciples)**

Supports: **[Claim FailSafe](#claim-failsafe)**

External Reference: [../app/controllers/application_controller.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../app/controllers/application_controller.rb)
<!-- end verocase -->

See the [parent claim section](#claim-failsafe) for details.

<!-- verocase element CompleteMedEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-completemedev"></a>
### Evidence CompleteMedEv: before_action authorization hooks in ApplicationController run on every request; no client-side access control decisions are made

Referenced by: **[Package DesignPrinciples](#package-designprinciples)**

Supports: **[Claim CompleteMed](#claim-completemed)**

External Reference: [../app/controllers/application_controller.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../app/controllers/application_controller.rb)
<!-- end verocase -->

See the [parent claim section](#claim-completemed) for details.

<!-- verocase element EconomyMechEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-economymechev"></a>
### Evidence EconomyMechEv: Custom code kept minimal and DRY; standard Rails patterns used; Gemfile shows focused, well-scoped dependency set

Referenced by: **[Package DesignPrinciples](#package-designprinciples)**

Supports: **[Claim EconomyMech](#claim-economymech)**

External Reference: [../Gemfile](https://github.com/ossf/best-practices-badge/blob/main/docs/../Gemfile)
<!-- end verocase -->

See the [parent claim section](#claim-economymech) for details.

<!-- verocase element STRIDEEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-strideev"></a>
### Evidence STRIDEEv: STRIDE threat analysis documented for all major components: web server, controllers/models/views, DBMS, Chief/Detective classes, admin CLI, and i18n service

Referenced by: **[Package Design](#package-design)**

Supports: **[Claim STRIDE](#claim-stride)**

External Reference: [../docs/case.md](https://github.com/ossf/best-practices-badge/blob/main/docs/../docs/case.md)
<!-- end verocase -->

See the [parent claim section](#claim-stride) for details.

<!-- verocase element SimpleDesignEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-simpledesignev"></a>
### Evidence SimpleDesignEv: Standard Rails MVC architecture with models, views, and controllers; no microservices or complex distributed patterns; custom code kept minimal

Referenced by: **[Package Design](#package-design)**

Supports: **[Claim SimpleDesign](#claim-simpledesign)**

External Reference: [../docs/design.md](https://github.com/ossf/best-practices-badge/blob/main/docs/../docs/design.md)
<!-- end verocase -->

See the [parent claim section](#claim-simpledesign) for details.

<!-- verocase element ThreatsIdentified -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-threatsidentified"></a>
### Claim ThreatsIdentified: Key threat actors (external attackers, bots, insiders, nation-states) have been identified and addressed

Referenced by: **[Package Requirements](#package-requirements)**

Supports: **[Claim Assets](#claim-assets)**
<!-- end verocase -->

We have identified the key threat actors who might attack the BadgeApp.
External attackers (including automated bots and nation-state actors) may attempt
to exploit vulnerabilities or overwhelm the system.
Insiders (developers with repository access) represent a supply-chain threat.
Each threat type is addressed by the countermeasures described throughout
this assurance case.

<!-- verocase element AssetsIdentified -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-assetsidentified"></a>
### Claim AssetsIdentified: Key assets (badge data, user credentials, system availability) have been identified

Referenced by: **[Package Requirements](#package-requirements)**

Supports: **[Claim Assets](#claim-assets)**
<!-- end verocase -->

We have identified the key assets that must be protected.
The primary assets are: badge award data (the self-assessments and resulting badge
levels that projects have earned), user credentials (passwords, remember-me tokens,
and OAuth tokens), user contact information (email addresses), and system
availability itself (the ability of the site to serve badge data on demand).
The countermeasures throughout this assurance case are designed to protect these assets.

<!-- verocase element OAuthEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-oauthev"></a>
### Evidence OAuthEv: OmniAuth-GitHub middleware authenticates remote users via GitHub OAuth 2.0; callback validates identity before creating local session

Referenced by: **[Package Requirements](#package-requirements)**

Supports: **[Claim RemoteAuthN](#claim-remoteauthn)**

External Reference: [../config/initializers/omniauth.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../config/initializers/omniauth.rb)
<!-- end verocase -->

See the [parent claim section](#claim-remoteauthn) for details.

<!-- verocase element LocalAuthNEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-localauthnev"></a>
### Evidence LocalAuthNEv: sessions_controller create action authenticates local users by verifying email and bcrypt password hash before establishing session

Referenced by: **[Package Requirements](#package-requirements)**

Supports: **[Claim LocalAuthN](#claim-localauthn)**

External Reference: [../app/controllers/sessions_controller.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../app/controllers/sessions_controller.rb)
<!-- end verocase -->

See the [parent claim section](#claim-localauthn) for details.

<!-- verocase element ScaleUpEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-scaleupev"></a>
### Evidence ScaleUpEv: Heroku cloud platform supports on-demand dyno scaling; Fastly CDN reduces origin load during traffic spikes

Referenced by: **[Package Availability](#package-availability)**

Supports: **[Claim ScaleUp](#claim-scaleup)**

External Reference: [../Procfile](https://github.com/ossf/best-practices-badge/blob/main/docs/../Procfile)
<!-- end verocase -->

See the [parent claim section](#claim-scaleup) for details.

<!-- verocase element BackupsEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-backupsev"></a>
### Evidence BackupsEv: Heroku Postgres automated daily backups retained across multiple snapshots; standard Rails and PostgreSQL restore mechanisms enable database recovery

Referenced by: **[Package Availability](#package-availability)**

Supports: **[Claim Backups](#claim-backups)**

External Reference: [https://devcenter.heroku.com/articles/heroku-postgres-backups](https://devcenter.heroku.com/articles/heroku-postgres-backups)
<!-- end verocase -->

See the [parent claim section](#claim-backups) for details.

<!-- verocase element QuickRecoveryEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-quickrecoveryev"></a>
### Evidence QuickRecoveryEv: Heroku allows rapid dyno restart and redeploy from last known good git commit, restoring service within minutes of an incident

Referenced by: **[Package Availability](#package-availability)**

Supports: **[Claim QuickRecovery](#claim-quickrecovery)**

External Reference: [../Procfile](https://github.com/ossf/best-practices-badge/blob/main/docs/../Procfile)
<!-- end verocase -->

See the [parent claim section](#claim-quickrecovery) for details.

<!-- verocase element FastlyCDNEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-fastlycdnev"></a>
### Evidence FastlyCDNEv: Fastly CDN configured as reverse proxy; badge image and static asset requests absorbed by CDN before reaching origin application server

Referenced by: **[Package Availability](#package-availability)**

Supports: **[Claim CDNDDoS](#claim-cdnddos)**

External Reference: [../config/initializers/fastly.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../config/initializers/fastly.rb)
<!-- end verocase -->

See the [parent claim section](#claim-cdnddos) for details.

<!-- verocase element AppModAuthEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-appmodauthev"></a>
### Evidence AppModAuthEv: GitHub repository requires authenticated access; branch protection rules enforce code review before merging to main; governance.md documents the process

Referenced by: **[Package Requirements](#package-requirements)**

Supports: **[Claim AppModAuth](#claim-appmodauth)**

External Reference: [../governance.md](https://github.com/ossf/best-practices-badge/blob/main/docs/../governance.md)
<!-- end verocase -->

See the [parent claim section](#claim-appmodauth) for details.

<!-- verocase element GravatarPrivacyEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-gravatarprivacyev"></a>
### Evidence GravatarPrivacyEv: use_gravatar boolean controls whether any MD5 hash is sent to Gravatar, giving each user control over this external disclosure

Referenced by: **[Package Confidentiality](#package-confidentiality)**

Supports: **[Claim UserPrivacy](#claim-userprivacy)**

External Reference: [../app/models/user.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../app/models/user.rb)
<!-- end verocase -->

See the [parent claim section](#claim-userprivacy) for details.

<!-- verocase element SelfHostedAssets -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-selfhostedassets"></a>
### Claim SelfHostedAssets: All web assets are self-hosted; no third-party transclusions reveal user activity to unrelated sites

Referenced by: **[Package Confidentiality](#package-confidentiality)**

Supported by: **[Evidence SelfHostedAssetsEv](#evidence-selfhostedassetsev)**

Supports: **[Claim UserPrivacy](#claim-userprivacy)**
<!-- end verocase -->

We serve all JavaScript, CSS, images, and fonts directly from our own origin,
with no embedded references to external CDNs, social-media widgets, or
analytics scripts.
This matters for privacy: if we embedded a third-party script tag, the
third-party server would receive the user's IP address and browsing context
every time a page loaded, even for anonymous visitors.
By self-hosting, we ensure that unrelated sites learn nothing about our users'
page-view activity.
This also improves security by eliminating the risk of a subverted third-party
asset silently attacking our users.

<!-- verocase element SelfHostedAssetsEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-selfhostedassetsev"></a>
### Evidence SelfHostedAssetsEv: Content-Security-Policy restricts script-src and style-src to self; application layouts contain no external CDN script or font references

Referenced by: **[Package Confidentiality](#package-confidentiality)**

Supports: **[Claim SelfHostedAssets](#claim-selfhostedassets)**

External Reference: [../config/initializers/secure_headers.rb](https://github.com/ossf/best-practices-badge/blob/main/docs/../config/initializers/secure_headers.rb)
<!-- end verocase -->

See the [parent claim section](#claim-selfhostedassets) for details.

<!-- verocase element KnownVulnsDependabotEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-knownvulnsdependabotev"></a>
### Evidence KnownVulnsDependabotEv: GitHub Dependabot automatically alerts on vulnerable gem dependencies and opens PRs with updated versions

Referenced by: **[Package ReuseSec](#package-reusesec)**

Supports: **[Claim KnownVulns](#claim-knownvulns)**

External Reference: [../.github/dependabot.yml](https://github.com/ossf/best-practices-badge/blob/main/docs/../.github/dependabot.yml)
<!-- end verocase -->

We configure GitHub Dependabot to automatically scan our gem dependencies
for known vulnerabilities and open pull requests with updated versions.
See [`.github/dependabot.yml`](.github/dependabot.yml).

<!-- verocase element KnownVulnsBundleEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-knownvulnsbundleev"></a>
### Evidence KnownVulnsBundleEv: bundle-audit checks all gem versions against the NVD on every rake run, detecting known CVEs in dependencies

Referenced by: **[Package ReuseSec](#package-reusesec)**

Supports: **[Claim KnownVulns](#claim-knownvulns)**

External Reference: [../Gemfile.lock](https://github.com/ossf/best-practices-badge/blob/main/docs/../Gemfile.lock)
<!-- end verocase -->

We run `bundle-audit` as part of every `rake` invocation. It compares
all gem versions in `Gemfile.lock` against the NVD and upstream advisory
databases, and fails the build if any known CVE is found.
See `Gemfile.lock` and `lib/tasks/default.rake`.

<!-- verocase element ActionCableSafe -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-actioncablesafe"></a>
### Claim ActionCableSafe: ActionCable information-exposure risk is mitigated because ActionCable is not used

Referenced by: **[Package ReuseSec](#package-reusesec)**

Supported by: **[Evidence ActionCableSafeEv](#evidence-actioncablesafeev)**

Supports: **[Claim SpecialAnalysis](#claim-specialanalysis)**
<!-- end verocase -->

ActionCable is a Rails subsystem for WebSocket-based real-time communication.
A potential vulnerability was identified: ActionCable logs cannot filter
sensitive data. However, we never configure or invoke ActionCable.
The `Gemfile` explicitly comments it out
(`# gem 'actioncable' # Not used. Client/server comm channel.`).
It appears in `Gemfile.lock` only as a transitive dependency of `rails`,
but no code paths in `app/` or `config/` ever reference it.
Since we never use ActionCable, no sensitive data ever flows through it.

<!-- verocase element ActionCableSafeEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-actioncablesafeev"></a>
### Evidence ActionCableSafeEv: ActionCable is a Rails transitive dependency but is never configured or invoked; no sensitive data flows through it

Referenced by: **[Package ReuseSec](#package-reusesec)**

Supports: **[Claim ActionCableSafe](#claim-actioncablesafe)**

External Reference: [../Gemfile.lock](https://github.com/ossf/best-practices-badge/blob/main/docs/../Gemfile.lock)
<!-- end verocase -->

See the [parent claim section](#claim-actioncablesafe) for details.

<!-- verocase element LocalSecretSafe -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-localsecretsafe"></a>
### Claim LocalSecretSafe: Checked-in tmp/local_secret.txt secret_key_base value poses no security risk

Referenced by: **[Package ReuseSec](#package-reusesec)**

Supported by: **[Evidence LocalSecretSafeEv](#evidence-localsecretsafeev)**

Supports: **[Claim SpecialAnalysis](#claim-specialanalysis)**
<!-- end verocase -->

The file `tmp/local_secret.txt` contains the value of `secret_key_base`
for development and test environments and is checked into the public
repository. This is intentional and safe: the value is only used in
development and test, where there are no real secrets to protect.
In production and staging we set the `SECRET_KEY_BASE` environment
variable, which takes precedence, and its value is never committed.
We check in this file to avoid a race condition in parallelized tests
(Rails recreates the file on demand, causing test failures when
multiple processes race to read it before it exists) and to make
development restarts smoother.

<!-- verocase element LocalSecretSafeEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-localsecretsafeev"></a>
### Evidence LocalSecretSafeEv: The file is only used in development and test; production always uses the SECRET_KEY_BASE environment variable; the checked-in value protects no real secrets

Referenced by: **[Package ReuseSec](#package-reusesec)**

Supports: **[Claim LocalSecretSafe](#claim-localsecretsafe)**

External Reference: [../tmp/local_secret.txt](https://github.com/ossf/best-practices-badge/blob/main/docs/../tmp/local_secret.txt)
<!-- end verocase -->

See the [parent claim section](#claim-localsecretsafe) for details.

<!-- verocase element ErubisSafe -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-erubissafe"></a>
### Claim ErubisSafe: XSS from erubis via pronto-rails_best_practices poses no production risk

Referenced by: **[Package ReuseSec](#package-reusesec)**

Supported by: **[Evidence ErubisSafeEv](#evidence-erubissafeev)**

Supports: **[Claim SpecialAnalysis](#claim-specialanalysis)**
<!-- end verocase -->

The `erubis` module was identified as potentially vulnerable to XSS,
introduced via `pronto-rails_best_practices`.
However, `rails_best_practices` and `pronto` are declared only in the
`development` and `test` groups in the `Gemfile` and are never bundled
into the production environment. They only process trusted developer
input, not untrusted user data, so this vulnerability has no production
impact.

<!-- verocase element ErubisSafeEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-erubissafeev"></a>
### Evidence ErubisSafeEv: rails_best_practices and pronto are dev/test-only dependencies; they never execute against untrusted input in production

Referenced by: **[Package ReuseSec](#package-reusesec)**

Supports: **[Claim ErubisSafe](#claim-erubissafe)**

External Reference: [../Gemfile](https://github.com/ossf/best-practices-badge/blob/main/docs/../Gemfile)
<!-- end verocase -->

See the [parent claim section](#claim-erubissafe) for details.

<!-- verocase element XXESafe -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="claim-xxesafe"></a>
### Claim XXESafe: Nokogiri/libxml2 XXE exception (CVE-2016-9318) poses no risk in our deployment

Referenced by: **[Package ReuseSec](#package-reusesec)**

Supported by: **[Evidence XXESafeEv](#evidence-xxesafeev)**

Supports: **[Claim SpecialAnalysis](#claim-specialanalysis)**
<!-- end verocase -->

Nokogiri (via rails-html-sanitizer → loofah) is used in production to
sanitize untrusted HTML. CVE-2016-9318 is an XXE vulnerability in
libxml2. However, Nokogiri 1.5.4 and later (which we use) disables DTD
loading and network access by default, rendering it immune to this CVE
unless an application explicitly opts into `DTDLOAD` and out of `NONET`.
We never process incoming XML from untrusted sources in production;
loofah processes HTML only and never sets `DTDLOAD` or clears `NONET`.
All other uses of nokogiri in `Gemfile.lock` (capybara, xpath, etc.)
are test-only, where all input is trusted.

<!-- verocase element XXESafeEv -->
<!-- DO NOT EDIT text from here until "end verocase" -->
<a id="evidence-xxesafeev"></a>
### Evidence XXESafeEv: Nokogiri disables DTD loading and network access by default; we never process incoming XML in production; loofah never opts into DTDLOAD or NONET

Referenced by: **[Package ReuseSec](#package-reusesec)**

Supports: **[Claim XXESafe](#claim-xxesafe)**

External Reference: [../Gemfile.lock](https://github.com/ossf/best-practices-badge/blob/main/docs/../Gemfile.lock)
<!-- end verocase -->

See the [parent claim section](#claim-xxesafe) for details.
