Set-StrictMode -Version 2.0

$script:IsaacSaveMagic = 'ISAACNGSAVE09R  '
$script:IsaacSaveHeaderSize = 0x20
$script:MaxPersistentSaveBytes = 8MB
$script:MaxAchievementBlockBytes = 1MB
$script:MaxAchievementCount = 16384
$script:MaxModSaveBytes = 4MB
$script:MaxCandidateFiles = 256
$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$script:StrictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)

function Get-CanonicalPath {
    param([Parameter(Mandatory = $true)][string] $Path)
    return [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string] $Path)
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
        finally { $sha.Dispose() }
    } finally { $stream.Dispose() }
}

function Read-BoundedFileBytes {
    param([string] $Path, [long] $MaximumBytes, [string] $Kind)
    $stream = New-Object System.IO.FileStream($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $length = $stream.Length
        if ($length -gt $MaximumBytes) { throw "$Kind 过大，已停止读取：$Path" }
        if ($length -gt [int]::MaxValue) { throw "$Kind 过大，已停止读取：$Path" }
        $bytes = New-Object byte[] ([int]$length)
        $offset = 0
        while ($offset -lt $bytes.Length) {
            $read = $stream.Read($bytes, $offset, $bytes.Length - $offset)
            if ($read -le 0) { throw "$Kind 在读取过程中被截断：$Path" }
            $offset += $read
        }
        if ($stream.Length -ne $length) { throw "$Kind 在读取过程中发生变化：$Path" }
        return $bytes
    } finally { $stream.Dispose() }
}

function Read-StrictUtf8File {
    param([string] $Path, [long] $MaximumBytes, [string] $Kind)
    $bytes = Read-BoundedFileBytes -Path $Path -MaximumBytes $MaximumBytes -Kind $Kind
    try { return $script:StrictUtf8.GetString($bytes) }
    catch { throw "$Kind 不是严格 UTF-8 文本：$Path" }
}

function Read-UInt32LittleEndian {
    param([byte[]] $Bytes, [int] $Offset)
    if ($null -eq $Bytes -or $Offset -lt 0 -or $Offset -gt ($Bytes.Length - 4)) {
        throw "读取 little-endian UInt32 时超出 4 字节边界：offset=$Offset"
    }
    return [BitConverter]::ToUInt32($Bytes, $Offset)
}

function Read-IsaacAchievementSnapshot {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][ValidateRange(1, 3)][int] $SaveSlot
    )
    $canonical = Get-CanonicalPath $Path
    if (-not [System.IO.File]::Exists($canonical)) { throw "游戏存档不存在：$canonical" }
    $bytes = Read-BoundedFileBytes -Path $canonical -MaximumBytes $script:MaxPersistentSaveBytes -Kind '游戏存档'
    if ($bytes.Length -lt $script:IsaacSaveHeaderSize) { throw "游戏存档在文件头之前已截断：$canonical" }
    $magic = [System.Text.Encoding]::ASCII.GetString($bytes, 0, $script:IsaacSaveMagic.Length)
    if ($magic -ne $script:IsaacSaveMagic) { throw "SAVE09R 文件头无效：$canonical" }
    $blockType = Read-UInt32LittleEndian $bytes 0x14
    $blockSize = Read-UInt32LittleEndian $bytes 0x18
    $achievementCount = Read-UInt32LittleEndian $bytes 0x1c
    if ($blockType -ne 1) { throw "首个数据块不是成就块：$canonical" }
    if ($blockSize -lt 1 -or $blockSize -gt $script:MaxAchievementBlockBytes) {
        throw "成就块大小无效：$canonical"
    }
    if ($achievementCount -lt 1 -or $achievementCount -gt $blockSize -or
        $achievementCount -gt $script:MaxAchievementCount) {
        throw "成就数量无效：$canonical"
    }
    if ($blockSize -gt ($bytes.Length - $script:IsaacSaveHeaderSize)) {
        throw "游戏存档在成就块中截断：$canonical"
    }

    $unlocked = New-Object System.Collections.Generic.List[int]
    for ($id = 1; $id -lt $achievementCount; $id++) {
        if ($bytes[$script:IsaacSaveHeaderSize + $id] -gt 0) { $unlocked.Add($id) }
    }
    return [pscustomobject]@{
        formatVersion = 1
        saveSlot = $SaveSlot
        achievementCount = [int]$achievementCount
        unlockedIds = [int[]]$unlocked.ToArray()
    }
}

