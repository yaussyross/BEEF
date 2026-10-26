import { expect, mock, test } from "bun:test";

let results: unknown[][] = [];
mock.module("../src/db", () => ({
  sql: () => async () => {
    const result = results.shift();
    if (!result) throw new Error("Unexpected database query");
    return result;
  },
}));
const { sendMessage } = await import("../src/lib/chat");

function duplicate(storedThread: string) {
  results = [
    [{ id: "current-thread", participant_low: "sender", participant_high: "recipient" }],
    [], // participation path: no block
    [], // send path: no block
    [], // duplicate insert
    [{ id: "stored-message", thread_id: storedThread, sender_id: "sender", body: "private original" }],
  ];
  return sendMessage("sender", {
    threadId: "current-thread", clientMessageId: "reused-id", body: "hello",
  });
}

test("same-conversation retry returns the original message", async () => {
  const result = await duplicate("current-thread");
  expect(result.created).toBe(false);
  expect(result.message.body).toBe("private original");
  expect(result.recipientId).toBe("recipient");
  expect(results).toHaveLength(0);
});

test("cross-conversation reuse cannot deliver private history to a new recipient", async () => {
  await expect(duplicate("different-thread")).rejects.toMatchObject({
    status: 409, code: "client_message_id_conflict",
  });
  expect(results).toHaveLength(0);
});
