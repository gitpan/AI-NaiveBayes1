#!/usr/bin/perl

use Test::More tests => 5;
use_ok("AI::NaiveBayes1");

require 't/auxfunctions.pl';

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

my $printedmodel =  "Model:\n" . $nb->print_model;

is($printedmodel, getfile('t/1-1.out'));

is($nb->export_to_YAML(), getfile('t/1-2.out'));

$nb->export_to_YAML_file('t/tmp1');

my $nb1 = AI::NaiveBayes1->import_from_YAML_file('t/tmp1');

is("Model:\n" . $nb1->print_model, getfile('t/1-1.out'));

my $tmp = $nb->export_to_YAML();
my $nb2 = AI::NaiveBayes1->import_from_YAML($tmp);
is("Model:\n" . $nb2->print_model, getfile('t/1-1.out'));
