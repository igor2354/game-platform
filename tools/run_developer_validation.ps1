param([string]$OutputDirectory,[int]$Parallel=3,[int]$TimeoutSeconds=120,[string[]]$Only=@())
$ErrorActionPreference='Stop'
$workspace=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$engine=(Resolve-Path (Join-Path $workspace '../../Движок/Godot_v4.7.2-stable_win64_console.exe')).Path
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$names=@('developer_3d_integration','developer_routes_parity','developer_mode_smoke','campaign_developer_smoke','developer_hotkeys_smoke','enemy_tools_smoke','settings_file_smoke','feature_switches_smoke','player_health_smoke','pause_display_smoke','movement_overlay_smoke','camera_overlay_smoke','zombie_overlay_smoke','zombie_switches_smoke','ragdoll_overlay_smoke','polygon_3d_menu_smoke','polygon_3d_geometry_smoke','polygon_3d_movement_smoke','polygon_3d_slopes_in_game_smoke','polygon_3d_traversal_smoke','polygon_3d_crouch_camera_smoke','polygon_3d_combat_smoke','player_3d_dash_slide_smoke','player_3d_transitions_smoke','player_3d_gait_direction_smoke','player_3d_all_phases_smoke','player_3d_aim_gait_regression','shooting_3d_catalog_smoke','shooting_3d_features_smoke','shooting_3d_trigger_parity','shooting_3d_recoil_parity','shooting_3d_reload_parity','shooting_3d_input_smoke','shooting_3d_move_reverse_smoke','shooting_3d_magazine_smoke','shooting_3d_effects_parity','casing_3d_materials_smoke','zombie_3d_smoke','zombie_3d_rig_smoke','death_ragdoll_3d_smoke','ragdoll_3d_targets_smoke','ragdoll_3d_resistance_smoke','weapon_loadout_smoke','mp40_3d_integration','pistol_pause_cycle_3d','svt_thumb_pistol_3d','player_actor_anatomy_3d','player_actor_stability_3d','player_right_shoulder_3d','player_weapon_stances_3d')
if($Only.Count -gt 0){$names=$Only}
$pending=[System.Collections.Generic.Queue[string]]::new()
foreach($name in $names){$pending.Enqueue($name)}
$running=[System.Collections.Generic.List[object]]::new()
$results=[System.Collections.Generic.List[object]]::new()
while($pending.Count -gt 0 -or $running.Count -gt 0){
 while($pending.Count -gt 0 -and $running.Count -lt $Parallel){
  $name=$pending.Dequeue()
  $isolated=Join-Path $env:TEMP ('ubershrike-validation-'+$name+'-'+[Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $isolated -Force | Out-Null
  $oldRoaming=$env:APPDATA; $oldLocal=$env:LOCALAPPDATA; $oldTemp=$env:TEMP; $oldTmp=$env:TMP
  try {
   $env:APPDATA=Join-Path $isolated 'roaming'; $env:LOCALAPPDATA=Join-Path $isolated 'local'; $env:TEMP=$isolated; $env:TMP=$isolated
   $process=Start-Process -FilePath $engine -WorkingDirectory $workspace -ArgumentList @('--headless','--fixed-fps','60','--path','.','--script',('res://tests/'+$name+'.gd')) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $OutputDirectory ($name+'.stdout.log')) -RedirectStandardError (Join-Path $OutputDirectory ($name+'.stderr.log')) -PassThru
  } finally {$env:APPDATA=$oldRoaming; $env:LOCALAPPDATA=$oldLocal; $env:TEMP=$oldTemp; $env:TMP=$oldTmp}
  $running.Add([PSCustomObject]@{Name=$name;Process=$process;Start=[DateTime]::UtcNow;Isolated=$isolated})
 }
 foreach($job in @($running.ToArray())){
  $timeout=([DateTime]::UtcNow-$job.Start).TotalSeconds -gt $TimeoutSeconds
  if(-not $job.Process.HasExited -and -not $timeout){continue}
  if($timeout -and -not $job.Process.HasExited){$job.Process.Kill();$job.Process.WaitForExit()}
  $job.Process.Refresh()
  $stdout=Get-Content -LiteralPath (Join-Path $OutputDirectory ($job.Name+'.stdout.log')) -Raw -ErrorAction SilentlyContinue
  $stderr=Get-Content -LiteralPath (Join-Path $OutputDirectory ($job.Name+'.stderr.log')) -Raw -ErrorAction SilentlyContinue
  $combined=[string]$stdout+[Environment]::NewLine+[string]$stderr
  $issues=@($combined -split '\r?\n' | Where-Object {($_ -match '^SCRIPT ERROR|^ERROR:|^FAIL\b|failures=[1-9]') -and ($_ -notmatch 'root certificate store')})
  $expectedErrors=@($issues | Where-Object {$job.Name -in @('developer_mode_smoke','campaign_developer_smoke') -and $_ -match '^ERROR: ConfigFile parse error'})
  $issues=@($issues | Where-Object {$_ -notin $expectedErrors})
  $record=[PSCustomObject]@{ExpectedErrors=$expectedErrors;Name=$job.Name;ExitCode=$job.Process.ExitCode;Timeout=$timeout;Seconds=[Math]::Round(([DateTime]::UtcNow-$job.Start).TotalSeconds,2);Issues=$issues;Passed=($job.Process.ExitCode -eq 0 -and -not $timeout -and $issues.Count -eq 0);Isolation=$job.Isolated}
  $results.Add($record)
  [void]$running.Remove($job)
  $results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'results.json') -Encoding utf8
  Write-Output (($results.Count.ToString()+'/'+$names.Count+' '+$record.Name+' PASS='+$record.Passed))
 }
 Start-Sleep -Milliseconds 250
}
