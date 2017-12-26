package Lab::Moose::Sweep;

#ABSTRACT: Base class for high level sweeps (step/list)

# Continuous sweeps might get a separate base class

=head1 DESCRIPTION

=cut

use 5.010;
use Moose;
use Moose::Util::TypeConstraints 'enum';
use MooseX::Params::Validate;
use File::Spec::Functions 'catfile';
use Data::Printer colored => 0;

# Do not import functions as they clash with the attribute methods.
use Lab::Moose ();

use Carp;

#
# Public attributes set by the user
#

has from => ( is => 'ro', isa => 'Num', required => 1 );
has to   => ( is => 'ro', isa => 'Num', required => 1 );
has step => ( is => 'ro', isa => 'Num', required => 1 );

has filename_extension => ( is => 'ro', isa => 'Str', default => 'Value=' );

has instrument =>
    ( is => 'ro', isa => 'Lab::Moose::Instrument', required => 1 );

#
# Private attributes used internally
#

has points => (
    is => 'ro', isa => 'ArrayRef[Num]', lazy => 1, init_arg => undef,
    builder => '_build_points'
);

has slave => (
    is     => 'ro', isa => 'Lab::Moose::Sweep', init_arg => undef,
    writer => '_slave'
);

has is_slave =>
    ( is => 'ro', isa => 'Bool', init_arg => undef, writer => '_is_slave' );

has datafile_params => (
    is  => 'ro',
    isa => 'HashRef', init_arg => undef, writer => '_datafile_params'
);

# real Lab::Moose::DataFile
has datafile => (
    is     => 'ro', isa => 'Lab::Moose::DataFile', init_arg => undef,
    writer => '_datafile'
);

has create_datafile_blocks => (
    is     => 'ro', isa => 'Bool', init_arg => undef,
    writer => '_create_datafile_blocks'
);

# Should this sweep create a new datafile for each measurement point?
has create_datafiles => (
    is  => 'ro',
    isa => 'Bool', init_arg => undef, writer => '_create_datafiles'
);

has datafolder => (
    is       => 'ro',
    isa      => 'Lab::Moose::DataFolder',
    init_arg => undef,
    writer   => '_datafolder'
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
    my $self   = shift;
    my @points = Lab::Moose::linspace(
        from => $self->from,
        to   => $self->to,
        step => $self->step
    );
    return \@points;
}

sub _ensure_sweeps_different {
    my $self   = shift;
    my @sweeps = @_;

    my %h = map { ( $_ + 0 ) => 1 } (@sweeps);
    my @keys = keys %h;
    if ( @keys != @sweeps ) {
        croak "all sweeps must be separate objects!";
    }
}

# Called by user on master sweep
sub start {
    my $self = shift;
    my ( $slaves, $datafile_params, $measurement, $datafile_dim, $folder )
        = validated_list(
        \@_,
        slaves => { isa => 'ArrayRef[Lab::Moose::Sweep]', optional => 1 },
        datafile    => { isa => 'HashRef' }, # change to datafile handle later
        measurement => { isa => 'CodeRef' },
        datafile_dim => { isa => enum( [qw/2 1 0/] ), optional => 1 },
        folder => { isa => 'Str', optional => 1 },
        );

    $self->_ensure_no_slave();

    my $num_slaves = 0;
    my @slaves;
    my @sweeps = ($self);
    if ( defined $slaves ) {
        @slaves     = @{$slaves};
        $num_slaves = @slaves;
        push @sweeps, @slaves;
    }

    $self->_ensure_sweeps_different(@sweeps);

    if ( defined $datafile_dim ) {
        if ( $num_slaves == 0 and $datafile_dim == 2 ) {
            croak "cannot create 2D datafile without slaves";
        }
    }
    else {
        # Set default log_structure
        if ( $num_slaves == 0 ) {
            $datafile_dim = 1,
        }
        else {
            $datafile_dim = 2,
        }
    }

    if ( $datafile_dim == 2 ) {
        $sweeps[-2]->_create_datafile_blocks(1);
    }

    if ($num_slaves) {

        # Set slave/parent relationships
        my $parent = $self;
        for my $slave (@slaves) {
            $slave->_is_slave(1);
            $parent->_slave($slave);
            $parent = $slave;
        }
    }

    if ($num_slaves) {
        $slaves[-1]->_measurement($measurement);
    }
    else {
        $self->_measurement($measurement);
    }

    # Pass this to master sweep's _start method if we have a single datafile
    my $datafolder = Lab::Moose::datafolder(
        defined $folder ? ( path => $folder ) : () );

    my $datafile;

    if ( $num_slaves - $datafile_dim >= 0 ) {
        my $datafile_creating_sweep = $sweeps[ $num_slaves - $datafile_dim ];
        $datafile_creating_sweep->_create_datafiles(1);
        $datafile_creating_sweep->_datafile_params($datafile_params);
        $datafile_creating_sweep->_datafolder($datafolder);
    }
    else {
        # single datafile
        my $filename = delete $datafile_params->{filename};
        $filename .= '.dat';
        $datafile = Lab::Moose::datafile(
            folder   => $datafolder,
            filename => $filename,
            %{$datafile_params},
        );
    }

    $self->_start(
        datafile            => $datafile,
        filename_extensions => [],
    );

}

sub _gen_filename {
    my $self = shift;
    my ( $filename, $extensions ) = validated_list(
        \@_,
        filename   => { isa => 'Str' },
        extensions => { isa => 'ArrayRef[Str]' },
    );

    my @extensions = @{$extensions};

    my $basename = $filename . '_' . join( '_', @extensions ) . '.dat';

    pop @extensions;
    if ( @extensions >= 1 ) {

        # create subdirectories in datafolder
        return catfile( @extensions, $basename );
    }
    else {
        return $basename;
    }
}

sub _start {
    my $self = shift;
    my ( $datafile, $filename_extensions ) = validated_list(
        \@_,
        datafile            => { isa => 'Maybe[Lab::Moose::DataFile]' },
        filename_extensions => { isa => 'ArrayRef[Str]' },
    );

    my @points = @{ $self->points };
    my $slave  = $self->slave();

    if ( $self->create_datafiles and defined $datafile ) {
        croak "should not get datafile arg";
    }

    # for each point:
    for my $point (@points) {
        my @filename_extensions = @{$filename_extensions};
        push @filename_extensions,
            $self->filename_extension . sprintf( "%.14g", $point );

        say "sweep: setting instrument level to $point";
        $self->instrument->set_level( value => $point );

        # Create new datafile?
        if ( $self->create_datafiles ) {
            my %datafile_params = %{ $self->datafile_params };
            my $filename        = delete $datafile_params{filename};

            $filename = $self->_gen_filename(
                filename   => $filename,
                extensions => [@filename_extensions],
            );

            say "sweep: filename: $filename";
            say "filename_extensions:";
            p @filename_extensions;
            $datafile = Lab::Moose::datafile(
                folder   => $self->datafolder,
                filename => $filename,
                %datafile_params,
            );
        }

        if ($slave) {

            $slave->_start(
                datafile            => $datafile,
                filename_extensions => [@filename_extensions],
            );
            if ( $self->create_datafile_blocks() ) {
                $datafile->new_block();
            }
        }
        else {
            # do measurement
            say "sweep: doing measurement";
            $self->_datafile($datafile);
            my $meas = $self->measurement();
            $self->$meas();
        }

    }    # for my $point

}

sub log {
    my $self = shift;
    if ( $self->slave ) {
        croak "should only be called on last slave";
    }
    $self->datafile()->log(@_);
}

__PACKAGE__->meta->make_immutable();
1;
