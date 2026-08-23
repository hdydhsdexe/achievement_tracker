param(
    [Parameter(Mandatory = $true)]
    [string] $FixtureRoot,
    [Parameter(Mandatory = $true)]
    [string] $CoreScript
)

$ErrorActionPreference = 'Stop'
. $CoreScript

function Assert-True {
    param([bool] $Condition, [string] $Message)
    if (-not $Condition) { throw "ASSERT TRUE FAILED: $Message" }
}

function Assert-Equal {
    param($Actual, $Expected, [string] $Message)
    if ($Actual -ne $Expected) { throw "ASSERT EQUAL FAILED: $Message (actual=$Actual expected=$Expected)" }
}

function Assert-Throws {
    param([scriptblock] $Action, [string] $Pattern, [string] $Message)
    try { & $Action; throw "ASSERT THROWS FAILED: $Message" }
    catch {
        if ($_.Exception.Message -like 'ASSERT THROWS FAILED:*') { throw }
        if ($_.Exception.Message -notmatch $Pattern) {
            throw "ASSERT THROWS FAILED: $Message (message=$($_.Exception.Message))"
        }
    }
}

function New-Directory {
    param([string] $Path)
    [void][System.IO.Directory]::CreateDirectory($Path)
    return [System.IO.Path]::GetFullPath($Path)
}

function New-IsaacSave {
    param([string] $Path, [int[]] $Unlocked = @(1, 3), [int] $Count = 6, [switch] $Broken)
    $bytes = New-Object byte[] (0x20 + $Count)
    if (-not $Broken) {
        $magic = [System.Text.Encoding]::ASCII.GetBytes('ISAACNGSAVE09R  ')
        [Array]::Copy($magic, 0, $bytes, 0, $magic.Length)
    }
    [Array]::Copy([BitConverter]::GetBytes([uint32] 1), 0, $bytes, 0x14, 4)
    [Array]::Copy([BitConverter]::GetBytes([uint32] $Count), 0, $bytes, 0x18, 4)
    [Array]::Copy([BitConverter]::GetBytes([uint32] $Count), 0, $bytes, 0x1c, 4)
    foreach ($id in $Unlocked) { $bytes[0x20 + $id] = 1 }
    [System.IO.File]::WriteAllBytes($Path, $bytes)
}

function New-Layout {
    param([string] $Name)
    $base = New-Directory (Join-Path $FixtureRoot $Name)
    $game = New-Directory (Join-Path $base 'game')
    [System.IO.File]::WriteAllBytes((Join-Path $game 'isaac-ng.exe'), (New-Object byte[] 0))
    $modRoot = New-Directory (Join-Path $game 'mods\achievement_tracker_3788047099')
    $documents = New-Directory (Join-Path $base 'Documents')
    $steam = New-Directory (Join-Path $base 'Steam')
    return [pscustomobject]@{
        Base = $base
        Game = $game
        ModRoot = $modRoot
        Documents = $documents
        Steam = $steam
        Data = Join-Path $game 'data\achievement_tracker'
    }
}

function Get-Options {
    param($Layout)
    return @{
        ModRoot = $Layout.ModRoot
        DocumentsRoot = $Layout.Documents
        SkipProcessGuard = $true
        SkipMutex = $true
    }
}

function Invoke-WithOptions {
    param([hashtable] $Options)
    return Invoke-OneClickAchievementImport @Options
}

function Assert-NoImportTemps {
    param([string] $Directory, [string] $Message)
    if (-not [System.IO.Directory]::Exists($Directory)) { return }
    $residue = @([System.IO.Directory]::GetFiles($Directory, '*.tmp', [System.IO.SearchOption]::TopDirectoryOnly) | Where-Object {
        [System.IO.Path]::GetFileName($_) -match '\.(achievement-import|rollback|replace)\.'
    })
    Assert-Equal $residue.Count 0 $Message
}

