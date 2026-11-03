# Research summary (Part 1, condensed)

This is the concise record of the Part 1 research. It is a summary,
not a substitute for reading the papers. No finding below is presented
as PlacementPulse's own result.

## Verified sources

### Information extraction

- **Sarawagi, S. (2008). "Information Extraction."** Foundations and
  Trends in Databases, 1(3), 261–377. DOI: 10.1561/1500000003.
  Survey defining extraction as turning unstructured sources into
  structured entities, relationships, and attributes, and providing
  the field-level evaluation frame (correct / incorrect / missing /
  uncertain) used for M2.
- **Califf, M. E., & Mooney, R. J. (1999). "Relational Learning of
  Pattern-Match Rules for Information Extraction."** Proceedings of
  the AAAI Conference on Artificial Intelligence, 16, 328–334.
  RAPIER: pattern-match rules that directly extract slot fillers from
  documents. PlacementPulse uses the hand-written, deterministic
  version of that idea — one visible rule per slot, with a visible
  failure mode.
- **Soderland, S. (1999). "Learning Information Extraction Rules for
  Semi-Structured and Free Text."** Machine Learning, 34(1–3),
  233–272. DOI: 10.1023/A:1007562322031. WHISK: rules for text ranging
  from highly structured to free text, including text that is neither
  rigidly formatted nor grammatical. Placement notices sit in exactly
  that middle ground, which is why the parser pairs regexes with
  explicit uncertainty flags.

### Reminders and prospective memory

- **Gurol-Urganci, I., de Jongh, T., Vodopivec-Jamsek, V., Atun, R.,
  & Car, J. (2013). "Mobile phone messaging reminders for attendance
  at healthcare appointments."** Cochrane Database of Systematic
  Reviews, 2013(12), CD007458. DOI: 10.1002/14651858.CD007458.pub3.
  Attendance 67.8% (no reminder) vs 78.6% (mobile messaging), low to
  moderate quality evidence. Healthcare appointments, not placements.
- **Robotham, D., Satkunanathan, S., Reynolds, J., Stahl, D., &
  Wykes, T. (2016). "Using digital notifications to improve attendance
  in clinic: systematic review and meta-analysis."** BMJ Open, 6(10),
  e012116. DOI: 10.1136/bmjopen-2016-012116. Notified patients 23%
  more likely to attend and 25% less likely to no-show; multiple
  notifications were significantly more effective than single ones.
  This motivates the two-reminder design (24h and 2h). Healthcare
  clinics, not placements.
- **Black, L. D., & McBride, D. M. (2024). "Effects of delay and
  reminders on time-based prospective memory in a naturalistic
  task."** Memory, 32(7), 947–957. DOI: 10.1080/09658211.2024.2371615.
  Performance fell as delay grew from 1 day to several days; explicit
  reminders significantly improved time-based prospective-memory
  performance over implicit ones. Lesson: reminders must name the
  action, company, and exact deadline.
- **Tsai, P.-C., & Gilbert, S. J. (2025). "Strategic reminder setting
  for time-based intentions: Influence of metacognition, delay length,
  and cue visibility."** Memory & Cognition, 53(7), 2237–2254.
  DOI: 10.3758/s13421-025-01708-x. Reminder use improved accuracy and
  was more likely at longer delays — the placement case, where a
  notice is often seen weeks before its deadline.

## What was not found

No peer-reviewed evaluation of a campus placement portal combining
deterministic notice parsing, human review, explained eligibility,
and timed reminders — meeting the verification bar — was found during
Part 1. Commercial placement products exist and describe eligibility
filtering, but product pages are not research evidence and are not
cited as such. Recent placement-system papers found were descriptive
system builds without a controlled evaluation of parser accuracy or
missed deadlines.

## The gap, as a hypothesis

Coordinators send long notices by email, and students must re-read
each one to judge eligibility. Existing portals mainly list drives or
filter by stored criteria; they rarely start from pasted notice text.
No verified source evaluated a human-reviewed, deterministic parser
for campus notices, and reminder evidence comes mostly from healthcare
appointments, not placement registration deadlines. **Hypothesis:**
combining reviewed parsing, explained eligibility, and two timed
reminders will reduce missed deadlines. That hypothesis is unverified
until the 15-person survey, the timing study (M1), and the pilot (M6)
are actually run. Healthcare reminder evidence does **not** prove a
placement effect, and nothing in this repository claims otherwise.
