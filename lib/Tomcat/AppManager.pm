package Tomcat::AppManager;
=head1 NAME

Tomcat::AppManager

=cut

use strict;
use warnings;

use Data::Dumper;
use HTTP::Headers;
use IO::File;
use LWP::UserAgent;
use MIME::Base64;
use Try::Tiny;
use URI;
use YAML;

use Tomcat::AppManager::Exceptions;

use constant DEFAULT_PORT => 8080;

=head1 DESCRIPTION

Methods B<deploy>, B<undeploy>, B<start>, B<stop>, B<is_alive> accept
these special parameetrs:

    app_tag
        If 'config' option was specified on the manager object creation and
        it contains a configuration for provided 'app_tag', the method will load
        all requird parameters from the configuration while allowing to override
        the application configuration values with user supplied values.

=cut

=head1 CONSTRUCTORS

Generic constructor
TODO - more details

=cut

sub new {
    my $klass = shift;
    my %args = @_;

    my $self;

    # Load configuration from file if 'config' option is set
    if (defined $args{config}) {
        my $config_file = $args{config};
        $self = YAML::LoadFile($config_file);

    } else {
        $self = {};
    }

    bless $self, $klass;

    # Process passed-in arguments ( values from the config file
    # will be overwritten )

    my @required_args = qw(
        host
        username
        password
    );

    foreach my $arg (@required_args) {
        if (defined $args{$arg} && ($args{$arg} !~ /^\s*$/)) {
            $self->{$arg} = $args{$arg}
        } else {
            Tomcat::AppManager::ArgumentException->throw("$arg required")
                unless (defined $self->{$arg});
        }
    }

    $self->{port} = $args{port} || DEFAULT_PORT;

    # Construct API URL
    $self->{base_url} = sprintf("http://%s:%s", $self->{host}, $self->{port});
    $self->{api_url} = $self->{base_url}.'/manager/text';

    return $self;
}

=head1 ACCESSORS

=head2 get_last_request_object

Get last request object

=cut

sub get_last_request_object {
    my $self = shift;
    return $self->{request};
}

=head2 get_last_response_object

Get last response object

=cut

sub get_last_response_object {
    my $self = shift;
    return $self->{response};
}

=head1 METHODS

=head2 get_config_as_hash

Returns current configuration as a hash

=cut

sub get_config_as_hash {
    my $self = shift;
    my %data = ();
    $data{$_} = $self->{$_} for (qw(host port));
    return \%data;
}

=head2 get_app_config

Return the specified app configuration

=cut

sub get_app_config {
    my $self = shift;
    my $app_tag = shift;

    if (exists $self->{applications}) {
        if (defined $app_tag &&
                (exists $self->{applications}{$app_tag})) {
            return $self->{applications}{$app_tag};
        }
    }

    return undef;
}

=head2 save_config

Save current configuration into a file. Saves only global options,
doesn't store any application related configuration.

=cut

sub save_config {
    my $self = shift;
    my $filename = shift;
    YAML::DumpFile($filename, $self->get_config_as_hash());
}

=head2 deploy

Deploy a new application

Parameters:

    app_path - context path on a Tomcat instance
    app_location - application WAR/directory location

Returns:

    True on success

Throws:

    Tomcat::AppManager::OpFailException

=cut

sub deploy {
    my $self = shift;
    my %args = @_;
    my ($app_path, $app_location);
  
    my $app_config = $self->get_app_config($args{app_tag});
    if (defined $app_config) {
        $app_path = $app_config->{app_path};
        $app_location = $app_config->{app_location};
    }

    $app_path = $args{app_path} if (defined $args{app_path});
    $app_location = $args{app_location} if (defined $args{app_location});

    Tomcat::AppManager::ArgumentException->throw('app_path required')
        unless $app_path;

    Tomcat::AppManager::ArgumentException->throw('app_location required')
        unless $app_location;

    $self->api_call(
        call_type => 'deploy',
        call_data => {
            path => $app_path,
            war => 'file:'.$app_location
        }
    );
}

=head2 undeploy

Undeploy an existing application

Parameters:

    app_path - context path of the application

Returns:

    True on success

Throws:

    Tomcat::AppManager::OpFailException

=cut

sub undeploy {
    my $self = shift;
    my %args = @_;
    my ($app_path);

    my $app_config = $self->get_app_config($args{app_tag});
    if (defined $app_config) {
        $app_path = $app_config->{app_path};
    }

    $app_path = $args{app_path} if (defined $args{app_path});

    Tomcat::AppManager::ArgumentException->throw('app_path required')
        unless $app_path;

    $self->api_call(
        call_type => 'undeploy',
        call_data => { path => $app_path }
    );
}

