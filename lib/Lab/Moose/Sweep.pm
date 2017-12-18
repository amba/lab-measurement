package Lab::Moose::Sweep;

#ABSTRACT: Base class for high level sweeps (step/list)

# Continuous sweeps might get a separate base class

=head1 DESCRIPTION

=cut

use 5.010;
use Moose;
use MooseX::Params::Validate;

use Carp;

has from     => ( is => 'ro', isa => 'Num', required => 1 );
has to       => ( is => 'ro', isa => 'Num', required => 1 );
has stepsize => ( is => 'ro', isa => 'Num', required => 1 );
has points   => (
    is      => 'ro', isa => 'ArrayRef[Num]', lazy => 1,
    builder => '_build_points'
);

has separate_files     => ( is => 'ro', isa => 'Bool', default => 0 );
has filename_extension => ( is => 'ro', isa => 'Str',  default => '#' );

has slave => (
    is     => 'ro', isa => 'Lab::Moose::Sweep', init_arg => undef,
    writer => '_slave'
);
has parent => (
    is     => 'ro', isa => 'Lab::Moose::Sweep', init_arg => undef,
    writer => '_parent'
);

has instrument =>
    ( is => 'ro', isa => 'Lab::Moose::Instrument', required => 1 );

sub _build_points {

    # use linspace function LinearStepSweep
    ...;
}

sub add_measurement {

    # make callable only from master sweep; or check in start()
    ...;
}

# Need Sweep::Datafile class with add_plot method
sub add_datafile {

    # make callable only from master sweep; check in start()
    ...;
}

sub add_slave {
    ...;

    # $slave->_parent(...)
}

sub start {

    # optional datafiles argument? Hashref with handle_object => datafile_object
    # parent argument to ensure that user calls start for outermost sweep?
    ...;

    # create datafile?
    # if innermost sweep with separate_files => 1: Build datafile for each point. Get filename extensions from parents.

    # if outermost sweep and no slave has separate_files => 1: Build single datafile for all points
    # for each point:
    # - goto point (call $instrument->set_value(value => $point))
    # - if have slaves, run slaves
    # - if no slaves:
    #  - call measurement sub
}

__PACKAGE__->meta->make_immutable();
1;
