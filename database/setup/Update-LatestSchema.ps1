[CmdletBinding()]
param([switch]$DryRun,
    [Parameter(Mandatory)][ValidateRange(18,99)][int]$StartMigration,
    [Parameter(Mandatory)][ValidateRange(18,99)][int]$EndMigration,
    [switch]$IncludeDemoContent)
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
[xml]$configuration = Get-Content (Join-Path $repositoryRoot 'HelmetCartelOrderingAndManagementSys/Web.config')
$connection = New-Object System.Data.SqlClient.SqlConnection ($configuration.configuration.connectionStrings.add | Select-Object -First 1).connectionString
$connection.Open()
try {
    if ($StartMigration -gt $EndMigration) { throw 'Start migration must not exceed end migration.' }
    if ($connection.Database -ne 'HelmetCartelDB') { throw 'Migration scripts target HelmetCartelDB; configured database differs.' }
    if (-not $DryRun) {
        $backup = $connection.CreateCommand()
        $backup.CommandTimeout = 180
        $backup.CommandText = "DECLARE @Directory NVARCHAR(4000)=CONVERT(NVARCHAR(4000),SERVERPROPERTY('InstanceDefaultBackupPath')); IF @Directory IS NULL THROW 53032, 'SQL Server backup directory is unavailable.', 1; DECLARE @File NVARCHAR(4000)=@Directory+CASE WHEN RIGHT(@Directory,1) IN ('\','/') THEN '' ELSE '\' END+@Name; BACKUP DATABASE [HelmetCartelDB] TO DISK=@File WITH COPY_ONLY,CHECKSUM; SELECT @File;"
        [void]$backup.Parameters.AddWithValue('@Name', "HelmetCartelDB_before_${StartMigration}_${EndMigration}_" + [DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss_ffff') + '.bak')
        $backupPath = [string]$backup.ExecuteScalar()
        Write-Output ('Backup: ' + $backupPath)
        $verify = $connection.CreateCommand()
        $verify.CommandTimeout = 180
        $verify.CommandText = 'RESTORE VERIFYONLY FROM DISK=@File WITH CHECKSUM;'
        [void]$verify.Parameters.AddWithValue('@File', $backupPath)
        [void]$verify.ExecuteNonQuery()
        Write-Output 'Backup verification passed.'
    }
    $transaction = $connection.BeginTransaction()
    try {
        foreach ($number in $StartMigration..$EndMigration) {
            if ($number -eq 47 -and -not $IncludeDemoContent) {
                Write-Output 'Skipped optional demo-content cleanup migration 47.'
                continue
            }
            $file = @(Get-ChildItem (Join-Path (Split-Path $PSScriptRoot -Parent) 'schema') -Filter ('{0}_*.sql' -f $number) | Sort-Object Name)
            if ($file.Count -eq 0) { throw "No migration found for $number." }
            foreach ($migrationFile in $file) {
            $sql = [IO.File]::ReadAllText($migrationFile.FullName)
            foreach ($batch in [regex]::Split($sql, '(?im)^\s*GO\s*$')) {
                if ([string]::IsNullOrWhiteSpace($batch)) { continue }
                $command = $connection.CreateCommand()
                $command.Transaction = $transaction
                $command.CommandTimeout = 120
                $command.CommandText = $batch
                [void]$command.ExecuteNonQuery()
            }
            Write-Output ('Validated: ' + $migrationFile.Name)
            }
        }
        if ($DryRun) { $transaction.Rollback(); Write-Output 'Dry run passed; all changes rolled back.' }
        else { $transaction.Commit(); Write-Output "Migrations $StartMigration through $EndMigration committed." }
    } catch {
        try { $transaction.Rollback() } catch {}
        throw
    }
} finally { $connection.Close() }
