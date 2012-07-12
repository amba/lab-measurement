#!/usr/bin/perl -w

# Daniel Schmid, July 2010, composed following Markus'  & David's perl-scripts
 
use strict;
use Lab::Instrument::Yokogawa7651;
use Lab::Instrument::IPS12010;
use Lab::Instrument::HP3458A;
use Lab::Instrument::SR830;

use Time::HiRes qw/usleep/;
use Time::HiRes qw/sleep/;
use Time::HiRes qw/tv_interval/;
use Time::HiRes qw/time/;
use Time::HiRes qw/gettimeofday/;

use Lab::Measurement;

use warnings "all";

#general information
my $t = 0;			      # f�rs Stoppen der Messzeit
my $temperature = '30';      # Temperatur in milli-Kelvin!
my $temperatureunit = 'mK';
my $sample = "CB3224";

my @starttime = localtime(time);
my $startstring=sprintf("%04u-%02u-%02u_%02u-%02u-%02u",$starttime[5]+1900,$starttime[4]+1,$starttime[3],$starttime[2],$starttime[1],$starttime[0]);



# measurement constants
#---ac sample1---
my $DividerAC=0.0001;
my $DividerDC = 0.01;

my $yok1protect = 1;		# 0 oder 1 f�r an / aus, analog gateprotect
my $Yok1DcRange = 5;		# Handbuch S.6-22:R2=10mV,R3=100mV,R4=1V,R5=10V,R6=30V
my $Vdcmax1 = 12;	        # wird unten f�rs biasprotect verwendet, on 470 MOhm corresponds to about 32 nA  

my $ampI = 1e-8;         
my $risetime = 1;		# rise time Ithaco Zeit in ms
my $lockinsettings='Frequency 137.48Hz, amplitude 50mV*10^-4=5�V RMS, Phase 0, sens=100mV, integ. time 100ms';


my $multitime=2;  # multimeter integration time in line power cycles


#---gate---
############################## !!!!!!!!!!!!!!
my $Vgatestart = -0.4;
my $Vgatestop = 0.4;
my $stepgate = 0.0005;
##############################!!!!!!!!!!!!!!

my $Vgatemax = 5;				# wird unten f�rs gateprotect verwendet

my $Vbias = 35e-6;

##############################
# Magnetic Field

my $fieldstart=0;
my $fieldstop=17;
my $fieldstep=0.17;


# all gpib addresses

my $title = "B par trace AC";
my $filename = $startstring."_$sample bpar";


####################################################################

#	<---------- set Instruments

#---init Yokogawa--- Gatespannung
my $type_gate="Lab::Instrument::Yokogawa7651";
my $YokGate=new $type_gate({
	'connection_type' =>'VISA_GPIB',
	'gpib_board'    => 0,
    'gpib_address'  => 3,
    'gate_protect'  => 1,
    'gp_max_units_per_second' => 0.05,
    'gp_max_step_per_second' => 10,
    'gp_max_units_per_step' => 0.01,
    'gp_min_units' => -$Vgatemax, 	# gate equipped with 5 Hz filter from Leonid 
    'gp_max_units'  => $Vgatemax,
});
         

		  
print "setting up Agilent for dc current through sample \n";
my $hp2=new Lab::Instrument::HP3458A({
	'connection_type' =>'VISA_GPIB',
	'gpib_board' => 0,
	'gpib_address' => 15,
	});

	
my $lia=new Lab::Instrument::SR830({
	'connection_type' =>'VISA_GPIB',
	'gpib_board' => 0,
	'gpib_address' => 7,
	});

my $magnet=new Lab::Instrument::IPS12010(
        connection_type=>'VISA_GPIB',
        gpib_address => 24,
		max_current => 123.8,    # A
		max_sweeprate => 0.0167, # A/s
		soft_fieldconstant => 0.13731588, # T/A
		can_reverse => 1,
		can_use_negative_current => 1,
);
	
$hp2->write("TARM AUTO");
$hp2->write("NPLC $multitime");

#my $lia=new Lab::Instrument::SR830(0,$gpib_lia);
#my $lia_amplitude=($lia->get_amplitude())*$DividerAC;

#print "wait 3 hours for thermalization! \n";
#sleep(10800);
###################################################################################

my $comment=<<COMMENT;
AC dI measurment for different magnetic field in the few electron regime.
angle setting: -22� (208.7), which is most likely parallel field

