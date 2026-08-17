# Stage 02: Converse and Record

## Job

Understand the user's experience well enough to create a feedback record they
recognize as accurate.

## Inputs

- Layer 4 (working): the complete conversation and stage 1 working notes.
- Layer 3 (reference): templates under `../../feedback/`.
- Layer 3 (reference): relevant existing records under `../../feedback/`.

## Process

1. Let the user's language lead. Separate what they observed, what they wanted,
   and any implementation they suggested.
2. Ask one to three focused questions at a time. Explore only gaps that affect
   understanding: the user's goal, current behavior, expected outcome, impact,
   circumstances, evidence, and important constraints.
3. Reflect uncertainty explicitly. Do not diagnose a bug or promise a feature
   during the conversation.
4. Search existing feedback for the same need or observation. Add evidence to a
   related record when that preserves the user's distinct context; otherwise
   prepare a new record.
5. Summarize the feedback in plain language, including the desired outcome and
   unresolved questions. Ask the user to confirm or correct the summary.
6. After confirmation, create or update the appropriate feedback record:
   `feature-requests/` for a desired capability, `issue-reports/` for observed
   unexpected behavior, or `general/` when neither classification is justified.

Keep quotations or close paraphrases under **User account**. Put agent analysis
under **Workbench interpretation**. Never rewrite an inference as something the
user said.

## Review Gate

The user must confirm or correct the summary before the record is finalized and
before stage 3 begins.

## Output

- One confirmed record under `../../feedback/`, or an evidence update to an
  existing record.
- The path to that record carried into stage 3.
