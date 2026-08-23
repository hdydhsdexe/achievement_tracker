"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const importerPath = path.join(root, "tools", "save_importer", "save-importer.js");

const {
  parsePersistentGameData,
  inferPersistentSaveSlot,
  inferModSaveSlot,
  mergeModSaveData,
  mergeModSaveJson,
  LIMITS,
} = require(importerPath);

const MAGIC = "ISAACNGSAVE09R  ";

function makeSave(options = {}) {
  const magic = options.magic ?? MAGIC;
  const blockType = options.blockType ?? 1;
  const achievementBytes = options.achievementBytes ?? [1, 1, 0, 1, 0];
  const blockSize = options.blockSize ?? achievementBytes.length;
  const achievementCount = options.achievementCount ?? achievementBytes.length;
  const actualDataSize = options.actualDataSize ?? blockSize;
  const includeEventBlock = options.includeEventBlock ?? options.actualDataSize == null;
  const eventCounters = options.eventCounters ?? new Array(options.eventCounterCount ?? 496).fill(0);
  const eventCounterCount = options.eventCounterCount ?? eventCounters.length;
  const eventBlockSize = options.eventBlockSize ?? eventCounterCount * 4;
  const eventActualDataSize = options.eventActualDataSize ?? eventBlockSize;
  const eventBytes = includeEventBlock ? 12 + eventActualDataSize : 0;
  const buffer = new ArrayBuffer(0x20 + actualDataSize + eventBytes);
  const bytes = new Uint8Array(buffer);
  const view = new DataView(buffer);

  for (let index = 0; index < Math.min(16, magic.length); index += 1) {
    bytes[index] = magic.charCodeAt(index);
  }
  view.setUint32(0x10, 0x12345678, true);
  view.setUint32(0x14, blockType, true);
  view.setUint32(0x18, blockSize, true);
  view.setUint32(0x1c, achievementCount, true);
  bytes.set(achievementBytes.slice(0, actualDataSize), 0x20);
  if (includeEventBlock) {
    const eventHeaderOffset = 0x20 + actualDataSize;
    view.setUint32(eventHeaderOffset, options.eventBlockType ?? 2, true);
    view.setUint32(eventHeaderOffset + 4, eventBlockSize, true);
    view.setUint32(eventHeaderOffset + 8, eventCounterCount, true);
    for (let eventId = 0; eventId < Math.min(eventCounters.length, Math.floor(eventActualDataSize / 4)); eventId += 1) {
      view.setUint32(eventHeaderOffset + 12 + eventId * 4, eventCounters[eventId], true);
    }
  }
  return buffer;
}

function snapshot(options = {}) {
  const eventCounters = options.eventCounters ?? [0, 29, 7];
  return {
    saveSlot: options.saveSlot ?? 1,
    achievementCount: options.achievementCount ?? 3,
    unlockedIds: options.unlockedIds ?? [],
    eventCounterCount: options.eventCounterCount ?? eventCounters.length,
    eventCounters,
  };
}

test("parses the SAVE09R achievement block as little-endian bytes", () => {
  const parsed = parsePersistentGameData(makeSave());

  assert.equal(parsed.achievementCount, 5);
  assert.deepEqual(parsed.unlockedIds, [1, 3]);
  assert.equal(parsed.eventCounterCount, 496);
  assert.equal(parsed.eventCounters.length, 496);
});

test("parses Repentance and Repentance+ event counter blocks", () => {
  for (const count of [496, 523]) {
    const values = Array.from({ length: count }, (_, id) => id === count - 1 ? 0xffffffff : id);
    const parsed = parsePersistentGameData(makeSave({ eventCounters: values }));
    assert.equal(parsed.eventCounterCount, count);
    assert.deepEqual(parsed.eventCounters, values);
  }
});

test("rejects missing, mistyped, truncated, and inconsistent event counter blocks", () => {
  assert.throws(() => parsePersistentGameData(makeSave({ includeEventBlock: false })), /event counter|truncated/i);
  assert.throws(() => parsePersistentGameData(makeSave({ eventBlockType: 3 })), /event counter|block type/i);
  assert.throws(() => parsePersistentGameData(makeSave({ eventCounterCount: 496, eventBlockSize: 8 })), /event counter|size|count/i);
  assert.throws(() => parsePersistentGameData(makeSave({ eventCounterCount: 496, eventActualDataSize: 4 })), /event counter|truncated/i);
  assert.throws(() => parsePersistentGameData(makeSave({ eventCounterCount: LIMITS.maxEventCounterCount + 1 })), /event counter|size|count/i);
});

test("never treats achievement byte index zero as an achievement", () => {
  const parsed = parsePersistentGameData(makeSave({ achievementBytes: [1, 0, 0] }));

  assert.deepEqual(parsed.unlockedIds, []);
});

