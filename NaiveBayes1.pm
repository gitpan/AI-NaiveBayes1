# (c) 2003 Vlado Keselj www.cs.dal.ca/~vlado
#
# $Id: NaiveBayes1.pm,v 1.10 2003/09/04 11:05:25 vlado Exp $

package AI::NaiveBayes1;

use strict;

require Exporter;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS); # Exporter vars

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw(new);
our $VERSION = '1.0';

use vars qw($Version $Revision);
$Version = $VERSION;
($Revision = substr(q$Revision: 1.10 $, 10)) =~ s/\s+$//;

use vars @EXPORT_OK;

# non-exported package globals go here
use vars qw();

sub new {
  my $package = shift;
  return bless {
                attributes => [ ],
		labels     => [ ],
		attvals    => {},
		numof_instances => 0,
		stat_labels => {},
		stat_attributes => {},
	       }, $package;
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
    
    $m->{labelprob} = {};
    foreach my $label (keys(%{$self->{stat_labels}}))
    { $m->{labelprob}{$label} = $self->{stat_labels}{$label} /
                                $self->{numof_instances} } 
    $m->{condprob} = {};
    foreach my $att (keys(%{$self->{stat_attributes}})) {
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
}

sub predict {
  my ($self, %params) = @_;
  my $newattrs = $params{attributes} or die "Missing 'attributes' parameter for predict()";
  my $m = $self->{model};  # For convenience
  
  my %scores;
  my @labels = @{ $self->{labels} };
  $scores{$_} = $m->{labelprob}{$_} foreach (@labels);
  foreach my $att (keys(%{ $newattrs })) {
      die unless exists($self->{stat_attributes}{$att});
      my $attval = $newattrs->{$att};
      die unless exists($self->{stat_attributes}{$att}{$attval});
      foreach my $label (@labels) {
	  $scores{$label} *=
	      $m->{condprob}{$att}{$attval}{$label};
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
    @lines[0] .= "P(category)";
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
	my @lines2 = ( "P( $att | category )", '-' );
	my @attvals = sort keys(%{ $self->{stat_attributes}{$att} });
	foreach my $label (@labels) {
	    foreach my $attval (@attvals) {
		push @lines, "$label ";
		push @lines1, "$attval ";
		push @lines2, $m->{condprob}{$att}{$attval}{$label}
		              ." ";
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


=head1 DESCRIPTION

This module implements the classic "Naive Bayes" machine learning
algorithm.

=head1 METHODS

=head2 Constructor Methods

=over 4

=item new()

Creates a new C<AI::NaiveBayes1> object and returns it.

=item import_from_YAML( $string )

Creates a new C<AI::NaiveBayes1> object from a string where it is
represented in C<YAML>.  Requires YAML module.

=item import_from_YAML_file( $file_name )

Creates a new C<AI::NaiveBayes1> object from a file where it is
represented in C<YAML>.  Requires YAML module.

=back

=head2 Methods

=over 4

=item add_instance( attributes => HASH, label => STRING|ARRAY )

Adds a training instance to the categorizer.

=item add_instances( attributes => HASH, label => STRING|ARRAY, cases => NUMBER )

Adds a number of identical instances to the categorizer.

=item export_to_YAML()

Returns a C<YAML> string representation of an C<AI::NaiveBayes1>
object.  Requires YAML module.

=item export_to_YAML_file( $file_name )

Writes a C<YAML> string representation of an C<AI::NaiveBayes1>
object to a file.  Requires YAML module.

=item print_model()

Returns a string, human-friendly representation of the model.
The model is supposed to be trained before calling this method.

=item train()

Calculates the probabilities that will be necessary for categorization
using the C<predict()> method.

=item predict( attributes => HASH )

Use this method to predict the label of an unknown instance.  The
attributes should be of the same format as you passed to
C<add_instance()>.  C<predict()> returns a hash reference whose keys
are the names of labels, and whose values are corresponding
probabilities.

=item labels

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

=head1 HISTORY

Algorithms::NaiveBayes by Ken Williams was not what I needed so I
wrote this one.  Algorithms::NaiveBayes is oriented towards text
categorization, it includes smoothing, and log probabilities.  This
module is a generic, basic Naive Bayes algorithm.

=head1 THANKS

I'd like to thank Tom Dyson and Dan Von Kohorn for bug reports,
support, and comments; and to CPAN-testers (jlatour, Jost.Krieger) for
their bug reports.

=head1 AUTHOR

Copyright 2003 Vlado Keselj www.cs.dal.ca/~vlado

This script is provided "as is" without expressed or implied warranty.
This is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

The latest version can be found at F<http://www.cs.dal.ca/~vlado/srcperl/>.

=head1 SEE ALSO

Algorithms::NaiveBayes, L<perl>.

=cut
