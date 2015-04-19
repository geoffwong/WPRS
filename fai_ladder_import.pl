#!/usr/bin/perl
#
# No comp quality considerations
# No comp quality aging
#

require DBD::mysql;
use XML::Simple qw(:strict);
#use Algorithm::PageRank;
use Data::Dumper;
use DBLib;
use strict;

local * FD;

#
# Database handles
#

my $dbh;

#
# Extract 'fix' data into a nice record
#
sub read_membership
{
    my ($f) = @_;

    my @field;
    my $row;

    print "reading: $f\n";
    open(FD, "$f") or die "can't open $f: $!";

    while (<FD>)
    {
        $row = $_;

        print "row=$row\n";

        @field = split /,/, $row;
        print 'name: ', $field[1], ' ', $field[0], "\n";

        $dbh->do("INSERT INTO tblPilot (pilFirstName,pilLastName,pilHGFA,pilSex) VALUES (?,?,?,?)", undef, $field[1],$field[0],$field[2],'M');
    }

}


sub fix_date
{
    my ($str) = @_;
    my @arr;
    my ($yy,$mm,$dd);
    my $ret;
    my %month = ( 'Jan' => '01', 'Feb' => '02', 'Mar' => '03', 'Apr' => '04',
                  'May' => '05', 'Jun' => '06', 'Jul' => '07', 'Aug' => '08',
                  'Sep' => '09', 'Oct' => '10', 'Nov' => '11', 'Dec' => '12' );

    @arr = split / /,$str;
    $yy = $arr[2];

    $mm = $month{$arr[1]};
    $dd = $arr[0];

    $ret =  $yy.'-'.$mm.'-'.$dd;
    return $ret;
}

sub get_comp
{
    my ($comp) = @_;
    my @res;
    my @allrows;
    my @fields;
    my @subfields;
    my $out;
    my $maxscore;
    my $pilotcount;
    my $pre;
    my $rowcount;
    my $numb;
    my $score;
    my $selDateFrom;
    my $selDateTo;
    my $compname;
    my $location;
    my $lastrow;

    # Get the comp HTML from FAI website ..
    `wget -O fai/faicomp_$comp "http://civlrankings.fai.org/?a=334&competition_id=$comp"`;

    `sed s/\\\<image[^\\\>]*\\\>//g < fai/faicomp_$comp  | tidy -asxml -c -utf8 > /tmp/cleaned_$comp`;
    `./compin.pl /tmp/cleaned_$comp`;
    
    return;

    $out = `html2text -width 240 -nobs -ascii -style compact /tmp/faicomp_$comp | sed s/[^[:print:]]//g`;
    # Extract out all pilots / civl_id / and add to graph ..
    @allrows = split /\n/, $out;

    #print Dumper(\@allrows);

    $maxscore = 0;
    $pilotcount = 0;
    $pre = 0;
    $rowcount = 0;
    foreach my $row (@allrows)
    {
        @fields = split / [ ]*/, $row;
    
        if ($pre != 0)
        {
            $numb = scalar @fields;
            $score = $fields[$numb-1];
            if ($score > $maxscore)
            {
                $maxscore = $score;
            }
            if ($score > 0)
            {
                $pilotcount++;
            }
        }
        elsif ($fields[0] eq 'Periode')
        {
            @subfields = split / - /, substr($row, 8);
            $selDateTo = fix_date($subfields[1]);
            $selDateFrom = fix_date($subfields[0]);
            $pre = $rowcount;
        }
        elsif ($fields[0] eq 'Country')
        {
            $location = $fields[1];
            $compname = $lastrow;
     }
    
        $rowcount++;
        $lastrow = $row;
    }

    # add comp to db?
    # add results to db?

    return \@res;
}

