# Reliability regression cases

This directory holds deterministic fault-injection contracts for failures that cannot be made repeatable by adding another public workflow. They are separate from the workflow, Lark channel, and production risk counts.

`R01` covers the actor-owned checkpoint recovery path behind the Lark `/init` silence found while verifying issue #3210. The local Orleans test injects one checkpoint append failure and forces durable credential resolution to yield before the same actor resumes streaming. Production passed on Ready `4c0596c7`, which contains the required fix: one fresh Lark `/init` produced exactly one reply and neither forbidden activation/publication exception appeared in the correlated log window.

Run `ruby scripts/validate_regression_cases.rb` before committing changes to this directory.
