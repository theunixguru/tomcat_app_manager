#!/usr/bin/env perl

use strict;

use FindBin;
use lib "$FindBin::Bin/lib";

use Data::Dumper;
use Getopt::Long;
use Try::Tiny;

use Tomcat::AppManager;
use Tomcat::AppManager::Exceptions;

use constant EXIT_CODE_OPTION_ERROR => 1;
use constant EXIT_CODE_OP_FAILED => 2;

my %options = ();
GetOptions(\%options,
    'help',
    'config:s',
    'host:s',
    'port:i',
    'username:s',
    'password:s',
    'action:s',
    'app_path:s',
    'app_location:s',
    'app_tag:s'
);

if ($options{help}) {
    print_usage();
    exit;
}

# Creating an AppManager instance
my $app_manager = Tomcat::AppManager->new(%options);

unless (defined $options{action} && ($options{action} !~ /^\s*$/)) {
    print "\nOPTION ERROR: ", 'action option is required', "\n";
    print_usage();
    exit EXIT_CODE_OPTION_ERROR;
}
my $action = $options{action};

try {

    if ($action eq 'ping') {
        my $result = $app_manager->is_alive(%options);
        if ($result) {
            printf("%s is alive\n", $options{app_path});
        } else {
            printf("%s is not available\n", $options{app_path});
        }

    } else {
        $app_manager->$action(%options);
    }

} catch {
    die $_ unless (blessed $_ && $_->can('rethrow'));
    if ($_->isa('Tomcat::AppManager::ArgumentException')) {
        print "\nOPTION ERROR: ", $_->message, "\n";
        print_usage();
        exit EXIT_CODE_OPTION_ERROR;

    } elsif ($_->isa('Tomcat::AppManager::OpFailException')) {
        print "\nERROR: ", $_->message, "\n";
        print_usage();
        exit EXIT_CODE_OP_FAILED;
    }
};

sub print_usage {
    print <<USAGE_INFO;

USAGE

    app_deployer [OPTIONS]

OPTIONS

    --config        OPTIONAL    a config file with required options set and
                                optional applications configuration

    --host          REQUIRED    the application server hostname

    --port          REQUIRED    the application server port number

    --username      REQUIRED    A username to access text API

    --password      REQUIRED    A password for the same purpose

    --action        REQUIRED    An action to perform

                                Valid actions are:

                                    deploy, undeploy, start, stop, ping

                                The 'ping' action shows if an application
                                queried by the app_path option is alive or not.


    --app_path      REQUIRED    the application context path

    --app_location  REQUIRED    required only with 'deploy' action,
                                a WAR file or a directory of
                                the application requested for deployment

    --app_tag       OPTIONAL    can be used instead of 'app_path' when
                                'config' option is also specified

    --help        prints this usage information

USAGE_INFO
}