test("rejects an invalid SAVE09R magic", () => {
  assert.throws(
    () => parsePersistentGameData(makeSave({ magic: "NOT_AN_ISAAC_DAT" })),
    /SAVE09R|magic/i,
  );
});

test("requires the first block to be the achievement block", () => {
  assert.throws(
    () => parsePersistentGameData(makeSave({ blockType: 2 })),
    /achievement block|block type/i,
  );
});

test("rejects truncated blocks before reading achievement bytes", () => {
  assert.throws(
    () => parsePersistentGameData(makeSave({ blockSize: 6, achievementCount: 5, actualDataSize: 4 })),
    /truncated|block size/i,
  );
});

test("rejects achievement counts larger than the containing block", () => {
  assert.throws(
    () => parsePersistentGameData(makeSave({ blockSize: 4, achievementCount: 5 })),
    /count|block size/i,
  );
});

test("rejects empty and implausibly large achievement blocks", () => {
  assert.throws(
    () => parsePersistentGameData(makeSave({ blockSize: 0, achievementCount: 0 })),
    /block size|count/i,
  );

  const header = makeSave({ blockSize: 1, achievementCount: 1 });
  new DataView(header).setUint32(0x18, 0xffffffff, true);
  assert.throws(() => parsePersistentGameData(header), /block size|truncated/i);
});

test("caps persistent files, achievement counts, and existing Mod JSON", () => {
  assert.throws(
    () => parsePersistentGameData(new ArrayBuffer(LIMITS.maxPersistentFileBytes + 1)),
    /too large|size/i,
  );
  assert.throws(
    () => parsePersistentGameData(makeSave({
      blockSize: LIMITS.maxAchievementCount + 1,
      achievementCount: LIMITS.maxAchievementCount + 1,
      actualDataSize: LIMITS.maxAchievementCount + 1,
      achievementBytes: new Array(LIMITS.maxAchievementCount + 1).fill(0),
    })),
    /achievement count/i,
  );
  assert.throws(
    () => mergeModSaveJson(`{"padding":"${"x".repeat(LIMITS.maxModSaveJsonChars)}"}`, snapshot({
      saveSlot: 1,
      achievementCount: 2,
      unlockedIds: [],
    })),
    /too large|size/i,
  );
  assert.throws(
    () => mergeModSaveData(null, snapshot({
      saveSlot: 1,
      achievementCount: LIMITS.maxAchievementCount + 1,
      unlockedIds: [],
    })),
    /achievement count/i,
  );
  assert.throws(
    () => mergeModSaveData(null, snapshot({
      saveSlot: 1,
      achievementCount: LIMITS.maxAchievementCount,
      unlockedIds: new Array(LIMITS.maxAchievementCount).fill(1),
    })),
    /achievement IDs|too many/i,
  );
});

test("infers persistent save slots from local, Steam Cloud, and dated backup names", () => {
  assert.equal(inferPersistentSaveSlot("persistentgamedata1.dat"), 1);
  assert.equal(inferPersistentSaveSlot("rep_persistentgamedata2.dat"), 2);
  assert.equal(inferPersistentSaveSlot("20260815.rep_persistentgamedata3.dat"), 3);
  assert.equal(inferPersistentSaveSlot("rep+persistentgamedata2.dat"), 2);
  assert.equal(inferPersistentSaveSlot("20260815.rep+persistentgamedata3.dat"), 3);
  assert.equal(inferPersistentSaveSlot("20260815.REP_PERSISTENTGAMEDATA1.DAT"), 1);
  assert.equal(inferPersistentSaveSlot("persistentgamedata4.dat"), null);
  assert.equal(inferPersistentSaveSlot("backup.dat"), null);
});

test("infers Mod save slots only from save1.dat through save3.dat", () => {
  assert.equal(inferModSaveSlot("save1.dat"), 1);
  assert.equal(inferModSaveSlot("20260815-save3.dat"), 3);
  assert.equal(inferModSaveSlot("save0.dat"), null);
  assert.equal(inferModSaveSlot("persistentgamedata2.dat"), null);
});

test("merges an import snapshot while preserving existing Mod fields", () => {
  const existing = {
    schemaVersion: 3,
    language: "zh",
    tracked: ["achievement_326"],
    observedCompleted: { achievement_326: true },
    manuallyCompleted: { achievement_10: true },
    progressImport: { formatVersion: 1, saveSlot: 2, eventCounterCount: 1, values: [99] },
    progressObserved: { eventCounters: { "3": 12 } },
  };

  const merged = mergeModSaveData(existing, snapshot({
    saveSlot: 2,
    achievementCount: 6,
    unlockedIds: [5, 1, 5, 3],
  }));

  assert.equal(merged.schemaVersion, 10);
  assert.deepEqual(merged.achievementImport.unlockedIds, [1, 3, 5]);
  assert.deepEqual(merged.progressImport.values, [0, 29, 7]);
  assert.equal(merged.progressImport.saveSlot, 2);
  assert.match(merged.progressImport.importedAt, /^\d{4}-\d{2}-\d{2}T/);
  assert.deepEqual(merged.progressObserved, { eventCounters: {} });
  assert.notEqual(merged, existing);
});

