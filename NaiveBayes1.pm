# (c) 2003-2004 Vlado Keselj www.cs.dal.ca/~vlado
#
# $Id: NaiveBayes1.pm,v 1.13 2004/04/20 11:08:46 vlado Exp $

package AI::NaiveBayes1;
use strict;
require Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS); # Exporter vars
our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw(new);
our $VERSION = '1.1';

use vars qw($Version $Revision);
$Version = $VERSION;
($Revision = substr(q$Revision: 1.13 $, 10)) =~ s/\s+$//;

use vars @EXPORT_OK;

# non-exported package globals go here
use vars qw();

sub new {
  my $package = shift;
  return bless {
                attributes => [ ],
		labels     => [ ],
		attvals    => {},
		real_stat => {}, # statistics
		numof_instances => 0,
		stat_labels => {},
		stat_attributes => {},
	       }, $package;
}

sub set_real {
    my ($self, @attr) = @_;
    %{$self->{real_attr}} = map{$_=>1} @attr;
}

sub import_from_YAML {
    my $package = shift;
    my $yaml = shift;
    my $self = YAML::Load($yaml);
    return $self;
}

sub import_from_YAML_file {
    my $package = shift;
    my $yamlf = shift;
    my $self = YAML::LoadFile($yamlf);
    return $self;
}

sub add_instances {
  my ($self, %params) = @_;
  for ('attributes', 'label', 'cases') {
      die "Missing required '$_' parameter" unless exists $params{$_};
  }

  if (scalar(keys(%{ $self->{stat_attributes} })) == 0) {
      foreach my $a (keys(%{$params{attributes}})) {
	  $self->{stat_attributes}{$a} = {};
	  push @{ $self->{attributes} }, $a;
	  $self->{attvals}{$a} = [ ];
      }
  } else {
      foreach my $a (keys(%{$self->{stat_attributes}}))
      { die "attribute not given in instance: $a"
	    unless exists($params{attributes}{$a}) }
  }

  $self->{numof_instances} += $params{cases};

  push @{ $self->{labels} }, $params{label} unless
      exists $self->{stat_labels}->{$params{label}};

  $self->{stat_labels}{$params{label}} += $params{cases};

  foreach my $a (keys(%{$self->{stat_attributes}})) {
      if ( not exists($params{attributes}{$a}) )
      { die "attribute $a not given" }
      my $attval = $params{attributes}{$a};
      if (not exists($self->{stat_attributes}{$a}{$attval})) {
	  push @{ $self->{attvals}{$a} }, $attval;
	  $self->{stat_attributes}{$a}{$attval} = {};
      }
      $self->{stat_attributes}{$a}{$attval}{$params{label}} += $params{cases};
  }
}

sub add_instance {
    my ($self, %params) = @_; $params{cases} = 1;
    $self->add_instances(%params);
}

sub train {
    my $self = shift;
    my $m = $self->{model} = {};
    $m->{real_attr} = $self->{real_attr};
    
    $m->{labelprob} = {};
    foreach my $label (keys(%{$self->{stat_labels}}))
    { $m->{labelprob}{$label} = $self->{stat_labels}{$label} /
                                $self->{numof_instances} } 

    $m->{condprob} = {};
    foreach my $att (keys(%{$self->{stat_attributes}})) {
        next if $m->{real_attr}->{$att};
	$m->{condprob}{$att} = {};
	foreach my $attval (keys(%{$self->{stat_attributes}{$att}})) {
	    $m->{condprob}{$att}{$attval} = {};
	    foreach my $label (keys(%{$self->{stat_labels}})) {
		$m->{condprob}{$att}{$attval}{$label} =
		    $self->{stat_attributes}{$att}{$attval}{$label} /
		    $self->{stat_labels}{$label};
	    }
	}
    }

    # For real-valued attributes, we use Gaussian distribution
    # let us collect statistics
    foreach my $att (keys %{$m->{real_attr}}) {
        $m->{real_stat}->{$att} = {};
        foreach my $attval (keys %{$self->{stat_attributes}{$att}}){
            foreach my $label (keys %{$self->{stat_attributes}{$att}{$attval}}){
                $m->{real_stat}{$att}{$label}{sum}
                += $attval * $self->{stat_attributes}{$att}{$attval}{$label};

                $m->{real_stat}{$att}{$label}{count}
                += $self->{stat_attributes}{$att}{$attval}{$label};
            }
            foreach my $label (keys %{$self->{stat_attributes}{$att}{$attval}}){
		next if
                !defined($m->{real_stat}{$att}{$label}{count}) ||
		$m->{real_stat}{$att}{$label}{count} == 0;

                $m->{real_stat}{$att}{$label}{mean} =
                    $m->{real_stat}{$att}{$label}{sum} /
                        $m->{real_stat}{$att}{$label}{count};
            }
        }

        # calculate stddev
        foreach my $attval (keys %{$self->{stat_attributes}{$att}}) {
            foreach my $label (keys %{$self->{stat_attributes}{$att}{$attval}}){
                $m->{real_stat}{$att}{$label}{stddev} +=
		    ($attval - $m->{real_stat}{$att}{$label}{mean})**2 *
		    $self->{stat_attributes}{$att}{$attval}{$label};
            }
        }
	foreach my $label (keys %{$m->{real_stat}{$att}}) {
	    $m->{real_stat}{$att}{$label}{stddev} =
		sqrt($m->{real_stat}{$att}{$label}{stddev} /
		     ($m->{real_stat}{$att}{$label}{count}-1)
		     );
	}
    }				# foreach real attribute
}				# end of sub train

