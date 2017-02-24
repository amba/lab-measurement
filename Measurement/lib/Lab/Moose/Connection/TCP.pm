package Lab::Moose::Connection::TCP;

use 5.010;

use Moose;
use MooseX::Params::Validate;
use Moose::Util::TypeConstraints qw(enum);

use IO::Socket::INET;
use IO::Select;
use Time::HiRes qw/gettimeofday tv_interval/;
use Carp;

use Lab::Moose::Instrument qw/timeout_param/;

use Time::HiRes qw/gettimeofday tv_interval/;

use YAML::XS;
use namespace::autoclean;

our $VERSION = '3.540';

has client => (
    is       => 'ro',
    isa      => 'IO::Socket::INET',
    writer   => '_client',
    init_arg => undef,
);

has select => (
    is       => 'ro',
    isa      => 'IO::Select',
    writer   => '_select',
    init_arg => undef,
);

has host => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has port => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

sub BUILD {
    my $self = shift;

    my $host = $self->host();
    my $port = $self->port();

    my $client = IO::Socket::INET->new(
        PeerAddr => $host,
        PeerPort => $port,
        Proto    => 'tcp'
    ) or croak "cannot open connection with $host on port $port: $!";

    $self->_client($client);

    my $select = IO::Select->new($client)
        or croak "cannot create IO::Select object: $!";

    $self->_select($select);
}

sub Write {
    my ( $self, %arg ) = validated_hash(
        \@_,
        timeout_param,
        command => { isa => 'Str' },
    );

    my $command = $arg{command} . "\n";
    my $timeout = $self->_timeout_arg(%arg);

    if ( !$self->select()->can_write($timeout) ) {
        croak "timeout in connection Write";
    }

    my $len = $self->client()->syswrite($command);
    if ( !$len ) {
        croak "write error in connection: $!";
    }
    my $expected_len = length $command;
    if ( $len != $expected_len ) {

        # FIXME: do repeated writes?
        croak "incomplete write: written: $len, expected: $expected_len";
    }
}

sub Read {
    my ( $self, %arg ) = validated_hash(
        \@_,
        timeout_param(),
    );
    my $timeout = $self->_timeout_arg(%arg);

    my $result = "";

    # If the message does not fit into one IP packet, we will need several
    # sysread operations.
    my $start_time = [gettimeofday];
    while (1) {
        my $elapsed_time = tv_interval($start_time);

        if ( $elapsed_time > $timeout ) {
            croak(
                "timeout in Read with args:\n",
                Dump( \%arg )
            );
        }

        if ( !$self->select()->can_read($timeout) ) {
            croak "timeout in connection Write";
        }

        my $buffer;
        $self->client()->sysread( $buffer, 65536 )
            or croak "read error in connection: $!";

        $result .= $buffer;

        if ( substr( $buffer, -1 ) eq "\n" ) {
            last;
        }
    }
    return $result;
}

sub Query {
    my ( $self, %arg ) = validated_hash(
        \@_,
        timeout_param,
        command => { isa => 'Str' },
    );
    my %write_arg = %arg;
    $self->Write(%write_arg);
    delete $arg{command};
    return $self->Read(%arg);
}

sub Clear {

}

with 'Lab::Moose::Connection';

__PACKAGE__->meta->make_immutable();

1;