# PowerShell byte shifts must not truncate UInt32 values at the byte boundary.
$littleEndianVector = [byte[]](0x82, 0x02, 0x00, 0x00)
Assert-Equal (Read-UInt32LittleEndian -Bytes $littleEndianVector -Offset 0) 642 '82 02 00 00 decodes as UInt32 642'
$layout = New-Layout 'little-endian-642'
$largeSave = Join-Path $layout.Base 'persistentgamedata1.dat'
New-IsaacSave $largeSave -Count 642 -Unlocked @(1, 284, 641)
$largeSnapshot = Read-IsaacAchievementSnapshot -Path $largeSave -SaveSlot 1
Assert-Equal $largeSnapshot.achievementCount 642 'full SAVE09R retains achievement count 642'
Assert-True (@($largeSnapshot.unlockedIds) -contains 284) 'achievement id 284 remains unlocked'
Assert-True (@($largeSnapshot.unlockedIds) -contains 641) 'achievement id 641 remains unlocked'
Write-Output 'PASS: little-endian uint32 preserves achievement ids above 255'

# Canonical and legacy local directories are enumerated as independent coherent sets.
$layout = New-Layout 'canonical-local'
$canonicalLayout = $layout
$repCanonical = New-Directory (Join-Path $layout.Documents 'My Games\Binding of Isaac\Repentance')
$plusBackups = New-Directory (Join-Path $layout.Documents 'My Games\Binding of Isaac Repentance+\save_backups')
$legacyRep = New-Directory (Join-Path $layout.Documents 'My Games\Binding of Isaac Repentance')
New-IsaacSave (Join-Path $repCanonical '20260813.rep_persistentgamedata1.dat') -Unlocked @(1)
New-IsaacSave (Join-Path $legacyRep '20260813.rep_persistentgamedata2.dat') -Unlocked @(2)
New-IsaacSave (Join-Path $plusBackups '20260814.rep+persistentgamedata1.dat') -Unlocked @(3)
New-IsaacSave (Join-Path $plusBackups '20260814.rep+persistentgamedata2.dat') -Unlocked @(4)
New-IsaacSave (Join-Path $plusBackups '20260815.rep+persistentgamedata3.dat') -Unlocked @(5)
$families = @(Find-IsaacSaveFamilies -DocumentsRoot $layout.Documents)
Assert-True (@($families | Where-Object { $_.Directory -eq $repCanonical }).Count -eq 1) 'canonical Repentance directory discovered'
Assert-True (@($families | Where-Object { $_.Directory -eq $plusBackups }).Count -eq 2) 'Repentance+ backup dates remain separate sets'
Assert-True (@($families | Where-Object { $_.Directory -eq $legacyRep }).Count -eq 1) 'legacy flat Repentance remains compatible'
Write-Output 'PASS: canonical local directories are discovered'

$selected = Select-IsaacSaveFamily $families
Assert-Equal $selected.Edition 'Repentance+' '20260815 Repentance+ wins over 20260813 Repentance'
Assert-Equal $selected.SetName '20260815' 'newest parsed batch date wins'
Assert-Equal $selected.Slots.Count 1 'newest set does not fill slots from 20260814'
Assert-True ($selected.Slots.ContainsKey(3)) 'only slot 3 belongs to newest set'
Write-Output 'PASS: newest local set wins without filling gaps'

# Current files and dated batches use one normalized UTC recency comparison.
$layout = New-Layout 'current-newer-than-dated'
$local = New-Directory (Join-Path $layout.Documents 'My Games\Binding of Isaac Repentance')
$currentFile = Join-Path $local 'persistentgamedata1.dat'
New-IsaacSave $currentFile -Unlocked @(1)
[System.IO.File]::SetLastWriteTimeUtc($currentFile, [datetime]'2026-08-16T00:00:00Z')
New-IsaacSave (Join-Path $local '20260815.rep_persistentgamedata2.dat') -Unlocked @(2)
$selected = Select-IsaacSaveFamily @(Find-IsaacSaveFamilies -DocumentsRoot $layout.Documents)
Assert-Equal $selected.SetName 'current' 'newer current mtime wins over older dated batch'
Assert-Equal $selected.Slots.Count 1 'current winner does not take a slot from dated batch'
Assert-True ($selected.Slots.ContainsKey(1)) 'only current slot belongs to current winner'

