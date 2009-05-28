package MediaManager::Template::Context;

use MediaManager::Entry;
use MediaManager::Review;
use MediaManager::Util;
use MT::Util qw( format_ts);

sub mm_tags {
    return {
        block => {
	    MediaManagerRandomItem => \&_hdlr_random_item,
	    MediaManagerItems => \&_hdlr_mediamanager_entries,
	},
	function => {

	    # TODO 
	    'ItemIcon' => \&_hdlr_itemicon, # TODO
	    'ItemFinishedDate' => \&_hdlr_itemfinishedon, # TODO
	    'ItemModifiedDate' => \&_hdlr_itemmodifiedon, # TODO
	    'ItemEntryPermalink' => \&_hdlr_itementrylink, # TODO
	    'ItemIfBlogEntry?' => \&_hdlr_itemifentry, # TODO

	    # OBSOLETE
	    'ItemCount' => \&_hdlr_itemcount, # replaced by _hdlr_asset_count
	    'ItemISBN' => \&_hdlr_itemisbn, # replaced by AssetProperty
	    'ItemASIN' => \&_hdlr_itemisbn, # replaced by AssetProperty
	    'ItemStatus' => \&_hdlr_itemstatus, # replaced by AssetProperty
	    'ItemCatalog' => \&_hdlr_itemcatalog, # replaced by AssetProperty
	    'ItemTitle' => \&_hdlr_itemtitle, # replaced by AssetLabel
	    'ItemCreatedDate' => \&_hdlr_itemcreatedon, # replaced by AssetDateAdded
	    'ItemEntryDate' => \&_hdlr_itemcreatedon, # replaced by AssetDateAdded
	    'ItemEntryID' => \&_hdlr_itementryid, # TODO - need an AssetEntries
	    'ItemEntryLink' => \&_hdlr_itementrylink, # replaced by AssetLink

	    # RETIRE?
	    'ItemIfFinishedDate?' => \&_hdlr_itemiffinishedon,
	    'EntryIfReview?' => \&_hdlr_itemifentry,
	    'ReviewRatingNumber' =>\&_mm_review_rating_number,
	    'ReviewRatingName' => \&_mm_review_rating_name,
	    'ReviewRatingIs1?' => \&_mm_review_rating_is,
	    'ReviewRatingIs2?' => \&_mm_review_rating_is,
	    'ReviewRatingIs3?' => \&_mm_review_rating_is,
	    'ReviewRatingIs4?' => \&_mm_review_rating_is,
	    'ReviewRatingIs5?' => \&_mm_review_rating_is,
	},
    };
}	

