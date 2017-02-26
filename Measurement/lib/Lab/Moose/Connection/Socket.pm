package Lab::Moose::Connection::Socket;

use 5.010;

use Moose;
use MooseX::Params::Validate;

use IO::Socket::INET;
use IO::Select;
use Carp;

use Lab::Moose::Instrument qw/timeout_param/;

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
    my $self   = shift;
    my $host   = $self->host();
    my $port   = $self->port();
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

    print { $self->client() } $command;
}

sub Read {
    my ( $self, %arg ) = validated_hash(
        \@_,
        timeout_param(),
    );
    my $timeout = $self->_timeout_arg(%arg);
    my $client  = $self->client();

    if ( !$self->select()->can_read($timeout) ) {
        croak "timeout in connection Read";
    }

    my $line = <$client>;

    if ( $line =~ /^#([1-9])/ ) {

        # DEFINITE LENGTH ARBITRARY BLOCK RESPONSE DATA
        # See IEEE 488.2, Sec. 8.7.9
        my $num_digits = $1;
        my $num_bytes = substr( $line, 2, $num_digits );

        # We do require a trailing newline
        my $needed = 2 + $num_digits + $num_bytes - length($line) + 1;
        if ( $needed < 0 ) {
            croak "negative read length";
        }
        my $string;
        my $read_bytes = read( $client, $string, $needed );
        if ( $read_bytes != $needed ) {
            croak "tcp read returned too few bytes:\n"
                . "expected: $needed, got: $read_bytes";
        }
        return $line . $string;
    }
    else {
        return $line;
    }
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

with qw/
    Lab::Moose::Connection
    /;

__PACKAGE__->meta->make_immutable();

1;
