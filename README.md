# Aevatar workflow acceptance cases

Ten public-safe Aevatar workflow examples that exercise the same workflow primitives and Lark integration shapes as a private acceptance suite, using different practical business cases.

The committed YAML files contain placeholders rather than organization-specific Base, user, approval, or NyxID resource identifiers. They are templates: materialize them with your own Lark and NyxID resources before production preview or execution.

## Validation status

Validated on 2026-08-04:

- all 10 YAML files parse successfully;
- all step IDs are unique and every `next` / `switch` branch target exists;
- local external capability counts match production preview counts;
- all 14 configuration placeholders are declared and no organization-specific identifiers remain;
- the public step graphs and capability contracts were derived from configured private definitions by deterministic identifier normalization;
- all 10 configured definitions passed Aevatar mainnet `interactive` explicit-request preview through authenticated `nyxid` ingress;
- no workflow run, Base mutation, Lark approval creation, message send, or schedule was executed for this repository validation.

`interactive` preview proves parser and capability admission only. It is not runtime success evidence.

## Workflow matrix

| # | Workflow | Steps | Main features | Production preview | Side effects executed |
|---:|---|---:|---|---|---|
| 01 | `release_readiness_review` | 13 | `assign`, JSON parse/extract, two switches, parallel `foreach`, deterministic transforms | PASS, 0 external calls | None |
| 02 | `candidate_document_compliance_preview` | 3 | typed file ingress, parallel `foreach -> document_extract`, privacy-limited `llm_call` | PASS, 0 declared external calls | None |
| 03 | `email_access_approval_audit` | 5 | approval list GET, ID extraction, dynamic `foreach -> detail GET` | PASS, 2 GET/read-only | None |
| 04 | `saas_license_utilization_review` | 10 | six-source Base fan-in, deterministic utilization and cost aggregation | PASS, 6 GET/read-only | None |
| 05 | `asset_inventory_attestation` | 8 | input normalization, preview/submit switch, guarded Base record POST | PASS, 1 POST/write requiring approval | None |
| 06 | `project_shared_mailbox_approval` | 8 | Base record GET, approval payload, guarded approval POST, instance verification GET | PASS, 2 GET + 1 POST/write | None |
| 07 | `quarterly_access_review_reminder` | 8 | preview/submit switch, guarded Lark DM POST | PASS, 1 POST/write requiring approval | None |
| 08 | `saas_license_optimization_digest` | 21 | six Base reads, per-source normalization, fan-in digest, preview/confirmed send | PASS, 6 GET + 1 POST/write | None |
| 09 | `contractor_access_package_approval` | 23 | attachments, LLM classification, identity lookup, approval history, stable-key dedup, preview/submit, verification | PASS, 4 GET + 1 POST/write | None |
| 10 | `monthly_access_certification` | 28 | runtime period, month-end gate, Base aggregation, preview/approval/verification, reminder and completion notices | PASS, 2 GET + 3 POST/write | None |

## Per-workflow evidence

### 01 Release readiness review

Checks backup, monitoring, and rollback controls through deterministic primitives. It exercises explicit branch joins and a three-item parallel `foreach`. Local YAML/graph validation passed and production preview found no external capability call sites.

### 02 Candidate document compliance preview

Requires a typed attachment such as `fixtures/candidate-profile-sample.txt`. It extracts each file and asks the LLM for five boolean completeness checks without reproducing personal data. Local YAML/graph validation passed; production preview found no declared NyxID external call sites. Attachment ingress and runtime LLM output were not executed in this repository validation.

### 03 Email access approval audit

Lists one approval instance, extracts its ID, and fetches the detail through dynamic `foreach`. Local YAML/graph validation passed; production preview admitted two unique GET/read-only call sites with no approval requirement. No live GET was executed for this repository validation.

### 04 SaaS license utilization review

