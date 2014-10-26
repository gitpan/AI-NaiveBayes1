#!/usr/bin/perl

use Test::More tests => 12;
use_ok("AI::NaiveBayes1");

require 't/auxfunctions.pl';

my $nb = AI::NaiveBayes1->new;

$nb->add_instances(attributes=>{C=>'Y',F=>2},label=>'S=Y',cases=>30);
$nb->add_instances(attributes=>{C=>'Y',F=>2},label=>'S=N',cases=>10);
$nb->add_instances(attributes=>{C=>'Y',F=>0},label=>'S=Y',cases=>18);
$nb->add_instances(attributes=>{C=>'Y',F=>0},label=>'S=N',cases=>16);
$nb->add_instances(attributes=>{C=>'N',F=>2},label=>'S=Y',cases=>22);
$nb->add_instances(attributes=>{C=>'N',F=>2},label=>'S=N',cases=>14);
$nb->add_instances(attributes=>{C=>'N',F=>0},label=>'S=Y',cases=> 6);
$nb->add_instances(attributes=>{C=>'N',F=>0},label=>'S=N',cases=>84);

$nb->train;

my $printedmodel =  "Model:\n" . $nb->print_model;

#putfile('t/6-1.out', $printedmodel);
is($printedmodel, getfile('t/6-1.out'));

$nb->export_to_YAML_file('t/tmp6');
my $nb1 = AI::NaiveBayes1->import_from_YAML_file('t/tmp6');

is("Model:\n" . $nb1->print_model, getfile('t/6-1.out'));

my $p = $nb->predict(attributes=>{C=>'Y',F=>0});

#putfile('t/6-2.out', YAML::Dump($p));
ok(abs($p->{'S=N'} - 0.580) < 0.001);
ok(abs($p->{'S=Y'} - 0.420) < 0.001);

# Continual

$nb = AI::NaiveBayes1->new;

$nb->add_instances(attributes=>{C=>'Y',F=>2},label=>'S=Y',cases=>30);
$nb->add_instances(attributes=>{C=>'Y',F=>2},label=>'S=N',cases=>10);
$nb->add_instances(attributes=>{C=>'Y',F=>0},label=>'S=Y',cases=>18);
$nb->add_instances(attributes=>{C=>'Y',F=>0},label=>'S=N',cases=>16);
$nb->add_instances(attributes=>{C=>'N',F=>2},label=>'S=Y',cases=>22);
$nb->add_instances(attributes=>{C=>'N',F=>2},label=>'S=N',cases=>14);
#$nb->add_instances(attributes=>{C=>'N',F=>0},label=>'S=Y',cases=> 6);
#$nb->add_instances(attributes=>{C=>'N',F=>0},label=>'S=N',cases=>84);
$nb->add_table("  C   F   S  count\n".
               "------------------\n".
	       "  N   0   Y    6  \n".
	       "  N   0   N   84  \n".
	       '');

$nb->set_real('F');
$nb->train;

$printedmodel =  "Model:\n" . $nb->print_model;

#putfile('t/6-3.out', $printedmodel);
is($printedmodel, getfile('t/6-3.out'));

$nb->export_to_YAML_file('t/tmp6-2');
$nb1 = AI::NaiveBayes1->import_from_YAML_file('t/tmp6-2');

is("Model:\n" . $nb1->print_model, getfile('t/6-3.out'));

$p = $nb->predict(attributes=>{C=>'Y',F=>1});

#putfile('t/6-4.out', YAML::Dump($p));
ok(abs($p->{'S=N'} - 0.339) < 0.001);
ok(abs($p->{'S=Y'} - 0.661) < 0.001);

$nb = AI::NaiveBayes1->new;
$nb->add_table(
"Html  Caps  Free  Spam  count
-------------------------------
   Y     Y     Y     Y    42   
   Y     Y     Y     N    32   
   Y     Y     N     Y    17   
   Y     Y     N     N     7   
   Y     N     Y     Y    32   
   Y     N     Y     N    12   
   Y     N     N     Y    20   
   Y     N     N     N    16   
   N     Y     Y     Y    38   
   N     Y     Y     N    18   
   N     Y     N     Y    16   
   N     Y     N     N    16   
   N     N     Y     Y     2   
   N     N     Y     N     9   
   N     N     N     Y    11   
   N     N     N     N    91   
-------------------------------
");
$nb->train;
$printedmodel =  "Model:\n" . $nb->print_model;
#putfile('t/7-1.out', $printedmodel);
is($printedmodel, getfile('t/7-1.out'));

$p = $nb->predict(attributes=>{Html=>'N',Caps=>'N',Free=>'Y'});
# putfile('t/7-2.out', YAML::Dump($p));

ok(abs($p->{'Spam=N'} - 0.6580) < 0.001);
ok(abs($p->{'Spam=Y'} - 0.3420) < 0.001);