$layout = New-Layout 'dated-newer-than-current'
$local = New-Directory (Join-Path $layout.Documents 'My Games\Binding of Isaac Repentance')
$currentFile = Join-Path $local 'persistentgamedata1.dat'
New-IsaacSave $currentFile -Unlocked @(1)
[System.IO.File]::SetLastWriteTimeUtc($currentFile, [datetime]'2026-08-15T00:00:00Z')
New-IsaacSave (Join-Path $local '20260816.rep_persistentgamedata2.dat') -Unlocked @(2)
$selected = Select-IsaacSaveFamily @(Find-IsaacSaveFamilies -DocumentsRoot $layout.Documents)
Assert-Equal $selected.SetName '20260816' 'newer dated batch wins over older current mtime'
Assert-Equal $selected.Slots.Count 1 'dated winner does not take a slot from current set'
Assert-True ($selected.Slots.ContainsKey(2)) 'only dated slot belongs to dated winner'

$layout = New-Layout 'current-dated-tie-identical'
$local = New-Directory (Join-Path $layout.Documents 'My Games\Binding of Isaac Repentance')
$currentFile = Join-Path $local 'persistentgamedata1.dat'
$datedFile = Join-Path $local '20260815.rep_persistentgamedata1.dat'
New-IsaacSave $currentFile -Unlocked @(1)
[System.IO.File]::Copy($currentFile, $datedFile)
[System.IO.File]::SetLastWriteTimeUtc($currentFile, [datetime]'2026-08-15T00:00:00Z')
$selected = Select-IsaacSaveFamily @(Find-IsaacSaveFamilies -DocumentsRoot $layout.Documents)
Assert-Equal $selected.SetName '20260815' 'identical exact tie selects the stable lexical set'
Assert-Equal $selected.Slots.Count 1 'identical tie remains a single coherent set'

$layout = New-Layout 'current-dated-tie-divergent'
$local = New-Directory (Join-Path $layout.Documents 'My Games\Binding of Isaac Repentance')
$currentFile = Join-Path $local 'persistentgamedata1.dat'
New-IsaacSave $currentFile -Unlocked @(1)
[System.IO.File]::SetLastWriteTimeUtc($currentFile, [datetime]'2026-08-15T00:00:00Z')
New-IsaacSave (Join-Path $local '20260815.rep_persistentgamedata1.dat') -Unlocked @(2)
Assert-Throws { Select-IsaacSaveFamily @(Find-IsaacSaveFamilies -DocumentsRoot $layout.Documents) } '歧义|并列|tie' 'divergent current and dated exact tie aborts'
Write-Output 'PASS: current and dated sets compete by normalized recency'

# Even a newer cloud-shaped file is outside the local discovery roots and ignored.
$cloud = New-Directory (Join-Path $canonicalLayout.Steam 'userdata\999\250900\remote')
$cloudFile = Join-Path $cloud 'rep+persistentgamedata1.dat'
New-IsaacSave $cloudFile -Unlocked @(1, 2, 3, 4, 5)
[System.IO.File]::SetLastWriteTimeUtc($cloudFile, [datetime]'2099-01-01T00:00:00Z')
$options = Get-Options $canonicalLayout
$options.DryRun = $true
$localResult = Invoke-WithOptions $options
Assert-Equal $localResult.SetName '20260815' 'cloud file cannot enter local selection'
Assert-Equal $localResult.Location 'Local backup' 'result reports local backup'
Write-Output 'PASS: cloud files are ignored'

