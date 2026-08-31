import { sql } from "~/db";

/**
 * BEEF — NCMEC CyberTipline flow (CSAM). Server-only.
 *
 * Legal requirement, live BEFORE launch: when a report flags CSAM
 * (`reports.is_csam = true`), BEEF must preserve evidence, disable the reported
 * account, and submit to the NCMEC CyberTipline. Submission is human-reviewed
 * and requires credentials the owner has not yet provided, so this module is a
 * STUB today:
 *
 *   - `preserveEvidence()` snapshots the offending content (message body, report
 *     reason, reported user id) into `report_evidence` with a sha256 hash for
 *     chain-of-custody, so the source being deleted can't destroy the evidence.
 *   - `disableAccountForCsam()` freezes the reported account (status
 *     'suspended') and its profile (moderation_status 'suspended') — out of the
 *     grid, not yet banned; a human makes the final call.
 *   - `submitNcmecReport()` LOGS + returns `transmitted: false`. It does NOT
 *     transmit. Replace it with the real CyberTipline API call pre-launch.
 *
 * TODO(pre-launch): integrate the real NCMEC CyberTipline submission
 * (https://report.cybertip.org) — human-reviewed, with an `ncmec_status`
 * transition pending_submission → submitted → acknowledged, and store the
 * CyberTipline report id in `reports.ncmec_report_id`. Requires owner-supplied
 * NCMEC credentials (not yet available).
 */

export interface NcmecSubmissionResult {
  reportId: string;
  transmitted: false;
  status: "pending_submission";
  note: string;
}

/** sha256 hex of a UTF-8 string (Web Crypto — no node:crypto dependency). */
async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export interface EvidenceSnapshot {
  messageBody?: string | null;
  reason?: string | null;
  reportedUserId?: string | null;
}

/**
 * Snapshot offending content into `report_evidence` so evidence survives even
 * if the source message/profile/photo is later deleted. Only text + a content
 * hash are stored here — never location.
 */
export async function preserveEvidence(reportId: string, evidence: EvidenceSnapshot): Promise<void> {
  const parts: { kind: string; payload: string }[] = [];
  if (evidence.messageBody) parts.push({ kind: "message_body", payload: evidence.messageBody });
  if (evidence.reason) parts.push({ kind: "report_reason", payload: evidence.reason });
  if (evidence.reportedUserId) parts.push({ kind: "reported_user_id", payload: evidence.reportedUserId });

  for (const part of parts) {
    const contentHash = await sha256Hex(part.payload);
    await sql()`INSERT INTO report_evidence (report_id, kind, content_hash, payload)
               VALUES (${reportId}, ${part.kind}, ${contentHash}, ${part.payload})`;
  }
}

/** Freeze the reported account (suspended, not banned) pending human/NCMEC review. */
export async function disableAccountForCsam(userId: string): Promise<void> {
  await sql()`UPDATE users SET status = 'suspended' WHERE id = ${userId}`;
  await sql()`UPDATE profiles SET moderation_status = 'suspended' WHERE user_id = ${userId}`;
}

/**
 * NCMEC CyberTipline submission STUB. Does NOT transmit — logs and returns a
 * pending status so the report is tracked but no data leaves the server until a
 * human wires + reviews the real integration (pre-launch TODO above).
 */
export async function submitNcmecReport(reportId: string): Promise<NcmecSubmissionResult> {
  // The report insert already set reports.ncmec_status = 'pending_submission'.
  console.log(
    `[ncmec] STUB: queued CyberTipline submission for report ${reportId} (no credentials — human review required before launch).`
  );
  return {
    reportId,
    transmitted: false,
    status: "pending_submission",
    note: "STUB — no transmission; wire the real CyberTipline integration pre-launch.",
  };
}
