#!/usr/bin/perl

#
# (Attempt) to compute the combined-WPRS based that exists today
#
# Use the different formula for the times they seem to have been used
#
#
# Geoff Wong, 2015.
#

require DBD::mysql;
use XML::Simple qw(:strict);
use Data::Dumper;
use DBLib;
use strict;

my $formula = 'GPRS';

#
# Compute the pilot number (Pn) quality factor
# @param dbh - database handle
# @param date - date of the computation
# @param num_pilots - number of pilots
#
sub compute_Pn
{
    my ($dbh, $date, $num_pilots) = @_;
    my $Pn;
    my $ref;

    if ($date lt '2007-03-01')
    {
        # Pn < 80  (Number of pilots / 80) ^ 0.5, > 80 = 1.0
        if ($num_pilots < 80)
        {
            $Pn = ($num_pilots / 80) ** 0.5;
            return ( $Pn, 0.0 );
        }
        else
        {
            return ( 1.0, 0.0 );
        }
    }

    my $sth = $dbh->prepare("select C.comPk, count(*) as NumPilots from tblCompetition C, tblCompResult CR where CR.comPk=C.comPk and C.comDateTo between DATE_SUB(?, INTERVAL 1 YEAR) and ? group by C.comPk");
    $sth->execute($date, $date);

    my $total = 0;
    my @results;
    my $yrnum;
    while ($ref = $sth->fetchrow_hashref())
    {
        push @results, $ref;
        $total = $total + $ref->{'NumPilots'};
    }
    $yrnum = scalar @results;
    my $avg = $total / $yrnum;

    # Pilot Number - fixed
    # Pn_max = 1.2, saying that a competition with slightly more than average number of participants is a good benchmark.
    my $Pn_max = 1.2;

    $Pn = sqrt( $num_pilots / $avg );
    if ($Pn > $Pn_max) 
    {
        $Pn = $Pn_max;
    }

    print "Pn=$Pn total=$total yrnum=$yrnum avg=$avg\n";
    return ( $Pn, $yrnum );
}


#
# Compute the task (Ta) quality factor
# @param date - data of competition
# @param tasks - number of tasks
#
sub compute_Ta
{
    my ($date, $tasks) = @_;
    
    if ($date lt '2007-03-01')
    {
        my @tr = ( 0.0, 0.25, 0.6, 0.9, 1.0 );
        if ($tasks > 4)
        {
            $tasks = 4;
        }
        return $tr[$tasks];
    }
    else
    {
        my @tr = ( 0.0, 0.5, 0.8, 1.0);
        if ($tasks > 3)
        {
            $tasks = 3;
        }
        return $tr[$tasks];
    }
}

