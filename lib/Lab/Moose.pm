package Lab::Moose;

#ABSTRACT: Convenient loaders and constructors for L<Lab::Moose::Instrument>, L<Lab::Moose::DataFolder> and L<Lab::Moose::DataFile>

use warnings;
use strict;
use 5.010;

use MooseX::Params::Validate;

use Module::Load;
use Exporter 'import';
use Lab::Moose::Connection;
use Carp;

# FIXME: export 'use warnings; use strict; into caller'

our @EXPORT = qw/instrument datafolder datafile linspace/;

=head1 SYNOPSIS

 use Lab::Moose;

 my $vna = instrument(
     type => 'RS_ZVA',
     connection_type => 'LinuxGPIB',
     connection_options => {timeout => 2}
 );
 
 my $folder = datafolder();
 my $file = datafile(
     type => 'Gnuplot',
     folder => $folder,
     filename => 'data.dat',
     columns => ['gate', 'bias', 'current'],
 );

 my $meta_file = datafile(
     type => 'Meta',
     folder => $folder,
     filename => 'file.yml'
 );

 my @points = linspace(from => -1, to => 1, step => 0.1);

=head1 SUBROUTINES

=head2 instrument

Load an instrument driver module and call the constructor.

Create instrument with new connection:

 my $instr = instrument(
     instrument_type => 'RS_SMB',
     connection_type => 'VXI11',
     connection_options => {host => '192.168.2.23'},
     # other driver specific options
     foo => 'ON',
     bar => 'OFF',
 );

Create instrument with existing connection:

 my $instr = instrument(
     instrument_type => $type,
     connection => $connection_object,
     # driver specific options
     foo => 'ON',
     bar => 'OFF',
 );

=cut

sub instrument {
    my %args = validated_hash(
        \@_,
        type                           => { isa => 'Str' },
        MX_PARAMS_VALIDATE_ALLOW_EXTRA => 1,
    );

    my $type = delete $args{type};
    $type = "Lab::Moose::Instrument::$type";
    load $type;

    return $type->new(%args);
}

=head2 datafolder

 my $folder = datafolder(%args);

Load L<Lab::Moose::DataFolder> and call it's C<new> method with C<%args>.

=cut

sub datafolder {
    load 'Lab::Moose::DataFolder';
    return Lab::Moose::DataFolder->new(@_);
}

=head2 datafile

 my $file = datafile(type => $type, %args);

Load Lab::Moose::DataFile::C<$type> and call it's C<new> method with C<%args>.

=cut

sub datafile {
    my (%args) = validated_hash(
        \@_,
        type                           => { isa => 'Str' },
        MX_PARAMS_VALIDATE_ALLOW_EXTRA => 1
    );

    my $type = delete $args{type};

    $type = "Lab::Moose::DataFile::$type";

    load $type;

    return $type->new(%args);
}

=head2 linspace

 # create array (-1, -0.9, ..., 0.9, 1) 
 my @points = linspace(from => -1, to => 1, step => 0.1);

 # create array without first point (-0.9, ..., 1)
 my @points = linspace(from => -1, to => 1, step => 0.1, exclude_from => 1);

=cut

sub linspace {
    my ( $from, $to, $step, $exclude_from ) = validated_list(
        \@_,
        from         => { isa => 'Num' },
        to           => { isa => 'Num' },
        step         => { isa => 'Num' },
        exclude_from => { isa => 'Bool', default => 0 },
    );

    $step = abs($step);
    my $sign = $to > $from ? 1 : -1;

    my @steps;
    for ( my $i = $exclude_from ? 1 : 0;; ++$i ) {
        my $point = $from + $i * $sign * $step;
        if ( ( $point - $to ) * $sign >= 0 ) {
            last;
        }
        push @steps, $point;
    }
    return ( @steps, $to );
}

1;
