import crypto from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const API_URL = "https://bindingofisaacrebirth.wiki.gg/api.php";
const WIKI_ROOT = "https://bindingofisaacrebirth.wiki.gg/";
const EXPECTED_COUNT = 641;
const USER_AGENT = "AchievementTrackerIconGenerator/1.0 (offline mod asset generator)";
const DLC_RANK = new Map([
  ["rebirth", 0],
  ["afterbirth", 1],
  ["afterbirth+", 2],
  ["afterbirth plus", 2],
  ["repentance", 3],
  ["repentance+", 4],
  ["repentance plus", 4]
]);

const sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

function dlcRank(value) {
  return DLC_RANK.get(String(value || "").trim().toLowerCase()) ?? -1;
}

export function buildIconRecords(achievementRows, imageRows, options = {}) {
  const expectedCount = options.expectedCount ?? EXPECTED_COUNT;
  const imagesByAlias = new Map();
  for (const row of imageRows) {
    const alias = String(row.achievement || "").trim();
    const sourceFile = String(row.file || "").replace(/^File:/i, "").trim();
    if (!alias || !sourceFile) continue;
    const candidate = { sourceFile, dlc: String(row.dlc || "").trim() };
    const current = imagesByAlias.get(alias);
    if (!current || dlcRank(candidate.dlc) > dlcRank(current.dlc)
      || (dlcRank(candidate.dlc) === dlcRank(current.dlc)
        && candidate.sourceFile.localeCompare(current.sourceFile, "en") < 0)) {
      imagesByAlias.set(alias, candidate);
    }
  }

  const byId = new Map();
  for (const row of achievementRows) {
    const id = Number(row.id);
    const alias = String(row.alias || "").trim();
    if (!Number.isInteger(id) || id < 1 || id > expectedCount) continue;
    if (byId.has(id)) throw new Error(`Duplicate achievement id ${id}`);
    const image = imagesByAlias.get(alias);
    if (!image) throw new Error(`Achievement ${id} (${alias}) has no icon image`);
    byId.set(id, { id, alias, sourceFile: image.sourceFile, dlc: image.dlc });
  }

  const records = [];
  for (let id = 1; id <= expectedCount; id += 1) {
    if (!byId.has(id)) throw new Error(`Missing achievement id ${id}`);
    records.push(byId.get(id));
  }
  return records;
}

export function inspectPng(data) {
  if (!Buffer.isBuffer(data) || data.length < 24
    || !data.subarray(0, 8).equals(Buffer.from("89504e470d0a1a0a", "hex"))) {
    throw new Error("Invalid PNG signature");
  }
  if (data.toString("ascii", 12, 16) !== "IHDR") throw new Error("PNG is missing IHDR");
  const width = data.readUInt32BE(16);
  const height = data.readUInt32BE(20);
  if (width !== 64 || height !== 64) {
    throw new Error(`Achievement icon must be 64x64, received ${width}x${height}`);
  }
  return { width, height };
}

async function fetchJson(fetchImpl, url, options = {}) {
  const attempts = options.attempts ?? 4;
  const delay = options.delay ?? sleep;
  let lastError;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      const response = await fetchImpl(url, { headers: { "User-Agent": USER_AGENT } });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      return await response.json();
    } catch (error) {
      lastError = error;
      if (attempt < attempts) await delay(250 * (2 ** (attempt - 1)));
    }
  }
  throw new Error(`Request failed after ${attempts} attempts: ${url}: ${lastError?.message}`);
}

export async function fetchCargoRows(fetchImpl, table, fields, options = {}) {
  const pageSize = options.pageSize ?? 500;
  const rows = [];
  for (let offset = 0; ; offset += pageSize) {
    const url = new URL(API_URL);
    url.search = new URLSearchParams({
      action: "cargoquery",
      format: "json",
      tables: table,
      fields: fields.join(","),
      limit: String(pageSize),
      offset: String(offset)
    }).toString();
    const data = await fetchJson(fetchImpl, url, options);
    if (!Array.isArray(data.cargoquery)) throw new Error(`Invalid Cargo response for ${table}`);
    const page = data.cargoquery.map((entry) => entry.title);
    rows.push(...page);
    if (page.length < pageSize) break;
  }
  return rows;
}

