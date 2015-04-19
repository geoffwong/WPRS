#!/usr/bin/perl
#

#
# Get comp factors & tasks
#


require DBD::mysql;
use XML::Simple;
use Data::Dumper;
use File::Basename;
use DBLib;

my $database = 'fai';
my $hostname = 'localhost';
my $port = 3306;

my $allrows;
my $compinfo;
my $allranks;
my $cname;
my $dates;
my $tasks;
my @arr;
my ($from,$to);

my ($comPk,$pilPk,$resPk);
my ($Cc, $Ta, $Pn, $Pq, $Srp, $Srtp);

#$allrows = $config->{'body'}->{'form'}->{'table'}->{'tr'};

if (scalar @ARGV < 1)
{
    print "compin.pl <HTML comp file>\n";
}

my $comp = basename($ARGV[0]);
my $cleaned = "/tmp/cleaned_$comp";
`sed s/\\\<image[^\\\>]*\\\>//g < $ARGV[0] | tidy -asxml -c -b -utf8 > $cleaned`;
my $config = XMLin($cleaned);

$allrows = $config->{'body'}->{'form'}->{'table'}; #->{'tr'}; # 2009

#print Dumper($allrows);
#exit 1;

$compinfo = $allrows->[0]->{'tr'}->[1]; 
$allranks = $allrows->[1]->{'tr'}; 

$cname = $compinfo->{'td'}->[1]->{'a'}->{'content'};
$from = $compinfo->{'td'}->[0]->{'content'}->[0];
$to = $compinfo->{'td'}->[0]->{'content'}->[1];
$tasks = 0 + $compinfo->{'td'}->[8];
$Cc = 0 + $compinfo->{'td'}->[3];
if ($Cc == 0.0 || $Cc > 1.0)
{
    $CC = 0.8;
}
$Ta = 0 + $compinfo->{'td'}->[4];
$Pn = 0 + $compinfo->{'td'}->[5];
$Pq = 0 + $compinfo->{'td'}->[6];
$Srp = 0 + $compinfo->{'td'}->[10];
$Srtp = 0 + $compinfo->{'td'}->[11];

#print "Pn=$Pn Pq=$Pq Src=$Srp Srtp=$Srtp\n";

# Clean up the formatting mess
$cname =~ s/^[:ascii:]//g;
$cname =~ s/[\r\n']/ /g;
$from =~ s/^[:ascii:]//g;
$from =~ s/[\r\n']//g;
#$from=fix_date($from);
$to =~ s/^[:ascii:]//g;
$to =~ s/[\r\n']//g;
#$to=fix_date($to);

#$cname = $config->{'body'}->{'div'}->{'ctr_action_title'}->{'content'};
#$dates = $compinfo->[0]->{'td'}->[1]->{'content'};
#($from,$to) = split(/ - /, $dates);

print "Name=$cname ($tasks) on $from - $to\n";

db_connect('fai', 'localhost', 3306);

# insert_up($table, $pkey, $clause, $pairs)
$comPk = insertup('tblCompetition', 'comPk', "comName='$cname' and comDateFrom='$from'",
    { 'comName' => $cname, 'comDateFrom' => $from, 'comDateTo' => $to, 
      'comSanction' => 'Cat-2', 'comTasks' => $tasks });

my $cfPk = insertup('tblCompFactors', 'cfPk', "comPk=$comPk and cfName='WPRS'",
            { 'comPk' => $comPk, 'cfName' => 'WPRS', 'cfCc' => $Cc, 'cfPq' => $Pq, 'cfPn' => $Pn, 'cfTa' => $Ta, 'cfSrp' => $Srp, 'cfSrtp' => $Srtp });

#dbh->do("INSERT INTO tblCompetition (comName,comDateFrom,comDateTo,comSanction) VALUES (?,?,?,?)", undef, $cname,$from,$top,"Cat-2");
#$comPk = $dbh->last_insert_id(undef, undef, "tblCompetition", undef);

shift @$allranks;

#print Dumper($allranks);
#exit 1;

for my $row ( @$allranks )
{
    if (defined($row->{'td'}))
    {
        my $allinf = $row->{'td'};
        my ($pos, $score, $civl, $ref, $name, $nation);
        my ($pilPk,$fname,$lname);

        $pos = $allinf->[0]->{'content'};
        $score = $allinf->[4];
        #$nation = $allinf->[3]->{'a'}->{'content'};
        #$nation =~ s/^[:ascii:]//g;
        #$nation =~ s/[\r\n]//g;
        $name = $allinf->[7]->{'i'};
        $name =~ s/^[:ascii:]//g;
        $name =~ s/[\r\n]/ /g;
        @arr = split(/ /, $name);
        $lname = $arr[$#arr];
        pop(@arr);
        $fname = join(' ', @arr);
        $civl = $allinf->[8]->{'i'};

        #print("civl=$civl lname=$lname fname=$fname\n");
        if (defined($civl))
        {
            $pilPk = insertup('tblPilot', 'pilPk', "pilCIVL=$civl",
                { 'pilCIVL' => $civl, 'pilFirstName' => $fname, 'pilLastName' => $lname } );

            #print("comPk=$comPk pilPk=$pilPk cmpScore=$score cmpPos=$pos\n");
            $pilPk = insertup('tblCompResult', 'cmpPk', "comPk=$comPk and pilPk=$pilPk",
                { 'comPk' => $comPk, 'pilPk' => $pilPk, 'cmpScore' => $score, 'cmpPos' => $pos } );
        }

    }
}