sub predict {
  my ($self, %params) = @_;
  my $newattrs = $params{attributes} or die "Missing 'attributes' parameter for predict()";
  my $m = $self->{model};  # For convenience
  
  my %scores;
  my @labels = @{ $self->{labels} };
  $scores{$_} = $m->{labelprob}{$_} foreach (@labels);
  foreach my $att (keys(%{ $newattrs })) {
      next if defined $m->{real_attr}->{$att};
      die unless exists($self->{stat_attributes}{$att});
      my $attval = $newattrs->{$att};
      die unless exists($self->{stat_attributes}{$att}{$attval});
      foreach my $label (@labels) {
	  $scores{$label} *=
	      $m->{condprob}{$att}{$attval}{$label};
      }
  }

  foreach my $att (keys %{$newattrs}){
      next unless defined $m->{real_attr}->{$att};
      foreach my $label (@labels) {
	  die unless exists $m->{real_stat}{$att}{$label}{mean};
	  $scores{$label} *=
              0.398942280401433 / $m->{real_stat}{$att}{$label}{stddev}*
              exp( -0.5 *
                  ( ( $newattrs->{$att} -
                      $m->{real_stat}{$att}{$label}{mean})
                    / $m->{real_stat}{$att}{$label}{stddev}
                  ) ** 2
		 );
      }
  }

  my $sumPx = 0.0;
  $sumPx += $scores{$_} foreach (keys(%scores));
  $scores{$_} /= $sumPx foreach (keys(%scores));
  return \%scores;
}

