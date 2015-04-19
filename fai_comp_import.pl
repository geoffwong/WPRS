#!/usr/bin/perl
#
# No comp quality considerations
# No comp quality aging
#

require DBD::mysql;
use XML::Simple qw(:strict);
#use Algorithm::PageRank;
use Data::Dumper;
use strict;


my $database = 'fai';
my $hostname = 'localhost';
my $port = 3306;

local * FD;


#
# Database handles
#

my $dsn;
my $dbh;
my $drh;

sub db_connect
{
    $dsn = "DBI:mysql:database=$database;host=$hostname;port=$port";
    $dbh = DBI->connect( $dsn, 'root', 'ecit5lo5', { RaiseError => 1 } )
            or die "Can't connect: $!\n";
    $drh = DBI->install_driver("mysql");
}

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
    my ($base, $yr, $comp, $ext) = @_;
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
    my $ranking;

    # Get the comp HTML from FAI website ..
    #`wget -O $base/faicomp_$comp "http://civlrankings.fai.org/?a=334&competition_id=$comp"`;
    if (-f "$base/faicomp_$comp")
    {
        print "Exists: $base/faicomp_$comp\n";
    }
    else
    {
        $yr = $yr + 1;
        $ranking = "$yr-12-01";
        if ($ext eq '334')
        {
            `wget -O $base/faicomp_$comp "http://civlrankings.fai.org/?a=334&competition_id=$comp"`;
        }
        else
        {
            `wget -O $base/faicomp_$comp "http://civlrankings.fai.org/?a=342&ladder_id=3&ranking_date=$ranking&competition_id=$comp"`;
        }
    }

    `./compin$ext.pl $base/faicomp_$comp`;

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
#my @years = ( 2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015 );
#my @years = ( 2012, 2013, 2014, 2015 );
my @years = ( 2006 );
#my @years = ( 2005, 2006, 2007, 2008, 2009, 2010, 2011 ); 
#my @years = ( 2001, 2002, 2003, 2004 );

#
#
#
$comp = $ARGV[0];

db_connect();

# Get all the comps for a year ..
for my $yr ( @years )
{
    my $comp;
    my $res;

    if (-f "fai/year_$yr")
    {
        print "fai/year_$yr exists\n";
    }
    else
    {
        `wget -O fai/year_$yr "http://civlrankings.fai.org/?a=303&l=0&discipline_id=1&year=$yr&country_id=0&nac_country_id=0&event_name=&go=Go"`;
    }
    #$out = `html2text -width 240 -nobs -ascii -style compact /tmp/year_$yr | sed s/[^[:print:]]//g`;
    #$out = `tidy -asxml /tmp/year_$yr > /tmp/tidy_$yr`; 
    $out = `tidy -asxml fai/year_$yr | grep competition_id= | grep results`;

    # suck it in and extract competition ids ..
    @allrows = split /\n/, $out;
    foreach my $row (@allrows)
    {
        #print $row, "\n";
        $row =~ /.*competition_id=(\d+).*/;
        #print "comp_id=$1\n";
        #get_comp('fai', $yr, $1, '334');
        get_comp('comp', $yr, $1, '');
    }
}

#$pr = new Algorithm::PageRank;

# [ 0 => 1, 0 => 2, 1 => 0, 2 => 1, ]
#$pr->graph($graph);
#$pr->iterate();

#$pr->iterate(50);

#print $pr->result();