Reads four Base tables, the table catalog, and one view, then calculates seat utilization, monthly cost, and reduction candidates. The fixture contract expects 185 seats, 140 active users, USD 6,670 monthly cost, and one reduction candidate. Local validation passed; production preview admitted six unique GET/read-only call sites. No live GET was executed here.

### 05 Asset inventory attestation

Defaults to `{"submit":false}` and only reaches the Base POST for explicit `submit=true`. Local validation passed; production preview identified one POST/write call site requiring approval. The POST path was not executed.

### 06 Project shared mailbox approval

Reads a ready Base request, builds an email-access approval form, creates the instance after tool approval, and verifies the same instance. Local validation passed; production preview admitted two GET/read-only call sites and one POST/write call site requiring approval. No approval was created.

### 07 Quarterly access review reminder

Defaults to preview and sends a single Lark DM only for explicit `submit=true`. Local validation passed; production preview identified one POST/write call site requiring approval. No message was sent.

### 08 SaaS license optimization digest

Reads and normalizes six Base sources, builds a digest, previews it, or sends a Lark card after explicit confirmation. Local validation passed; production interactive preview admitted six GET/read-only call sites and one POST/write call site. Durable preview was rejected with `DURABLE_AUTHORIZATION_UNAVAILABLE`, so this workflow must not be advertised as a working recurring delivery schedule.

### 09 Contractor access package approval

Combines typed attachments, `document_extract`, LLM classification, Base-backed identity resolution, approval list/detail reads, stable request-key deduplication, preview, guarded creation, and verification. Local validation passed; production preview admitted four GET/read-only call sites and one POST/write call site. The exact Lark contact batch lookup was intentionally replaced because the acceptance bot lacked `contact:user.id:readonly`. No approval was created.

### 10 Monthly access certification

Parses mode/date/period, gates submit mode to the actual final day, aggregates monthly Base records, supports preview, creates and verifies an approval, and offers reminder/completion-message paths. Local validation passed; production interactive preview admitted two GET/read-only and three POST/write call sites. Durable preview was rejected with `NYXID_EXPLICIT_REQUEST_INTERACTIVE_REQUIRED`; automatic month-end approval and day-27 reminder schedules are not validated capabilities.

## Configure

Copy `config.example.yaml` to the ignored `config.local.yaml`, replace every value, and materialize configured definitions:

```bash
ruby scripts/materialize_workflows.rb config.local.yaml
```

The output defaults to `build/workflows/`. Required placeholders cover:

- NyxID Lark `UserService` identity;
- Base app token, six table IDs, and the shared-mailbox record ID;
- approval definition code and its textarea/link widget IDs;
- approval submitter and message recipient Lark user IDs.

The Base field and record contract is documented in `fixtures/base-records.example.yaml`. Case 04 intentionally asserts six tables, one SaaS view, and the supplied three-row totals.

## Validate

Run the public template validator:

```bash
ruby scripts/validate_workflows.rb
```

For production capability preview, use only an authenticated NyxID CLI and pass a configured YAML through stdin JSON to:

```text
nyxid proxy request aevatar \
  /api/scopes/{scopeId}/workflows:explicit-request-preview \
  --method POST \
  --header Content-Type:application/json \
  --data - \
  --output json
```

Use a distinct `workflowId` and `revisionId` for each preview. Preview never authorizes treating `202 Accepted`, pending tool approval, or model prose as workflow completion.

The redacted machine-readable preview summary is in `validation/production-preview-2026-08-04.json`.

## Safety boundaries

- Preview first. Mutation paths require explicit user intent and platform tool approval.
- Platform tool approval is not Lark business approval; a newly created approval normally remains `PENDING`.
- Do not schedule workflows 08 or 10 until their durable authorization failures are resolved.
- Do not commit `config.local.yaml`, tokens, credentials, tenant identifiers, business records, approval form contents, or run evidence.
- Runtime and Lark Bot end-to-end execution are deliberately not claimed by this repository validation.

## License

MIT
