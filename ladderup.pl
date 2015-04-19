#!/usr/bin/perl
#

require DBD::mysql;
use XML::Simple;
use Data::Dumper;
use DBLib;

my $database = 'fai';
my $hostname = 'localhost';
my $port = 3306;

my $config = XMLin($ARGV[0]);
my $allrows;
my $compinfo;
my $allranks;
my $cname;
my $dates;
my @arr;
my ($from,$to);

my ($comPk,$pilPk,$resPk);

#$allrows = $config->{'body'}->{'form'}->{'table'}->{'tr'};
$allrows = $config->{'body'}->{'form'}->{'div'}->{'table'}; #->{'tr'}; # 2009

$compinfo = $allrows->[0]->{'tr'}; 
$cname = $config->{'body'}->{'div'}->{'ctr_action_title'}->{'content'};
$dates = $compinfo->[2]->{'td'}->[1]->{'content'};

$allranks = $allrows->[1]->{'tr'};

$cname =~ s/^[:ascii:]//g;
$cname =~ s/[\r\n']//g;
print "Name=$cname on $dates\n";
($from,$to) = split(/ - /, $dates);

#print Dumper($allranks);

db_connect('fai', 'localhost', 3306);

# insert_up($table, $pkey, $clause, $pairs)
$from=fix_date($from);
$to=fix_date($to);
$ladPk = insertup('tblLadder', 'ladPk', "ladName='$cname' and ladDateTo='$from'",
    { 'ladName' => $cname, 'ladDateTo' => $from });
    
for my $row ( @$allranks )
{
    if (defined($row->{'td'}))
    {
        my $allinf = $row->{'td'};
        my ($pos, $points, $civl );
        my ($pilPk,$fname,$lname);

        $pos = $allinf->[0]->{'content'};
        $points = $allinf->[1]->{'content'};
        $civl = $arr[$#arr];
        # do->"select * from tblPilot where pilCIVL=$civl"
        #print("INSERT INTO tblPilot (pilFirstName,pilLastName,pilNation) VALUES ($fname,$lname,$nation)\n");
        $pilPk = insertup('tblPilot', 'pilPk', "pilCIVL=$civl",
            { 'pilCIVL' => $civl, 'pilFirstName' => $fname, 
            'pilLastName' => $lname, 'pilNation' => $nation } );
        #print("INSERT INTO tblCompResult ($comPk,$pilPk,$pos,$score)\n");
        $pilPk = insertup('tblLadderResult', 'ladPk', "ladPk=$ladPk and pilPk=$pilPk",
            { 'ladPk' => $ladPk, 'pilPk' => $pilPk, 'ldrPosition' => $pos, 'ldrPoints' => $points } );

    }
}


