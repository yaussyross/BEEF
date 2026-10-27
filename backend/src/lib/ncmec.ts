import { sql } from "~/db";

/**
 * Restricted evidence helpers and a NONTRANSMITTING external-reporting stub.
 * Report intake atomically preserves evidence and contains identified messages
 * through migration 0011. An accusation does not suspend an account. Ross is
 * the intended human reviewer; specialized access, decisions and escalation
 * procedures remain unspecified. This module grants none and sends no reports.
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
