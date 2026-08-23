(function (root, factory) {
  "use strict";

  const api = factory();
  if (typeof module === "object" && module.exports) {
    module.exports = api;
  } else {
    root.IsaacSaveImporter = api;
  }
}(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";

  const MAGIC = "ISAACNGSAVE09R  ";
  const HEADER_SIZE = 0x20;
  const ACHIEVEMENT_BLOCK_TYPE = 1;
  const MAX_BLOCK_SIZE = 1024 * 1024;
  const LIMITS = Object.freeze({
    maxPersistentFileBytes: 8 * 1024 * 1024,
    maxModSaveJsonChars: 2 * 1024 * 1024,
    maxAchievementCount: 16384,
  });

  function asBytes(input) {
    if (input instanceof ArrayBuffer) {
      return new Uint8Array(input);
    }
    if (ArrayBuffer.isView(input)) {
      return new Uint8Array(input.buffer, input.byteOffset, input.byteLength);
    }
    throw new TypeError("Save data must be an ArrayBuffer or typed array.");
  }

  function readMagic(bytes) {
    let result = "";
    for (let index = 0; index < MAGIC.length; index += 1) {
      result += String.fromCharCode(bytes[index]);
    }
    return result;
  }

  function parsePersistentGameData(input) {
    const bytes = asBytes(input);
    if (bytes.byteLength > LIMITS.maxPersistentFileBytes) {
      throw new Error("Save file is too large to import safely.");
    }
    if (bytes.byteLength < HEADER_SIZE) {
      throw new Error("Save file is truncated before the SAVE09R header.");
    }
    if (readMagic(bytes) !== MAGIC) {
      throw new Error("Invalid SAVE09R magic. Select a Repentance or Repentance+ persistent save.");
    }

    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    const blockType = view.getUint32(0x14, true);
    const blockSize = view.getUint32(0x18, true);
    const achievementCount = view.getUint32(0x1c, true);

    if (blockType !== ACHIEVEMENT_BLOCK_TYPE) {
      throw new Error(`The first block is not an achievement block (block type ${blockType}).`);
    }
    if (blockSize < 1 || blockSize > MAX_BLOCK_SIZE) {
      throw new Error(`Invalid achievement block size: ${blockSize}.`);
    }
    if (achievementCount < 1 || achievementCount > blockSize
      || achievementCount > LIMITS.maxAchievementCount) {
      throw new Error(`Invalid achievement count ${achievementCount} for block size ${blockSize}.`);
    }
    if (blockSize > bytes.byteLength - HEADER_SIZE) {
      throw new Error("Save file is truncated inside the achievement block.");
    }

    const unlockedIds = [];
    for (let achievementId = 1; achievementId < achievementCount; achievementId += 1) {
      if (bytes[HEADER_SIZE + achievementId] > 0) {
        unlockedIds.push(achievementId);
      }
    }

    return { achievementCount, unlockedIds };
  }

  function inferPersistentSaveSlot(fileName) {
    if (typeof fileName !== "string") {
      return null;
    }
    const match = fileName.match(/(?:^|[._-])(?:(?:rep_)|(?:rep\+))?persistentgamedata([123])\.dat$/i);
    return match ? Number(match[1]) : null;
  }

  function inferModSaveSlot(fileName) {
    if (typeof fileName !== "string") {
      return null;
    }
    const match = fileName.match(/(?:^|[._-])save([123])\.dat$/i);
    return match ? Number(match[1]) : null;
  }

  function validateSnapshot(snapshot) {
    if (!snapshot || typeof snapshot !== "object" || Array.isArray(snapshot)) {
      throw new TypeError("Achievement import must be an object.");
    }
    if (!Number.isInteger(snapshot.saveSlot) || snapshot.saveSlot < 1 || snapshot.saveSlot > 3) {
      throw new Error("Save slot must be an integer from 1 through 3.");
    }
    if (!Number.isInteger(snapshot.achievementCount) || snapshot.achievementCount < 1
      || snapshot.achievementCount > LIMITS.maxAchievementCount) {
      throw new Error("Achievement count must be a positive integer.");
    }
    if (!Array.isArray(snapshot.unlockedIds)) {
      throw new Error("Unlocked achievement IDs must be an array.");
    }
    if (snapshot.unlockedIds.length > snapshot.achievementCount - 1) {
      throw new Error("Too many unlocked achievement IDs for this snapshot.");
    }

    const unlockedIds = [];
    const seen = new Set();
    for (const achievementId of snapshot.unlockedIds) {
      if (!Number.isInteger(achievementId)
        || achievementId < 1
        || achievementId >= snapshot.achievementCount) {
        throw new Error(`Invalid achievement ID ${String(achievementId)}.`);
      }
      if (!seen.has(achievementId)) {
        seen.add(achievementId);
        unlockedIds.push(achievementId);
      }
    }
    unlockedIds.sort((left, right) => left - right);

    return {
      formatVersion: 1,
      saveSlot: snapshot.saveSlot,
      achievementCount: snapshot.achievementCount,
      unlockedIds,
    };
  }

  function validateExistingData(existing) {
    if (existing == null) {
      return {};
    }
    if (typeof existing !== "object" || Array.isArray(existing)) {
      throw new Error("Existing Mod save JSON must contain a JSON object.");
    }
    return existing;
  }

  function assertPriorImportSlot(existing, saveSlot) {
    const prior = existing.achievementImport;
    if (prior && Number.isInteger(prior.saveSlot) && prior.saveSlot !== saveSlot) {
      throw new Error(`Save slot conflict: existing import is slot ${prior.saveSlot}, selected save is slot ${saveSlot}.`);
    }
  }

  function mergeModSaveData(existingData, snapshot) {
    const existing = validateExistingData(existingData);
    const achievementImport = validateSnapshot(snapshot);
    assertPriorImportSlot(existing, achievementImport.saveSlot);

    return {
      ...existing,
      schemaVersion: 9,
      achievementImport,
    };
  }

  function parseExistingJson(existingJson) {
    if (existingJson == null || existingJson.trim() === "") {
      return null;
    }
    if (existingJson.length > LIMITS.maxModSaveJsonChars) {
      throw new Error("Existing Mod save JSON is too large to import safely.");
    }
    let parsed;
    try {
      parsed = JSON.parse(existingJson);
    } catch (error) {
      throw new Error(`Existing Mod save is not valid JSON: ${error.message}`);
    }
    return validateExistingData(parsed);
  }

  function mergeModSaveJson(existingJson, snapshot, options) {
    const settings = options || {};
    const existing = parseExistingJson(existingJson);
    const achievementImport = validateSnapshot(snapshot);
    const fileSlot = inferModSaveSlot(settings.existingFileName);
    if (settings.existingFileName != null && fileSlot === null) {
      throw new Error("Cannot determine the save slot from the existing Mod filename; select save1.dat, save2.dat, or save3.dat.");
    }
    if (fileSlot !== null && fileSlot !== achievementImport.saveSlot) {
      throw new Error(`Save slot conflict: ${settings.existingFileName} is slot ${fileSlot}, selected save is slot ${achievementImport.saveSlot}.`);
    }

    const merged = mergeModSaveData(existing, achievementImport);
    return {
      fileName: `save${achievementImport.saveSlot}.dat`,
      json: `${JSON.stringify(merged, null, 2)}\n`,
      data: merged,
    };
  }

  return {
    LIMITS,
    parsePersistentGameData,
    inferPersistentSaveSlot,
    inferModSaveSlot,
    mergeModSaveData,
    mergeModSaveJson,
  };
}));