# Recency ties deduplicate identical mirrors but reject divergent sets.
$layout = New-Layout 'local-tie-identical'
$repCanonical = New-Directory (Join-Path $layout.Documents 'My Games\Binding of Isaac\Repentance')
$legacyRep = New-Directory (Join-Path $layout.Documents 'My Games\Binding of Isaac Repentance')
$canonicalFile = Join-Path $repCanonical '20260815.rep_persistentgamedata1.dat'
$legacyFile = Join-Path $legacyRep '20260815.rep_persistentgamedata1.dat'
New-IsaacSave $canonicalFile -Unlocked @(1)
[System.IO.File]::Copy($canonicalFile, $legacyFile)
$selected = Select-IsaacSaveFamily @(Find-IsaacSaveFamilies -DocumentsRoot $layout.Documents)
Assert-Equal $selected.SetName '20260815' 'identical tied mirrors select deterministically'
$layout = New-Layout 'local-tie-divergent'
$repCanonical = New-Directory (Join-Path $layout.Documents 'My Games\Binding of Isaac\Repentance')
$plusBackups = New-Directory (Join-Path $layout.Documents 'My Games\Binding of Isaac Repentance+\save_backups')
New-IsaacSave (Join-Path $repCanonical '20260815.rep_persistentgamedata1.dat') -Unlocked @(1)
New-IsaacSave (Join-Path $plusBackups '20260815.rep+persistentgamedata1.dat') -Unlocked @(2)
Assert-Throws { Select-IsaacSaveFamily @(Find-IsaacSaveFamilies -DocumentsRoot $layout.Documents) } '歧义|并列|tie' 'divergent newest tie aborts'
Write-Output 'PASS: recency ties deduplicate or abort safely'

# Same date/slot aliases are accepted only when their bytes are identical.
$layout = New-Layout 'aliases-identical'
$local = New-Directory (Join-Path $layout.Documents 'My Games\Binding of Isaac Repentance')
$aliasA = Join-Path $local '20260815.persistentgamedata1.dat'
$aliasB = Join-Path $local '20260815.rep_persistentgamedata1.dat'
$aliasC = Join-Path $local '20260815_persistentgamedata1.dat'
New-IsaacSave $aliasA -Unlocked @(1, 2)
[System.IO.File]::Copy($aliasA, $aliasB)
[System.IO.File]::Copy($aliasA, $aliasC)
$families = @(Find-IsaacSaveFamilies -DocumentsRoot $layout.Documents)
Assert-Equal $families.Count 1 'identical aliases deduplicate to one family'
Assert-Equal $families[0].Slots.Count 1 'deduplicated alias contains one slot'
$layout = New-Layout 'aliases-divergent'
$local = New-Directory (Join-Path $layout.Documents 'My Games\Binding of Isaac Repentance')
New-IsaacSave (Join-Path $local '20260815.persistentgamedata1.dat') -Unlocked @(1)
New-IsaacSave (Join-Path $local '20260815.rep_persistentgamedata1.dat') -Unlocked @(2)
Assert-Throws { Find-IsaacSaveFamilies -DocumentsRoot $layout.Documents } '同日期|不同|歧义' 'divergent aliases abort'
$layout = New-Layout 'aliases-same-prefix'
$local = New-Directory (Join-Path $layout.Documents 'My Games\Binding of Isaac Repentance')
$dotAlias = Join-Path $local '20260815.persistentgamedata1.dat'
$underscoreAlias = Join-Path $local '20260815_persistentgamedata1.dat'
New-IsaacSave $dotAlias -Unlocked @(1)
New-IsaacSave $underscoreAlias -Unlocked @(2)
Assert-Throws { Find-IsaacSaveFamilies -DocumentsRoot $layout.Documents } '同日期|同槽位|不同|歧义' 'same-prefix separator aliases with divergent bytes abort'
Write-Output 'PASS: same-date aliases deduplicate only when identical'