#
# Compute the pilot quality factor (Pq)
# @param dbh - database handle
# @param lastWPRS - date of last WPRS
# @param date - date of the computation
# @param num_pilots - number of pilots
# @param pilarr - array of pilot information (from db)
#
sub compute_Pq
{
    my ($dbh, $lastWPRS, $date, $num_pilots, $pilarr) = @_;
    my $tophalf;
    my $Pq;

    # Pilot quality
    if ($date lt '2007-03-01')
    {
        my $pilotweight = 0;
        for my $row ( @$pilarr )
        {
            my $PilotRank = 0 + $row->{'ldrPosition'};

            if ($PilotRank == 0)
            {
                # do nothing
            }
            elsif ($PilotRank <= 40) 
            {
                $pilotweight += 40;
            }
            elsif ($PilotRank <= 80) 
            {
                $pilotweight += 28;
            }
            elsif ($PilotRank <= 110) 
            {
                $pilotweight += 22;
            }
            elsif ($PilotRank <= 140) 
            {
                $pilotweight += 16;
            }
            elsif ($PilotRank <= 160) 
            {
                $pilotweight += 11;
            }
            elsif ($PilotRank <= 180) 
            {
                $pilotweight += 8;
            }
            elsif ($PilotRank <= 200) 
            {
                $pilotweight += 6;
            }
            elsif ($PilotRank <= 220) 
            {
                $pilotweight += 4;
            }
            elsif ($PilotRank <= 240) 
            {
                $pilotweight += 3;
            }
            elsif ($PilotRank <= 260) 
            {
                $pilotweight += 2;
            }
        }

        my $PqMax = 1.0;
        my $PqMin = 0.25;
        my $SpwMax = 850;
        my $SpwMin = 25;


        $Pq = (($PqMax - $PqMin) / ($SpwMax - $SpwMin)) * ($pilotweight - $SpwMin) + $PqMin;

        if ($Pq > 1.0)
        {
            $Pq = 1.0;
        }
        if ($Pq < 0.25)
        {
            $Pq = 0.25;
        }

        # Pq - (max 1.0, min 0.25)
        return ( $Pq, 0.0, 0.0 );
    }

    if ($date lt '2008-03-01')
    {
        $tophalf = $num_pilots;
    }
    elsif ($date lt '2009-03-01')
    {
        $tophalf = $num_pilots * 2 / 3;
    }
    else
    {
        $tophalf = $num_pilots / 2;
    }
        
    my @spilarr;
    for my $row ( @$pilarr )
    {
        push @spilarr, $row->{'pilPk'};
    }

    my @spilarr = splice @spilarr, 0, $tophalf;
    my $allpils = join(',', @spilarr);

    # Sum of ranking points of $tophalf of the pilots flying
    my $sth = $dbh->prepare("select sum(ldrPoints) as CompRank from tblLadder L, tblLadderResult LR where LR.ladPk=L.ladPk and L.ladName=? and L.ladDateTo=? and LR.pilPk in ($allpils)");
    $sth->execute($formula, $lastWPRS);
    my $ref = $sth->fetchrow_hashref();
    my $Pq_srp = $ref->{'CompRank'};

    # Sum ranking-points if they had been the top-ranked pilots of the world" 
    #print("select sum(ldrPoints) as TopRanked from tblLadder L, tblLadderResult LR where LR.ladPk=L.ladPk and L.ladName='GPRS' and L.ladDateTo='$lastWPRS' and LR.ldrPosition <= $tophalf\n");
    $sth = $dbh->prepare("select sum(ldrPoints) as TopRanked from tblLadder L, tblLadderResult LR where LR.ladPk=L.ladPk and L.ladName=? and L.ladDateTo=? and LR.ldrPosition <= ?");
    $sth->execute($formula, $lastWPRS, $tophalf);
    $ref = $sth->fetchrow_hashref();
    my $Pq_srtp = $ref->{'TopRanked'};

    print "    Pq_srp=$Pq_srp Pq_srtp=$Pq_srtp\n";
    my $Pq_min = 0.2; 
    my $Pq = $Pq_srp / $Pq_srtp * (1 - $Pq_min) + $Pq_min;

    return ( $Pq, $Pq_srp, $Pq_srtp );
}

#
# Sort, splice to maximum 4 and sum
#
sub pil_score
{
    my ($arr) = @_;
    my $sum;

    my @sorted = sort { $b->{'score'} <=> $a->{'score'} } @$arr;
    @sorted = splice @sorted, 0, 4;
    $sum += $_->{'score'} for @sorted;

    return [ $sum, \@sorted ];
}