function Add-SaveAlias {
    param([hashtable] $Slots, [int] $Slot, [string] $Candidate, [string] $Directory)
    if (-not $Slots.ContainsKey($Slot)) {
        $Slots[$Slot] = $Candidate
        return
    }
    $existing = $Slots[$Slot]
    $existingInfo = New-Object System.IO.FileInfo($existing)
    $candidateInfo = New-Object System.IO.FileInfo($Candidate)
    if ($existingInfo.Length -gt $script:MaxPersistentSaveBytes -or $candidateInfo.Length -gt $script:MaxPersistentSaveBytes) {
        throw "游戏存档过大，已停止比较同日期别名：$Directory"
    }
    if ((Get-Sha256 $existing) -ne (Get-Sha256 $Candidate)) {
        throw "同日期、同槽位的备份别名内容不同，存在歧义：$existing；$Candidate"
    }
    $Slots[$Slot] = @($existing, $Candidate | Sort-Object)[0]
}

function Get-LocalSaveSetsFromDirectory {
    param(
        [Parameter(Mandatory = $true)][string] $Directory,
        [Parameter(Mandatory = $true)][string] $Edition,
        [Parameter(Mandatory = $true)][string[]] $Prefixes,
        [switch] $AllowCurrent
    )
    if (-not [System.IO.Directory]::Exists($Directory)) { return @() }
    $canonical = Get-CanonicalPath $Directory
    $candidateFiles = @([System.IO.Directory]::GetFiles($canonical, '*.dat', [System.IO.SearchOption]::TopDirectoryOnly))
    if ($candidateFiles.Count -gt $script:MaxCandidateFiles) { throw "候选存档文件过多，已停止扫描：$canonical" }

    $dated = @{}
    $current = @{}
    foreach ($file in $candidateFiles) {
        $name = [System.IO.Path]::GetFileName($file)
        $candidate = Get-CanonicalPath $file
        $matched = $false
        foreach ($prefix in $Prefixes) {
            $escapedPrefix = [Regex]::Escape($prefix)
            $datedMatch = [Regex]::Match($name, '^(?<date>\d{8})[._-]?' + $escapedPrefix + '(?<slot>[123])\.dat$', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($datedMatch.Success) {
                $date = $datedMatch.Groups['date'].Value
                try {
                    [void][datetime]::ParseExact($date, 'yyyyMMdd', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None)
                } catch { throw "存档备份日期无效：$candidate" }
                if (-not $dated.ContainsKey($date)) { $dated[$date] = @{} }
                Add-SaveAlias -Slots $dated[$date] -Slot ([int]$datedMatch.Groups['slot'].Value) -Candidate $candidate -Directory $canonical
                $matched = $true
                break
            }
            if ($AllowCurrent) {
                $currentMatch = [Regex]::Match($name, '^' + $escapedPrefix + '(?<slot>[123])\.dat$', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
                if ($currentMatch.Success) {
                    Add-SaveAlias -Slots $current -Slot ([int]$currentMatch.Groups['slot'].Value) -Candidate $candidate -Directory $canonical
                    $matched = $true
                    break
                }
            }
        }
        if ($matched) { continue }
    }

    $sets = New-Object System.Collections.Generic.List[object]
    foreach ($date in @($dated.Keys | Sort-Object)) {
        $recency = [datetime]::SpecifyKind(
            [datetime]::ParseExact($date, 'yyyyMMdd', [Globalization.CultureInfo]::InvariantCulture),
            [DateTimeKind]::Utc
        )
        $sets.Add([pscustomobject]@{
            Edition = $Edition; Location = 'Local backup'; Directory = $canonical
            SetName = $date; Slots = $dated[$date]; RecencyUtc = $recency
        })
    }
    if ($current.Count -gt 0) {
        $latestWrite = @($current.Values | ForEach-Object { [System.IO.File]::GetLastWriteTimeUtc($_) } | Sort-Object -Descending)[0]
        $sets.Add([pscustomobject]@{
            Edition = $Edition; Location = 'Local backup'; Directory = $canonical
            SetName = 'current'; Slots = $current; RecencyUtc = $latestWrite
        })
    }
    return $sets.ToArray()
}

function Find-IsaacSaveFamilies {
    param([Parameter(Mandatory = $true)][string] $DocumentsRoot)
    $myGames = Join-Path (Get-CanonicalPath $DocumentsRoot) 'My Games'
    $definitions = @(
        @{ Edition = 'Repentance'; Directory = Join-Path $myGames 'Binding of Isaac\Repentance'; Prefixes = @('rep_persistentgamedata') },
        @{ Edition = 'Repentance+'; Directory = Join-Path $myGames 'Binding of Isaac Repentance+\save_backups'; Prefixes = @('rep+persistentgamedata') },
        @{ Edition = 'Repentance'; Directory = Join-Path $myGames 'Binding of Isaac Repentance'; Prefixes = @('persistentgamedata', 'rep_persistentgamedata') }
    )
    $families = New-Object System.Collections.Generic.List[object]
    foreach ($definition in $definitions) {
        foreach ($family in @(Get-LocalSaveSetsFromDirectory -Directory $definition.Directory -Edition $definition.Edition -Prefixes $definition.Prefixes -AllowCurrent)) {
            $families.Add($family)
        }
    }
    return $families.ToArray()
}

function Get-SlotFingerprint {
    param([hashtable] $Slots)
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($slot in @($Slots.Keys | Sort-Object)) {
        $info = New-Object System.IO.FileInfo($Slots[$slot])
        if ($info.Length -gt $script:MaxPersistentSaveBytes) { throw "游戏存档过大，已停止比较：$($Slots[$slot])" }
        $parts.Add("$slot=" + (Get-Sha256 $Slots[$slot]))
    }
    return $parts -join ';'
}

function Get-FamilyFingerprint {
    param($Family)
    return Get-SlotFingerprint $Family.Slots
}

function Select-IsaacSaveFamily {
    param([object[]] $Families)
    $available = @($Families)
    if ($available.Count -eq 0) { throw '未找到可导入的 Repentance 或 Repentance+ 存档。' }
    $newest = @($available | Sort-Object RecencyUtc -Descending)[0].RecencyUtc
    $available = @($available | Where-Object { $_.RecencyUtc -eq $newest })
    if ($available.Count -eq 1) { return $available[0] }
    $fingerprints = @($available | ForEach-Object { Get-FamilyFingerprint $_ } | Select-Object -Unique)
    if ($fingerprints.Count -eq 1) {
        return @($available | Sort-Object Directory, Edition, SetName)[0]
    }
    $descriptions = @($available | ForEach-Object { "$($_.Edition) / $($_.SetName) / $($_.Directory)" }) -join '；'
    throw "最新存档集合并列但内容不同，存在歧义，未执行导入：$descriptions"
}

function Get-DocumentsDirectory {
    $knownFolder = [Environment]::GetFolderPath('MyDocuments')
    if (-not [string]::IsNullOrWhiteSpace($knownFolder)) { return Get-CanonicalPath $knownFolder }
    $userProfile = [Environment]::GetEnvironmentVariable('USERPROFILE')
    if (-not [string]::IsNullOrWhiteSpace($userProfile)) {
        return Get-CanonicalPath (Join-Path $userProfile 'Documents')
    }
    throw '无法确定当前用户的 Documents 目录。'
}

function Assert-IsaacNotRunning {
    param([string[]] $ProcessNames = @('isaac-ng'))
    foreach ($name in $ProcessNames) {
        if (@(Get-Process -Name $name -ErrorAction SilentlyContinue).Count -gt 0) {
            throw "检测到游戏仍在运行（$name）。请完全关闭游戏后重试。"
        }
    }
}

function Enter-ImportMutex {
    param([string] $Name = 'Local\AchievementTrackerSaveImporter')
    $created = $false
    $mutex = New-Object System.Threading.Mutex($true, $Name, [ref]$created)
    if (-not $created) {
        $mutex.Dispose()
        throw '已有另一个成就存档导入进程正在运行。'
    }
    return $mutex
}

function Exit-ImportMutex {
    param($Mutex)
    if ($null -eq $Mutex) { return }
    try { $Mutex.ReleaseMutex() } catch { }
    $Mutex.Dispose()
}

function Assert-NotReparsePoint {
    param([string] $Path, [string] $Kind)
    if (-not [System.IO.File]::Exists($Path) -and -not [System.IO.Directory]::Exists($Path)) { return }
    $attributes = [System.IO.File]::GetAttributes($Path)
    if (($attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "$Kind 不能是重解析点（ReparsePoint）：$Path"
    }
}

function Assert-SafeDestination {
    param([string] $GameRoot, [string] $DataDirectory, [object[]] $Prepared = @())
    $gameExecutable = Join-Path $GameRoot 'isaac-ng.exe'
    if (-not [System.IO.File]::Exists($gameExecutable)) { throw "游戏目录缺少 isaac-ng.exe：$GameRoot" }
    Assert-NotReparsePoint -Path $GameRoot -Kind '游戏目录'
    Assert-NotReparsePoint -Path (Join-Path $GameRoot 'data') -Kind 'data 目录'
    Assert-NotReparsePoint -Path $DataDirectory -Kind 'Mod 数据目录'
    Assert-NotReparsePoint -Path (Join-Path $DataDirectory 'backups') -Kind '备份目录'
    foreach ($item in @($Prepared)) { Assert-NotReparsePoint -Path $item.Target -Kind '目标存档' }
}

function Get-TargetState {
    param([string] $Path)
    if (-not [System.IO.File]::Exists($Path)) { return [pscustomobject]@{ Exists = $false; Length = 0L; LastWriteTicks = 0L; Hash = '' } }
    $info = New-Object System.IO.FileInfo($Path)
    return [pscustomobject]@{
        Exists = $true
        Length = $info.Length
        LastWriteTicks = $info.LastWriteTimeUtc.Ticks
        Hash = Get-Sha256 $Path
    }
}

function Assert-TargetUnchanged {
    param([string] $Path, $Expected)
    $actual = Get-TargetState $Path
    if ($actual.Exists -ne $Expected.Exists -or $actual.Length -ne $Expected.Length -or
        $actual.LastWriteTicks -ne $Expected.LastWriteTicks -or $actual.Hash -ne $Expected.Hash) {
        throw "目标 Mod 存档在导入过程中发生变化，已停止写入：$Path"
    }
}

function Read-ModSaveObject {
    param([string] $Path, [int] $ExpectedSlot)
    if (-not [System.IO.File]::Exists($Path)) { return [pscustomobject][ordered]@{} }
    $file = New-Object System.IO.FileInfo($Path)
    if ($file.Length -gt $script:MaxModSaveBytes) { throw "Mod 存档过大，已停止导入：$Path" }
    $text = Read-StrictUtf8File -Path $Path -MaximumBytes $script:MaxModSaveBytes -Kind 'Mod 存档'
    try { $data = $text | ConvertFrom-Json }
    catch { throw "Mod 存档不是有效 JSON：$Path；$($_.Exception.Message)" }
    if ($null -eq $data -or $data -is [System.Array] -or $data -is [string] -or
        $data -is [bool] -or $data -is [ValueType]) {
        throw "Mod 存档 JSON 根节点必须是对象：$Path"
    }
    $importProperty = $data.PSObject.Properties['achievementImport']
    if ($null -ne $importProperty -and $null -ne $importProperty.Value) {
        $slotProperty = $importProperty.Value.PSObject.Properties['saveSlot']
        if ($null -ne $slotProperty -and $null -ne $slotProperty.Value -and [int]$slotProperty.Value -ne $ExpectedSlot) {
            throw "Mod 存档中的槽位与文件名冲突：$Path"
        }
    }
    return $data
}

function Merge-ModSaveObject {
    param($Existing, $Snapshot)
    $Existing | Add-Member -MemberType NoteProperty -Name schemaVersion -Value 5 -Force
    $import = [pscustomobject][ordered]@{
        formatVersion = 1
        saveSlot = [int]$Snapshot.saveSlot
        achievementCount = [int]$Snapshot.achievementCount
        unlockedIds = [int[]]@($Snapshot.unlockedIds)
    }
    $Existing | Add-Member -MemberType NoteProperty -Name achievementImport -Value $import -Force
    return $Existing
}

function ConvertTo-ModSaveJson {
    param($Data)
    return (($Data | ConvertTo-Json -Depth 100) + [Environment]::NewLine)
}

function Assert-StagedModSave {
    param([string] $Path, $ExpectedSnapshot)
    $data = Read-ModSaveObject -Path $Path -ExpectedSlot $ExpectedSnapshot.saveSlot
    if ([int]$data.schemaVersion -ne 5 -or [int]$data.achievementImport.formatVersion -ne 1 -or
        [int]$data.achievementImport.achievementCount -ne [int]$ExpectedSnapshot.achievementCount) {
        throw "暂存 Mod 存档复验失败：$Path"
    }
    $actual = @($data.achievementImport.unlockedIds | ForEach-Object { [int]$_ }) -join ','
    $expected = @($ExpectedSnapshot.unlockedIds | ForEach-Object { [int]$_ }) -join ','
    if ($actual -ne $expected) { throw "暂存 Mod 存档的成就列表复验失败：$Path" }
}

function New-BackupDirectory {
    param([string] $DataDirectory)
    $backupRoot = Join-Path $DataDirectory 'backups'
    [void][System.IO.Directory]::CreateDirectory($backupRoot)
    $stamp = [DateTime]::Now.ToString('yyyyMMdd-HHmmss-fff')
    $candidate = Join-Path $backupRoot $stamp
    $suffix = 0
    while ([System.IO.Directory]::Exists($candidate)) {
        $suffix++
        $candidate = Join-Path $backupRoot ($stamp + '-' + $suffix)
    }
    [void][System.IO.Directory]::CreateDirectory($candidate)
    return Get-CanonicalPath $candidate
}

function Remove-TemporaryFile {
    param([string] $Path)
    try {
        if ([System.IO.File]::Exists($Path)) { [System.IO.File]::Delete($Path) }
    } catch { }
}

function Replace-FileAtomically {
    param([string] $StagedPath, [string] $TargetPath)
    $replaceBackup = $TargetPath + '.replace.' + [Guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [System.IO.File]::Replace($StagedPath, $TargetPath, $replaceBackup, $true)
    } finally {
        Remove-TemporaryFile $replaceBackup
    }
}

function Restore-ImportBatch {
    param([object[]] $Replaced, [string] $BackupPath)
    foreach ($entry in @($Replaced | Sort-Object Order -Descending)) {
        if (-not $entry.Applied) { continue }
        if ($entry.Existed) {
            $backup = Join-Path $BackupPath ([System.IO.Path]::GetFileName($entry.Target))
            $restoreStage = $entry.Target + '.rollback.' + [Guid]::NewGuid().ToString('N') + '.tmp'
            try {
                [System.IO.File]::Copy($backup, $restoreStage, $true)
                if ([System.IO.File]::Exists($entry.Target)) {
                    Replace-FileAtomically -StagedPath $restoreStage -TargetPath $entry.Target
                } else {
                    [System.IO.File]::Move($restoreStage, $entry.Target)
                }
            } finally { Remove-TemporaryFile $restoreStage }
        } elseif ([System.IO.File]::Exists($entry.Target)) {
            [System.IO.File]::Delete($entry.Target)
        }
    }
}

function Invoke-OneClickAchievementImport {
    param(
        [Parameter(Mandatory = $true)][string] $ModRoot,
        [string] $DocumentsRoot = $null,
        [switch] $DryRun,
        [switch] $SkipProcessGuard,
        [switch] $SkipMutex,
        [scriptblock] $BeforeCommit = $null,
        [scriptblock] $AfterReplace = $null
    )
    $canonicalModRoot = Get-CanonicalPath $ModRoot
    if ([System.IO.Path]::GetFileName($canonicalModRoot) -ne 'achievement_tracker_3788047099' -or
        [System.IO.Path]::GetFileName([System.IO.Path]::GetDirectoryName($canonicalModRoot)) -ne 'mods') {
        throw "脚本位置无效：必须位于 mods\achievement_tracker_3788047099。"
    }
    $gameRoot = Get-CanonicalPath (Split-Path (Split-Path $canonicalModRoot -Parent) -Parent)
    $dataDirectory = Get-CanonicalPath (Join-Path $gameRoot 'data\achievement_tracker')
    $expectedData = Get-CanonicalPath (Join-Path $gameRoot 'data\achievement_tracker')
    if ($dataDirectory -ne $expectedData) { throw '目标目录安全校验失败。' }
    Assert-SafeDestination -GameRoot $gameRoot -DataDirectory $dataDirectory

    if (-not $PSBoundParameters.ContainsKey('DocumentsRoot')) { $DocumentsRoot = Get-DocumentsDirectory }

    $mutex = $null
    try {
        if (-not $DryRun) {
            if (-not $SkipProcessGuard) { Assert-IsaacNotRunning }
            if (-not $SkipMutex) { $mutex = Enter-ImportMutex }
        }

        $families = @(Find-IsaacSaveFamilies -DocumentsRoot $DocumentsRoot)
        $family = Select-IsaacSaveFamily -Families $families
        $prepared = New-Object System.Collections.Generic.List[object]
        foreach ($slot in @($family.Slots.Keys | Sort-Object)) {
            $source = $family.Slots[$slot]
            $snapshot = Read-IsaacAchievementSnapshot -Path $source -SaveSlot $slot
            $target = Join-Path $dataDirectory ("save$slot.dat")
            Assert-NotReparsePoint -Path $target -Kind '目标存档'
            $targetState = Get-TargetState $target
            $existing = Read-ModSaveObject -Path $target -ExpectedSlot $slot
            $merged = Merge-ModSaveObject -Existing $existing -Snapshot $snapshot
            $prepared.Add([pscustomobject]@{
                Slot = $slot; Source = $source; Target = $target; Snapshot = $snapshot
                Json = ConvertTo-ModSaveJson $merged; Existed = $targetState.Exists; TargetState = $targetState
            })
        }
        $slotReports = @($prepared | ForEach-Object {
            [pscustomobject]@{ SaveSlot = $_.Slot; UnlockedCount = @($_.Snapshot.unlockedIds).Count; Source = $_.Source }
        })
        if ($DryRun) {
            return [pscustomobject]@{ DryRun = $true; Edition = $family.Edition; Location = $family.Location; SetName = $family.SetName; Slots = $slotReports; BackupPath = $null }
        }

        [void][System.IO.Directory]::CreateDirectory($dataDirectory)
        Assert-SafeDestination -GameRoot $gameRoot -DataDirectory $dataDirectory -Prepared $prepared.ToArray()
        $backupPath = $null
        $stages = New-Object System.Collections.Generic.List[object]
        try {
            foreach ($item in $prepared) {
                $stage = $item.Target + '.achievement-import.' + [Guid]::NewGuid().ToString('N') + '.tmp'
                $stages.Add([pscustomobject]@{ Item = $item; Path = $stage })
                [System.IO.File]::WriteAllText($stage, $item.Json, $script:Utf8NoBom)
                Assert-StagedModSave -Path $stage -ExpectedSnapshot $item.Snapshot
            }

            if ($null -ne $BeforeCommit) { & $BeforeCommit }
            if (-not $SkipProcessGuard) { Assert-IsaacNotRunning }
            Assert-SafeDestination -GameRoot $gameRoot -DataDirectory $dataDirectory -Prepared $prepared.ToArray()
            foreach ($item in $prepared) { Assert-TargetUnchanged -Path $item.Target -Expected $item.TargetState }

            $backupPath = New-BackupDirectory $dataDirectory
            Assert-SafeDestination -GameRoot $gameRoot -DataDirectory $dataDirectory -Prepared $prepared.ToArray()
            Assert-NotReparsePoint -Path $backupPath -Kind '本次备份目录'
            foreach ($item in $prepared) {
                if ($item.Existed) {
                    $backupFile = Join-Path $backupPath ([System.IO.Path]::GetFileName($item.Target))
                    [System.IO.File]::Copy($item.Target, $backupFile, $false)
                    if ((Get-Sha256 $backupFile) -ne $item.TargetState.Hash) {
                        throw "备份文件与准备阶段的目标存档不一致，已停止提交：$backupFile"
                    }
                }
            }

            if (-not $SkipProcessGuard) { Assert-IsaacNotRunning }
            Assert-SafeDestination -GameRoot $gameRoot -DataDirectory $dataDirectory -Prepared $prepared.ToArray()
            foreach ($item in $prepared) { Assert-TargetUnchanged -Path $item.Target -Expected $item.TargetState }

            $replaced = New-Object System.Collections.Generic.List[object]
            try {
                $order = 0
                foreach ($stageEntry in $stages) {
                    $order++
                    $item = $stageEntry.Item
                    $rollbackEntry = [pscustomobject]@{ Order = $order; Target = $item.Target; Existed = $item.Existed; Applied = $false }
                    $replaced.Add($rollbackEntry)
                    if ($item.Existed) {
                        Replace-FileAtomically -StagedPath $stageEntry.Path -TargetPath $item.Target
                    } else {
                        [System.IO.File]::Move($stageEntry.Path, $item.Target)
                    }
                    $rollbackEntry.Applied = $true
                    if ($null -ne $AfterReplace) { & $AfterReplace $item.Slot }
                }
            } catch {
                $writeError = $_
                try { Restore-ImportBatch -Replaced $replaced.ToArray() -BackupPath $backupPath }
                catch { throw "导入失败，自动回滚也失败。备份位于：$backupPath；原始错误：$($writeError.Exception.Message)；回滚错误：$($_.Exception.Message)" }
                throw "导入失败，已从备份回滚。备份位于：$backupPath；$($writeError.Exception.Message)"
            }
        } finally {
            foreach ($stageEntry in $stages) {
                Remove-TemporaryFile $stageEntry.Path
            }
        }
        return [pscustomobject]@{ DryRun = $false; Edition = $family.Edition; Location = $family.Location; SetName = $family.SetName; Slots = $slotReports; BackupPath = $backupPath }
    } finally {
        if ($null -ne $mutex) { Exit-ImportMutex $mutex }
    }
}
