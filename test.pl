# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 2 };
use AI::NaiveBayes1;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

#mkdir 'tmp', 0700 unless -d 'tmp';
#mkdir 'AI', 0700 unless -d 'AI';
#`ln -s ../NaiveBayes1.pm AI/NaiveBayes1.pm`;

print "perl testfiles/test1.pl > testfiles/tmp1\n";
print `perl testfiles/test1.pl > testfiles/tmp1`;
my $f = getfile('testfiles/tmp1');
my $f1 = getfile('testfiles/test1.out');
ok( $f eq $f1);

sub getfile($) {
    my $f = shift;
    local *F;
    open(F, "<$f") or die "getfile:cannot open $f:$!";
    my @r = <F>;
    close(F);
    return wantarray ? @r : join ('', @r);
}
