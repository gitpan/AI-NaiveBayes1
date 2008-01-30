#!/usr/bin/perl

sub compare_by_line {
    my $got = shift;
    my $file = shift;
    my $expected = getfile($file);
    if ($got eq $expected) { pass; return }
    print STDERR "Failed comparison with $file!\n";
    while ($got ne '' or $expected ne '') {
	$got =~ /^.*\n?/;      my $a = $&; $got = $';
	$expected =~ /^.*\n?/; my $b = $&; $expected = $';
	if ($a ne $b) {
	    print STDERR "     Got: $a".
                 	 "Expected: $b";
	}
    }
    fail;
}

sub shorterdecimals {
    local $_ = shift;
    s/(\.\d{14})\d+/$1/g;
    return $_;
}

sub getfile($) {
    my $f = shift;
    local *F;
    open(F, "<$f") or die "getfile:cannot open $f:$!";
    my @r = <F>;
    close(F);
    return wantarray ? @r : join ('', @r);
}

sub putfile($@) {
    my $f = shift;
    local *F;
    open(F, ">$f") or die "putfile:cannot open $f:$!";
    print F '' unless @_;
    while (@_) { print F shift(@_) }
    close(F);
}

1;