sub print_model {
    my $self = shift;
    my $m = $self->{model};
    my @labels = $self->labels;
    my $r;

    # prepare table category P(category)
    my @lines;
    push @lines, 'category ', '-';
    push @lines, "$_ " foreach @labels;
    @lines = _append_lines(@lines);
    @lines = map { $_.='| ' } @lines;
    $lines[1] = substr($lines[1],0,length($lines[1])-2).'+-';
    @lines[0] .= "P(category) ";
    foreach my $i (2..$#lines) {
	$lines[$i] .= $m->{labelprob}{$labels[$i-2]} .' ';
    }
    @lines = _append_lines(@lines);

    $r .= join("\n", @lines) . "\n". $lines[1]. "\n\n";

    # prepare conditional tables
    my @attributes = sort $self->attributes;
    foreach my $att (@attributes) {
	@lines = ( "category ", '-' );
	my @lines1 = ( "$att ", '-' );
	my @lines2 = ( "P( $att | category ) ", '-' );
	my @attvals = sort keys(%{ $self->{stat_attributes}{$att} });
	foreach my $label (@labels) {
	    if (! exists($m->{real_attr}->{$att})) {
		foreach my $attval (@attvals) {
		    push @lines, "$label ";
		    push @lines1, "$attval ";
		    push @lines2, $m->{condprob}{$att}{$attval}{$label}
		    ." ";
		}
	    } else {
		push @lines, "$label ";
		push @lines1, "real ";
		push @lines2, "Gaussian(mean=".
		    $m->{real_stat}{$att}{$label}{mean}.",stddev=".
		    $m->{real_stat}{$att}{$label}{stddev}.") ";
	    }
	}
	@lines = _append_lines(@lines);
	foreach my $i (0 .. $#lines)
	{ $lines[$i] .= ($i==1?'+-':'| ') . $lines1[$i] }
	@lines = _append_lines(@lines);
	foreach my $i (0 .. $#lines)
	{ $lines[$i] .= ($i==1?'+-':'| ') . $lines2[$i] }
	@lines = _append_lines(@lines);

	$r .= join("\n", @lines). "\n". $lines[1]. "\n\n";
    }

    return $r;
}

sub _append_lines {
    my @l = @_;
    my $m = 0;
    foreach (@l) { $m = length($_) if length($_) > $m }
    @l = map 
    { while (length($_) < $m) { $_.=substr($_,length($_)-1) }; $_ }
    @l;
    return @l;
}

sub labels {
  my $self = shift;
  return @{ $self->{labels} };
}

sub attributes {
  my $self = shift;
  return keys %{ $self->{stat_attributes} };
}

sub export_to_YAML {
    my $self = shift;
    require YAML;
    return YAML::Dump($self);
}

sub export_to_YAML_file {
    my $self = shift;
    my $file = shift;
    require YAML;
    YAML::DumpFile($file, $self);
}

1;
__END__

=head1 NAME

AI::NaiveBayes1 - Bayesian prediction of categories

=head1 SYNOPSIS

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

  foreach my $k (keys(%{ $result })) {
      print "for label $k P = " . $result->{$k} . "\n";
  }

  # export the model into a string
  my $string = $nb->export_to_YAML();

  # create the same model from the string
  my $nb1 = AI::NaiveBayes1->import_from_YAML($string);

  # write the model to a file (shorter than model->string->file)
  $nb->export_to_YAML_file('t/tmp1');

  # read the model from a file (shorter than file->string->model)
  my $nb2 = AI::NaiveBayes1->import_from_YAML_file('t/tmp1');

See Examples for more examples.

=head1 DESCRIPTION

This module implements the classic "Naive Bayes" machine learning
algorithm.

=head1 METHODS

=head2 Constructor Methods

=over 4

=item new()

Creates a new C<AI::NaiveBayes1> object and returns it.

=item set_real(list_of_attributes)

Delares a list of attributes to be real-valued.  During training,
their conditional probabilities will be modeled with Gaussian (normal)
distributions. 

=item import_from_YAML($string)

Creates a new C<AI::NaiveBayes1> object from a string where it is
represented in C<YAML>.  Requires YAML module.

=item import_from_YAML_file($file_name)

Creates a new C<AI::NaiveBayes1> object from a file where it is
represented in C<YAML>.  Requires YAML module.

=back

=head2 Methods

=over 4

=item C<add_instance(attributes=E<gt>HASH,label=E<gt>STRING|ARRAY)>

Adds a training instance to the categorizer.

=item C<add_instances(attributes=E<gt>HASH,label=E<gt>STRING|ARRAY,cases=E<gt>NUMBER)>

Adds a number of identical instances to the categorizer.

=item export_to_YAML()

Returns a C<YAML> string representation of an C<AI::NaiveBayes1>
object.  Requires YAML module.

=item C<export_to_YAML_file( $file_name )>

Writes a C<YAML> string representation of an C<AI::NaiveBayes1>
object to a file.  Requires YAML module.

=item print_model()

Returns a string, human-friendly representation of the model.
The model is supposed to be trained before calling this method.

=item train()

Calculates the probabilities that will be necessary for categorization
using the C<predict()> method.

=item C<predict( attributes =E<gt> HASH )>

Use this method to predict the label of an unknown instance.  The
attributes should be of the same format as you passed to
C<add_instance()>.  C<predict()> returns a hash reference whose keys
are the names of labels, and whose values are corresponding
probabilities.

=item C<labels>

Returns a list of all the labels the object knows about (in no
particular order), or the number of labels if called in a scalar
context.

=back

=head1 THEORY

Bayes' Theorem is a way of inverting a conditional probability. It
states:

                P(y|x) P(x)
      P(x|y) = -------------
                   P(y)

and so on... (You can read more about it in many books.)

=head1 EXAMPLES

Example with a real-valued attribute modeled by a Gaussian
distribution (from Witten I. and Frank E. book "Data Mining" (the WEKA
book), page 86):

 # @relation weather
 # 
 # @attribute outlook {sunny, overcast, rainy}
 # @attribute temperature real
 # @attribute humidity real
 # @attribute windy {TRUE, FALSE}
 # @attribute play {yes, no}
 # 
 # @data
 # sunny,85,85,FALSE,no
 # sunny,80,90,TRUE,no
 # overcast,83,86,FALSE,yes
 # rainy,70,96,FALSE,yes
 # rainy,68,80,FALSE,yes
 # rainy,65,70,TRUE,no
 # overcast,64,65,TRUE,yes
 # sunny,72,95,FALSE,no
 # sunny,69,70,FALSE,yes
 # rainy,75,80,FALSE,yes
 # sunny,75,70,TRUE,yes
 # overcast,72,90,TRUE,yes
 # overcast,81,75,FALSE,yes
 # rainy,71,91,TRUE,no
 
 $nb->set_real('temperature', 'humidity');
 
 $nb->add_instance(attributes=>{outlook=>'sunny',temperature=>85,humidity=>85,windy=>'FALSE'},label=>'play=no');
 $nb->add_instance(attributes=>{outlook=>'sunny',temperature=>80,humidity=>90,windy=>'TRUE'},label=>'play=no');
 $nb->add_instance(attributes=>{outlook=>'overcast',temperature=>83,humidity=>86,windy=>'FALSE'},label=>'play=yes');
 $nb->add_instance(attributes=>{outlook=>'rainy',temperature=>70,humidity=>96,windy=>'FALSE'},label=>'play=yes');
 $nb->add_instance(attributes=>{outlook=>'rainy',temperature=>68,humidity=>80,windy=>'FALSE'},label=>'play=yes');
 $nb->add_instance(attributes=>{outlook=>'rainy',temperature=>65,humidity=>70,windy=>'TRUE'},label=>'play=no');
 $nb->add_instance(attributes=>{outlook=>'overcast',temperature=>64,humidity=>65,windy=>'TRUE'},label=>'play=yes');
 $nb->add_instance(attributes=>{outlook=>'sunny',temperature=>72,humidity=>95,windy=>'FALSE'},label=>'play=no');
 $nb->add_instance(attributes=>{outlook=>'sunny',temperature=>69,humidity=>70,windy=>'FALSE'},label=>'play=yes');
 $nb->add_instance(attributes=>{outlook=>'rainy',temperature=>75,humidity=>80,windy=>'FALSE'},label=>'play=yes');
 $nb->add_instance(attributes=>{outlook=>'sunny',temperature=>75,humidity=>70,windy=>'TRUE'},label=>'play=yes');
 $nb->add_instance(attributes=>{outlook=>'overcast',temperature=>72,humidity=>90,windy=>'TRUE'},label=>'play=yes');
 $nb->add_instance(attributes=>{outlook=>'overcast',temperature=>81,humidity=>75,windy=>'FALSE'},label=>'play=yes');
 $nb->add_instance(attributes=>{outlook=>'rainy',temperature=>71,humidity=>91,windy=>'TRUE'},label=>'play=no');
 
 $nb->train;
 
 my $printedmodel =  "Model:\n" . $nb->print_model;
 my $p = $nb->predict(attributes=>{outlook=>'sunny',temperature=>66,humidity=>90,windy=>'TRUE'});

 YAML::DumpFile('file', $p);
 die unless (abs($p->{'play=no'}  - 0.792) < 0.001);
 die unless(abs($p->{'play=yes'} - 0.208) < 0.001);

=head1 HISTORY

Algorithms::NaiveBayes by Ken Williams was not what I needed so I
wrote this one.  Algorithms::NaiveBayes is oriented towards text
categorization, it includes smoothing, and log probabilities.  This
module is a generic, basic Naive Bayes algorithm.

=head1 THANKS

I would like to thank the following people (in chronological order):

Tom Dyson and Dan Von Kohorn for bug reports, support, and comments;

to CPAN-testers (jlatour, Jost.Krieger) for their bug reports,

and Yung-chung Lin (xern@ cpan. org) for his implementation of the
Gaussian model for continuous variables.

=head1 AUTHOR

Copyright 2003-2004 Vlado Keselj www.cs.dal.ca/~vlado

2004 Yung-chung Lin provided implementation of the Gaussian model for
continous variables.

This script is provided "as is" without expressed or implied warranty.
This is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

The module is available on CPAN (F<http://search.cpan.org/~vlado>), and
F<http://www.cs.dal.ca/~vlado/srcperl/>.  The latter site is
updated more frequently.

=head1 SEE ALSO

Algorithms::NaiveBayes, perl.

=cut
