#!/usr/bin/perl

#
# Some track/database handling stuff
# And a bunch of big circle geometry stuff
#
# Notes: UTC is 13 seconds later than GPS time (!)
#        metres, kms, kms/h, DDMMYY HHMMSSsss, true north,
#        DDMM.MMMM (NSEW designators), hPascals
#
# Geoff Wong 2015
#
require DBD::mysql;

use Math::Trig;
use Data::Dumper;

$pi = atan2(1,1) * 4;    # accurate PI.

local * FD;

my %months =
(
    'Jan' => '01',
    'Feb' => '02',
    'Mar' => '03',
    'Apr' => '04',
    'May' => '05',
    'Jun' => '06',
    'Jul' => '07',
    'Aug' => '08',
    'Sep' => '09',
    'Oct' => '10',
    'Nov' => '11',
    'Dec' => '12'
);

#
# Database handling
#

my $dsn;
my $dbh;
my $drh;

sub db_connect
{
    my ($database,$hostname,$port) = @_;
    $dsn = "DBI:mysql:database=$database;host=$hostname;port=$port";
    $dbh = DBI->connect( $dsn, 'root', 'ecit5lo5', { RaiseError => 1 } )
            or die "Can't connect: $!\n";
    $drh = DBI->install_driver("mysql");
    return $dbh;
}

sub fix_date
{
    my ($str) = @_;
    my @arr;

    @arr = split(/ /, $str);
    #print Dumper(@arr);
    return $arr[2] . '-' . $months{$arr[1]} . '-' . $arr[0];
}

sub insertup
{
    my ($table, $pkey, $clause, $pairs) = @_;
    my @keys;
    my @keystr;
    my $val;
    my $qmarks = '?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?';
    my $size;
    my $ref;
    my $sth;
    my $fields;

    @keys = keys %$pairs;

    if (defined($clause))
    {
        #print("select * from $table where $clause\n");
        $sth = $dbh->prepare("select * from $table where $clause");
        $sth->execute();
        $ref = $sth->fetchrow_hashref();
    }

    if (defined($ref))
    {
        # update fields
        for my $k ( @keys )
        {
            if ($pairs->{$k} ne '')
            {
                $ref->{$k} = $pairs->{$k};
            }

            push @keystr, $k . "=" . $dbh->quote($ref->{$k});
        }

        # create nice string
        $fields = join ",", @keystr;

        #print ("update $table set $fields where $clause\n");
        $dbh->do("update $table set $fields where $clause", undef);
        # return requested key value ..
        #print "insertup: ", $ref->{$pkey}, "\n";
        return $ref->{$pkey};
    }
    else
    {
        # else insert
        $fields = join(',', @keys);
        $size = scalar @keys;
        $qmarks = substr($qmarks, 0, $size*2-1);
        #print("INSERT INTO $table ($fields) VALUES ($qmarks)\n");
        #print Dumper($pairs);
        $dbh->do("INSERT INTO $table ($fields) VALUES ($qmarks)", undef, values %$pairs);
        # get last key insert for primary key value ..
        return $dbh->last_insert_id(undef,undef,$table,undef);
    }
}
1;
