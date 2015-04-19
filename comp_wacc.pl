#!/usr/bin/perl

#
#

require DBD::mysql;
use XML::Simple qw(:strict);
use Data::Dumper;
use DBLib;
use strict;

#
# Determine the normalised predicted 'distance' between ladder and results
# What to do about unranked pilots?
#
sub compute_accuracy
{
    my ($dbh, $comref, $lastWPRS, $formula) = @_;
    my @pilarr;
    my ($total, $totalpp, $totalpr);
    my $sth;
    my $ref;

    # Find all the pilots actual ladder positions and sort accordingly
    $sth = $dbh->prepare("
         select CR.*, NR.ldrPosition from tblCompResult CR 
         left outer join (select LR.* from tblLadder L, tblLadderResult LR where 
                    LR.ladPk=L.ladPk and L.ladName=? and L.ladDateTo=?) NR 
                on CR.pilPk=NR.pilPk where CR.comPk=? order by CR.cmpPos");
    $sth->execute($formula, $lastWPRS, $comref->{'comPk'});

    while ($ref = $sth->fetchrow_hashref())
    {
        push @pilarr, $ref;
    }
    #print Dumper(\@pilarr);

    # Sort by ldrPosition (to give expected comp position)
    # FIX: what to do about unranked pilots?
    my @pilarr = sort { $a->{'ldrPosition'} <=> $b->{'ldrPosition'} } @pilarr;

    # Compute offset
    my $raw_tot = 0;
    my $big_offset_weight = 1.3;
    my $worst_pilot_weight = 0.0;
    my $expected = 1;
    my $ranked = 0;
    my $num_pilots = scalar @pilarr;
    my $max;

    for my $pil ( @pilarr )
    {
        my $pos = 0 + $pil->{'ldrPosition'};
        my $rev_expected;
        if ($pos > 0)
        {
            $total = $total + ((abs($expected - $pil->{'cmpPos'}) ** $big_offset_weight)) / (1+log($pos));
            $raw_tot = $raw_tot + abs($expected - $pil->{'cmpPos'});
            $rev_expected = abs(2*$expected - ($num_pilots+1));
            $worst_pilot_weight += (($rev_expected**$big_offset_weight) / (1+log($pos)));
            $ranked++;
            #print("total=$total raw_tot=$raw_tot maxd=$maxd tpw=$worst_pilot_weight ranked=$ranked expected=$expected\n");
        }
        $expected++;
    }

    # Normalise to number of pilots
    if ($ranked > 0)
    {
        $totalpp = $total / $ranked;
        $totalpr = 1.0 - ($total / $worst_pilot_weight);
    }
    else
    {
        $total = 0;
        $totalpp = 0;
        $totalpr = 0;
    }

    # Store in tblCompFactors
    # cfWacc - WPRS Weighted Accuracy
    # cfWApp - Wacc per ranked pilot
    # cfRaw  - naive distance from WPRS
    # cfWapr - 1 - (Wacc / Reversed_Expected_Order)
    my $comPk = $comref->{'comPk'};
    my $cfPk = insertup('tblCompFactors', 'cfPk', "comPk=$comPk and cfName='$formula'",
                { 'comPk' => $comPk, 'cfName' => $formula, 'cfWAcc' => $total, 'cfWApp' => $totalpp, 'cfWApr' => $totalpr, 'cfRaw' => $raw_tot });

    #$sth = $dbh->prepare("update tblCompFactors set cfWacc=? where comPk=? and cfName=?");
    #$sth->execute($total, $comref->{'comPk'}, $formula);

    # Print out for debugging
    print "Comp ($formula): ", $comPk, " = ", $total, "\n";
}

if (scalar @ARGV < 1)
{
    print "compute_accuracy.pl <formula name> [ comPk ]\n";
    exit 1;
}

my $formula = $ARGV[0];
my $dbh = db_connect('fai', 'localhost', 3306);
my $ref;
my $sth;
my @allcomps;

my @wprs_dates = ( '2001-01-01', '2002-12-01', '2003-12-01',
                   '2004-03-01', '2004-06-01', '2004-09-01', '2004-12-01',
                   '2005-03-01', '2005-06-01', '2005-09-01', '2005-12-01',
                   '2006-03-01' );

# Precompute comp factors
#my $sth = $dbh->prepare("select *, DATE_FORMAT(comDateTo, '%Y-%m-01') as LastWPRS from tblCompetition where comDateTo > '2010-01-01'");

if (scalar @ARGV > 1)
{
    $sth = $dbh->prepare("select *, unix_timestamp(comDateTo) as comUDate from tblCompetition where comPk=?");
    $sth->execute($ARGV[1]);
}
else
{
    $sth = $dbh->prepare("select *, unix_timestamp(comDateTo) as comUDate from tblCompetition where comDateTo between '2001-01-01' and '2021-03-01' order by comDateTo");
    $sth->execute();
}

while ($ref = $sth->fetchrow_hashref())
{
    push @allcomps, $ref;
}


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

    compute_accuracy($dbh, $ref, $lastWPRS, $formula);
}



