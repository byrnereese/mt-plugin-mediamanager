package MTAmazon3::Template::Context;

use MTAmazon3::Plugin qw(ItemLookupHelper);
use MTAmazon3::Util qw(trim readconfig find_cached_item cache_item CallAmazon handle_expressions);

use MT::Util qw( format_ts);

sub amazon_tags {
    return {
        block => {
	    'AmazonItemLookup' => \&ItemLookup,
	    'AmazonItemSearch' => \&ItemSearch,
	    'AmazonSimilarityLookup' => \&AmazonSimilarityLoopup,
	    'AmazonListSearch' => \&ListSearch,
	    'AmazonListLookup' => \&AmazonListLookup,
	    'AmazonIfItemAttribute?' => \&AmazonIfItemAttribute,
	},
	function => {
	    'AmazonTitle' => \&AmazonTitle,
	    'AmazonDetailPageURL' => \&AmazonDetailPageURL,
	    'AmazonASIN' => \&AmazonASIN,
	    'AmazonProductGroup' => \&AmazonProductGroup,
	    'AmazonItemAttributes' => \&AmazonItemAttributes,
	    'AmazonImageTag' => \&AmazonImage,
	    'AmazonCustomImageURL' => \&AmazonCustomImage,
	    'AmazonPrice' => \&AmazonPrice,
	    'AmazonField' => \&AmazonField,
	    'AmazonListId' => \&AmazonListId,
	    'AmazonListURL' => \&AmazonListURL,
	    'AmazonListType' => \&AmazonListType,
	    'AmazonListName' => \&AmazonListName,
	},
    };
}

sub ItemLookup {
    my ($ctx, $args) = @_;

    if (!defined($args->{'responsegroup'})) {
	$args->{'responsegroup'} = 'Small,Images,OfferSummary';
    }

    my $config = readconfig($ctx->stash('blog_id'));

    my $tokens = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');

#    $args = handle_expressions($ctx, $args);

    my $content_tree;
    eval {
	$content_tree = ItemLookupHelper($config,$args);
    };
    if ($@) {
	return $ctx->error($@);
    }
#    $ctx->stash('AmazonXML', $p->XMLout($content_tree));
    my $details = $content_tree->{'Items'}->{'Item'};
    return '' unless defined $details; 
    my $prod = '';
    $ctx->stash('AmazonItem', $details);
    my $out = $builder->build($ctx, $tokens);
    return $ctx->error( $builder->errstr ) unless defined $out;
    $prod .= $out;
    return $prod;
}

sub ItemSearch {
    my ($ctx, $args) = @_;

    if (!defined($args->{'responsegroup'})) {
	$args->{'responsegroup'} = 'Small,Images,OfferSummary';
    }
    my $config = readconfig($ctx->stash('blog_id'));

    my $tokens = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    $args = handle_expressions($ctx, $args);

    my $lastn = $args->{lastn} || 1;
    my $pages = int(($lastn/10) + .9999);
    my $items = [];
    for (my $page = 1; $page <= $pages; $page++) {
	my $content_tree;
	my $item;
	require XML::Simple;
	my $p = new XML::Simple;
	$args->{'ItemPage'} = $page;
	my $content = CallAmazon("ItemSearch",$config,$args);
	eval { $content_tree = $p->XMLin($content); };
	if ($content_tree && $content_tree->{'Error'}) {
	    return $ctx->error("Amazon returned the following error: ".
			       $content_tree->{Error}->{Message});
	} elsif ($@) {
	    return $ctx->error("Error reading response from Amazon. It is ".
			       "possible that Amazon returned an HTTP Status ".
			       "of 500 due to an intermittent problem on their ".
			       "end. Here is the content of their response: ".
			       $content);
	}

	$ctx->stash('AmazonXML', $p->XMLout($content_tree));

	if ($page == 1 && 
	    $content_tree->{'Items'}->{'TotalPages'} && 
            $content_tree->{'Items'}->{'TotalPages'} < $pages) {
	    $pages = $content_tree->{'Items'}->{'TotalPages'};
	}

	my $details;
	if ((ref $content_tree->{'Items'}->{'Item'} eq 'HASH')) {
	    $details = [ $content_tree->{'Items'}->{'Item'} ];
	} else {
	    $details = $content_tree->{'Items'}->{'Item'};
	}
	$details = [] if !$details;
	push @$items, @$details;
    }

    return '' unless defined @$items; 
    my $prod;
    my $count = 0;
    for my $i (@$items) {
        last if ++$count > $lastn;
        $ctx->stash('AmazonItem', $i);
        my $out = $builder->build($ctx, $tokens);
        return $ctx->error( $builder->errstr ) unless defined $out;
        $prod .= $out;
    }
    return $prod;
}

