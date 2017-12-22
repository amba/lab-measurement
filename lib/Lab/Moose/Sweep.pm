package Lab::Moose::Sweep;

#ABSTRACT: Base class for high level sweeps (step/list)

# Continuous sweeps might get a separate base class

=head1 DESCRIPTION

=cut

use 5.010;
use Moose;
use MooseX::Params::Validate;

use Carp;

#
# Public attributes set by the user
#

has from     => ( is => 'ro', isa => 'Num', required => 1 );
has to       => ( is => 'ro', isa => 'Num', required => 1 );
has stepsize => ( is => 'ro', isa => 'Num', required => 1 );
has points   => (
    is      => 'ro', isa => 'ArrayRef[Num]', lazy => 1,
    builder => '_build_points'
);

has separate_files     => ( is => 'ro', isa => 'Bool', default => 0 );
has filename_extension => ( is => 'ro', isa => 'Str',  default => 'Value=' );

#
# Private attributes used internally
#

has slave => (
    is     => 'ro', isa => 'Lab::Moose::Sweep', init_arg => undef,
    writer => '_slave'
);

has is_slave =>
    ( is => 'ro', isa => 'Bool', init_arg => undef, writer => '_is_slave' );

# Highest level sweep
has master => (
    is     => 'ro', isa => 'Lab::Moose::Sweep', init_arg => undef,
    writer => '_master'
);

has parent => (
    is     => 'ro', isa => 'Lab::Moose::Sweep', init_arg => undef,
    writer => '_parent'
);

has instrument =>
    ( is => 'ro', isa => 'Lab::Moose::Instrument', required => 1 );

has datafile_params => (
    is        => 'ro',
    isa       => 'HashRef', init_arg => undef, writer => '_datafile_params',
    predicate => 'has_datafile_params'
);

# Should this sweep create a new datafile for each measurement point?
has create_datafiles => (
    is  => 'ro',
    isa => 'Bool', init_arg => undef, writer => '_create_datafiles'
);

# Create datafile before starting master sweep
has single_datafile => (
    is  => 'ro',
    isa => 'Bool', init_arg => undef, writer => '_single_datafile'
);

has measurement => (
    is => 'ro', isa => 'CodeRef', init_arg => undef, writer => '_measurement',
    predicate => 'has_measurement',
);

sub _ensure_no_slave {
    my $self = shift;
    if ( $self->is_slave() ) {
        croak "cannot do this with slave";
    }
}

sub _build_points {

    # use linspace function LinearStepSweep
    ...;
}

sub add_measurement {
    my $self = shift;
    my ($meas) = pos_validated_list(
        \@_,
        { isa => 'CodeRef' }
    );

    $self->_ensure_no_slave();
    if ( $self->has_measurement() ) {
        croak "add_measurement called twice";
    }
}

# Need Sweep::Datafile class with add_plot method
sub add_datafile {
    my ( $self, %args ) = validated_hash(
        \@_,
        MX_PARAMS_VALIDATE_ALLOW_EXTRA => 1,
    );

    $self->_ensure_no_slave();
    if ( $self->has_measurement() ) {
        croak "add_measurement called twice";
    }

    # make callable only from master sweep; check in start()
    ...;
}

sub add_slaves {
    my $self = shift;
    my ($slaves) = pos_validated_list(
        \@_,
        { isa => 'ArrayRef[Lab::Moose::Sweep]' }
    );

    if ( not $self->has_measurement ) {
        croak "Need to add measurement before calling 'add_slaves'";
    }

    if ( not $self->has_datafile_params ) {
        croak "Need to add datafile befor calling 'add_slaves'";
    }

    my @slaves = @{$slaves};

    my $parent = $self;

    # Set slave/parent relationships
    for my $slave (@slaves) {
        $slave->_is_slave(1);
        $slave->_master($self);
        $parent->_slave($slave);
        $slave->_parent($parent);

        $parent = $slave;
    }

    # Set create_datafiles/single_datafile attributes:
    # Gnuplot datafile is limited to 2D blocks
    # maximum number of two sweeps (the innermost) write into one datafile
    my @sweeps = ( $self, @slaves );
    if ( $sweeps[-1]->separate_files() ) {
        $sweeps[-1]->_create_datafiles(1);
    }
    elsif ( defined $sweeps[-2] and $sweeps[-2]->separate_files() ) {
        $sweeps[-2]->_create_datafiles(1);
    }
    elsif ( defined $sweeps[-3] ) {
        $sweeps[-3]->_create_datafiles(1);
    }
    else {
        $self->_single_datafile(1);
    }
}

# Called by user on master sweep
sub start {
    my $self = shift;
    ...;
    $self->_ensure_no_slave();
    ...;
    $self->_start();
}

sub _start {

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
