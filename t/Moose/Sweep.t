#!perl

use warnings;
use strict;
use 5.010;
use lib 't';
use Test::More;
use Lab::Test import => ['file_ok'];

use Lab::Moose;
use Lab::Moose::Sweep;

use File::Temp qw/tempdir/;

my $dir = tempdir();

my $gate = instrument(
    type                 => 'DummySource',
    connection_type      => 'Debug',
    verbose              => 0,
    max_units            => 10,
    min_units            => -10,
    max_units_per_step   => 1,
    max_units_per_second => 100
);

my $bias = instrument(
    type                 => 'DummySource',
    connection_type      => 'Debug',
    verbose              => 0,
    max_units            => 10,
    min_units            => -10,
    max_units_per_step   => 1,
    max_units_per_second => 100
);

my $gate_sweep = Lab::Moose::Sweep->new(
    instrument => $gate,
    from       => -1,
    to         => 1,
    step       => 0.1
);

my $bias_sweep = Lab::Moose::Sweep->new(
    instrument => $bias,
    from       => -2,
    to         => 2,
    step       => 0.1
);

isa_ok( $gate_sweep, 'Lab::Moose::Sweep' );

my $datafile = {
    type     => 'Gnuplot',
    filename => 'data',
    columns  => [qw/gate bias current/]
};

my $current = 0;
my $meas    = sub {
    my $sweep = shift;
    $sweep->log(
        gate    => $gate->get_level(),
        bias    => $bias->get_level(),
        current => $current++
    );
};

$gate_sweep->start(
    slaves       => [$bias_sweep],
    datafile     => $datafile,
    measurement  => $meas,
    folder       => $dir,
    datafile_dim => 0,
);

say "dir: $dir";

done_testing();