Ithaco: Verstaerkung $ampI  , Rise Time $risetime ms;
Messen der Ausgangsspannung des Ithaco �ber Agilent;
Voltage dividers DC: $DividerDC 
Voltage divider AC: $DividerAC

Effective LIA amplitude 10�V.
Multimeter integ. time (PLC) $multitime

Lock-in settings: $lockinsettings

Temperatur = $temperature $temperatureunit;

Bias without offset = $Vbias V;

Field Vgate Iac Iacx Iacy Iacr t
COMMENT


####################################################################################



my $measurement=new Lab::Measurement(
    sample          => $sample,
    title           => $title,
    filename_base   => $filename,
    description     => $comment,

    live_plot       => 'dIac',
    live_refresh    => '500',

constants       => [
        {
            'name'          => 'ampI',
            'value'         => $ampI,
        },
    ],
    columns         => [
		{
            'unit'          => 'T',
            'label'         => 'Bpar',
            'description'   => "magnetic field parallel tube",
        },
		{
            'unit'          => 'V',
            'label'         => 'Gate voltage',
            'description'   => 'Applied to gate',
        },
		{
			'unit'          => 'A',
            'label'         => 'Idc',
            'description'   => "measured dc current through $sample",
        },
#	----sonstiges---
		{
            'unit'          => 'sec',
            'label'         => 'time',
            'description'   => "Time",
        },
    ],
    axes            => [
		{
            'unit'          => 'T',
            'expression'    => '$C0',
			'label'         => 'Bpar',
            'description'   => "magnetic field parallel tube",
        },
        {
            'unit'          => 'V',
            'expression'    => '$C1',
            'label'         => 'gate voltage',
            'description'   => 'Applied to backgate via 5Hz filter.',
        },
		{
	        'unit'          => 'A',
            'expression'    => '$C5',
            'label'         => 'dIac',
            'description'   => 'Measured ac current through $sample',
        },
		{
            'unit'          => 'sec',
			'expression'    => '$C6',
            'label'         => 'time',
            'description'   => "Timestamp (seconds since unix epoch)",
        },
    ],
    plots           => {
        'dIac'    => {
            'type'          => 'pm3d',
            'xaxis'         => 0,
            'yaxis'         => 1,
            'cbaxis'        => 2,
            'grid'          => 'xtics ytics',
        },
    },
);

###############################################################################

 
unless (($Vgatestop-$Vgatestart)/$stepgate > 0) { # um das gate in die richtige Richtung laufen zu lassen
    $stepgate = -$stepgate;
}
my $stepsign_gate=$stepgate/abs($stepgate);

unless (($fieldstop-$fieldstart)/$fieldstep > 0) { # um das bias in die richtige Richtung laufen zu lassen
    $fieldstep = -$fieldstep;
}
my $stepsign_field=$fieldstep/abs($fieldstep);


##Start der Messung
for (my $B=$fieldstart;$stepsign_field*$B<=$stepsign_field*$fieldstop;$B+=$fieldstep)	{

	$measurement->start_block();

	#print "setting gate voltage $Vgatestart ";
	my $measVg=$YokGate->set_voltage($Vgatestart);

	
	print "Setting magnetic field: $B T\n";
	$magnet->set_field($B);
 	print "Done, entering inner loop.\n";

	for (my $Vgate=$Vgatestart;$stepsign_gate*$Vgate<=$stepsign_gate*$Vgatestop;$Vgate+=$stepgate) {

	    my $Vgate = $YokGate->set_voltage($Vgate);
		
		my $t = gettimeofday();
        my $Vithaco = $hp2 -> get_value();			    # lese Strominfo von Ithako
	    chomp $Vithaco;                                 # raw data (remove line feed from string)
		

		my ($Vacx,$Vacy)=$lia->get_xy();
		
		my $Iacx= -($Vacx*$ampI);
		my $Iacy= -($Vacy*$ampI);
		my $Iacr=sqrt($Iacx*$Iacx+$Iacy*$Iacy);
		
		
	    my $Idc = -($Vithaco*$ampI);              # '-' f�r den Ithako, damit positives G rauskommt
            
	    $measurement->log_line($B, $Vgate, $Idc, $Iacx, $Iacy, $Iacr, $t);
	    
	}
}    

my $meta=$measurement->finish_measurement();

printf "End of Measurement!\n";