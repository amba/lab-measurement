
package Lab::Instrument::MagnetSupply;
use strict;


our @ISA=('Lab::Instrument');

my %fields = (
	supported_connections => [],

	# supported config options
	device_settings => {
		gate_protect => undef,
		gp_max_volt_per_second => undef,
		gp_max_volt_per_step => undef,
		gp_max_step_per_second => undef,
		gp_min_volt => undef,
		gp_max_volt => undef,
		gp_equal_level => undef,
		fast_set => undef,
	},

	# Config hash passed to subchannel objects or $self->configure()
	default_device_settings => {},
);

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = $class->SUPER::new(@_);
	$self->_construct(__PACKAGE__, \%fields);
	$self->configure($self->config());
	$self->device_settings($self->config('device_settings')) if defined
$self->config('device_settings') && ref($self->config('device_settings'))
eq 'HASH';
    
    return $self;
}

















sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self = bless {}, $class;

    %{$self->{default_config}}=%{shift @_}; # ? David: fills the new hash %default_config with the first argument from @_ (e.g. "ASRL1" => undef ???)
    %{$self->{config}}=%{$self->{default_config}};  # ? David: copy the hash %default_config to %config

    $self->{config}->{field_constant}=0;
    $self->{config}->{max_current}=1;
    $self->{config}->{max_sweeprate}=0.001;
    $self->{config}->{max_sweeprate_persistent}=0.001;  # David: NOT USED!
    $self->{config}->{has_heater}=1;
    $self->{config}->{heater_delaytime}=20; # David: NOT USED!
    $self->{config}->{can_reverse}=0;
    $self->{config}->{can_use_negative_current}=0;
    $self->{config}->{use_persistentmode}=0;    # David: NOT USED!

    $self->configure(@_);   # uses the remaining argument list to configure itself

    print "Magnet power supply support is experimental. You have been warned.\n";
    return $self;
}

# usage:
# my $source=new Lab::Instrument::IPS12010new({ ... })
# $source->{config}{"field_constant"}=1;
sub configure {
    my $self=shift;
    #supported config options are (so far)
    #   field_constant (T/A)
    #   max_current (A)
    #   max_sweeprate (A/min)
    #   max_sweeprate_persistent (A/min)
    #   has_heater (0/1)
    #   heater_delaytime (s)
    #   can_reverse (0/1)
    #   can_use_negative_current (0/1)
    #   use_persistentmode (0/1)
    #   
    my $config=shift;
    if ((ref $config) =~ /HASH/) {
        for my $conf_name (keys %{$self->{default_config}}) {
            # print "Key: $conf_name, default: ",$self->{default_config}->{$conf_name},", old config: ",$self->{config}->{$conf_name},", new config: ",$config->{$conf_name},"\n";
            unless ((defined($self->{config}->{$conf_name})) || (defined($config->{$conf_name}))) {
                $self->{config}->{$conf_name}=$self->{default_config}->{$conf_name};
            } elsif (defined($config->{$conf_name})) {
                $self->{config}->{$conf_name}=$config->{$conf_name};
            }
        }
        return $self;
    } elsif($config) {
        return $self->{config}->{$config};
    } else {
        return $self->{config};
    }
}

# converts the argument in AMPS to TESLA, if field_constant != 0
sub ItoB {
    my $self=shift;
    my $current=shift;

    my $fconst = $self->{config}->{field_constant};

    if ($fconst==0) { 
      die "MagnetSupply.pm: Field constant not defined!!!\n";
    };
    
    return($fconst*$current);
}


# converts the argument in TESLA to AMPS, if field_constant != 0
sub BtoI {
    my $self=shift;
    my $field=shift;

    my $fconst = $self->{config}->{field_constant};

    if ($fconst==0) { 
        die "MagnetSupply.pm: Field constant not defined!!!\n";
    };
    
    return($field/$fconst);
}


# field in TESLA
sub set_field {
    my $self=shift;
    my $field=shift;
    
    my $current = $self->BtoI($field);

    $field = $self->ItoB($self->set_current($current));
    return $field;
}