test("creates a minimal schema v10 Mod save when no existing JSON is supplied", () => {
  const merged = mergeModSaveData(null, snapshot({
    saveSlot: 1,
    achievementCount: 3,
    unlockedIds: [2],
  }));

  assert.equal(merged.schemaVersion, 10);
  assert.deepEqual(merged.achievementImport.unlockedIds, [2]);
  assert.deepEqual(merged.progressImport.values, [0, 29, 7]);
  assert.deepEqual(merged.progressObserved, { eventCounters: {} });
});

test("validates imported slots, counts, and achievement IDs", () => {
  assert.throws(
    () => mergeModSaveData(null, snapshot({ saveSlot: 4, achievementCount: 3, unlockedIds: [] })),
    /save slot/i,
  );
  assert.throws(
    () => mergeModSaveData(null, snapshot({ saveSlot: 1, achievementCount: 0, unlockedIds: [] })),
    /achievement count/i,
  );
  assert.throws(
    () => mergeModSaveData(null, snapshot({ saveSlot: 1, achievementCount: 3, unlockedIds: [4] })),
    /achievement id/i,
  );
  assert.throws(
    () => mergeModSaveData(null, snapshot({ eventCounterCount: 2, eventCounters: [1] })),
    /event counter array|continuous|count/i,
  );
  assert.throws(
    () => mergeModSaveData(null, snapshot({ eventCounters: [0, -1, 2] })),
    /event counter/i,
  );
});

test("parses optional existing JSON and returns stable pretty JSON", () => {
  const result = mergeModSaveJson('{"language":"en","schemaVersion":3}', snapshot({
    saveSlot: 3,
    achievementCount: 4,
    unlockedIds: [3, 1],
  }), {
    existingFileName: "save3.dat",
  });

  assert.equal(result.fileName, "save3.dat");
  assert.equal(result.json.endsWith("\n"), true);
  const parsed = JSON.parse(result.json);
  assert.equal(parsed.language, "en");
  assert.equal(parsed.schemaVersion, 10);
  assert.deepEqual(parsed.achievementImport.unlockedIds, [1, 3]);
  assert.deepEqual(parsed.progressImport.values, [0, 29, 7]);
});

test("rejects malformed or non-object existing Mod JSON", () => {
  assert.throws(
    () => mergeModSaveJson("{broken", snapshot({ saveSlot: 1, achievementCount: 2, unlockedIds: [] })),
    /JSON/i,
  );
  assert.throws(
    () => mergeModSaveJson("[]", snapshot({ saveSlot: 1, achievementCount: 2, unlockedIds: [] })),
    /JSON object/i,
  );
});

test("rejects slot conflicts from the Mod filename or its prior import", () => {
  const imported = snapshot({ saveSlot: 1, achievementCount: 2, unlockedIds: [1] });

  assert.throws(
    () => mergeModSaveJson("{}", imported, { existingFileName: "save2.dat" }),
    /slot.*conflict/i,
  );
  assert.throws(
    () => mergeModSaveJson('{"achievementImport":{"saveSlot":3}}', imported),
    /slot.*conflict/i,
  );
  assert.throws(
    () => mergeModSaveJson('{"progressImport":{"saveSlot":3}}', imported),
    /slot.*conflict/i,
  );
});

test("rejects an existing Mod file whose slot cannot be proven from its filename", () => {
  assert.throws(
    () => mergeModSaveJson("{}", snapshot({
      saveSlot: 1,
      achievementCount: 2,
      unlockedIds: [1],
    }), {
      existingFileName: "achievement-tracker-backup.dat",
    }),
    /Mod filename|slot/i,
  );
});

test("the browser UI is local-only and communicates the safe replacement flow", () => {
  const html = fs.readFileSync(path.join(root, "tools", "save_importer", "index.html"), "utf8");

  assert.match(html, /type="file"/);
  assert.match(html, /save-importer\.js/);
  assert.match(html, /arrayBuffer\(\)/);
  assert.match(html, /gameFile\.size\s*>\s*IsaacSaveImporter\.LIMITS\.maxPersistentFileBytes/);
  assert.match(html, /modFile\.size\s*>\s*IsaacSaveImporter\.LIMITS\.maxModSaveJsonChars/);
  assert.match(html, /URL\.createObjectURL/);
  assert.doesNotMatch(html, /fetch\s*\(|XMLHttpRequest|<form[^>]+action=/i);
  assert.match(html, /关闭游戏/);
  assert.match(html, /备份/);
  assert.match(html, /不会上传/);
  assert.match(html, /rep_persistentgamedataN\.dat/);
  assert.match(html, /rep\+persistentgamedataN\.dat/);
});
