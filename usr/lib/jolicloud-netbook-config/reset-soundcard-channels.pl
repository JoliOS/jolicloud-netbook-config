#!/usr/bin/perl

use Data::Dumper;
use IO::Handle;

my $channel = "";
my $mixer = {};

my $LOGFILE = "/tmp/jolicloud-netbook-config";
my $VERBOSE = 0;
my $DRYRUN = 0;
my $DEBUG = 0;

my $config = {

    #
    # Begin pvolume/pswitch playback channel settings
    #

    "'Master',0" => {
        pvolume => "90%",
        pswitch => "unmute"
    },
    "'PCM',0" => {
        pvolume => "100%",
        pswitch => "unmute",
    },
    "'Headphone',0" => {
        pvolume => "100%",
        pswitch => "unmute",
    },
    "'Speaker',0" => {
        pvolume => "100%",
        pswitch => "unmute",
    },
    "'iSpeaker',0" => {
        pvolume => "100%",
        pswitch => "unmute",
    },
    "'Beep',0" => {
        pvolume => "0%",
        pswitch => "mute",
    },
    "'PC Beep',0" => {
        pvolume => "0%",
        pswitch => "mute",
    },
    "'Mic',0" => {
        pvolume => "0%",            # Disable internal mic output on speakers
        pswitch => "mute",
    },
    "'Int Mic',0" => {
        pvolume => "0%",            # Disable internal mic output on speakers
        pswitch => "mute",
    },
    "'Ext Mic',0" => {
        pvolume => "0%",            # Disable internal mic output on speakers
        pswitch => "mute",
    },
    "'Int Mic Boost',0" => {
        pvolume => "33%",           # Identified on a Samsung NC-10
        pswitch => "unmute"
    },
    "'Internal Mic Boost',0" => {
        pvolume => "33%",
        pswitch => "unmute"
    },
    "'Front Mic Boost',0" => {
        pvolume => "33%",
        pswitch => "unmute"
    },

    #
    # Begin enum/cenum configuration settings
    #

    "'Mic Jack Mode',0" => {
        enum => "Mic In"            # Identified on an HP Mini 110-1000
    },
    "'Input Source',0" => {
        cenum => [
            "Front Mic",            # Identified on an Acer Aspire One
            "i-Mic",                # Identified on an EeePC 701
            "Internal Mic"          # Identified on a Samsung NC-10
        ],
    },

    #
    # Begin cvolume/cswitch capture channel settings
    #

    "'Capture',0" => {
        cvolume => "100%",
        cswitch => "cap",
    },
    "'Front Mic',0" => {
        cvolume => "90%",
        cswitch => "cap",
    },
    "'i-Mic',0" => {
        cvolume => "90%",
        cswitch => "cap",
    },
    "'Line In',0" => {
        cvolume => "90%",
        cswitch => "cap",
    },
};

#open( LOG, ">>$LOGFILE" );
#STDOUT->fdopen( \*LOG, "w" ) || die $!;

&log( "Begin $0" );

while ( my $arg = shift ) {
    if ( $arg eq "-D" ) {
        $DEBUG = 1;
    }
    elsif ( $arg eq "-d" ) {
        $DRYRUN = 1;
    }
    elsif ( $arg eq "-v" ) {
        $VERBOSE = 1;
    }
}

foreach my $line ( `amixer` ) {
    chomp;
    if ( $line =~ /^Simple mixer control ('.*?',(\d))$/ ) {
        # Skip channels that do not end in 0
        $channel = ( $2 eq "0" ) ? $1 : "";
    }
    elsif ( $channel && $line =~ /^  (.*?): (.*?)$/ ) {
        my ( $key, $val ) = ( $1, $2 );
        if ( ( $key eq "Capabilities" ) ||
             ( $key =~ "Items" ) ) {
            if ( $val =~ s/^'(.*?)'$/$1/ ) {
                $val = [ split( "' '", $val ) ];
            }
            else {
                $val = [ split( " ", $val ) ];
            }
        }
        elsif ( $key eq "Item0" ) {
            $val =~ s/^'(.*?)'$/$1/;
        }
        $mixer->{ $channel }->{ $key } = $val;
    }
}

&log( "Amixer Settings: " . Dumper( $mixer ) );
&log( "Global Config: " . Dumper( $config ) );

# Load any device-specific config

#&log( "Device Config: " . Dumper( $config ) );

while ( ( $channel, $data ) = each %{ $mixer } ) {
    my @sset;

    if ( exists $config->{ $channel } ) {
        my $cfg = $config->{ $channel };

        while ( my ( $capability, $setting ) = each %{ $cfg } ) {
            if ( &isin( $capability, $data->{ 'Capabilities' } ) ) {
                my @options;

                # Some settings are defined as an array, this is the case
                # for enum/cenum where only one option should be selected,
                # but we need to validate each possibility 
                @options = ref( $setting ) eq "ARRAY"
                    ? @{ $setting } : ( $setting );

                # If we're dealing with an enum or cenum, make sure the
                # setting requested exists in the Items array, otherwise
                # amixer will error out.
                foreach $setting ( @options ) {
                    if ( $capability =~ /enum$/ &&
                         ! &isin( $setting, $data->{ 'Items' } ) ) {
                        &log( "WARNING: cannot apply $channel -> $setting" );
                        next;
                    }
                    push( @sset, qq("$setting") );
                }
            }
        }
    }

    if ( @sset ) {
        my $cmd = "/usr/bin/amixer sset $channel " . join( ' ', @sset );
        print STDERR "$cmd\n" if ( $VERBOSE );
        &log( $cmd );
        # Execute the command. Data returned on STDOUT is relayed to LOG
        my $out = `$cmd` if ( ! $DRYRUN );
        print $out . "\n" if ( $VERBOSE );
    }
}

&log( "Finish $0" );
#close( LOG );



sub log
{
    my $msg  = shift;
    my @time = localtime;
    $time[ 5 ] += 1900;
    $time[ 4 ] += 1;

    my $time = sprintf "%04d-%02d-%02d %02d:%02d:%02d", reverse @time[ 0..5 ];

    if ( $DEBUG ) {
        print "$time (RSC) $msg\n";
    }
    if ( $msg =~ /^(WARNING|ERROR)/ ) {
        print STDERR "$time (RSC) $msg\n";
    }
}


sub isin
{
    my ( $needle, $haystack ) = @_;
    return grep( $_ eq $needle, @{ $haystack } );
}