# Dry-run parses everything but cannot create backups, data files, or target directories.
$layout = New-Layout 'dry-run'
$local = New-Directory (Join-Path $layout.Documents 'My Games\Binding of Isaac Repentance')
New-IsaacSave (Join-Path $local 'persistentgamedata1.dat') -Unlocked @(1, 4)
$options = Get-Options $layout
$options.DryRun = $true
$result = Invoke-WithOptions $options
Assert-Equal $result.Slots.Count 1 'dry-run should report the discovered slot'
Assert-Equal $result.Slots[0].UnlockedCount 2 'dry-run reports unlock count'
Assert-True (-not (Test-Path -LiteralPath $layout.Data)) 'dry-run must not create target directory'
Write-Output 'PASS: DryRun is read-only'

# A real import preserves arbitrary fields, backs up old bytes, produces BOM-free schema v7,
# handles every available slot, and leaves absent slot 2 untouched.
$layout = New-Layout 'merge'
$local = New-Directory (Join-Path $layout.Documents 'My Games\Binding of Isaac Repentance')
New-IsaacSave (Join-Path $local 'persistentgamedata1.dat') -Unlocked @(1, 3)
New-IsaacSave (Join-Path $local 'persistentgamedata3.dat') -Unlocked @(2, 5)
$data = New-Directory $layout.Data
$oldJson = '{"schemaVersion":3,"language":"zh","tracked":["achievement_326"],"observedCompleted":{"achievement_326":true}}'
[System.IO.File]::WriteAllText((Join-Path $data 'save1.dat'), $oldJson, (New-Object System.Text.UTF8Encoding($false)))
$slot2 = Join-Path $data 'save2.dat'
[System.IO.File]::WriteAllText($slot2, '{"sentinel":true}', (New-Object System.Text.UTF8Encoding($false)))
$source1 = Join-Path $local 'persistentgamedata1.dat'
$source3 = Join-Path $local 'persistentgamedata3.dat'
$source1Hash = Get-Sha256 $source1
$source3Hash = Get-Sha256 $source3
$options = Get-Options $layout
$result = Invoke-WithOptions $options
$merged = Get-Content -LiteralPath (Join-Path $data 'save1.dat') -Raw | ConvertFrom-Json
$minimal = Get-Content -LiteralPath (Join-Path $data 'save3.dat') -Raw | ConvertFrom-Json
Assert-Equal $merged.schemaVersion 7 'schema upgraded'
Assert-Equal $merged.language 'zh' 'language preserved'
Assert-Equal $merged.tracked[0] 'achievement_326' 'tracked goals preserved'
Assert-True ([bool]$merged.observedCompleted.achievement_326) 'observations preserved'
Assert-Equal $merged.achievementImport.saveSlot 1 'slot 1 snapshot'
Assert-Equal $merged.achievementImport.unlockedIds.Count 2 'slot 1 unlocks'
Assert-Equal $minimal.schemaVersion 7 'minimal slot 3 created'
Assert-Equal $minimal.achievementImport.saveSlot 3 'slot 3 snapshot'
Assert-True ((Get-Content -LiteralPath $slot2 -Raw) -eq '{"sentinel":true}') 'missing source slot 2 remains untouched'
Assert-True (Test-Path -LiteralPath (Join-Path $result.BackupPath 'save1.dat')) 'existing slot is backed up'
Assert-Equal (Get-Content -LiteralPath (Join-Path $result.BackupPath 'save1.dat') -Raw) $oldJson 'backup has exact old content'
$newBytes = [System.IO.File]::ReadAllBytes((Join-Path $data 'save1.dat'))
Assert-True (-not ($newBytes.Length -ge 3 -and $newBytes[0] -eq 0xef -and $newBytes[1] -eq 0xbb -and $newBytes[2] -eq 0xbf)) 'JSON must not contain UTF-8 BOM'
Assert-NoImportTemps $data 'successful import removes all temporary files'
Write-Output 'PASS: merge backs up and preserves existing fields'

