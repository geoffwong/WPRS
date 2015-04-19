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
my $tasks;
my @arr;
my ($from,$to);

my ($comPk,$pilPk,$resPk);

#$allrows = $config->{'body'}->{'form'}->{'table'}->{'tr'};
$allrows = $config->{'body'}->{'form'}->{'table'}; #->{'tr'}; # 2009

#print Dumper($allrows);
#exit 1;

$compinfo = $allrows->[0]->{'tr'}->[1]; 
$allranks = $allrows->[1]->{'tr'}; 

$cname = $compinfo->{'td'}->[1]->{'a'}->{'content'};
$from = $compinfo->{'td'}->[0]->{'content'}->[0];
$to = $compinfo->{'td'}->[0]->{'content'}->[1];
$tasks = $compinfo->{'td'}->[8];

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
    
