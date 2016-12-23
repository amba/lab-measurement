#!perl

use warnings;
use strict;
use 5.010;

use Test::More;
use File::Temp qw/tempfile/;
use Lab::Moose::DataFile::Read;
use Data::Dumper;
use PDL;

my ( undef, $file ) = tempfile();
open my $fh, '+>', $file
    or die "cannot open";

{
    package Myreader;
    use Moose;
    with 'Lab::Moose::DataFile::Read';
}

print {$fh} <<"EOF";
# x y
1 2
3\t4
\t
5 6
7 8
9  10
EOF

my $reader          = Myreader->new();
my @cols            = @{ $reader->read_2d_gnuplot_format( fh => $fh ) };
my @perl_array_cols = map { unpdl($_) } @cols;

my $expected = [ [ 1, 3, 5, 7, 9 ], [ 2, 4, 6, 8, 10 ] ];

is_deeply( \@perl_array_cols, $expected, "read 2 columns" );

print {$fh} "11 12\n";

@cols = @{ $reader->read_2d_gnuplot_format( fh => $fh ) };
@perl_array_cols = map { unpdl($_) } @cols;

$expected = [ [ 1, 3, 5, 7, 9, 11 ], [ 2, 4, 6, 8, 10, 12 ] ];

is_deeply( \@perl_array_cols, $expected, "added one more line" );

done_testing();

