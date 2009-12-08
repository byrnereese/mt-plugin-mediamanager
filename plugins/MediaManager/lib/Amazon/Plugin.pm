package Amazon::Plugin;

use Amazon::Util qw(trim readconfig handle_expressions);
use Net::Amazon;

use MT::Util qw( format_ts);

sub _process_args {
    my ($args) = @_;

    if (!defined($args->{'responsegroup'})) {
        $args->{'responsegroup'} = 'Small,Images,OfferSummary';
    }

#    foreach (qw(ItemId ResponseGroup ItemPage SearchIndex Keywords)) {
#        my $key = lc($_);
#        $args->{$_} = delete $args->{$key} if ($args->{$key});
#    }

    foreach my $key (keys %$args) {
        if ($key eq 'productgroup') {
            $args->{'mode'} = lc delete $args->{$key};
        } elsif ($key eq '@') {
            # Hack
            delete $args->{$key};
        } elsif ($key eq 'responsegroup') {
            # Does this require special handling? Removing for backwards compat
            delete $args->{$key};
        } elsif ($key eq 'keywords') {
            $args->{'keyword'} = delete $args->{$key};
        }
    }

    return $args;
}

sub ItemSearch {
    my ($ctx, $args) = @_;
    
    my $config = readconfig($ctx->stash('blog_id'));
    $args = _process_args( $args );
    $args = handle_expressions($ctx, $args);

    my $lastn = $args->{lastn} || 10;

    my $cache = undef;
    if ($config->{cache_path} && $config->{cache_expire}) {
        require Cache::File;
        $cache = Cache::File->new( 
            cache_root        => $config->{cache_path},
            default_expires   => $config->{cache_expire},
            namespace         => 'MTAmazon',
            );
    }

    my $ua = Net::Amazon->new(
        token      => $config->{accesskey},
        secret_key => $config->{secretkey},
        locale     => $config->{locale},
        ($cache ? (cache => $cache) : ()),
        );
    
    # Get a request object
    my $response = $ua->search( %$args );
    return $ctx->error( $response->message() ) unless $response->is_success();

    my $prod;
    my $count = 0;
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    my $out = '';
    my $vars = $ctx->{__stash}{vars} ||= {};
    my $glue = $args->{glue};
    my $var = $args->{var};
    for my $item ($response->properties) {
        local $vars->{__first__} = $count == 1;
        local $vars->{__last__} = $count == scalar @$var;
        local $vars->{__odd__} = ($count % 2 ) == 1;
        local $vars->{__even__} = ($count % 2 ) == 0;
        local $vars->{__counter__} = $count;
        last if ++$count > $lastn;
        $ctx->stash('AmazonItem', $item);
        my $out = $builder->build($ctx, $tokens);
        return $ctx->error( $builder->errstr ) unless defined $out;
        $prod .= $out;
        $i++;
    }
    return $prod;
}

sub AmazonASIN {
    my $ctx = shift;
    defined(my $i = $ctx->stash('AmazonItem'))
        or return '';
    $i->Asin || '';
}

sub AmazonDetailPageURL {
    my $ctx = shift;
    defined(my $i = $ctx->stash('AmazonItem'))
        or return '';
    $i->url || '';
}

sub AmazonTitle {
    my $ctx = shift;
    defined(my $i = $ctx->stash('AmazonItem'))
        or return '';
    $i->ProductName || '';
}

sub AmazonProductGroup {
    my $ctx = shift;
    defined(my $i = $ctx->stash('AmazonItem'))
        or return '';
    $i->Catalog || '';
}

sub AmazonItemProperty {
    my ($ctx, $args) = @_;
    defined(my $i = $ctx->stash('AmazonItem'))
        or return '';
    my $property = $args->{'property'};
    return $i->$property();
}

sub AmazonPrice {
    my ($ctx, $args) = @_;
    defined(my $i = $ctx->stash('AmazonItem'))
        or return '';
    my $type = lc($args->{'type'}) || 'New';
    if ($type eq 'new') {
        return $i->OurPrice;
    } elsif ($type eq 'used') {
        return $i->UsedPrice;
    } elsif ($type eq 'list') {
        return $i->ListPrice;
    }
}

sub AmazonImageTag {
    my ($ctx, $args) = @_;
    defined(my $i = $ctx->stash('AmazonItem'))
        or return '';
    my $size = $args->{'size'};
    $size =~ s/^(.)(.*)/uc($1).lc($2)/e;
    my $uprop = $size.'Image';
    my $wprop = $size.'ImageWidth';
    my $hprop = $size.'ImageHeight';
    my $url = $i->$uprop();
    my $h   = $i->$hprop();
    my $w   = $i->$wprop();
    return '<img src="'.$url.'" width="'.$w.'" height="'.$h.'" />';
}

sub AmazonImageURL {
    my ($ctx,$args) = @_;
    defined(my $i = $ctx->stash('AmazonItem'))
        or return '';
    
    my $config = readconfig($ctx->stash('blog_id'));
    
    my $opts = "_";
    $opts .= "THUMBZZZ_" if $args->{'size'} eq "thumb";
    $opts .= "TZZZZZZZ_" if $args->{'size'} eq "small";
    $opts .= "SCMZZZZZZZ_" if $args->{'size'} eq "medium";
    $opts .= "SCLZZZZZZZ_" if $args->{'size'} eq "large";
    $opts .= "AA".$args->{'width'}."_" if $args->{'width'};
    if ($opts eq '_') { # user did not specify a size
        $opts .= "SCMZZZZZZZ_";
    }
    $opts .= "PU".$args->{'rotation'}."_" if $args->{'rotation'};
    $opts .= "BL".$args->{'blur'}."_" if $args->{'blur'};
    $opts .= "PB_" if $args->{'shadow'} eq 'left';
    $opts .= "PC_" if $args->{'shadow'} eq 'right';
    if ($args->{'percent'}) {
        $opts .= "PD".$args->{'percent'}."_" if $args->{'percentloc'} eq 'left';
        $opts .= "PE".$args->{'percent'}."_" if $args->{'percentloc'} eq 'right';
    }
	
	my $locale;
    if ($config->{locale} eq 'uk') {
		$locale = '02';
    } elsif ($config->{locale} eq 'de') {
		$locale = '03';
    } elsif ($config->{locale} eq 'jp') {
		$locale = '09';
    } elsif ($config->{locale} eq 'fr') {
		$locale = '08';
    } elsif ($config->{locale} eq 'ca') {
		$locale = '01';
    } else { # default to US
		$locale = '01';
    }
	
    return 'http://images.amazon.com/images/P/'.$i->Asin.'.'.$locale.'.'.$opts.'.jpg';
}

1;
__END__