=head2 start

Start a deployed application

Parameters:

    app_path - a context path of the application

Returns:

    True on success

Throws:

    Tomcat::AppManager::OpFailException

=cut

sub start {
    my $self = shift;
    my %args = @_;
    my ($app_path);

    my $app_config = $self->get_app_config($args{app_tag});
    if (defined $app_config) {
        $app_path = $app_config->{app_path};
    }

    $app_path = $args{app_path} if (defined $args{app_path});

    Tomcat::AppManager::ArgumentException->throw('app_path required')
        unless $app_path;

    $self->api_call(
        call_type => 'start',
        call_data => { path => $app_path }
    );
}

=head2 stop

Stop a deployed application

Parameters:

    app_path - a context path of the application

Returns:

    True on success

Throws:

    Tomcat::AppManager::OpFailException

=cut

sub stop {
    my $self = shift;
    my %args = @_;
    my ($app_path);

    my $app_config = $self->get_app_config($args{app_tag});
    if (defined $app_config) {
        $app_path = $app_config->{app_path};
    }

    $app_path = $args{app_path} if (defined $args{app_path});

    Tomcat::AppManager::ArgumentException->throw('app_path required')
        unless $app_path;

    $self->api_call(
        call_type => 'stop',
        call_data => { path => $app_path }
    );
}

=head2 is_alive

Check if an application is running/stopped

Parameters:

    app_path - a context path of the application

Returns:

    True - the application is alive and running
    False - the application is not available

Throws:

    Tomcat::AppManager::OpFailException

=cut

sub is_alive {
    my $self = shift;
    my %args = @_;
    my ($app_path);

    my $app_config = $self->get_app_config($args{app_tag});
    if (defined $app_config) {
        $app_path = $app_config->{app_path};
    }

    $app_path = $args{app_path} if (defined $args{app_path});

    Tomcat::AppManager::ArgumentException->throw('app_path required')
        unless $app_path;

    Tomcat::Appmanager::ArgumentException->throw('app_path must start with a /')
        unless ($app_path =~ /^\//);

    my $request = HTTP::Request->new(
        GET => $self->{base_url}.$app_path
    );
    $self->{request} = $request;

    my $response = $self->_send_http_request($request);
    $self->{response} = $response;

    # App is alive
    if ($response->code == 200) {
        return 1;
    # App is NOT alive
    } elsif ($response->code == 404) {
        return 0;
    }

    # Something wrong is going on
    Tomcat::AppManager::Exception->throw($response->decoded_content());
}

=head2 api_call

A high level entry point to send an API request.

Parameters:

    method - a valid HTTP method

    call_type - an API call type

    call_data - a request data

Returns:

    True on success

Throws:

    Tomcat::AppManager::OpFailException

=cut

sub api_call {
    my $self = shift;
    my %args = @_;

    my $method = uc($args{method} || 'get');
    my $call_type = $args{call_type} or die 'call_type required';
    my $call_data = $args{call_data} || {};

    # Sort data by keys - a great help with testing
    $call_data = [ map {$_ => $call_data->{$_}}
        sort {$a cmp $b} keys %$call_data ];

    my $request_uri = URI->new($self->{api_url}.'/'.$call_type);
    $request_uri->query_form($call_data);

    my $headers = HTTP::Headers->new();
    $headers->header('Authorization' =>
        'Basic '.encode_base64($self->{username}.':'.$self->{password}));

    my $request = new HTTP::Request(
        $method,
        $request_uri->canonical(),
        $headers
    );
    $self->{request} = $request;

    my $response = $self->_send_http_request($request);
    $self->{response} = $response;

    my $response_body = $response->decoded_content;
    if ($response->is_success) {
        if ($response_body =~ /^OK - /) {
            return 1;
        }
    } 

    my $message = '';
    if ($response_body =~ /^FAIL -/) {
        $message = $response_body;
    } else {
        $message = $response->title;
    }
    Tomcat::AppManager::OpFailException->throw($message);
}

#
# private _send_http_request
#
# The transport method to send a HTTP request.
#
# Parameters:
#
#     $request - a prepared HTTP::Request ready to be sent
#
# Returns:
#
#     An HTTP::Response object
#

sub _send_http_request {
    my $self = shift;
    my $request = shift;

    my $ua = LWP::UserAgent->new();
    return $ua->request($request);
}

1;
