package Amazon::Template::Context;

use Amazon::Plugin qw(ItemLookupHelper);
use Amazon::Util qw(trim readconfig handle_expressions);
use Net::Amazon;

use MT::Util qw( format_ts);

sub amazon_tags {
    return {
        block => {
            'AmazonItemSearch' => \&ItemSearch,
#            'AmazonListSearch' => \&ListSearch,
#            'AmazonListLookup' => \&AmazonListLookup,
#            'AmazonIfItemAttribute?' => \&AmazonIfItemAttribute,

        },
        function => {
            'AmazonASIN' => \&AmazonASIN,
            'AmazonTitle' => \&AmazonTitle,
            'AmazonDetailPageURL' => \&AmazonDetailPageURL,
            'AmazonProductGroup' => \&AmazonProductGroup,
            'AmazonImageTag' => \&AmazonImageTag,
            'AmazonImageURL' => \&AmazonImageURL,
            'AmazonPrice' => \&AmazonPrice,
            'AmazonItemProperty' => \&AmazonItemProperty,
#            'AmazonListId' => \&AmazonListId,
#            'AmazonListURL' => \&AmazonListURL,
#            'AmazonListType' => \&AmazonListType,
#            'AmazonListName' => \&AmazonListName,

        },
    };
}

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
    
    $args = _process_args( $args );

    my $config = readconfig($ctx->stash('blog_id'));

    my $tokens = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    $args = handle_expressions($ctx, $args);

    my $lastn = $args->{lastn} || 10;

    my $cache = undef;
    if ($config->{cache_path} && $config->{cache_expire}) {
        require Cache::File;
        $cache = Cache::File->new( 
            cache_root        => $config->{cache_path},
            namespace         => 'MTAmazon',
            default_expires   => $config->{cache_expire},
            );
    }

    my $ua = Net::Amazon->new(
        token      => $config->{accesskey},
        secret_key => $config->{secretkey}
        cache      => $cache,
        );
        
    # Get a request object
    my $response = $ua->search( %$args );
    return '' unless $response->is_success();

    my $count = 0;
    my $prod;
    for my $i ($response->properties) {
        last if ++$count > $lastn;
        $ctx->stash('AmazonItem', $i);
        my $out = $builder->build($ctx, $tokens);
        return $ctx->error( $builder->errstr ) unless defined $out;
        $prod .= $out;
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

sub ListSearch {
    my ($ctx, $args) = @_;

    if (!defined($args->{'responsegroup'})) {
	$args->{'responsegroup'} = 'Request,ListInfo';
    }
    if (!defined($args->{'ListType'})) {
	$args->{'ListType'} = 'WishList';
    }
    my $config = readconfig($ctx->stash('blog_id'));

    my $tokens = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    $args = handle_expressions($ctx, $args);

    my $lastn = $args->{lastn} || 1;
    my $pages = int(($lastn/10) + .9999);
    my $lists;
    for (my $page = 1; $page <= $pages; $page++) {
	my $content_tree;
	my $list;
	require XML::Simple;
	my $p = new XML::Simple;
	$args->{'ListPage'} = $page;
	my $content = CallAmazon("ListSearch",$config,$args);
	eval { $content_tree = $p->XMLin($content); };
	if ($content_tree && 
	    $content_tree->{'Lists'}->{'Request'}->{'Errors'}->{'Error'}) {
	    return $ctx->error("Amazon returned the following error: ".
	       $content_tree->{'Lists'}->{'Request'}->{'Errors'}->{'Error'}->{'Message'});
	} elsif ($@) {
	    return $ctx->error("Error reading response from Amazon. It is ".
			       "possible that Amazon returned an HTTP Status ".
			       "of 500 due to an intermittent problem on their ".
			       "end. Here is the content of their response: ".
			       $content);
	}

	$ctx->stash('AmazonXML', $p->XMLout($content_tree));

	if ($page == 1 && 
	    $content_tree->{'Lists'}->{'TotalPages'} && 
            $content_tree->{'Lists'}->{'TotalPages'} < $pages) {
	    $pages = $content_tree->{'Lists'}->{'TotalPages'};
	}

	my $details;
	if ((ref $content_tree->{'Lists'}->{'List'} eq 'HASH')) {
	    $details = [ $content_tree->{'Lists'}->{'List'} ];
	} else {
	    $details = $content_tree->{'Lists'}->{'List'};
	}
	push @$lists, @$details;
    }

    return '' unless defined @$lists; 
    my $prod;
    my $count = 0;
    for my $i (@$lists) {
        last if ++$count > $lastn;
        $ctx->stash('AmazonList', $i);
        my $out = $builder->build($ctx, $tokens);
        return $ctx->error( $builder->errstr ) unless defined $out;
        $prod .= $out;
    }
    return $prod;
}

sub ListLookup {
    my ($ctx, $args) = @_;

    if (!defined($args->{'responsegroup'})) {
	$args->{'responsegroup'} = 'ItemAttributes,ListInfo,ListItems,Small,Images,OfferSummary';
    }
    if (!defined($args->{'ListType'})) {
	$args->{'ListType'} = 'WishList';
    }
    my $config = readconfig($ctx->stash('blog_id'));

    my $tokens = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    $args = handle_expressions($ctx, $args);

    my $lastn = $args->{lastn} || 1;
    my $pages = int(($lastn/10) + .9999);
    my $items;
    for (my $page = 1; $page <= $pages; $page++) {
	my $content_tree;
	my $item;
	require XML::Simple;
	my $p = new XML::Simple;
	$args->{'ItemPage'} = $page;
	my $content = CallAmazon("ListLookup",$config,$args);
	eval { $content_tree = $p->XMLin($content); };
	if ($content_tree && 
	    $content_tree->{'Lists'}->{'Request'}->{'Errors'}->{'Error'}) {
	    return $ctx->error("Amazon returned the following error: ".
	       $content_tree->{'Lists'}->{'Request'}->{'Errors'}->{'Error'}->{'Message'});
	} elsif ($@) {
	    return $ctx->error("Error reading response from Amazon. It is ".
			       "possible that Amazon returned an HTTP Status ".
			       "of 500 due to an intermittent problem on their ".
			       "end. Here is the content of their response: ".
			       $content);
	}

	$ctx->stash('AmazonXML', $p->XMLout($content_tree));

	if ($page == 1 && 
	    $content_tree->{'Lists'}->{'TotalPages'} && 
            $content_tree->{'Lists'}->{'TotalPages'} < $pages) {
	    $pages = $content_tree->{'Lists'}->{'TotalPages'};
	}

	my $details;
	if ((ref $content_tree->{'Lists'}->{'List'}->{'ListItem'} eq 'HASH')) {
	    $details = [ $content_tree->{'Lists'}->{'List'}->{'ListItem'} ];
	} else {
	    $details = $content_tree->{'Lists'}->{'List'}->{'ListItem'};
	}
	push @$items, @$details;
    }

    return '' unless defined @$items; 
    my $prod;
    my $count = 0;
    for my $i (@$items) {
        last if ++$count > $lastn;
        $ctx->stash('AmazonItem', $i->{Item});
        my $out = $builder->build($ctx, $tokens);
        return $ctx->error( $builder->errstr ) unless defined $out;
        $prod .= $out;
    }
    return $prod;
}

sub AmazonListId {
    my $ctx = shift;
    defined(my $i = $ctx->stash('AmazonList'))
        or return '';
    $i->{ListId} || '';
}

sub AmazonListURL {
    my $ctx = shift;
    defined(my $i = $ctx->stash('AmazonList'))
        or return '';
    $i->{ListURL} || '';
}

sub AmazonListName {
    my $ctx = shift;
    defined(my $i = $ctx->stash('AmazonList'))
        or return '';
    $i->{ListName} || '';
}

sub AmazonListType {
    my $ctx = shift;
    defined(my $i = $ctx->stash('AmazonList'))
        or return '';
    $i->{ListType} || '';
}