# current in AMPS
sub set_current {
    my $self=shift;
    my $current=shift;

    if ($current > $self->{config}->{max_current}) {
        $current = $self->{config}->{max_current};
    };
    
    if ($current < 0) {
        if ($self->{config}->{can_reverse}) {

            if ($self->{config}->{can_use_negative_current}) {

                if ($current < -$self->{config}->{max_current}) {
                    $current = -$self->{config}->{max_current};
                };

                # HERE TODO: sweep to negative current
                die "MagnetSupply.pm: negative current supported, but not yet implemented!";
                return $self->get_current();
                
            } else {
                   die "MagnetSupply.pm: negative current not supported\n";
            };
            
        } else {
               die "MagnetSupply.pm: reverse current not supported\n";
        }
    
    };

    $self->_set_sweeprate($self->{config}->{max_sweeprate});
    
    # TODO: why another test for can_use_negative_current, and why not continue if the test fails?
    # if ($self->{config}->{can_use_negative_current}) {
        # $self->_set_sweep_target_current($current);
    # } else {
    # die "not supported yet\n";
    # }
    

    $self->_sweep_to_current($current); # sweeps and waits until finished
}



sub start_sweep_to_field {
    my $self=shift;
    my $field=shift;
    $self->start_sweep_to_current($self->BtoI($field));
}


# DANGER!
# does only work for IPS12010new.pm!, undefined behaviour!
# identical to set_current, only diff: does NOT wait until sweeping is finished
sub start_sweep_to_current {
    my $self=shift;
    my $current=shift;

    if ($current > $self->{config}->{max_current}) {
        $current = $self->{config}->{max_current};
    };
    
    if ($current < 0) {
        if ($self->{config}->{can_reverse}) {

            if ($self->{config}->{can_use_negative_current}) {

                if ($current < -$self->{config}->{max_current}) {
                    $current = -$self->{config}->{max_current};
                };

                # HERE TODO: sweep to negative current
                die "MagnetSupply.pm: negative current supported, but not yet implemented!";
                return $self->get_current();
                
            } else {
                   die "MagnetSupply.pm: negative current not supported\n";
            };
            
        } else {
               die "MagnetSupply.pm: reverse current not supported\n";
        }
    
    };

    $self->_set_sweeprate($self->{config}->{max_sweeprate});
    
    # TODO: why another test for can_use_negative_current, and why not continue if the test fails?
    # if ($self->{config}->{can_use_negative_current}) {
        # $self->_set_sweep_target_current($current);
    # } else {
    # die "not supported yet\n";
    # }
    
    $self->_set_sweep_target_current($current);
    
    $self->_set_hold(0);    # pause OFF, so sweeping begins
    
    # now return, while sweeping continues
}



# returns the field in TESLA
sub get_field {
    my $self=shift;
    return $self->ItoB($self->_get_current());
}

# returns the current in AMPS
sub get_current {
    my $self=shift;
    return $self->_get_current();
}

# returns:
# 0 == off, Magnet at Zero (switch closed)
# 1 == On (switch open)
# 2 == Off, Magnet at Field (switch closed)
sub get_heater() {
    my $self=shift;
    my $value = $self->_get_heater();
    return $value;
}

# parameter:
# 0 == off
# 1 == on iff PSU=Magnet
# 2 == on (no checks)
sub set_heater() {
    my $self=shift;
    my $value=shift;
    return $self->_set_heater($value);
}

# returns sweeprate in AMPS/MINUTE, or in TESLA/MINUTE if device supports TESLA mode and IS in TESLA mode
sub get_sweeprate() {
    my $self=shift;
    return $self->_get_sweeprate();
}

# $rate in AMPS/MINUTE, or in TESLA/MINUTE if device supports TESLA mode and IS in TESLA mode
sub set_sweeprate() {
    my $self=shift;
    my $rate=shift;
    $self->{config}->{max_sweeprate} = $rate;
    return $self->_set_sweeprate($rate);
}


# David: this is the interface needed to be implemented
# David: these are probably the fallbacks if a sub is not implemented in e.g. IPS12010new.pm, or Cryogenic.pm


sub _get_current {
    die '_get_current not implemented for this instrument';
}

sub _set_sweep_target_current {
    die '_set_sweep_target_current not implemented for this instrument';
}

sub _set_hold {
    die '_set_hold not implemented for this instrument';
}

sub _get_hold {
    die '_get_hold not implemented for this instrument';
}

sub _set_heater {
    die '_set_heater not implemented for this instrument';
}

sub _get_heater {
    die '_get_heater not implemented for this instrument';
}

sub _set_sweeprate {
    die '_set_sweeprate not implemented for this instrument';
}

sub _get_sweeprate {
    die '_get_sweeprate not implemented for this instrument';
}


1;



=head1 NAME

Lab::Instrument::MagnetSupply - Base class for magnet power supply instruments

David Borowsky
=cut