sub add_ladder
{
    my ($ladPk, $start, $out) = @_;
    my $config = XMLin($out, KeyAttr => ['name', 'key', 'id'], ForceArray => 1);
    my $numpilots;
    my $grid;
    my @arr;
    my $pilPk;
    my ($cname);
    my ($rank, $civl, $name, $points);
    my @values;

    #print Dumper($config);

    $numpilots = $config->{'body'}->[0]->{'div'}->{'ctr_stuff_before_server_form'}->{'p'}->[0];
    @arr = split /: /, $numpilots;
    $numpilots = 0 + $arr[1];

    $grid = $config->{'body'}->[0]->{'form'}->{'ctr_form'}->{'div'}->[0]->{'table'}->{'ctl02_GridView1'}->{'tr'};
    #print Dumper($grid);

    if (!defined($grid))
    {
        return 0;
    }

    for my $row ( 1 .. scalar @$grid )
    {
        #print Dumper($grid->[$row]->{'td'}->[0]->{'div'});
        $rank = 0 + $grid->[$row]->{'td'}->[0]->{'div'}->[0]->{'content'};
        @arr = split /: /, $grid->[$row]->{'td'}->[1]->{'div'}->[0]->{'content'};
        $civl = 0 + $arr[1];
        $name = $grid->[$row]->{'td'}->[1]->{'a'}->[0]->{'content'}, "#\n";
        $points = $grid->[$row]->{'td'}->[4];

        my $sth = $dbh->prepare("select pilPk from tblPilot where pilCIVL=$civl");
        $sth->execute();
        my $ref = $sth->fetchrow_hashref();
        $pilPk = $ref->{'pilPk'};
        print $rank, " ", $civl, " ", $name, " ", $pilPk, "\n";
        if ($pilPk > 0)
        {
            push @values, [$ladPk,$pilPk,$rank,$points];
        }
        else
        {
            print "Unknown pilot ($name): $civl\n";
        }
    }

    my $sth = $dbh->prepare("insert into tblLadderResult (ladPk, pilPk, ldrPosition, ldrPoints) values (?, ?, ?, ?)");

    # start new transaction 
    $dbh->begin_work();  #or perhaps $dbh->do("BEGIN");
    foreach my $row (@values)
    {
       $sth->execute(@$row);
    }
    # end the transaction 
    $dbh->commit();

    return $numpilots;
}

#
# Main program here ..
#

my $flight;
my $allflights;
my $traPk;
my $totlen = 0;
my $coords;
my $numc;

my $pilPk;
my $selPk;
my $comp;
my @names;
my @allrows;
my $out;
my $pre;
my $quality;
my $sth;
my $ref;
my $pr;
my $graph = [];
#my @years = ( 2011, 2012, 2013, 2014, 2015 ); #2010 - 02 onwards still needed
my @years = ( 2004, 2005 );
#my @months = ( "01",  "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12" );
my @months = ( "03", "06", "09", "12" );

#
#
#
$comp = $ARGV[0];

$dbh = db_connect('fai', 'localhost', 3306);

# Get all the comps for a year ..
for my $yr ( @years )
{
    my $comp;
    my $res;
    my $cname;
    my $ladPk;

    for my $mt ( @months )
    {
        my $start = 1;
        my $num_pilots = 100;

        if (-f "ladder/${yr}_${mt}_01_$start")
        {
            print "Exists: ladder/${yr}_${mt}_01_$start\n"
        }
        else
        {
            `wget -O ladder/${yr}_${mt}_01_$start "http://civlrankings.fai.org/?start_rank=$start&a=326&ladder_id=3&ranking_date=${yr}-${mt}-01&"`;
        }

        # Create a new ladder (remove existing results)
        $cname = "WPRS ${yr}_${mt}_01";
        $ladPk = insertup('tblLadder', 'ladPk', "ladName='WPRS' and ladDateTo='${yr}-${mt}-01'",
            { 'ladName' => 'WPRS', 'ladDateTo' => "${yr}-${mt}-01" });
        if ($ladPk == 0)
        {
            exit 1;
        }
        $dbh->do("delete from tblLadderResult where ladPk=$ladPk");

        while ($start < $num_pilots)
        {
            #$out = `html2text -width 240 -nobs -ascii -style compact ladder/${yr}_${mt}_01_$start | sed s/[^[:print:]]//g`;
            #$out = `tidy -asxml /tmp/year_$yr > /tmp/tidy_$yr`; 

            `sed s/\\\<image[^\\\>]*\\\>//g < ladder/${yr}_${mt}_01_$start | tidy -asxml -c -utf8 > /tmp/cleaned_${yr}_${mt}`;
            $out = `tidy -asxml /tmp/cleaned_${yr}_${mt}`;
            $num_pilots = add_ladder($ladPk, $start, $out);
            $start += 100;
            if (-f "ladder/${yr}_${mt}_01_$start")
            {
                print "Exists: ladder/${yr}_${mt}_01_$start\n"
            }
            else
            {
                `wget -O ladder/${yr}_${mt}_01_$start "http://civlrankings.fai.org/?start_rank=$start&a=326&ladder_id=3&ranking_date=${yr}-${mt}-01&"`;
            }
        }

        if ($num_pilots > 0 && -f "ladder/${yr}_${mt}_01_$start")
        {
            `sed s/\\\<image[^\\\>]*\\\>//g < ladder/${yr}_${mt}_01_$start | tidy -asxml -c -utf8 > /tmp/cleaned_${yr}_${mt}`;
            $out = `tidy -asxml /tmp/cleaned_${yr}_${mt}`;
            add_ladder($ladPk, $start, $out);
        }
    }
}

#$pr = new Algorithm::PageRank;

# [ 0 => 1, 0 => 2, 1 => 0, 2 => 1, ]
#$pr->graph($graph);
#$pr->iterate();

#$pr->iterate(50);

#print $pr->result();




