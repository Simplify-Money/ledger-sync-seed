# ledger-sync

Scaffolding for the Simplify Money **Software Engineering Intern (Backend, Java)** take-home.

Read this file completely before you write any code. Then read
`fixtures/corpus-a.jsonl` — not all 500 lines, but enough of them that you stop
being surprised.

> **Do not open a pull request here.** Work in your own fork and submit by email.
> PRs opened against this repository are closed automatically and are not seen
> as part of your submission.

---

## What this service is for

Simplify Money tells a user where their money went. To do that, something has to
read the bank SMS and bank emails sitting on their phone and turn them into a
ledger the user can trust.

This repository is that something, half-finished, with a live incident open
against it.

---

## What you are being asked to do, exactly

**Input:** `fixtures/corpus-a.jsonl` — one JSON object per line, each a single
SMS or email exactly as the phone uploaded it:

```json
{"message_id":"m-00004-9c11ae","channel":"sms","sender":"AD-HDFCBK-S",
 "received_at":"2026-07-04T07:19:00+05:30","device_id":"dev-3f1a90c47b21",
 "body":"Rs.5 debited from a/c **4821 on 04-07-26 at 07:19 to UPI/WATER CAN. Avl Bal: Rs.92,213.10. Not you? Call 18002586161"}
```

**Output:** three JSON files, written by `report <dir>`.

### 1. `ledger.json` — one entry per real transaction

```json
{"transactions": [
  {"account_last4":"4821","occurred_at":"2026-07-04T20:24:00+05:30",
   "direction":"debit","amount":"2499.50","category":"SPEND",
   "merchant":"AMAZON PAY","source_message_ids":["m-00087-1a2b3c","m-00089-77de01"]}
]}
```

`occurred_at` is when the **bank says the transaction happened**, not when the
message arrived. `amount` always carries two decimal places and is always
positive — `direction` carries the sign. `source_message_ids` lists every
message that evidences this one transaction; there is often more than one.

### 2. `summary.json` — per-account totals

```json
{"accounts": {
  "4821": {"spend":"87068.38","income":"101340.83",
           "micro_count":52,"micro_total":"2357.51",
           "transferred_out":"25000.00","transferred_in":"6000.00"}
}}
```

### 3. `reconciliation.json` — anything your ledger cannot account for

```json
{"discrepancies": [
  {"account_last4":"4821","occurred_at":"...","amount":"...","note":"..."}
]}
```

We are not telling you how to find these, or whether there are any. Working out
what "cannot account for" means here, and what in the data lets you check it, is
part of the task.

---

## The four categories

Every transaction gets exactly one.

| Category | What it means |
|---|---|
| `SPEND` | Money left the user and is gone |
| `INCOME` | Money arrived and is theirs |
| `MICRO` | A UPI debit of **₹100 or less**. Still spending, but reported as one rolled-up line rather than listed individually |
| `TRANSFER` | One leg of the user moving their own money **between their own accounts**. Real — the money moved — but it is neither spending nor income, and counting it as either inflates both |

`micro_total` is the sum of `MICRO`. `spend` is the sum of `SPEND` and does
**not** include `MICRO` or `TRANSFER`. `income` likewise excludes `TRANSFER`.

---

## Your checkpoint

`fixtures/corpus-a-totals.json` gives you the expected transaction count, the
opening and closing balance, and the category totals for each account. No
row-level answers. Use it to check yourself.

If your numbers do not match it, **say so and say why.** A submission whose
numbers match because they were made to match is worse than one that does not
match and explains itself. We can tell the difference, and we check.

---

## Where the code is now

```
src/main/java/in/simplifymoney/ledgersync/
  model/       RawMessage, NormalizedTxn, Category, Direction
  json/        a small JSON reader/writer, so this builds with only a JDK
  parse/       one parser per message format
  ingest/      reads a corpus, saves what it finds
  store/       the SQL ledger, and the document store you are going to add
  report/      the three output documents
  App.java     migrate | ingest | report
  SelfCheck.java
```

Run it (needs a JDK, version 17 or newer — 17 and 21 both work; nothing else to install):

```bash
./verify.sh                      # compile + run the pipeline, no network needed
./gradlew test                   # the test suite (needs network once, for JUnit)
./gradlew run --args="migrate"
./gradlew run --args="ingest fixtures/corpus-a.jsonl"
./gradlew run --args="report submission/"
```

`./verify.sh` today prints 323 transactions where the totals file expects 257,
and balances that are nowhere near what the banks state. That is the starting
point, not a bug you have hit.

---

## What is missing, in the order we would do it

1. **`EmailParser` is a stub.** Every email in the corpus is currently dropped.
2. **`IciciSmsParser` reads one of the ICICI formats.** There is at least one
   more in the corpus, falling straight through.
3. **Nothing deduplicates.** `IngestService` saves one transaction per message.
   One transaction is not one message.
4. **Categories are decided from the direction alone.** No `MICRO`, no
   `TRANSFER`.
5. **`Reports.summary` adds up whatever it is given.** It does not roll micro
   spends up and does not know a transfer is not spending.
6. **`Reports.reconciliation` is not written.**
7. **`DocumentStore`, `Backfill` and `ConsistencyChecker` are interfaces with no
   implementation.** See below.
8. **`incident/INC-2026-09-11.md` is open.** Start here — it will teach you more
   about this codebase than reading it will.

---

## The document store

The ledger is moving off SQL onto a document store. **DynamoDB preferred,
MongoDB fine** — your choice, and say why. It must run from your
`docker compose up`.

`DocumentStore` declares the only three queries this service makes:

1. one account's transactions for one month, newest first
2. running totals per category for an account
3. given a message id, which transaction did it produce

Design your documents so the engine serves these directly. We are not going to
tell you what a document should look like — that decision is the exercise.

For each of the three, **report how many items the engine examined versus how
many it returned, at 100,000 transactions.** DynamoDB gives you `ScannedCount`
and `Count`; MongoDB gives you `totalDocsExamined` and `nReturned`. Put the six
numbers in your README.

Then:

- **`Backfill`** moves what is already in SQL across. Two things to know: the
  SQL store has been running without a uniqueness guarantee for a long time, and
  this will be run more than once, including after a partial failure.
- **`ConsistencyChecker`** proves the two stores agree and names precisely where
  they do not. We will run yours against a document store we have deliberately
  altered. It has to find what we changed. A checker that compares row counts
  will not.

---

## Rules

- `model/NormalizedTxn.java`, `model/Category.java` and
  `src/test/.../NormalizedTxnContractTest.java` are **frozen**. Do not edit
  them. Everything behind them is yours.
- Java. Any framework, or none — say why in your decision log.
- Real commit history. Not one squashed commit.
- If something in here is wrong or unclear, **email us**. Guessing when you
  could have asked is a worse signal than asking.

`talent.acquisition@simplifymoney.in`
