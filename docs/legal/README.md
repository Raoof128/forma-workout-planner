# Legal documents

[Back to README](../../README.md)

FORMA's **Privacy Policy** and **Terms of Use** are shown in the app at
`#privacy` and `#terms` (for example
[forma.raoufabedini.dev/#privacy](https://forma.raoufabedini.dev/#privacy)).
Their text lives in one place, [`src/legal/content.js`](../../src/legal/content.js),
so the app and this record cannot drift apart.

| Document       | Version | Effective       | Operator                                | Contact             |
| -------------- | ------- | --------------- | --------------------------------------- | ------------------- |
| Privacy Policy | 1.3     | 17 October 2026 | Raouf Abedini (individual), Sydney, NSW | raoof.r12@gmail.com |
| Terms of Use   | 1.0     | 13 October 2026 | Raouf Abedini (individual), Sydney, NSW | raoof.r12@gmail.com |

**These documents were drafted from official guidance and are not legal
advice.** Have an Australian lawyer review them before FORMA opens accounts to
the public or is used commercially.

## How they are presented

- Linked from every page (sidebar footer) and from the sign-up form.
- Sign-up requires two separate checkboxes: (1) age (16+, or 13–15 with a
  parent or guardian's permission) and agreement to the Terms with
  acknowledgement of the Privacy Policy; (2) express consent to storing workout
  records that may include health-related information (APP 3.3).
- A short APP 5 collection notice sits on the sign-up form.
- `tests/legal.spec.js` checks the pages are reachable, contain the required
  sections, pass an axe WCAG 2.2 AA scan and fit a 360 px screen.

## Design decisions and why

| Decision                                                                                                    | Basis                                                                                                                                                                                                     |
| ----------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Follow the Australian Privacy Principles even if the small business exemption may apply                     | Fitness data may be health information, and providing a health service removes the exemption (Privacy Act s 6D(4), s 6FB; OAIC APP Guidelines B.78, B.81). The statutory privacy tort applies regardless. |
| Name overseas countries (United States; Cloudflare's global network)                                        | APP 1.4(f)–(g) and APP 8; Cloudflare and DigitalOcean are US companies and Cloudflare processes globally.                                                                                                 |
| Separate express consent for workout data                                                                   | Health information is sensitive information; APP 3.3 requires consent and the OAIC prefers express consent.                                                                                               |
| No "supply again" liability cap                                                                             | ACL s 64A only allows that cap for services not ordinarily acquired for personal use; a personal workout planner is such a service, so the cap would be void.                                             |
| ACL savings clause; no "as is" exclusion without it; 14 days' notice of changes; reasons before termination | ACL s 64 voids exclusions of consumer guarantees; the unfair contract terms regime (strengthened 9 November 2023) targets one-sided variation and termination terms (ACL ss 23–25).                       |
| Not directed at the EU or UK                                                                                | GDPR Art 3(2) applies on targeting, and the EDPB says mere accessibility is not targeting; member rights are honoured anyway.                                                                             |
| Accounts 16+, 13–15 with permission, none under 13                                                          | No general statutory minimum; FORMA is not an age-restricted social media platform (Online Safety Act s 63C); keeps clear of the forthcoming Children's Online Privacy Code.                              |
| Plain language, layered summary, version and date                                                           | OAIC Guide to developing an APP privacy policy.                                                                                                                                                           |

## Commitments the operator must keep

The documents make promises; the service and the operator must match them.

- Respond to access, correction and complaint requests within 30 days, and
  acknowledge complaints within 7 days.
- Delete backup copies within **35 days**, and store backups only in Australia
  or the United States. Backups are not yet configured; configure them to
  match.
- Give account holders **14 days' notice** of material changes to the terms,
  and notice before significant privacy policy changes.
- Notify affected people (and the OAIC where required) of a breach likely to
  cause serious harm.
- Reasonable notice before discontinuing account mode so members can export.
- Keep the email address in `src/legal/content.js` monitored.

## Review triggers

Review both documents at least yearly and when any of these happen:

- Accounts open to the public, or FORMA starts charging, advertising or using
  analytics.
- A new service provider, backup location or country.
- 10 December 2026: automated decision-making transparency requirements (APP
  1.7–1.9) commence, and the Children's Online Privacy Code is due to be
  registered. FORMA does not use automated decision-making today.
- Changes to the Privacy Act, Australian Consumer Law or OAIC guidance.

## Sources

All accessed 13 October 2026.

- Privacy Act 1988 (Cth), ss 6C, 6D, 6EA, 6FA, 6FB — [legislation.gov.au](https://www.legislation.gov.au/C2004A03712/latest/text)
- OAIC, Australian Privacy Principles guidelines: [Chapter B key concepts](https://www.oaic.gov.au/privacy/australian-privacy-principles/australian-privacy-principles-guidelines/chapter-b-key-concepts), [APP 1](https://www.oaic.gov.au/privacy/australian-privacy-principles/australian-privacy-principles-guidelines/chapter-1-app-1-open-and-transparent-management-of-personal-information), [APP 3](https://www.oaic.gov.au/privacy/australian-privacy-principles/australian-privacy-principles-guidelines/chapter-3-app-3-collection-of-solicited-personal-information), [APP 5](https://www.oaic.gov.au/privacy/australian-privacy-principles/australian-privacy-principles-guidelines/chapter-5-app-5-notification-of-the-collection-of-personal-information), [APP 8](https://www.oaic.gov.au/privacy/australian-privacy-principles/australian-privacy-principles-guidelines/chapter-8-app-8-cross-border-disclosure-of-personal-information), [APP 11](https://www.oaic.gov.au/privacy/australian-privacy-principles/australian-privacy-principles-guidelines/chapter-11-app-11-security-of-personal-information), [APP 12](https://www.oaic.gov.au/privacy/australian-privacy-principles/australian-privacy-principles-guidelines/chapter-12-app-12-access-to-personal-information), [APP 13](https://www.oaic.gov.au/privacy/australian-privacy-principles/australian-privacy-principles-guidelines/chapter-13-app-13-correction-of-personal-information)
- OAIC, [Guide to developing an APP privacy policy](https://www.oaic.gov.au/privacy/privacy-guidance-for-organisations-and-government-agencies/more-guidance/guide-to-developing-an-app-privacy-policy); [Small business](https://www.oaic.gov.au/privacy/privacy-guidance-for-organisations-and-government-agencies/organisations/small-business); [Notifiable data breaches](https://www.oaic.gov.au/privacy/your-privacy-rights/data-breaches/what-is-a-notifiable-data-breach); [Complaints](https://www.oaic.gov.au/privacy/privacy-complaints/complain-to-an-organisation-or-agency); [Statutory tort](https://www.oaic.gov.au/privacy/your-privacy-rights/more-privacy-rights/statutory-tort-for-serious-invasions-of-privacy); [Children's Online Privacy Code](https://www.oaic.gov.au/privacy/privacy-for-kids/privacy-for-kids-childrens-online-privacy-code)
- Privacy and Other Legislation Amendment Act 2024 — [legislation.gov.au](https://www.legislation.gov.au/C2024A00128/asmade/text)
- Competition and Consumer Act 2010, Schedule 2 (Australian Consumer Law) ss 3, 23–25, 60–64A, and s 139A — [legislation.gov.au](https://www.legislation.gov.au/C2004A00109/latest/text)
- ACCC, [unfair contract terms penalties](https://www.accc.gov.au/media-release/accc-welcomes-new-penalties-and-expansion-of-the-unfair-contract-terms-laws)
- Online Safety Amendment (Social Media Minimum Age) Act 2024, s 63C — [legislation.gov.au](https://www.legislation.gov.au/C2024A00127/asmade/text); [eSafety](https://www.esafety.gov.au/about-us/industry-regulation/social-media-age-restrictions)
- GDPR [Art 3](https://gdpr-info.eu/art-3-gdpr/) and [Art 9](https://gdpr-info.eu/art-9-gdpr/); EDPB [Guidelines 3/2018 on territorial scope](https://www.edpb.europa.eu/sites/default/files/files/file1/edpb_guidelines_3_2018_territorial_scope_after_public_consultation_en_1.pdf); ICO, [who the UK GDPR applies to](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/personal-information-what-is-it/who-does-the-uk-gdpr-apply-to/)
- Cloudflare [Customer DPA](https://www.cloudflare.com/cloudflare-customer-dpa/) and [Privacy Policy](https://www.cloudflare.com/privacypolicy/); DigitalOcean [DPA](https://www.digitalocean.com/legal/data-processing-agreement) and [regional availability](https://docs.digitalocean.com/platform/regional-availability/)

Points that could not be verified from primary sources are recorded as open in
the research notes: whether a self-service workout planner is a "health
service", whether a free hobby app is supplied "in trade or commerce", and the
final status of the Children's Online Privacy Code.
