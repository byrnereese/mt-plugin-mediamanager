# Media Manager Movable Type Plugin
# This software is licensed under the GPL
# Copyright (C) 2005-2007, Six Apart, Ltd.

package MTAmazon3::Util;

use strict;
use vars qw($TTL_DAYS @EXPORT_OK @ISA);
require Exporter;
@EXPORT_OK = qw(trim readconfig find_cached_item cache_item CallAmazon handle_expressions);
@ISA = qw(Exporter);

$TTL_DAYS = 7;

sub plugin {
    return MT->component('MTAmazon');
}

sub trim {
    my($string)=@_;
    for ($string) {
	s/^\s+//;
	s/\s+$//;
    }
    return $string;
}

sub readconfig {
    my ($scope,$options) = @_;
    $options = {} if !defined($options);
    require MT::Request;

    my $blog_id = $scope;
    
    my $config;
    $config = MT::Request->instance->stash('MTAmazon3Config');
    return $config if (defined($config));

    my $sys_config = plugin()->get_config_hash('system');
    foreach my $key (keys %$sys_config) {
	if (defined($sys_config->{$key} && $sys_config->{$key} ne '')) {
	    $config->{$key} = trim($sys_config->{$key});
	}
    }
    my $blog_config = plugin()->get_config_hash('blog:'.$blog_id);
    foreach my $key (keys %$blog_config) {
	next if ($key eq "allow_sid" || $key eq "allow_aid");
	next if ($key eq "associateid" && !$sys_config->{'allow_aid'});
	next if ($key eq "accesskey" && !$sys_config->{'allow_sid'});
	if ($blog_config->{$key} ne '' && defined($blog_config->{$key})) {
	    $config->{$key} = trim($blog_config->{$key});
	}
    }
    if (!$options->{ignore_errors}&& 
	(!defined($config->{'accesskey'}) ||
	 $config->{'accesskey'} eq "")) {
	die "You have not configured MTAmazon properly. Please visit the system level plugin settings and enter in a 'Access Key Id.'";
    }
    if (!$options->{ignore_errors}&& 
	(!defined($config->{'associateid'}) ||
	 $config->{'associateid'} eq "")) {
	die "You have not configured MTAmazon properly. Please visit your blog's plugin settings and enter in an 'Associates Id.'";
    }
    MT::Request->instance->stash('MTAmazon3Config', $config);
    return $config;
}

sub find_cached_item {
    my ($asin, $response_groups) = @_;
    my @groups = split(",",$response_groups);
    my $sorted_groups = join(",",sort @groups);

    my %constraints;
    $constraints{asin}            = $asin;
    $constraints{response_groups} = $sorted_groups;

    my $item;
    require MTAmazon3::Item;
    if ( $item = MTAmazon3::Item->load( \%constraints ) ) {
	my $now = time();
	my ($year,$mon,$mday,$hour,$min,$sec) = 
	    ($item->created_on =~ /(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/);
	require Time::Local;
	my $then = Time::Local::timelocal($sec,$min,$hour,$mday,($mon - 1),$year);
	my $diff = $now - $then;
	my $ttl = $TTL_DAYS * 24 * 60 * 60;
        if ($diff > $ttl) {
	    $item->remove;
	    return undef;
        }
        return $item;  
    }
    return undef;
}

sub cache_item {
    my ($asin,$response_groups,$data) = @_;
    my @groups = ($response_groups ? split(",",$response_groups) : ());
    my $sorted_groups = join(",",sort @groups);

    my %constraints;
    $constraints{asin}            = $asin;
    $constraints{response_groups} = $sorted_groups;

    require MTAmazon3::Item;
    my $item;
    if ( $item = MTAmazon3::Item->load( \%constraints ) ) {
	$item->remove;
    }
    $item = MTAmazon3::Item->new;
    $item->asin($asin);
    $item->response_groups($sorted_groups);
    use Data::Dumper;
    $item->data(Dumper($data));
    $item->save;
}

sub _compose_url {
    my ($operation,$config,$args) = @_;
    my $url;
    if (!$config) { die "No configuration defined."; }
    if ($config->{locale} eq 'uk') {
	$url = "http://webservices.amazon.co.uk/onca/xml";
    } elsif ($config->{locale} eq 'de') {
	$url = "http://webservices.amazon.de/onca/xml";
    } elsif ($config->{locale} eq 'jp') {
	$url = "http://webservices.amazon.co.jp/onca/xml";
    } elsif ($config->{locale} eq 'fr') {
	$url = "http://webservices.amazon.fr/onca/xml";
    } elsif ($config->{locale} eq 'ca') {
	$url = "http://webservices.amazon.ca/onca/xml";
    } else { # default to US
	$url = "http://webservices.amazon.com/onca/xml";
    }
    my $qs = "Service=AWSECommerceService";
    $qs .= "&Operation=$operation";
    $qs .= "&AWSAccessKeyId=".$config->{accesskey};
    $qs .= "&AssociateTag=".$config->{associateid};
    foreach (keys %$args) {
	unless ($_ eq "AWSAccessKey" || $_ eq "Operation") {
	    $qs .= "&".$_."=".$args->{$_} if $args->{$_};
	}
    }
    return $url."?".$qs;
}

sub CallAmazon {
    my ($operation, $config, $args) = @_;
    
    my $delay = $config->{'delay'};
    if ($delay) { 
	sleep(1); 
    }
    my $associateid = $config->{'associateid'};
    my $accesskey   = $config->{'accesskey'};
    my $locale      = $config->{'locale'};

    foreach (qw(ItemId ResponseGroup ItemPage SearchIndex Keywords)) {
	my $key = lc($_);
	$args->{$_} = delete $args->{$key} if ($args->{$key});
    }
    # the following line(s) short circuit the call to Amazon if we know we will 
    # not get anything in response
    if ($args->{ItemId} eq "" && $operation eq "ItemLookup") { return ""; }

    my $url = _compose_url($operation, $config, $args);

    require LWP::UserAgent;
    require HTTP::Request;
    my $ua = new LWP::UserAgent;
    $ua->agent("MTAmazon/".$MT::Plugin::MTAmazon3::VERSION);
    my $http_request = new HTTP::Request('GET', $url);
    my $http_response = $ua->request($http_request);
    my $content = $http_response->{'_content'};
    # convert nodes that contain only spaces to empty nodes
    $content =~ s/<[^\/]([^>]+)>\s+<\/[^>]+>/<$1 \/>/g; 
    return $content;
}

# Process MT tags in all arguments. Returns an argument reference
# with all tags processed.
sub handle_expressions {
    my($ctx, $args) = @_;
    use MT::Util qw(decode_html);
    my %new_args;
    my $builder = $ctx->stash('builder');
    for my $arg (keys %$args) {
        my $expr = decode_html($args->{$arg});
        if ( ($expr =~ m/\<MT.*?\>/g) ||
              $expr =~ s/\[(MT(.*?))\]/<$1>/g) {
            my $tok = $builder->compile($ctx, $expr);
            my $out = $builder->build($ctx, $tok);
            return $ctx->error("Error in argument expression: ".$builder->errstr) unless defined $out;
            $new_args{$arg} = $out;
        } else {
            $new_args{$arg} = $expr;
        }
    }
    \%new_args;
}

sub generate_sig {
    my ($key, $data) = @_;
    # concatenating: Service, Operation, Timestamp
    require Digest::HMAC_SHA1;
    my $hmac = Digest::HMAC_SHA1->new($key);
    $hmac->add($data);
    my $digest = $hmac->b64digest;
    return $digest;
}

1;

__END__

