#!/usr/bin/perl -Iblib/lib

use AI::NaiveBayes1;
my $nb = AI::NaiveBayes1->new;

$nb->add_instances(attributes=>{model=>'H',place=>'B'},label=>'repairs=Y',cases=>30);
$nb->add_instances(attributes=>{model=>'H',place=>'B'},label=>'repairs=N',cases=>10);
$nb->add_instances(attributes=>{model=>'H',place=>'N'},label=>'repairs=Y',cases=>18);
$nb->add_instances(attributes=>{model=>'H',place=>'N'},label=>'repairs=N',cases=>16);
$nb->add_instances(attributes=>{model=>'T',place=>'B'},label=>'repairs=Y',cases=>22);
$nb->add_instances(attributes=>{model=>'T',place=>'B'},label=>'repairs=N',cases=>14);
$nb->add_instances(attributes=>{model=>'T',place=>'N'},label=>'repairs=Y',cases=> 6);
$nb->add_instances(attributes=>{model=>'T',place=>'N'},label=>'repairs=N',cases=>84);

$nb->train;

print "Model:\n" . $nb->print_model;
  
# Find results for unseen instances
my $result = $nb->predict
    (attributes => {model=>'T', place=>'N'});

print &toString($result);

# preserves order, flattens array refs
sub union {
    my @r = ();
    my %elements;
    while (@_) {
        my $e = shift(@_);
        while (ref($e) eq "ARRAY") {
            unshift @_, @{ $e };
            $e = shift(@_);
        }
        next if exists($elements{$e});
        push @r, $e;
        $elements{$e} = 1;
    }
    return @r;
}

# preserves first order, arguments are array refs
sub intersection {
    my @r = @{ shift(@_) };
    my $c = 1;
    my %hash;
    foreach my $e (@r) { $hash{$e} = 1 }
    while (@_) {
        ++ $c;
        my @s = @{ shift(@_) };
        foreach my $e (@s)
        { ++ $hash{$e} if exists( $hash{$e} ) }
    }
    my @r1;
    foreach my $e (@r) { push @r1, $e if $hash{$e} == $c }
    return @r1;
}

# Produce string representation of a hash whose ref is given as the
# first parameter.
# other parameters are options:
#  --email-style  - email headers style
#  --key-order=k1,k2... - key order (other keys are alphabetically
# appended)
#
# Union and intersection subroutines required.
#
sub toString($@) {
    my $x = shift;
    my $emailstyle = '';
    my @keyorder = ();
    while (@_) {
        my $o = shift;
        if ($o eq '--email-style') { $emailstyle = 1 }
        elsif ($o =~ /^--key-order=/) { @keyorder = split(',', $') }
        else { die "unknown option:$o" }
    }

    my $r;
    if (ref($x) eq "HASH") {
        my @keys =
            intersection( [union(@keyorder, sort(keys(%{ $x })))],
                          [sort(keys(%{ $x }))] );

	if (not @keys) {
	    return "{ }" unless $emailstyle;
	    die "don't know how to represent empty hash in email style";
	}

        if (not $emailstyle) { $r = "{\n" }
        foreach my $k (@keys) {
            my $v = $x->{$k};
            if ($emailstyle) { $r .= "$k:$v\n" }
            else {
                $k =~ s/\\/\\\\/g; $k =~ s/'/\\'/g;
                $v =~ s/\\/\\\\/g; $v =~ s/'/\\'/g;
                $r .= "  '$k' => '$v',\n";
            }
        }
	$r =~ s/,\n$/\n}\n/;
        return $r;
    }
    else { die "not yet implemented ref=: ".ref($x) }
}