sub SimilarityLookup {
    my ($ctx, $args) = @_;

    if (!defined($args->{'responsegroup'})) {
	$args->{'responsegroup'} = 'Small,Images,OfferSummary';
    }
    my $config = readconfig($ctx->stash('blog_id'));

    my $tokens = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    $args = handle_expressions($ctx, $args);

    my $lastn = $args->{lastn} || 1;
    my $pages = int(($lastn/10) + .9999);
    my $items = ();
    for (my $page = 1; $page <= $pages; $page++) {
	my $content_tree;
	my $item;
	require XML::Simple;
	my $p = new XML::Simple;
	$args->{'ItemPage'} = $page;
	my $content = CallAmazon("SimilarityLookup",$config,$args);
	eval { $content_tree = $p->XMLin($content); };
	if ($content_tree && $content_tree->{'Error'}) {
	    return $ctx->error("Amazon returned the following error: ".
			       $content_tree->{Error}->{Message});
	} elsif ($@) {
	    return $ctx->error("Error reading response from Amazon. It is ".
			       "possible that Amazon returned an HTTP Status ".
			       "of 500 due to an intermittent problem on their ".
			       "end. Here is the content of their response: ".
			       $content);
	}

	$ctx->stash('AmazonXML', $p->XMLout($content_tree));

	if ($page == 1 && 
	    $content_tree->{'Items'}->{'TotalPages'} && 
            $content_tree->{'Items'}->{'TotalPages'} < $pages) {
	    $pages = $content_tree->{'Items'}->{'TotalPages'};
	}

	my $details;
	if ((ref $content_tree->{'Items'}->{'Item'} eq 'HASH')) {
	    $details = [ $content_tree->{'Items'}->{'Item'} ];
	} elsif ((ref $content_tree->{'Items'}->{'Item'} eq 'ARRAY')) {
	    $details = $content_tree->{'Items'}->{'Item'};
	} else {
	    return $ctx->error("Unknown response from Amazon - response was of type: " .
			       ref $content_tree->{'Items'}->{'Item'});
	}
	push @$items, @$details;
    }

    return '' unless defined @$items; 
    my $prod;
    my $count = 0;
    for my $i (@$items) {
        last if ++$count > $lastn;
        $ctx->stash('AmazonItem', $i);
        my $out = $builder->build($ctx, $tokens);
        return $ctx->error( $builder->errstr ) unless defined $out;
        $prod .= $out;
    }
    return $prod;
}

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

sub AmazonASIN {
    my $ctx = shift;
    defined(my $i = $ctx->stash('AmazonItem'))
        or return '';
    $i->{ASIN} || '';
}

sub AmazonDetailPageURL {
    my $ctx = shift;
    defined(my $i = $ctx->stash('AmazonItem'))
        or return '';
    $i->{DetailPageURL} || '';
}

sub AmazonTitle {
    my $ctx = shift;
    defined(my $i = $ctx->stash('AmazonItem'))
        or return '';
    $i->{ItemAttributes}->{Title} || '';
}

sub AmazonProductGroup {
    my $ctx = shift;
    defined(my $i = $ctx->stash('AmazonItem'))
        or return '';
    $i->{ItemAttributes}->{ProductGroup} || '';
}

sub AmazonIfItemAttribute {
    my ($ctx, $args) = @_;
    defined(my $i = $ctx->stash('AmazonItem'))
        or return 0;
    my $name = $args->{'name'};
    my $elem = $i->{ItemAttributes}->{$name};
    return defined($elem);
}

sub AmazonItemAttributes {
    my ($ctx, $args) = @_;
    defined(my $i = $ctx->stash('AmazonItem'))
        or return '';
    my $name = $args->{'name'};
    my $elem = $i->{ItemAttributes}->{$name};
    if (!defined($elem)) {
	return '';
    } elsif ((ref $elem eq 'ARRAY')) {
	return join(", ",@$elem);
    } else {
	return $elem;
    }
}

sub AmazonPrice {
    my ($ctx, $args) = @_;
    defined(my $i = $ctx->stash('AmazonItem'))
        or return '';
    my $name = lc($args->{'type'}) || 'New';
    $name =~ s/^(.)(.*)/uc($1).lc($2)/e;
    return $i->{OfferSummary}->{'Lowest'.$name.'Price'}->{FormattedPrice};
}

sub AmazonImage {
    my ($ctx, $args) = @_;
    defined(my $i = $ctx->stash('AmazonItem'))
        or return '';
    my $size = $args->{'size'};
    $size =~ s/^(.)(.*)/uc($1).lc($2)/e;
    my $url = $i->{$size.'Image'}->{URL};
    my $h   = $i->{$size.'Image'}->{Height}->{content};
    my $w   = $i->{$size.'Image'}->{Width}->{content};
    return '<img src="'.$url.'" width="'.$w.'" height="'.$h.'" />';
}

sub AmazonCustomImage {
    my ($ctx,$args) = @_;
    defined(my $i = $ctx->stash('AmazonItem'))
        or return '';
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
    return 'http://images.amazon.com/images/P/'.$i->{ASIN}.'.01.'.$opts.'.jpg';
}

sub AmazonField { 
    my ($ctx, $args) = @_; 
    $args = handle_expressions($ctx, $args);
    my $name = $args->{name}; 
    return '' unless $name; 
    defined(my $i = $ctx->stash('AmazonItem')) 
     or return ''; 
    if ($name =~ m|/|) {
        my @path = split(/\//, $name);
        $name = pop @path;
        for my $node (@path) {
            $i = $i->{$node};
        }
    }
    $i->{$name} || ''; 
} 

1;
__END__

