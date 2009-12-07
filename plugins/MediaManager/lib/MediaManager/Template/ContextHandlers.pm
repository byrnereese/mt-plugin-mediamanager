package MediaManager::Template::Context;

use MediaManager::Util;
use MT::Util qw( format_ts);

sub mm_tags {
    return {
        block => {
#	    MediaManagerRandomItem => \&_hdlr_random_item,
#	    MediaManagerItems => \&_hdlr_mediamanager_entries,
	},
	function => {

	    # TODO 
#	    'ItemIcon' => \&_hdlr_itemicon, # TODO
#	    'ItemFinishedDate' => \&_hdlr_itemfinishedon, # TODO
#	    'ItemModifiedDate' => \&_hdlr_itemmodifiedon, # TODO
#	    'ItemEntryPermalink' => \&_hdlr_itementrylink, # TODO
#	    'ItemIfBlogEntry?' => \&_hdlr_itemifentry, # TODO

	    # OBSOLETE
#	    'ItemCount' => \&_hdlr_itemcount, # replaced by _hdlr_asset_count
#	    'ItemISBN' => \&_hdlr_itemisbn, # replaced by AssetProperty
#	    'ItemASIN' => \&_hdlr_itemisbn, # replaced by AssetProperty
#	    'ItemStatus' => \&_hdlr_itemstatus, # replaced by AssetProperty
#	    'ItemCatalog' => \&_hdlr_itemcatalog, # replaced by AssetProperty
#	    'ItemTitle' => \&_hdlr_itemtitle, # replaced by AssetLabel
#	    'ItemCreatedDate' => \&_hdlr_itemcreatedon, # replaced by AssetDateAdded
#	    'ItemEntryDate' => \&_hdlr_itemcreatedon, # replaced by AssetDateAdded
#	    'ItemEntryID' => \&_hdlr_itementryid, # TODO - need an AssetEntries
#	    'ItemEntryLink' => \&_hdlr_itementrylink, # replaced by AssetLink

	    # RETIRE?
#	    'ItemIfFinishedDate?' => \&_hdlr_itemiffinishedon,
#	    'EntryIfReview?' => \&_hdlr_itemifentry,
#	    'ReviewRatingNumber' =>\&_mm_review_rating_number,
#	    'ReviewRatingName' => \&_mm_review_rating_name,
#	    'ReviewRatingIs1?' => \&_mm_review_rating_is,
#	    'ReviewRatingIs2?' => \&_mm_review_rating_is,
#	    'ReviewRatingIs3?' => \&_mm_review_rating_is,
#	    'ReviewRatingIs4?' => \&_mm_review_rating_is,
#	    'ReviewRatingIs5?' => \&_mm_review_rating_is,
	},
    };
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

sub _no_entry_error {
    return $_[0]->error(MT->translate(
        "You used an '[_1]' tag outside of the context of an entry; " .
        "perhaps you mistakenly placed it outside of an 'MTEntries' container?",
        $_[1]));
}

1;
