#!/usr/bin/perl
#

use XML::Simple;
use Data::Dumper;


sub get_comp
{
    my ($comp) = @_;
    my @res;

    # Get the comp HTML from FAI website ..
    `wget -O /tmp/faicomp_$comp "http://civlrankings.fai.org/?a=334&competition_id=$comp"`;

    return;

    #$out = `html2text -width 240 -nobs -ascii -style compact /tmp/faicomp_$comp | sed s/[^[:print:]]//g`;
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

my $config = XMLin($ARGV[0]);
my $allrows;


#print Dumper($config);
#$allrows = $config->{'body'}->{'div'}->{'form'}; #->{'table'}->{'tr'}; # 2009
$allrows = $config->{'body'}->{'form'}->{'table'}->{'tr'};
#print Dumper($allrows);

for my $row ( @$allrows )
{
    if (defined($row->{'td'}))
    {
        my $allinf = $row->{'td'};
        my ($dates, $name, $ref, $id);
        my @arr;

        $dates = $allinf->[0]->{'content'};
        $name = $allinf->[1]->{'a'}->{'content'};
        $ref = $allinf->[1]->{'a'}->{'href'};
        @arr = split(/=/, $ref);
        $id = $arr[$#arr];
        $name =~ s/^[:ascii:]//g;
        $name =~ s/[\r\n]//g;
        if ($allinf->[1]->{'i'}->{'a'}->{'content'} eq "results")
        {
            print "Fetching: $name ($id)\n";
            get_comp($id);
        }
    }
}


