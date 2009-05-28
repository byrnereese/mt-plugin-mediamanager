# Media Manager Movable Type Plugin
# This software is licensed under the GPL
# Copyright (C) 2005-2007, Six Apart, Ltd.

package YouTube::CMS;

use strict;
use base qw( MT::App );

sub plugin {
    return MT->component('MediaManager');
}

use MT::Util qw( format_ts offset_time_list encode_url );
use MT::ConfigMgr;
use XML::Simple;

sub id { 'youtube_cms' }

sub init {
    my $app = shift;
    my %param = @_;
#    $app->SUPER::init(%param) or return;
#    require MTAmazon3::Util;
#    eval {
#	$app->{mmanager_cfg} = MTAmazon3::Util::readconfig($app->{query}->param('blog_id'));
#    };
    return $app->error($@) if $@;
    $app;
}

# Dialog Flow:
# 1) Search form (find)
# 2) Search results (find_results)
# 3) Asset Options (asset_options)
# If "insert into post" then 4a) Insert Options (insert_options)
# Else 4b) DO INSERT

# This handler is responsible for displaying the initial search form
# so that a user can search amazon.
sub find {
    my $app = shift;
    my $q = $app->{query};
    my $blog = $app->blog;
    my $tmpl = $app->load_tmpl('youtube/dialog/find.tmpl');
    $tmpl->param(blog_id      => $blog->id);
    return $app->build_page($tmpl);
}

sub _get_youtube_feed {
    my (%opts) = @_;
    my $url;
    if ($opts{'keywords'}) {
	$url = 'http://gdata.youtube.com/feeds/videos?vq=' . encode_url($opts{'keywords'});
    } elsif ($opts{'video'}) {
	$url = 'http://gdata.youtube.com/feeds/videos/' . $opts{'video'};
    } else {
    }
    require LWP::UserAgent;
    require HTTP::Request;
    my $ua = new LWP::UserAgent;
    $ua->agent("MediaManager/".$MT::Plugin::MediaManager::VERSION);
    my $http_request = new HTTP::Request('GET', $url);
    my $http_response = $ua->request($http_request);
    my $content = $http_response->{'_content'};
    # convert nodes that contain only spaces to empty nodes
    $content =~ s/<[^\/]([^>]+)>\s+<\/[^>]+>/<$1 \/>/g; 
    return $content;
}

# This handler is responsible for displaying a list of search results.
# The user will select an item in this list and then select continue, taking
# them to a screen to tag the item, rename the item, etc.
sub find_results {
    my $app = shift;
    init($app);

    my $q = $app->{query};
    my $blog = $app->blog;

    my $blog_id  = $q->param('blog_id');
    my $keywords = $q->param('kw');
    my $page     = $q->param('page') || 1;

    my @entry_data;
      
    my $xml = _get_youtube_feed( keywords => $keywords );
    my $results = XMLin($xml);
    my $items = $results->{entry};
    my $n_results = $results->{'openSearch:totalResults'};
    my $n_pages = $n_results / $results->{'openSearch:itemsPerPage'};

    my $count = 0;
    foreach my $ns (keys %$items) {
	my ($id) = ($ns =~ /http:\/\/gdata.youtube.com\/feeds\/videos\/(.*)/);
	my $item = $items->{$ns};
        my $row = {
            blog_id      => $blog_id,
	    video_id     => $id,
            entry_odd    => $count++ % 2 ? 1 : 0,
            title        => $item->{title}->{content},
	    thumbnail    => $item->{'media:group'}->{'media:thumbnail'}->[0]->{url},
        };
        push @entry_data, $row;
    }

    my $tmpl = $app->load_tmpl('youtube/dialog/find_results.tmpl');

    my $limit = 10;
    my $offset = $limit * ($page - 1);
    $tmpl->param(return_args => "__mode=find&blog_id=".$blog->id."&kw=".$keywords);
    $tmpl->param(list_start => $offset + 1);
    $tmpl->param(list_end => $offset + (scalar @entry_data));
    $tmpl->param(list_total => $n_results);
    $tmpl->param(next_max => ($tmpl->param('list_total') - $limit));
    $tmpl->param(next_max => (($tmpl->param('next_max') || 0) < $offset + 1) ? 0 : 1);
    $tmpl->param(PREV_OFFSET => $offset > 0);
    $tmpl->param(prev_offset_val => $page - 1);
    $tmpl->param(next_offset => $offset + $limit < $tmpl->param('list_total'));
    $tmpl->param(next_offset_val => $page + 1);

    $tmpl->param(blog_id => $blog->id);
    $tmpl->param(blog_name => $blog->name);
    $tmpl->param(entry_loop => \@entry_data);
    $tmpl->param(empty => !$n_results);
    $tmpl->param(page => $page);
    $tmpl->param(paginate => $n_pages > 1 ? 1 : 0);
    $tmpl->param(keywords => $keywords);
    $tmpl->param(n_results => $n_results);
    $tmpl->param(n_pages => $n_pages);
    $tmpl->param(show_all_options => 0);

    $tmpl->param(breadcrumbs  => $app->{breadcrumbs});

    return $app->build_page($tmpl);
}

# This handler is responsible for saving the asset and also for presenting
# the user with a list of options for inserting it into a post.
# Saving however should take place one step earlier because a user may
# decide NOT to insert it into a post.
sub asset_options {
    my $app = shift;
    init($app);
    my $q = $app->{query};
    my $blog = $app->blog;
    my $vid = $q->param('selected');

    my $xml = _get_youtube_feed( video => $vid );
    my $item = XMLin($xml);
    use Data::Dumper;
    my $title = $item->{title}->{content};
    require MT::Asset::YouTube;
    my $asset = MT::Asset::YouTube->new;
    $asset->blog_id($q->param('blog_id'));
    $asset->video_id($vid);
    $asset->label($title);
    $asset->description($item->{'media:group'}->{'media:description'}->{'content'});
    $asset->url($item->{'media:group'}->{'media:player'}->{url});
    $asset->yt_thumbnail_url($item->{'media:group'}->{'media:thumbnail'}->[0]->{url});
    $asset->yt_thumbnail_width($item->{'media:group'}->{'media:thumbnail'}->[0]->{width});
    $asset->yt_thumbnail_height($item->{'media:group'}->{'media:thumbnail'}->[0]->{height});

    $asset->created_by( $app->user->id );

    $asset->original_title($title);

    my $original = $asset->clone;
    $asset->save;
    $app->run_callbacks( 'cms_post_save.asset', $app, $asset, $original );

    return $app->complete_insert( 
        asset       => $asset,
        video_id    => $vid,
#        title       => $title,
        description => $asset->description,
	thumbnail   => $asset->thumbnail_url,
	is_youtube  => 1,
    );
}

1;

__END__