#
# Compute WPRS (current)
# @param dbh - database handle
# @param date - date of the WPRS to be computed
#
sub compute_wprs
{
    my ($dbh, $dateTo) = @_;
    my $sth;
    my $ref;
    my @comps;
    my %pilots;
    my %pilotcount;
    my $num_comps;
    my $Td;

    # round date ..
    #SELECT DATE_FORMAT('2007-07-12', '%Y-%m-01');
    #For each competition in previous N year period
    $sth = $dbh->prepare("select *, datediff(?,C.comDateTo) as DaysSinceEnd from tblCompetition C, tblCompFactors CF 
        where C.comPk=CF.comPk and CF.cfName=? and C.comDateTo between DATE_SUB(?, INTERVAL 3 YEAR) and ? group by C.comPk");
    $sth->execute($dateTo, $formula, $dateTo, $dateTo);
    while ($ref = $sth->fetchrow_hashref())
    {
        push @comps, $ref;
    }

    $num_comps = scalar @comps;
    print "compute_wprs: $dateTo, num_comps=", $num_comps, "\n";

    # Insert ladder in question
    my $ladPk = insertup('tblLadder', 'ladPk', "ladDateTo='$dateTo' and ladName='$formula'",
        { ladName => $formula, ladDateTo => $dateTo, ladNumComps => $num_comps } );

    # Compute each one
    # The actual WPRS formula:
    # $WPR = Pp*Pq*Pn*Ta*Td
    # To make the points more readable it is multiplied by 100 and round to 1 decimal.
    # This gives an s-curve with x in the range 0 to 1096 (days or 3 years) and y 
    # going from 1.0 to 0.0. Td_a = 2, Td_b = 20 (changing these will change shape of the s-curve).
    # (changing these will change shape of the s-curve).
    my $Td_a = 2.0;
    my $Td_b = 20.0; 
    for my $row ( @comps )
    {
        my $DaysSinceEndOfComp = $row->{'DaysSinceEnd'}; 
        $Td = 1/(1+ $Td_a ** ($DaysSinceEndOfComp/1096 * $Td_b - $Td_b/2));

        $dbh->do("delete from tblLadderCompFactors where ladPk=$ladPk and comPk=" . $row->{'comPk'});
        $sth = $dbh->prepare("insert into tblLadderCompFactors (ladPk, comPk, lcTd, lcDaySinceEnd ) values (?,?,?,?)");
        $sth->execute($ladPk, $row->{'comPk'}, $Td, $DaysSinceEndOfComp);

        $sth = $dbh->prepare("select CR.*, PF.* from tblCompResult CR, tblPilotFactors PF where CR.comPk=? and PF.pilPk=CR.pilPk and PF.cfPk=?");
        $sth->execute($row->{'comPk'}, $row->{'cfPk'});
        while ($ref = $sth->fetchrow_hashref())
        {
            if (!defined($pilots{$ref->{'pilPk'}}))
            {
                $pilots{$ref->{'pilPk'}} = [];
                $pilotcount{$ref->{'pilPk'}} = 1;
            }
            # my $WPR = round($Pp*$Pq*$Pn*$Ta*$Td*100, 1);
            #print "pil=", $ref->{'pilPk'}, " Pp=", $ref->{'cfPp'}, " Pq=", $row->{'cfPq'}, " Pn=", $row->{'cfPn'}, " Ta=", $row->{'cfTa'}, " Td=$Td\n";
            my $arr = $pilots{$ref->{'pilPk'}};
            if ($dateTo < '2007-03-01')
            {
                push @$arr, { 'comPk' => $row->{'comPk'} , 'score' => (100 * $row->{'cfCc'} * $row->{'cfPn'} * $row->{'cfTa'} * $Td * $ref->{'cfPp'} ** (1 / $row->{'cfPq'})) };
            }
            else
            {
                push @$arr, { 'comPk' => $row->{'comPk'}, 'score' => (($ref->{'cfPp'} * $row->{'cfPq'} * $row->{'cfPn'} * $row->{'cfTa'} * $Td) * 100) };
            }
        }
    }

    for my $pkey ( keys %pilots )
    {
        my $scores = pil_score($pilots{$pkey});

        $pilots{$pkey} = $scores;
    }

    #$dbh->do("insert into tblLadder (ladName, ladDateTo) values ('GPRS', '$dateTo')");
    #my $ladPk = $dbh->last_insert_id(undef, undef, "tblLadder", undef);

    # Sort pilots and insert into LadderResult
    my @sorted = sort { $pilots{$b}->[0] <=> $pilots{$a}->[0] } keys %pilots;
    my $count = 1;

    #print Dumper(\%pilots);
    $sth = $dbh->do("delete from tblLadderResult where ladPk=$ladPk");
    $sth = $dbh->prepare("insert into tblLadderResult (ladPk, pilPk, ldrPosition, ldrPoints, ldrCom1, ldrScore1, ldrCom2, ldrScore2, ldrCom3, ldrScore3, ldrCom4, ldrScore4 ) values (?,?,?,?,?,?,?,?,?,?,?,?)");
    $dbh->begin_work(); 
    for my $pil ( @sorted )
    {
        $sth->execute($ladPk,$pil,$count,$pilots{$pil}->[0],
            $pilots{$pil}->[1]->[0]->{'comPk'}, $pilots{$pil}->[1]->[0]->{'score'},
            $pilots{$pil}->[1]->[1]->{'comPk'}, $pilots{$pil}->[1]->[1]->{'score'},
            $pilots{$pil}->[1]->[2]->{'comPk'}, $pilots{$pil}->[1]->[2]->{'score'},
            $pilots{$pil}->[1]->[3]->{'comPk'}, $pilots{$pil}->[1]->[3]->{'score'}); 
        $count++;
    }
    $dbh->commit();

    # Actually print out the top 10 for debugging purposes.
    $sth = $dbh->prepare("select P.pilLastName, L.ldrPosition, L.ldrPoints from tblLadder D, tblLadderResult L, tblPilot P where L.pilPk=P.pilPk and D.ladPk=L.ladPk and D.ladDateTo=? and D.ladName=? order by L.ldrPoints desc limit 10");
    $sth->execute($dateTo, $formula);
    my @top;
    while ($ref = $sth->fetchrow_hashref())
    {
        push @top, $ref;
    }
    print Dumper(\@top);
}

#
# Compute and store the pilot placing (Pp) factors
# @param dbh - database handle
# @param date - date of the WPRS to be computed
# @param comPk - database key for the competition
# @param num_pilots - number of pilots participating in the competition
# @param minScore - minimum score in the competition
# @param maxScore - maximum score in the competition
# @param Pq - pilot quality for the competition
#
sub compute_Pp
{
    my ($dbh, $date, $comPk, $cfPk, $num_pilots, $minScore, $maxScore, $Pq) = @_;
    my $sth;

    $dbh->do("delete from tblPilotFactors where cfPk=$cfPk");

    # Insert Pilot Placing (compute_Pp) Factors
    if ($date lt '2007-03-01')
    {
        # Pp = (NumPilots - PilotPlace + 1) / NumPilots 
        $sth = $dbh->prepare("insert into tblPilotFactors (cfPk, pilPk, cfPp) 
            select cfPk, pilPk, ((? - CR.cmpPos) / ?) from 
            tblCompResult CR, tblCompFactors CF where CR.comPk=CF.comPk and CR.comPk=? and CF.cfPk=?");
        $sth->execute($num_pilots, $num_pilots, $comPk, $cfPk);
    }
    if ($date lt '2008-03-01')
    {
        $sth = $dbh->prepare("insert into tblPilotFactors (cfPk, pilPk, cfPp) 
            select cfPk, pilPk, (CR.cmpScore - ?) / (? - ?) from 
            tblCompResult CR, tblCompFactors CF where CR.comPk=CF.comPk and CR.comPk=? and CF.cfPk=?");
        $sth->execute($minScore, $maxScore, $minScore, $comPk, $cfPk);
    }
    elsif ($date lt '2009-03-01')
    {
        $sth = $dbh->prepare("insert into tblPilotFactors (cfPk, pilPk, cfPp) 
            select cfPk, pilPk, ((CR.cmpScore - ?) / (? - ?) + (? - CR.cmpPos) / (? - 1))/2 
            from tblCompResult CR, tblCompFactors CF where CR.comPk=CF.comPk and CR.comPk=? and CF.cfPk=?");
        $sth->execute($minScore, $maxScore, $minScore, $num_pilots, $num_pilots, $comPk, $cfPk);
    }
    else
    {
        # NB: this worked suprisingly well with the pre 2007-03-01 formula elsewhere (!)
        $sth = $dbh->prepare("insert into tblPilotFactors (cfPk, pilPk, cfPp) 
            select cfPk, pilPk, greatest(pow(($num_pilots - cmpPos+1)/$num_pilots, $Pq), (($num_pilots - cmpPos+1)/$num_pilots)*(($num_pilots - cmpPos+1)/$num_pilots)) 
            from tblCompResult CR, tblCompFactors CF where CR.comPk=CF.comPk and CR.comPk=? and CF.cfPk=?");
        $sth->execute($comPk,$cfPk);
    }
}

#
# Compute and store non-varying WPRS factors for a specific comp
#
sub comp_total
{
    my ($dbh, $comPk, $lastWPRS) = @_;
    my @results;
    my @pilarr;
    my $num_pilots;
    my $tot_pilots;
    my $avg_pilots;
    my $tophalf;
    my ($Pp,$Pq,$Pn,$Ta,$Td);
    my $ref;
    my $cdate;
    my $tasks;
    my $cname;
    my ($minScore, $maxScore);
    my $Cc = 0.8;

    # Task Devaluation - Ta
    #print("select *, DATE_FORMAT(comDateTo, '%Y-%m-01') as LastWPRS from tblCompetition where comPk=$comPk\n");

    # Determine Ta (task quality) and other comp info
    my $sth = $dbh->prepare("select * from tblCompetition where comPk=$comPk");
    $sth->execute();
    if ($ref = $sth->fetchrow_hashref())
    {
        $cdate = $ref->{'comDateTo'};
        $tasks = $ref->{'comTasks'};
        $cname = $ref->{'comName'};
        if ($ref->{'comSanction'} eq 'Cat-1')
        {
            $Cc = 1.0;
        }
    }
    $Ta = compute_Ta($cdate, $tasks);

    # Determine number of pilots (actually maximum position)
    $sth = $dbh->prepare("
         select CR.*, NR.ldrPosition from  tblCompResult CR 
         left outer join (select LR.* from tblLadder L, tblLadderResult LR where 
                    LR.ladPk=L.ladPk and L.ladName=? and L.ladDateTo=?) NR 
                on CR.pilPk=NR.pilPk where CR.comPk=? order by CR.cmpPos");
    $sth->execute($formula, $lastWPRS, $comPk);
    $num_pilots = 0;
    while ($ref = $sth->fetchrow_hashref())
    {
        if ($ref->{'cmpScore'} > 0)
        {
            push @pilarr, $ref;
            if ($ref->{'cmpPos'} > $num_pilots)
            {
                $num_pilots = $ref->{'cmpPos'};
            }
            if ($ref->{'cmpScore'} > $maxScore)
            {
                $maxScore = $ref->{'cmpScore'};
            }
            if ($ref->{'cmpScore'} < $minScore)
            {
                $minScore = $ref->{'cmpScore'};
            }
        }
    }

    if ($num_pilots < scalar @pilarr)
    {
        $num_pilots = scalar @pilarr;
    }

    print $cname, " comPk=$comPk Ta=$Ta num_pilots=$num_pilots lastWPRS=$lastWPRS\n";

    if ($num_pilots == 0)
    {
        my $cfPk = insertup('tblCompFactors', 'cfPk', "comPk=$comPk and cfName='$formula'",
            { 'comPk' => $comPk, 'cfName' => $formula, 'cfPq' => 0.0, 'cfPn' => 0.0, 'cfTa' => 0.0 } );
        return;
    }

    # Pq has the value of 0.2 to 1.0 based on the rankings of the pilots in the competition.
    # As the formula uses Pq as power creating a curve and Pq varies, the curve varies.
    # So the formula use the maximum value comparing the value based on the actual Pq and if 
    # this was the highest valued competition with Pq = 1.0.  

    # Pilot quality
    my ( $Pq, $srp, $srtp ) = compute_Pq($dbh, $lastWPRS, $cdate, $num_pilots, \@pilarr);

    # Pilot number
    my ( $Pn, $yrnum ) = compute_Pn($dbh, $cdate, $num_pilots);

    print "    Pq=$Pq Pn=$Pn\n";

    # Insert non-changing factors into ladder
    my $cfPk = insertup('tblCompFactors', 'cfPk', "comPk=$comPk and cfName='$formula'",
        { 'comPk' => $comPk, 'cfName' => $formula, 'cfPq' => $Pq, 'cfPn' => $Pn, 
          'cfTa' => $Ta, 'cfCc' => $Cc, 'cfSrp' => $srp, 'cfSrtp' => $srtp, 
          'cfYrnum' => $yrnum, 'cfMaxPos' => $num_pilots } );

    compute_Pp($dbh, $cdate, $comPk, $cfPk, $num_pilots, $minScore, $maxScore, $Pq);
}

#
# Main body of program below
#


my $dbh = db_connect('fai', 'localhost', 3306);
my $ref;
my $sth;
my $start = '2001-01-01';
my $comPk = 0;

if (scalar @ARGV > 0)
{
    if (index($ARGV[0], "-") > -1)
    {
        $start = $ARGV[0];
    }
    else
    {
        $comPk = 0 + $ARGV[0];
    }
}

# Precompute comp factors
if ($comPk > 0)
{
    $sth = $dbh->prepare("select *, unix_timestamp(comDateTo) as comUDate from tblCompetition where comPk=?");
    $sth->execute($comPk);
}
else
{
    $dbh->do("delete LR.* from tblLadderResult LR inner join tblLadder L on LR.ladPk=L.ladPk where L.ladDateTo > '$start' and L.ladName='$formula'");
    $dbh->do("delete from tblLadder where ladDateTo > '$start' and ladName='$formula'");

    $sth = $dbh->prepare("select *, unix_timestamp(comDateTo) as comUDate from tblCompetition where comDateTo between ? and '2021-03-01' order by comDateTo");
    $sth->execute($start);
}

my @allcomps;
while ($ref = $sth->fetchrow_hashref())
{
    push @allcomps, $ref;
}

# Temporary stuff
my @wprs_dates = ( '2001-01-01', '2002-12-01', '2003-12-01', 
                   '2004-03-01', '2004-06-01', '2004-09-01', '2004-12-01',
                   '2005-03-01', '2005-06-01', '2005-09-01', '2005-12-01',
                   '2006-03-01' );

for $ref (@allcomps)
{
    my $lastWPRS;
    my $uDate = $ref->{'comUDate'};
    my $cDate = $ref->{'comDateTo'};
    my $lastWPRS;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($uDate);
    $year += 1900;
    $mon += 1;

    if ($cDate gt '2006-03-01')
    {
        $lastWPRS = sprintf("%04d-%02d-01", $year, $mon);
    }
    else
    {
        # Hacks to lastWPRS for bootstrap
        $lastWPRS = '2001-01-01';
        for my $nextWPRS ( @wprs_dates )
        {
            if ($cDate lt $nextWPRS)
            {
                last;
            }
            $lastWPRS = $nextWPRS;
        }
    }
    print $ref->{'comName'}, " end $cDate uses $lastWPRS\n";
    
    $sth = $dbh->prepare("select * from tblLadder L, tblLadderResult LR where L.ladDateTo='$lastWPRS' and L.LadName=? and LR.ladPk=L.ladPk");
    $sth->execute($formula);
    if ($sth->rows == 0)
    {
        compute_wprs($dbh, $lastWPRS);
    }
    comp_total($dbh, $ref->{'comPk'}, $lastWPRS);
}



