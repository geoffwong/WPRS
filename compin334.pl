#!/usr/bin/perl
#
#
# Get names / values from pilot list & score page
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
my @arr;
my ($from,$to);

my ($comPk,$pilPk,$resPk);

#$allrows = $config->{'body'}->{'form'}->{'table'}->{'tr'};
if (scalar @ARGV < 1)
{
    print "compin.pl <HTML comp file>\n";
}

$comp = basename($ARGV[0]);
my $cleaned = "/tmp/cleaned_$comp";
`sed s/\\\<image[^\\\>]*\\\>//g < $ARGV[0]  | tidy -asxml -c -b -utf8 > $cleaned`;
my $config = XMLin($cleaned);

$allrows = $config->{'body'}->{'form'}->{'div'}->{'table'}; #->{'tr'}; # 2009

$compinfo = $allrows->[0]->{'tr'}; 
$cname = $config->{'body'}->{'div'}->{'ctr_action_title'}->{'content'};
$dates = $compinfo->[2]->{'td'}->[1]->{'content'};

$allranks = $allrows->[1]->{'tr'};

$cname =~ s/^[:ascii:]//g;
$cname =~ s/[\r\n']/ /g;
print "Name=$cname on $dates\n";
($from,$to) = split(/ - /, $dates);


db_connect('fai', 'localhost', 3306);

# insert_up($table, $pkey, $clause, $pairs)
$from=fix_date($from);
$to=fix_date($to);
$comPk = insertup('tblCompetition', 'comPk', "comName='$cname' and comDateFrom='$from'",
    { 'comName' => $cname, 'comDateFrom' => $from, 'comDateTo' => $to, 'comSanction' => 'Cat-2' });
    
#dbh->do("INSERT INTO tblCompetition (comName,comDateFrom,comDateTo,comSanction) VALUES (?,?,?,?)", undef, $cname,$from,$top,"Cat-2");
#$comPk = $dbh->last_insert_id(undef, undef, "tblCompetition", undef);


for my $row ( @$allranks )
{
    if (defined($row->{'td'}))
    {
        my $allinf = $row->{'td'};
        my ($pos, $score, $civl, $ref, $name, $nation);
        my ($pilPk,$fname,$lname);

        $pos = $allinf->[0]->{'content'};
        $score = $allinf->[6]->{'content'};
        $nation = $allinf->[3]->{'a'}->{'content'};
        $nation =~ s/^[:ascii:]//g;
        $nation =~ s/[\r\n]//g;
        if (defined($allinf->[1]->{'a'}))
        {
            $name = $allinf->[1]->{'a'}->{'content'};
            $ref = $allinf->[1]->{'a'}->{'href'};
            @arr = split(/=/, $ref);
            $civl = $arr[$#arr];
        }
        else
        {
            $name = $allinf->[1]->{'content'};
            $civl = rand() % 100000 + 100000;
            $nation = 'Unknown';
        }

        # Extract first/last names
        $name =~ s/^[:ascii:]//g;
        $name =~ s/[\r\n]//g;
        @arr = split(/ /, $name);
        $lname = $arr[$#arr];
        pop(@arr);
        $fname = join(' ', @arr);

        print("INSERT INTO tblPilot (pilFirstName,pilLastName,pilNation) VALUES ($fname,$lname,$nation)\n");
        $pilPk = insertup('tblPilot', 'pilPk', "pilCIVL=$civl",
            { 'pilCIVL' => $civl, 'pilFirstName' => $fname, 
            'pilLastName' => $lname, 'pilNation' => $nation } );
        print("INSERT INTO tblCompResult ($comPk,$pilPk,$pos,$score)\n");
        $pilPk = insertup('tblCompResult', 'cmpPk', "comPk=$comPk and pilPk=$pilPk",
            { 'comPk' => $comPk, 'pilPk' => $pilPk, 
            'cmpScore' => $score, 'cmpPos' => $pos } );

    }
}