sub _compile_tag_filter {
    my ($tag_expr, $tags) = @_;

    # sort in descending order by length
    @$tags = sort {length($b->name) <=> length($a->name)} @$tags;

    my %tags_used;
    foreach my $tag (@$tags) {
        my $name = $tag->name;
        my $id = $tag->id;
        if ($tag_expr =~ s/(?<!#)\Q$name\E/#$id/g) {
            $tags_used{$id} = $tag;
        }
    }
    @$tags = values %tags_used if $tag_expr !~ m/\bNOT\b/i;
    $tag_expr =~ s/\bAND\b/&&/gi;
    $tag_expr =~ s/\bOR\b/||/gi;
    $tag_expr =~ s/\bNOT\b/!/gi;
    $tag_expr =~ s/( |#\d+|&&|\|\||!|\(|\))|([^#0-9&|!()]+)/$2?'(0)':$1/ge;

    # strip out all the 'ok' stuff. if anything is left, we have
    # some invalid data in our expression:
    my $test_expr = $tag_expr;
    $test_expr =~ s/!|&&|\|\||\(0\)|\(|\)|\s|#\d+//g;
    return undef if ($test_expr);

    $tag_expr =~ s/#(\d+)/(exists \$p->{\$e}{$1})/g;
    my $expr = 'sub{my($e,$p)=@_;'.$tag_expr.';}';
    my $cexpr = eval $expr;
    $@ ? undef : $cexpr;
}

sub config {
    my $config = {};
    if ($plugin) {
	require MT::Request;
	my ($scope) = (@_);
	$config = MT::Request->instance->cache('mmanager_config_'.$scope);
	if (!$config) {
	    $config = $plugin->get_config_hash($scope);
	    MT::Request->instance->cache('mmanager_config_'.$scope, $config);
	}
    }
    $config;
}

sub check_catalog {
    my ($catalog) = @_;
    my @types = qw ( all Books VideoGames Video Software VHS DVD Music MusicTracks Electronics Kitchen );
    foreach my $type (@types) {
	return 1 if $type eq $catalog;
    }
    return 0;
}

sub _hdlr_mediamanager_entries {
    my($ctx, $args, $cond) = @_;

    MediaManager::Util::debug("Calling MTMediaManagerEntries with ".join(',',keys %$args).".");

    my $status     = lc($args->{status})     || 'all';
    my $catalog    = $args->{catalog}        || 'all';
    my $isbn       = $args->{isbn}           || '';
    my $entry_id   = $args->{entry_id};

    my $entries = $ctx->stash('mm_entries');
    local $ctx->{__stash}{mm_entries};
    my (@filters, %terms, %args);
    my $blog_id = $ctx->stash('blog_id');

    $terms{blog_id} = $blog_id;
    $terms{catalog} = $catalog if $catalog ne 'all';
    $terms{status}  = $status if $status ne 'all';
    $terms{isbn}    = $isbn if $isbn ne '';

    # Adds a tag filter to the filters list.
    if (my $tag_arg = $args->{tag} || $args->{tags}) {
	MediaManager::Util::debug("Found tags: $tag_arg");
        require MT::Tag;
        require MT::ObjectTag;

        my $terms;
        if ($tag_arg !~ m/\b(AND|OR|NOT)\b|\(|\)/i) {
            my @tags = MT::Tag->split(',', $tag_arg);
            $terms = { name => \@tags };
            $tag_arg = join " or ", @tags;
        }
        my $tags = [ MT::Tag->load($terms, {
            binary => { name => 1 },
            join => ['MT::ObjectTag', 'tag_id', { blog_id => $blog_id, object_datasource => MediaManager::Entry->datasource }]
        }) ];
        my $cexpr = _compile_tag_filter($tag_arg, $tags);

        if ($cexpr) {
            my %map;
            for my $tag (@$tags) {
                my $iter = MT::ObjectTag->load_iter({ tag_id => $tag->id, blog_id => $blog_id, object_datasource => MediaManager::Entry->datasource });
                while (my $et = $iter->()) {
                    $map{$et->object_id}{$tag->id}++;
                }
            }
            push @filters, sub { $cexpr->($_[0]->id, \%map) };
        } else {
            return $ctx->error(MT->translate("You have an error in your 'tag' attribute: [_1]", $args->{tag} || $args->{tags}));
        }
    }

    my $no_resort = 0;
    my @entries;
    if (!$entries) {
	MediaManager::Util::debug("No stashed entries.");
        $args{'sort'} = 'created_on';
        $args{'direction'} = 'descend';
        if (!@filters) {
            if (my $last = $args->{lastn}) {
                $args{limit} = $last;
            }
            $args{offset} = $args->{offset} if $args->{offset};
	    MediaManager::Util::debug("No filters found: loading entries with terms: ".join(',',keys %terms));
            @entries = MediaManager::Entry->load(\%terms, \%args);
        } else {
	    MediaManager::Util::debug("Filters found: loading entries with terms: ".join(',',keys %terms));
            my $iter = MediaManager::Entry->load_iter(\%terms, \%args);
            my $i = 0; my $j = 0;
            my $off = $args->{offset} || 0;
            my $n = $args->{lastn};
            ENTRY: while (my $e = $iter->()) {
                for (@filters) {
                    next ENTRY unless $_->($e);
                }
                next if $off && $j++ < $off;
                push @entries, $e;
                $i++;
                last if $n && $i >= $n;
            }
        }
	my $res = '';
    } else {
	MediaManager::Util::debug("Stashed entries!");
        my $so = $args->{sort_order} || '';
        my $col = $args->{sort_by} || 'created_on';
        # TBD: check column being sorted; if it is numeric, use numeric sort
        @$entries = $so eq 'ascend' ?
            sort { $a->$col() cmp $b->$col() } @$entries :
            sort { $b->$col() cmp $a->$col() } @$entries;
        $no_resort = 1;

        if (@filters) {
            my $i = 0; my $j = 0;
            my $off = $args->{offset} || 0;
            my $n = $args->{lastn};
            ENTRY2: foreach my $e (@$entries) {
                for (@filters) {
                    next ENTRY2 unless $_->($e);
                }
                next if $off && $j++ < $off;
                push @entries, $e;
                $i++;
                last if $n && $i >= $n;
            }
        } else {
            my $offset;
            if ($offset = $args->{offset}) {
                if ($offset < scalar @$entries) {
                    @entries = @$entries[$offset..$#$entries];
                } else {
                    @entries = ();
                }
            } else {
                @entries = @$entries;
            }
            if (my $last = $args->{lastn}) {
                if (scalar @entries > $last) {
                    @entries = @entries[0..$last-1];
                }
            }
        }
    }

    my $count = MediaManager::Entry->count(\%terms);
    $ctx->stash( 'mm_count', $count );

    # $entries were on the stash or were just loaded
    # based on a start/end range.

    my $res = '';
    my $tok = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    unless ($no_resort) {
        my $so = $args->{sort_order} || $ctx->stash('blog')->sort_order_posts || '';
        my $col = $args->{sort_by} || 'created_on';
        # TBD: check column being sorted; if it is numeric, use numeric sort
        @entries = $so eq 'ascend' ?
            sort { $a->$col() cmp $b->$col() } @entries :
            sort { $b->$col() cmp $a->$col() } @entries;
    }
    my($last_day, $next_day) = ('00000000') x 2;
    my $i = 0;
    local $ctx->{__stash}{entries} = \@entries;
    my $glue = $args->{glue};
    MediaManager::Util::debug("Found " . $#entries . " items in filter.");
    for my $e (@entries) {
        local $ctx->{__stash}{mm_entry} = $e;
        local $ctx->{current_timestamp} = $e->created_on;
        local $ctx->{modification_timestamp} = $e->modified_on;
        my $this_day = substr $e->created_on, 0, 8;
        my $next_day = $this_day;
        my $footer = 0;
        if (defined $entries[$i+1]) {
            $next_day = substr($entries[$i+1]->created_on, 0, 8);
            $footer = $this_day ne $next_day;
        } else { 
	    $footer++;
	}
#	_stash_mm_entry($ctx,$e);
        my $allow_comments ||= 0;
        my $out = $builder->build($ctx, $tok, {
            %$cond,
            DateHeader => ($this_day ne $last_day),
            DateFooter => $footer,
            EntriesHeader => !$i,
            EntriesFooter => !defined $entries[$i+1],
        });
        return $ctx->error( $builder->errstr ) unless defined $out;
        $last_day = $this_day;
        $res .= $glue if defined $glue && $i;
        $res .= $out;
        $i++;
    }

    $res;
}

sub _stash_mm_entry {
    my ($ctx, $entry) = @_;
    my @fields = qw( isbn status modified_on entry_id finished_on catalog
		     created_on title tags );
    for (@fields) {
	$ctx->stash('mm_' . $_, $entry->$_ || '');
    }
    return $ctx;
}

sub _get_mm_entry {
    my ($ctx) = @_;
    if(my $mm_entry = $ctx->stash('mm_entry')) {
        return $mm_entry;
    }
    my $entry = $_[0]->stash('mm_entry');
    if ($entry) {
        if(my $mm_entry = $ctx->stash('auto_mm_entry')) {
            if($mm_entry->entry_id == $entry->id) {
                return $mm_entry;
            }
            ## this auto mm entry is not for this blog entry
            delete $ctx->{__stash}->{auto_mm_entry};
        }
        if(my $mm_entry = MediaManager::Entry->load({ entry_id => $entry->id })) {
            $ctx->stash('auto_mm_entry', $mm_entry);
            return $mm_entry;
        }
        ## blog entry is not a review
    }
    ## no blog entry context or blog entry is not a review
    return;
}

sub _get_mm_data {
    my ($ctx, $field) = @_;
    if(my $data = $ctx->stash("mm_$field")) {
        return $data;
    }
    my $mm_entry = _get_mm_entry($ctx)
        or return;
    return $mm_entry->$field;
}

sub _get_mm_review {
    my ($ctx) = @_;
    if (my $mm_review = $ctx->stash('mm_review')) {
        return $mm_review;
    }
    if (my $mm_entry = _get_mm_entry($ctx)) {
        if (my $mm_review = $ctx->stash('auto_mm_review')) {
            if ($mm_review->entry_id == $mm_entry->id) {
                return $mm_review;
            }
            ## this auto mm review is not for this mm entry
            delete $ctx->{__stash}->{auto_mm_review};
        }
        if(my $mm_review = MediaManager::Review->load({ entry_id => $mm_entry->id })) {
            $ctx->stash('auto_mm_review', $mm_review);
            return $mm_review;
        }
        ## mm entry has no review
    }
    ## no mm entry or mm entry has no review
    return;
}

sub _get_review_data {
    my ($ctx, $field) = @_;
    my $mm_review = _get_mm_review($ctx)
        or return;
    return $mm_review->$field;
}

sub _hdlr_random_item
{
    my ($ctx, $args) = @_;

    my $builder = $ctx->stash('builder');
    my $tokens  = $ctx->stash('tokens');
    my $blog_id = $ctx->stash('blog_id');

    my $status     = lc($args->{status})     || 'all';
    my $catalog    = $args->{catalog}        || 'all';

    return $ctx->error("Recognized catalog type: $catalog")
	if !check_catalog($catalog);

    my $blog = $ctx->stash('mm_blog');
    if (!defined($blog)) { 
      require MT::Blog;
      $blog = MT::Blog->load($blog_id); 
      $ctx->stash('mm_blog', $blog);
    }

    my %constraints;
    $constraints{blog_id} = $blog->id;
    $constraints{status}  = $status if $status ne 'all';
    $constraints{catalog} = $catalog if $catalog ne 'all';

    my $count = MediaManager::Entry->count(\%constraints);
    my $offset = rand $count;
    my %options;
    $options{offset} = $offset;
    $options{limit}  = 1;

    $ctx->stash( 'mm_count', $count );
    my $iter = MediaManager::Entry->load_iter( 
         \%constraints,
	 \%options,
    );
    my $res = '';
    my @fields = qw( isbn status modified_on entry_id finished_on catalog
		     created_on tags );
    
    while (my $entry = $iter->()) {
	for (@fields) {
	    $ctx->stash('mm_' . $_, $entry->$_ || '');
	}
	defined(my $out = $builder->build($ctx, $tokens))
	    or return $ctx->error($ctx->errstr);
	$res .= $out;
    } 
    $res;
}

sub hdlr_itemicon
{
    my $e = $_[0]->stash('mm_entry')
	or return $_[0]->_no_entry_error('MTItemTitle');
    my $app = MT->instance;
    my $icon = $app->{cfg}->StaticWebPath . "/plugins/MediaManager/images/icon-" . lc($e->catalog) . ".gif";
    $icon =~ s/ //g;
    return $icon;
}

sub hdlr_itemtitle {
    my $e = $_[0]->stash('mm_entry')
	or return $_[0]->_no_entry_error('MTItemTitle');
    my $title = defined $e->title ? $e->title : '';
    $title;
}

sub hdlr_itemcount
{
    return $_[0]->stash('mm_count')
	or return $_[0]->_no_entry_error('MTItemCount');
}

sub hdlr_itemcatalog
{
    my $e = $_[0]->stash('mm_entry')
	or return $_[0]->_no_entry_error('MTItemCatalog');
    my $catalog = defined $e->catalog ? $e->catalog : '';
    $catalog;
}

sub hdlr_itemisbn
{
    my $e = $_[0]->stash('mm_entry')
	or return $_[0]->_no_entry_error('MTItemISBN');
    my $isbn = defined $e->isbn ? $e->isbn : '';
    $isbn;
}

# Deprecated starting in MM 1.1
sub hdlr_itemstatus
{
    my $e = $_[0]->stash('mm_entry')
	or return $_[0]->_no_entry_error('MTItemStatus');
    my $status = defined $e->status ? $e->status : '';
    $status;
}

sub hdlr_itemcreatedon
{
    my $e = $_[0]->stash('mm_entry')
	or return $_[0]->_no_entry_error('MTItemCreatedOn');
    my $fin = defined $e->created_on ? $e->created_on : '';
    return "" if !$fin;
    format_ts($args->{format}, $fin, $_[0]->stash('blog'));
}

sub hdlr_itemfinishedon
{
    my $e = $_[0]->stash('mm_entry')
	or return $_[0]->_no_entry_error('MTItemFinishedOn');
    my $fin = defined $e->finished_on ? $e->finished_on : '';
    return "" if !$fin;
    format_ts($_[1]->{format}, $fin, $_[0]->stash('blog'));
}

sub hdlr_itemiffinishedon
{
    my $e = $_[0]->stash('mm_entry')
	or return $_[0]->_no_entry_error('MTItemIfFinishedDate');
    return defined $e->finished_on ? 1 : 0;
}

sub hdlr_itemmodifiedon
{
    my $e = $_[0]->stash('mm_entry')
	or return $_[0]->_no_entry_error('MTItemModifiedOn');
    my $fin = defined $e->modified_on ? $e->modified_on : '';
    return "" if !$fin;
    format_ts($_[1]->{format}, $fin, $_[0]->stash('blog'));
}

sub _ifentryid 
{
    my $e = shift;
    if (defined($e->entry_id) && $e->entry_id) {
	return 1;
    }
    return 0;
}

sub hdlr_itemifentry
{
    my $e = $_[0]->stash('mm_entry')
	or return $_[0]->_no_entry_error('MTItemIfBlogEntry');
    return _ifentryid($e);
}

sub hdlr_itementryid
{
    my $e = $_[0]->stash('mm_entry')
	or return $_[0]->_no_entry_error('MTItemEntryId');
    return $e->entry_id;
}

sub hdlr_itementrylink
{
    my $e = $_[0]->stash('mm_entry')
	or return $_[0]->_no_entry_error('MTItemEntryLink');
    my $archive_type = $_[1]->{archive_type};
    if (_ifentryid($e)) {
	my $entry_id     = $e->entry_id;
	require MT::Entry;
	my $entry        = MT::Entry->load($entry_id)
	    or return $ctx->error("No entry found for id \"$entry_id\"");
	return $entry->archive_url($archive_type ? $archive_type : ());
    }
    return '';
}

sub mm_review_rating_number
{
    my ($ctx, $args) = @_;
    return _get_review_data($ctx, 'rating') || '0';
}

sub mm_review_rating_name
{
    my ($ctx, $args) = @_;
    my $rating = _get_review_data($ctx, 'rating') || 0;
    my %rating_names = ( 1 => 'Hated it', 2 => q(Didn't like it),
                         3 => 'Liked it', 4 => 'Really liked it',
                         5 => 'Loved it', 0 => 'No rating' );
    return $rating_names{$rating} if $rating_names{$rating};
    return;
}

sub mm_review_rating_is
{
    my ($ctx, $args) = @_;
    my $rating = _get_review_data($ctx, 'rating');
    $ctx->stash('tag') =~ m{ (\d+)$ }xms;
    my $compare = $1;
    return 1 if $compare == $rating;
    return;
}

sub _no_entry_error {
    return $_[0]->error(MT->translate(
        "You used an '[_1]' tag outside of the context of an entry; " .
        "perhaps you mistakenly placed it outside of an 'MTEntries' container?",
        $_[1]));
}

1;
