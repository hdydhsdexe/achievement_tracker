"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const root = path.resolve(__dirname, "..");
const launcher = path.join(root, "一键导入成就.cmd");
const entryScript = path.join(root, "tools", "save_importer", "one-click-import.ps1");
const coreScript = path.join(root, "tools", "save_importer", "one-click-import-core.ps1");
const harness = path.join(root, "tests", "helpers", "one-click-import-case.ps1");

test("ships a fixed, space-safe root launcher that preserves the exit code", () => {
  const source = fs.readFileSync(launcher, "utf8");

  assert.match(source, /"%SystemRoot%\\System32\\WindowsPowerShell\\v1\.0\\powershell\.exe"/i);
  assert.match(source, /-NoProfile/i);
  assert.match(source, /-File\s+"%~dp0tools\\save_importer\\one-click-import\.ps1"/i);
  assert.doesNotMatch(source, /%\*/);
  assert.match(source, /exit\s+\/b\s+%[A-Za-z]+%/i);
});

test("production entry exposes only DryRun and derives fixed paths from its own location", () => {
  const entry = fs.readFileSync(entryScript, "utf8");
  const core = fs.readFileSync(coreScript, "utf8");

  assert.match(entry, /param\s*\(\s*\[switch\]\s*\$DryRun\s*\)/i);
  const parameterBlock = entry.match(/param\s*\([\s\S]*?\)/i)?.[0] ?? "";
  assert.doesNotMatch(parameterBlock, /TestRoot|OutputPath|GameRoot|ModDataPath|ModRoot/i);
  assert.match(entry, /Split-Path[\s\S]+Split-Path[\s\S]+Split-Path/i);
  assert.match(entry, /Invoke-OneClickAchievementImport/);
  assert.match(core, /Get-Process/i);
  assert.match(core, /isaac-ng/i);
  assert.match(core, /if\s*\(-not\s+\$DryRun\)[\s\S]*?Assert-IsaacNotRunning[\s\S]*?Enter-ImportMutex/i);
  assert.match(core, /System\.Threading\.Mutex/);
  assert.match(core, /Binding of Isaac Repentance\+/);
  assert.match(core, /Binding of Isaac['"]?\s*[,)]?[\s\S]*?Repentance/i);
  assert.match(core, /Binding of Isaac Repentance\+[\s\S]*?save_backups/i);
  assert.match(core, /Binding of Isaac Repentance/i);
  assert.doesNotMatch(core, /Steam|userdata|loginusers|Registry::|250900|remote/i);
  assert.match(core, /isaac-ng\.exe/i);
  assert.match(core, /ReparsePoint/i);
  assert.match(core, /FileStream/i);
  assert.doesNotMatch(core, /ReadAllBytes\(\$canonical\)/i);
  assert.match(core, /UTF8Encoding\(\$false,\s*\$true\)/i);
  assert.match(core, /GetEnvironmentVariable\(['"]USERPROFILE['"]\)/i);
  assert.match(core, /ConvertTo-Json\s+-Depth\s+100/i);
  assert.match(core, /UTF8Encoding\]\s*::new\(\$false\)|New-Object\s+System\.Text\.UTF8Encoding\s*\(\$false\)/i);
});

test("PowerShell 5.1 integration suite keeps discovery and writes inside temp fixtures", { skip: process.platform !== "win32" }, () => {
  const testRoot = fs.mkdtempSync(path.join(os.tmpdir(), "achievement-import-test-"));
  try {
    const result = spawnSync("powershell.exe", [
      "-NoLogo",
      "-NoProfile",
      "-ExecutionPolicy", "Bypass",
      "-File", harness,
      "-FixtureRoot", testRoot,
      "-CoreScript", coreScript,
    ], {
      cwd: root,
      encoding: "utf8",
      timeout: 30000,
      windowsHide: true,
    });

    assert.equal(result.status, 0, `PowerShell integration suite failed:\n${result.stdout}\n${result.stderr}`);
    assert.match(result.stdout, /PASS: canonical local directories are discovered/);
    assert.match(result.stdout, /PASS: little-endian uint32 preserves achievement ids above 255/);
    assert.match(result.stdout, /PASS: newest local set wins without filling gaps/);
    assert.match(result.stdout, /PASS: current and dated sets compete by normalized recency/);
    assert.match(result.stdout, /PASS: cloud files are ignored/);
    assert.match(result.stdout, /PASS: recency ties deduplicate or abort safely/);
    assert.match(result.stdout, /PASS: same-date aliases deduplicate only when identical/);
    assert.match(result.stdout, /PASS: DryRun is read-only/);
    assert.match(result.stdout, /PASS: merge backs up and preserves existing fields/);
    assert.match(result.stdout, /PASS: validation is batch-atomic/);
    assert.match(result.stdout, /PASS: staged output validates before backup/);
    assert.match(result.stdout, /PASS: replacement failure rolls back the batch/);
    assert.match(result.stdout, /PASS: target TOCTOU aborts before importer writes/);
    assert.match(result.stdout, /PASS: reparse targets are rejected|SKIP: reparse fixture unsupported/);
    assert.match(result.stdout, /PASS: game and concurrent-run guards abort/);
    assert.match(result.stdout, /PASS: source saves are never modified/);
  } finally {
    fs.rmSync(testRoot, { recursive: true, force: true });
  }
});