# All source and destination JSON must validate before the first backup/write.
$layout = New-Layout 'validate-first'
$local = New-Directory (Join-Path $layout.Documents 'My Games\Binding of Isaac Repentance')
New-IsaacSave (Join-Path $local 'persistentgamedata1.dat')
New-IsaacSave (Join-Path $local 'persistentgamedata2.dat') -Broken
$data = New-Directory $layout.Data
$original = '{"language":"en"}'
[System.IO.File]::WriteAllText((Join-Path $data 'save1.dat'), $original, (New-Object System.Text.UTF8Encoding($false)))
$options = Get-Options $layout
Assert-Throws { Invoke-WithOptions $options } 'SAVE09R|文件头|magic' 'a corrupt source aborts the batch'
Assert-Equal (Get-Content -LiteralPath (Join-Path $data 'save1.dat') -Raw) $original 'slot 1 is unchanged'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $data 'backups'))) 'no backup is created before complete validation'
[System.IO.File]::WriteAllText((Join-Path $local 'persistentgamedata2.dat'), ('x' * (8MB + 1)), (New-Object System.Text.UTF8Encoding($false)))
Assert-Throws { Invoke-WithOptions $options } '过大|too large' 'oversized source aborts safely'
[System.IO.File]::Delete((Join-Path $local 'persistentgamedata2.dat'))
[System.IO.File]::WriteAllBytes((Join-Path $data 'save1.dat'), [byte[]](0x7b, 0x22, 0xff, 0x22, 0x3a, 0x31, 0x7d))
Assert-Throws { Invoke-WithOptions $options } 'UTF-8' 'invalid UTF-8 existing Mod JSON aborts safely'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $data 'backups'))) 'invalid UTF-8 cannot create backups'
[System.IO.File]::WriteAllText((Join-Path $data 'save1.dat'), '{broken', (New-Object System.Text.UTF8Encoding($false)))
Assert-Throws { Invoke-WithOptions $options } 'JSON' 'malformed existing Mod JSON aborts safely'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $data 'backups'))) 'invalid JSON cannot create backups'
Write-Output 'PASS: validation is batch-atomic'

# The staged merged JSON is re-read before a backup directory is created.
$layout = New-Layout 'stage-before-backup'
$local = New-Directory (Join-Path $layout.Documents 'My Games\Binding of Isaac Repentance')
New-IsaacSave (Join-Path $local 'persistentgamedata1.dat')
$data = New-Directory $layout.Data
$padding = 'x' * ($script:MaxModSaveBytes - 40)
$nearLimit = '{"padding":"' + $padding + '"}'
[System.IO.File]::WriteAllText((Join-Path $data 'save1.dat'), $nearLimit, (New-Object System.Text.UTF8Encoding($false)))
$options = Get-Options $layout
Assert-Throws { Invoke-WithOptions $options } 'Mod 存档过大|too large' 'oversized staged output aborts'
Assert-Equal (Get-Content -LiteralPath (Join-Path $data 'save1.dat') -Raw) $nearLimit 'target remains unchanged after stage validation failure'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $data 'backups'))) 'stage validation happens before backup creation'
Assert-NoImportTemps $data 'failed stage validation cleans temporary output'
Write-Output 'PASS: staged output validates before backup'