export async function fetchIconBuffer(fetchImpl, url, options = {}) {
  const attempts = options.attempts ?? 4;
  const delay = options.delay ?? sleep;
  let lastError;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      const response = await fetchImpl(url, { headers: { "User-Agent": USER_AGENT } });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = Buffer.from(await response.arrayBuffer());
      inspectPng(data);
      return data;
    } catch (error) {
      lastError = error;
      if (attempt < attempts) await delay(250 * (2 ** (attempt - 1)));
    }
  }
  throw new Error(`Icon download failed after ${attempts} attempts: ${url}: ${lastError?.message}`);
}

export async function resolveImageInfo(fetchImpl, records) {
  const resolved = [];
  for (let index = 0; index < records.length; index += 50) {
    const batch = records.slice(index, index + 50);
    const url = new URL(API_URL);
    url.search = new URLSearchParams({
      action: "query",
      format: "json",
      formatversion: "2",
      prop: "imageinfo",
      iiprop: "url|size",
      titles: batch.map((entry) => `File:${entry.sourceFile}`).join("|")
    }).toString();
    const data = await fetchJson(fetchImpl, url);
    const pages = data.query?.pages;
    if (!Array.isArray(pages)) throw new Error("Invalid MediaWiki imageinfo response");
    const byTitle = new Map(pages.map((page) => [page.title.toLocaleLowerCase("en-US"), page]));
    for (const record of batch) {
      const title = `File:${record.sourceFile}`;
      const page = byTitle.get(title.toLocaleLowerCase("en-US"));
      const info = page?.imageinfo?.[0];
      if (!info?.url) throw new Error(`No imageinfo URL for ${title}`);
      if (info.width !== 64 || info.height !== 64) {
        throw new Error(`${title} must be 64x64, received ${info.width}x${info.height}`);
      }
      resolved.push({
        ...record,
        descriptionUrl: info.descriptionurl
          || `${WIKI_ROOT}wiki/${encodeURIComponent(title.replace(/ /g, "_"))}`,
        downloadUrl: info.url
      });
    }
  }
  return resolved;
}

async function mapConcurrent(values, concurrency, mapper) {
  const results = new Array(values.length);
  let nextIndex = 0;
  async function worker() {
    while (nextIndex < values.length) {
      const index = nextIndex;
      nextIndex += 1;
      results[index] = await mapper(values[index], index);
    }
  }
  await Promise.all(Array.from({ length: Math.min(concurrency, values.length) }, worker));
  return results;
}

export async function generateAchievementIcons(options = {}) {
  const fetchImpl = options.fetchImpl ?? globalThis.fetch;
  if (typeof fetchImpl !== "function") throw new Error("This generator requires fetch (Node.js 18+)");
  const outputDir = options.outputDir ?? path.resolve(path.dirname(fileURLToPath(import.meta.url)),
    "..", "resources", "gfx", "ui", "achievement_icons");

  const [achievementRows, imageRows] = await Promise.all([
    fetchCargoRows(fetchImpl, "achievement", ["id", "alias"]),
    fetchCargoRows(fetchImpl, "achievement_image", ["achievement", "file", "dlc"])
  ]);
  const records = buildIconRecords(achievementRows, imageRows);
  const resolved = await resolveImageInfo(fetchImpl, records);
  await fs.mkdir(outputDir, { recursive: true });

  const icons = await mapConcurrent(resolved, options.concurrency ?? 8, async (record) => {
    const data = await fetchIconBuffer(fetchImpl, record.downloadUrl);
    const file = `achievement_${String(record.id).padStart(3, "0")}.png`;
    await fs.writeFile(path.join(outputDir, file), data);
    return {
      id: record.id,
      alias: record.alias,
      file,
      sourceFile: record.sourceFile,
      dlc: record.dlc,
      descriptionUrl: record.descriptionUrl,
      downloadUrl: record.downloadUrl,
      sha256: crypto.createHash("sha256").update(data).digest("hex")
    };
  });

  const manifest = { source: WIKI_ROOT, icons };
  await fs.writeFile(path.join(outputDir, "manifest.json"),
    `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
  return manifest;
}

const isMain = process.argv[1]
  && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href;
if (isMain) {
  generateAchievementIcons()
    .then((manifest) => console.log(`Generated ${manifest.icons.length} achievement icons.`))
    .catch((error) => {
      console.error(error.stack || error.message);
      process.exitCode = 1;
    });
}
