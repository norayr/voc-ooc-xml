#!/usr/bin/perl -w

use strict;

$/=undef;
my $file=<>;
my %tests=();
while ($file =~ m:(<test.*?</test>):imsg) {
  my $elem = $1;
  my ($type) = $elem =~ m:type\s*=\s*['"]([^'"]*)['"]:i;
  my ($uri) = $elem =~ m:uri\s*=\s*['"]([^'"]*)['"]:i;
  push @{$tests{$type}}, $uri;
}
for my $i (keys %tests) {
  my $fname = "$i.list";
  print "Writing $fname\n";
  open F, ">$fname";
  print F join("\n", @{$tests{$i}}), "\n";
  close F;
}