# A failure after the first replacement restores old targets and removes new targets.
$layout = New-Layout 'rollback'
$local = New-Directory (Join-Path $layout.Documents 'My Games\Binding of Isaac Repentance')
New-IsaacSave (Join-Path $local 'persistentgamedata1.dat') -Unlocked @(1)
New-IsaacSave (Join-Path $local 'persistentgamedata2.dat') -Unlocked @(2)
$data = New-Directory $layout.Data
$original = '{"language":"en","tracked":["achievement_320"]}'
[System.IO.File]::WriteAllText((Join-Path $data 'save1.dat'), $original, (New-Object System.Text.UTF8Encoding($false)))
$options = Get-Options $layout
$options.AfterReplace = { param($slot) if ($slot -eq 2) { throw 'simulated replacement failure' } }
Assert-Throws { Invoke-WithOptions $options } 'simulated replacement failure' 'injected write failure propagates'
Assert-Equal (Get-Content -LiteralPath (Join-Path $data 'save1.dat') -Raw) $original 'existing target restored'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $data 'save2.dat'))) 'new target removed during rollback'
Assert-NoImportTemps $data 'rollback removes all temporary files'
Write-Output 'PASS: replacement failure rolls back the batch'

# A target changed after preparation must abort before backup or importer target writes.
$layout = New-Layout 'target-toctou'
$local = New-Directory (Join-Path $layout.Documents 'My Games\Binding of Isaac Repentance')
New-IsaacSave (Join-Path $local 'persistentgamedata1.dat') -Unlocked @(1)
$data = New-Directory $layout.Data
$target = Join-Path $data 'save1.dat'
[System.IO.File]::WriteAllText($target, '{"language":"en"}', (New-Object System.Text.UTF8Encoding($false)))
$changed = '{"externalChange":true}'
$options = Get-Options $layout
$options.BeforeCommit = { [System.IO.File]::WriteAllText($target, $changed, (New-Object System.Text.UTF8Encoding($false))) }
Assert-Throws { Invoke-WithOptions $options } '发生变化|changed' 'target mutation aborts commit'
Assert-Equal (Get-Content -LiteralPath $target -Raw) $changed 'importer leaves externally changed target untouched'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $data 'backups'))) 'TOCTOU abort precedes backup'
Assert-NoImportTemps $data 'TOCTOU abort cleans staging files'
Write-Output 'PASS: target TOCTOU aborts before importer writes'

# Existing reparse points in the fixed destination chain are rejected when the platform permits a junction.
$layout = New-Layout 'reparse'
$local = New-Directory (Join-Path $layout.Documents 'My Games\Binding of Isaac Repentance')
New-IsaacSave (Join-Path $local 'persistentgamedata1.dat')
$realData = New-Directory (Join-Path $layout.Base 'redirected')
[void][System.IO.Directory]::CreateDirectory((Join-Path $layout.Game 'data'))
try {
    $junction = New-Item -ItemType Junction -Path $layout.Data -Target $realData -ErrorAction Stop
    $options = Get-Options $layout
    Assert-Throws { Invoke-WithOptions $options } '重解析|reparse' 'destination junction aborts'
    Write-Output 'PASS: reparse targets are rejected'
} catch {
    if ($_.Exception.Message -match 'ASSERT THROWS FAILED') { throw }
    Write-Output 'SKIP: reparse fixture unsupported'
}

# Default guard functions detect a matching process name and a held named mutex.
$currentProcessName = (Get-Process -Id $PID).ProcessName
Assert-Throws { Assert-IsaacNotRunning -ProcessNames @($currentProcessName) } '运行|关闭|running' 'running process guard'
$mutexName = 'Local\AchievementTrackerImporter_Test_' + [Guid]::NewGuid().ToString('N')
$firstMutex = Enter-ImportMutex -Name $mutexName
try {
    Assert-Throws { Enter-ImportMutex -Name $mutexName } '已有|另一个|another' 'concurrent mutex guard'
} finally {
    Exit-ImportMutex -Mutex $firstMutex
}
Write-Output 'PASS: game and concurrent-run guards abort'

# The successful write above must not mutate any game source bytes.
Assert-Equal (Get-Sha256 $source1) $source1Hash 'slot 1 game source unchanged'
Assert-Equal (Get-Sha256 $source3) $source3Hash 'slot 3 game source unchanged'
Write-Output 'PASS: source saves are never modified'

Write-Output 'ALL ONE-CLICK IMPORT TESTS PASSED'
