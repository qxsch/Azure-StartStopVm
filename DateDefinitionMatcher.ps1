function Get-DateWithTimeZone {
    param(
      [Parameter(Mandatory=$false, Position=0)]
      [datetime]$Date = (Get-Date),
      [Parameter(Mandatory=$true, Position=1)]
      [string]$TimeZone
    )
    return [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId(
      $Date,
      $TimeZone
    )
}

class DateDefinitionMatcher {
    hidden [System.Text.RegularExpressions.Regex] $_rex
    hidden [datetime] $FromTime
    hidden [datetime] $UntilTime
    hidden [bool] $compareSingleDate = $false
    hidden [hashtable] $dayOfWeekMap = @{
        "mon" = [DayOfWeek]::Monday
        "tue" = [DayOfWeek]::Tuesday
        "wed" = [DayOfWeek]::Wednesday
        "thu" = [DayOfWeek]::Thursday
        "fri" = [DayOfWeek]::Friday
        "sat" = [DayOfWeek]::Saturday
        "sun" = [DayOfWeek]::Sunday
    }

    DateDefinitionMatcher([datetime]$FromTime, [datetime]$UntilTime) {
        $this._rex = [System.Text.RegularExpressions.Regex]::new(
            '^' + 
            '((?<DateMonthBegin1>\d{2})([/](?<DateDayBegin1>\d{1,2}))?(\s*-\s*(?<DateMonthEnd1>\d{2})([/](?<DateDayEnd1>\d{1,2})))?\s+)?' + 
            '((?<WeekdayBegin>mon|tue|wed|thu|fri|sat|sun)(-(?<WeekdayEnd>mon|tue|wed|thu|fri|sat|sun))?\s+)?' +
            '((?<DateMonthBegin2>\d{2})([/](?<DateDayBegin2>\d{1,2}))?(\s*-\s*(?<DateMonthEnd2>\d{2})([/](?<DateDayEnd2>\d{1,2})))?\s+)?' + 
            '(?<Time>\d{2}:\d{2}(:\d{2})?)' +
            '$', 
            (
                [System.Text.RegularExpressions.RegexOptions]::Compiled -bor
                [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )
        )
        $this.setTimeRange($FromTime, $UntilTime)
    }

    [datetime[]] getTimeRange() {
        return @($this.FromTime, $this.UntilTime)
    }

    [void] setTimeRange([datetime[]]$d) {
        if($d.Count -ne 2) {
            throw "Invalid number of arguments"
        }
        $this.setTimeRange($d[0], $d[1])
    }
    [void] setTimeRange([datetime]$FromTime, [datetime]$UntilTime) {
        if($FromTime -gt $UntilTime) {
            throw "FromTime must be less than UntilTime"
        }
        if(($UntilTime - $FromTime).TotalMinutes -gt 1200) {
            throw "Date range must be less than 20 hours"
        }
        $this.FromTime = $FromTime
        $this.UntilTime = $UntilTime
        if($this.FromTime.Day -eq $this.UntilTime.Day) {
            $this.compareSingleDate = $true
        }
        else {
            $this.compareSingleDate = $false
        }
    }

    hidden [hashtable] getPrioritizedHash([System.Text.RegularExpressions.Match] $m) {
        $o = @{
            "Segements" = @{"Month" = $false ; "Day"  = $false; "DayOfWeek" = $false }
            "NormalizedDefinition" = ""
            "Priority" = 5
            "Time" = $m.Groups["Time"].Value
        }
        # setting date ranges
        for($i = 2; $i -ge 1; $i--) {
            if($m.Groups["DateMonthBegin$i"].Success) {
                $o["Segements"]["Month"] = $true
                $o["DateMonthBegin"] = [int]$m.Groups["DateMonthBegin$i"].Value
                # setting begin and end days, if any
                if($m.Groups["DateDayBegin$i"].Success -or $m.Groups["DateDayEnd$i"].Success) {
                    $o["Segements"]["Day"] = $true
                    if($m.Groups["DateDayBegin$i"].Success) {
                        $o["DateDayBegin"] = [int]$m.Groups["DateDayBegin$i"].Value
                    }
                    else {
                        $o["DateDayBegin"] = 1
                    }
                    if($m.Groups["DateDayEnd$i"].Success) {
                        $o["DateDayEnd"] = [int]$m.Groups["DateDayEnd$i"].Value
                    }
                    else {
                        $o["DateDayEnd"] = 31
                    }
                    # sanity checks (days 1-31)
                    foreach($k in @("DateDayBegin", "DateDayEnd")) {
                        if($o[$k] -lt 1)  { $o[$k] = 1  }
                        if($o[$k] -gt 31) { $o[$k] = 31 }
                    }
                }
                # setting end of month
                if($m.Groups["DateMonthEnd$i"].Success) {
                    $o["DateMonthEnd"] = [int]$m.Groups["DateMonthEnd$i"].Value
                }
                else {
                    $o["DateMonthEnd"] = $o["DateMonthBegin"]
                }
                # sanity checks (months 1-12)
                foreach($k in @("DateMonthBegin", "DateMonthEnd")) {
                    if($o[$k] -lt 1)  { $o[$k] = 1  }
                    if($o[$k] -gt 12) { $o[$k] = 12 }
                }
                break
            }
        }
        # day of week
        if($m.Groups["WeekdayBegin"].Success) {
            $o["Segements"]["DayOfWeek"] = $true
            $o["WeekdayBegin"] = $m.Groups["WeekdayBegin"].Value
            $o["WeekdayBeginEnum"] = $this.dayOfWeekMap[$m.Groups["WeekdayBegin"].Value.ToLower()]
            if($m.Groups["WeekdayEnd"].Success) {
                $o["WeekdayEnd"] = $m.Groups["WeekdayEnd"].Value
                $o["WeekdayEndEnum"] = $this.dayOfWeekMap[$m.Groups["WeekdayEnd"].Value.ToLower()]
            }
            else {
                $o["WeekdayEnd"] = $o["WeekdayBegin"]
                $o["WeekdayEndEnum"] = $o["WeekdayBeginEnum"]
            }
        }

        # setting priority
        # 0.) 12/30 mon 12:00
        # 1.) 12/30 12:00
        # 2.) 12 mon 12:00
        # 3.) 12 12:00
        # 4.) mon 12:00
        # 5.) 12:00
        if($o["Segements"]["Month"]) {
            if($o["Segements"]["Day"]) {
                if($o["Segements"]["DayOfWeek"]) {
                    $o["Priority"] = 0
                    $o["NormalizedDefinition"] = ("{0:00}/{1:00} - {2:00}/{3:00}  {4}-{5}  {6}" -f $o["DateMonthBegin"], $o["DateDayBegin"], $o["DateMonthEnd"], $o["DateDayEnd"], $o["WeekdayBegin"], $o["WeekdayEnd"], $o["Time"])
                }
                else {
                    $o["Priority"] = 1
                    $o["NormalizedDefinition"] = ("{0:00}/{1:00} - {2:00}/{3:00}  {4}" -f $o["DateMonthBegin"], $o["DateDayBegin"], $o["DateMonthEnd"], $o["DateDayEnd"], $o["Time"])
                }
            }
            else {
                if($o["Segements"]["DayOfWeek"]) {
                    $o["Priority"] = 2
                    $o["NormalizedDefinition"] = ("{0:00}/{1:00} - {2:00}/{3:00}  {4}-{5}  {6}" -f $o["DateMonthBegin"], 1, $o["DateMonthEnd"], 31, $o["WeekdayBegin"], $o["WeekdayEnd"], $o["Time"])
                }
                else {
                    $o["Priority"] = 3
                    $o["NormalizedDefinition"] = ("{0:00}/{1:00} - {2:00}/{3:00}  {4}" -f $o["DateMonthBegin"], 1, $o["DateMonthEnd"], 31, $o["Time"])
                }
            }
        }
        else {
            if($o["Segements"]["DayOfWeek"]) {
                $o["Priority"] = 4
                $o["NormalizedDefinition"] = ("{0}-{1}  {2}" -f $o["WeekdayBegin"], $o["WeekdayEnd"], $o["Time"])
            }
            else {
                $o["Priority"] = 5
                $o["NormalizedDefinition"] = ("{0}" -f $o["Time"])
            }
        }
        return $o
    }

    [bool] isDayHit([hashtable]$h) {
        # compare day of week
        if($h["Segements"]["DayOfWeek"]) {
            if($this.compareSingleDate) {
                if($h["WeekdayBeginEnum"] -gt $h["WeekdayEndEnum"]) {
                    if(-not($this.UntilTime.DayOfWeek -ge $h["WeekdayBeginEnum"] -or $this.UntilTime.DayOfWeek -le $h["WeekdayEndEnum"])) {
                        return $false
                    }
                }
                else {
                    if(-not($this.UntilTime.DayOfWeek -ge $h["WeekdayBeginEnum"] -and $this.UntilTime.DayOfWeek -le $h["WeekdayEndEnum"])) {
                        return $false
                    }
                }
            }
            else {
                if($h["WeWeekdayBeginEnum"] -gt $h["WeekdayEndEnum"]) {
                    if(-not(
                        ($this.UntilTime.DayOfWeek -ge $h["WeWeekdayBeginEnum"] -or $this.UntilTime.DayOfWeek -le $h["WeekdayEndEnum"]) -or
                        ($this.FromTime.DayOfWeek -ge $h["WeekdayBeginEnum"] -or $this.FromTime.DayOfWeek -le $h["WeekdayEndEnum"])
                    )) {
                        return $false
                    }
                }
                else {
                    if(-not(
                        ($this.UntilTime.DayOfWeek -ge $h["WeWeekdayBeginEnum"] -and $this.UntilTime.DayOfWeek -le $h["WeekdayEndEnum"]) -or
                        ($this.FromTime.DayOfWeek -ge $h["WeekdayBeginEnum"] -and $this.FromTime.DayOfWeek -le $h["WeekdayEndEnum"])
                    )) {
                        return $false
                    }
                }
            }
        }
        # compare date
        if($h["Segements"]["Month"]) {
            if($h["Segements"]["Day"]) {
                if($this.compareSingleDate) {
                    if(-not(
                        ($this.UntilTime.Month -gt $h["DateMonthBegin"] -and $this.UntilTime.Month -lt $h["DateMonthEnd"]) -or
                        ($this.UntilTime.Month -eq $h["DateMonthBegin"] -and $this.UntilTime.Month -ne $h["DateMonthEnd"]   -and $this.UntilTime.Day -ge $h["DateDayBegin"] ) -or
                        ($this.UntilTime.Month -eq $h["DateMonthEnd"]   -and $this.UntilTime.Month -ne $h["DateMonthBegin"] -and $this.UntilTime.Day -le $h["DateDayEnd"]) -or
                        ($this.UntilTime.Month -eq $h["DateMonthBegin"] -and $this.UntilTime.Month -eq $h["DateMonthEnd"]   -and $this.UntilTime.Day -ge $h["DateDayBegin"] -and $this.UntilTime.Day -le $h["DateDayEnd"])
                    )) {
                        return $false
                    }
                }
                else {
                    if(-not(
                        ($this.UntilTime.Month -gt $h["DateMonthBegin"] -and $this.UntilTime.Month -lt $h["DateMonthEnd"]) -or
                        ($this.UntilTime.Month -eq $h["DateMonthBegin"] -and $this.UntilTime.Month -ne $h["DateMonthEnd"]   -and $this.UntilTime.Day -ge $h["DateDayBegin"] ) -or
                        ($this.UntilTime.Month -eq $h["DateMonthEnd"]   -and $this.UntilTime.Month -ne $h["DateMonthBegin"] -and $this.UntilTime.Day -le $h["DateDayEnd"]) -or
                        ($this.UntilTime.Month -eq $h["DateMonthBegin"] -and $this.UntilTime.Month -eq $h["DateMonthEnd"]   -and $this.UntilTime.Day -ge $h["DateDayBegin"] -and $this.UntilTime.Day -le $h["DateDayEnd"]) -or
                        ($this.FromTime.Month -gt $h["DateMonthBegin"] -and $this.FromTime.Month -lt $h["DateMonthEnd"]) -or
                        ($this.FromTime.Month -eq $h["DateMonthBegin"] -and $this.FromTime.Month -ne $h["DateMonthEnd"]   -and $this.FromTime.Day -ge $h["DateDayBegin"] ) -or
                        ($this.FromTime.Month -eq $h["DateMonthEnd"]   -and $this.FromTime.Month -ne $h["DateMonthBegin"] -and $this.FromTime.Day -le $h["DateDayEnd"]) -or
                        ($this.FromTime.Month -eq $h["DateMonthBegin"] -and $this.FromTime.Month -eq $h["DateMonthEnd"]   -and $this.FromTime.Day -ge $h["DateDayBegin"] -and $this.FromTime.Day -le $h["DateDayEnd"])
                    
                    )) {
                        return $false
                    }
                }    
            }
            else {
                if($this.compareSingleDate) {
                    if(-not($this.UntilTime.Month -ge $h["DateMonthBegin"] -and $this.UntilTime.Month -le $h["DateMonthEnd"])) {
                        return $false
                    }
                }
                else {
                    if(-not(
                        ($this.UntilTime.Month -ge $h["DateMonthBegin"] -and $this.UntilTime.Month -le $h["DateMonthEnd"]) -or
                        ($this.FromTime.Month  -ge $h["DateMonthBegin"] -and $this.FromTime.Month  -le $h["DateMonthEnd"])
                    )) {
                        return $false
                    }
                }
            }
        }
        return $true
    }

    [bool] isTimeHit([hashtable]$h) {
        $t = $h["Time"] -split ":"
        $t[0] = [int]$t[0]
        $t[1] = [int]$t[1]
        if($t[0] -ge 24) {
            return $false
        }
        if($this.FromTime.Hour -gt $this.UntilTime.Hour) {
            if(
                ($t[0] -gt $this.FromTime.Hour  -or  $t[0] -lt $this.UntilTime.Hour) -or
                ($t[0] -eq $this.FromTime.Hour  -and $t[1] -ge $this.FromTime.Minute) -or
                ($t[0] -eq $this.UntilTime.Hour -and $t[1] -le $this.UntilTime.Minute)
            ) {
                return $true
            }
            else {
                return $false
            }
        }
        else {
            if(
                ($t[0] -gt $this.FromTime.Hour  -and $t[0] -lt $this.UntilTime.Hour) -or
                ($t[0] -eq $this.FromTime.Hour  -and $t[0] -ne $this.UntilTime.Hour -and $t[1] -ge $this.FromTime.Minute) -or
                ($t[0] -eq $this.UntilTime.Hour -and $t[0] -ne $this.FromTime.Hour  -and $t[1] -le $this.UntilTime.Minute) -or
                ($t[0] -eq $this.FromTime.Hour  -and $t[0] -eq $this.UntilTime.Hour -and $t[1] -ge $this.FromTime.Minute -and $t[1] -le $this.UntilTime.Minute)
            ) {
                return $true
            }
            else {
                return $false
            }
        }
        
        return $false
    }

    [bool] isWithinDateDefinition([string]$DateDef) {
        $rulesets = @( @{}, @{}, @{}, @{}, @{}, @{} )
        foreach($d in ($datedef -split "[;]")) {
            $d = $d.trim().ToLower()
            $m = $this._rex.Match($d)
            if($m.Success) {
                $h = $this.getPrioritizedHash($m)
                $rulesets[$h["Priority"]][$h["NormalizedDefinition"]] = $h
                Write-Host -ForegroundColor Yellow "IN $d"
                #Write-Host ($m.Groups | Where-Object { $_.Success } | Select-Object Name, Value | Out-String).Trim()
                Write-Host ($h | Out-String).Trim()
            }
        }
        # evaluating rules
        $isDayHit = $false
        foreach($rs in $rulesets) {
            foreach($h in $rs.Values) {
                if($this.isDayHit($h)) {
                    Write-Host -ForegroundColor Yellow ("DAY HIT " + $h["NormalizedDefinition"])
                    $isDayHit = $true
                    if($this.isTimeHit($h)) {
                        Write-Host -ForegroundColor Green ("TIME HIT " + $h["NormalizedDefinition"])
                        return $true
                    }
                }
            }
            # if we had a day hit, we can skip lower priority definitions (because just time is not yet satisfied within in the higher priority definition)
            if($isDayHit) {
                break
            }
        }
        return $false
    }
}


$UntilTime = Get-DateWithTimeZone -TimeZone "Eastern Standard Time"
$FromTime = $UntilTime.AddMinutes(-15)
Write-Host "FromTime:  $FromTime"
Write-Host "UntilTime: $UntilTime"
$dtm = [DateDefinitionMatcher]::new($FromTime, $UntilTime)
$dtm.isWithinDateDefinition("mon-tue 12:00; 12/10-12/20 08:30; fri-sun 08:30")


