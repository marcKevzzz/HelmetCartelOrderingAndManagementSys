$ErrorActionPreference = 'Stop'
[xml]$configuration = Get-Content 'HelmetCartelOrderingAndManagementSys/Web.config'
[void][Reflection.Assembly]::LoadFrom((Join-Path $PWD 'HelmetCartelOrderingAndManagementSys/bin/Newtonsoft.Json.dll'))
[void][Reflection.Assembly]::LoadFrom((Join-Path $PWD 'HelmetCartelOrderingAndManagementSys/bin/HelmetCartelOrderingAndManagementSys.dll'))
$factory = New-Object HelmetCartelOrderingAndManagementSys.Infrastructure.DbConnectionFactory($configuration.configuration.connectionStrings.add.connectionString)
$repo = New-Object HelmetCartelOrderingAndManagementSys.Repositories.AdminDataRepository($factory)
$now = [DateTime]::UtcNow
function Measure-Dashboard([bool]$parallel) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    if ($parallel) {
        $tasks = @($repo.GetDashboardStatsAsync(), $repo.GetHourlySalesAsync($now.Date),
            $repo.GetDailySalesAsync($now.AddDays(-30),$now.AddDays(1)),
            $repo.GetInventoryReportAsync(), $repo.GetRecentActivityAsync(8))
        foreach ($task in $tasks) { [void]$task.GetAwaiter().GetResult() }
    } else {
        [void]$repo.GetDashboardStatsAsync().GetAwaiter().GetResult()
        [void]$repo.GetHourlySalesAsync($now.Date).GetAwaiter().GetResult()
        [void]$repo.GetDailySalesAsync($now.AddDays(-7),$now.AddDays(1)).GetAwaiter().GetResult()
        [void]$repo.GetDailySalesAsync($now.AddDays(-30),$now.AddDays(1)).GetAwaiter().GetResult()
        [void]$repo.GetInventoryReportAsync().GetAwaiter().GetResult()
        [void]$repo.GetRecentActivityAsync(8).GetAwaiter().GetResult()
    }
    $timer.Stop(); return $timer.Elapsed.TotalMilliseconds
}
[void](Measure-Dashboard $false); [void](Measure-Dashboard $true)
$before=@();$after=@()
1..10 | ForEach-Object { $before += Measure-Dashboard $false; $after += Measure-Dashboard $true }
"Dashboard data load, 10 interleaved warm runs: sequential $([Math]::Round(($before|Measure-Object -Average).Average,2)) ms; parallel/reused daily data $([Math]::Round(($after|Measure-Object -Average).Average,2)) ms."
