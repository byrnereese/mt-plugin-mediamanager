# Media Manager Movable Type Plugin
#
# $Id: $
#
# Copyright (C) 2005 Byrne Reese
#

package MediaManager::Plugin;
use strict;

use MT::Plugin;
@MediaManager::Plugin::ISA = qw( MT::Plugin );

sub new {
    my $self = shift;
    $self->SUPER::new(@_) or return;
}

sub init_app {
    my $plugin = shift;
    my ($app) = @_; 
    if ($app->isa('MT::App::CMS')) {
        $app->add_methods(
			  mm_entry_edit    => \&mm_entry_edit,
			  mm_entry_save    => \&mm_entry_save,
			  );
    }
}

# intercepts calls to edit entries and sends them to
# a media manager edit entry handler
sub init_request {
    my $plugin = shift;
    my $app = shift;
    if (defined($app->mode) && 
	defined($app->param('_type')) &&
	$app->mode eq 'view' && 
	$app->param('_type') eq 'entry') {
	my $blog = $app->blog;
	$app->mode('mm_entry_edit');
    } elsif (defined($app->mode) && 
	     defined($app->param('_type')) && 
	     $app->mode eq 'save_entry' && 
	     $app->param('_type') eq 'entry') {
	my $blog = $app->blog;
	$app->mode('mm_entry_save');
    }
}

sub mm_entry_edit {
    # receives all the parameters that MT::App::CMS::edit_object would
    my $app = shift;
    my ($param) = @_;
    $param ||= {};

    require MediaManager::Entry;
    require MediaManager::Review;
    require MediaManager::Util;

    my $entry_id    = $app->{query}->param('id');
    my $mm_entry_id = $app->{query}->param('mm_entry_id');
    my $review;
    my $mm_entry;

    MediaManager::Util::debug("Trying to find a MediaManager::Entry (entry_id=$entry_id, mm_entry_id=$mm_entry_id)");
    if ((defined($entry_id) && 
	 ($mm_entry = MediaManager::Entry->load({ entry_id => $entry_id }))) ||
	(defined($mm_entry_id) && 
	 ($mm_entry = MediaManager::Entry->load({ id => $mm_entry_id })))) {

	MediaManager::Util::debug("MediaManager::Entry found: id ".$mm_entry->id);

	require MT::Request;
	MT::Request->instance->stash('mm_entry' => $mm_entry);

	$mm_entry_id = $mm_entry->id;
	unless ($review = MediaManager::Review->load( { entry_id => $mm_entry->id } )) {
	    $review = MediaManager::Review->new;
	}

	$param->{mm_toolbar}    = 1;
	$param->{mm_entry_id}   = $mm_entry_id;
	$param->{asin}          = $mm_entry->isbn;

	$param->{rating}        = $review->rating;
	$param->{layout}        = $review->layout || 'Left';
	$param->{img_size}      = $review->image_size;
	$param->{img_drop}      = $review->image_drop_shadow || 'None';
	$param->{img_rot}       = $review->image_rotation || 0;
	$param->{img_blur}      = $review->image_blur || 0;
	$param->{img_url}       = $review->image_url;
	$param->{show_buynow}   = $review->show_buynow;
	$param->{show_price}    = $review->show_price;
	$param->{show_rating}   = $review->show_rating;
	
	$param->{img_url} = 'http://images.amazon.com/images/P/'.$param->{asin}.'.01.THUMBZZZ.jpg'
	    if $param->{img_url} eq "";
	
	my @rating_data;
	my %rating_names = ( 1 => 'Hated it', 2 => q(Didn't like it),
                         3 => 'Liked it', 4 => 'Really liked it',
                         5 => 'Loved it', 0 => 'No rating' );
	for (qw( 0 1 2 3 4 5 )) {
	    push @rating_data, { rating => $_, rating_name => ($rating_names{$_} || '') };
	    $rating_data[-1]{checked} = 1 if $_ <= $param->{rating};
	}
	$param->{rating_loop} = \@rating_data;
	my @drop_data;
	for (qw( None Left Right )) {
	    push @drop_data, { drop => $_ };
	    $drop_data[-1]{checked} = 1 if $param->{img_drop} eq $_;
	}
	$param->{drop_loop} = \@drop_data;
	
	$param->{"layout_".$param->{layout}."_selected"} = 1;
	
	my @imgsize_data;
	my %sizes = ( "01Thumbnail"     => "_THUMBZZZ", 
		      "02Small"         => "_TZZZZZZZ",  
		      "03Medium"        => "_SCMZZZZZZZ", 
		      "04Super Size Me" => "_SCLZZZZZZZ",
		      "0575 pixels"     => "_AA75",
		      "06100 pixels"    => "_AA100",
		      "07125 pixels"    => "_AA125",
		      "08150 pixels"    => "_AA150",
		      "09175 pixels"    => "_AA175",
		      "10200 pixels"    => "_AA200",
		      );
	for (sort keys %sizes) {
	    my ($idx,$label) = ($_ =~ /(..)(.*)/);
	    push @imgsize_data, { 
		img_size_label => $label,
		img_size       => $sizes{$_} 
	    };
	    $imgsize_data[-1]{checked} = 1 if $param->{img_size} eq $sizes{$_};
	}
	$param->{imgsize_loop} = \@imgsize_data;
    
    } 

    # restore mode just in case CMS looks at it
    $app->mode('view');
    
    # return control to edit_object
    $app->edit_object($param);

}

sub mm_entry_save {
    my $app = shift;
    my ($param) = @_;
    $param ||= {};

    my $mm_entry_id = $app->{query}->param('mm_entry_id');
    
    if ($mm_entry_id) {
	require MediaManager::Review;
	require MediaManager::Entry;
	require MediaManager::Util;
	MediaManager::Util::debug("Loading entry with id: ".$mm_entry_id);
	my $mm_entry = MediaManager::Entry->load({ id => $mm_entry_id });
	my $review;
	unless ($review = MediaManager::Review->load( { entry_id => $mm_entry_id } )) {
	    MediaManager::Util::debug("A review object has NOT been found.");
	    $review = MediaManager::Review->new;
	    $review->entry_id($mm_entry_id);
	} else {
	    MediaManager::Util::debug("A review object has been found.");
	}

	$review->rating($app->{query}->param('rating'));
	$review->layout($app->{query}->param('layout'));

	$review->image_drop_shadow($app->{query}->param('img_drop'));
	$review->image_size($app->{query}->param('img_size'));
	$review->image_rotation($app->{query}->param('img_rot'));
	$review->image_blur($app->{query}->param('img_blur'));
	$review->image_url($app->{query}->param('img_url'));

	$review->show_buynow($app->{query}->param('show_buynow') == 1 ? "1" : "0");
	$review->show_price($app->{query}->param('show_price') == 1 ? "1" : "0");
	$review->show_rating($app->{query}->param('show_rating') == 1 ? "1" : "0");

	unless ($review->save) {
	    MediaManager::Util::debug("Error saving review: " . $review->errstr);
	    return $app->error("Error saving review: " . $review->errstr);
	}

	require MT::Request;
	MT::Request->instance->stash('mm_entry_id' => $mm_entry_id);
	MT::Request->instance->stash('mm_entry' => $mm_entry);
	MT::Request->instance->stash('mm_review' => $review);

    }

    # restore mode just in case CMS looks at it
    $app->mode('view');

    # return control to edit_object
    $app->save_entry($param);
}

# Convert:
# <div id="entry-container">
# To:
# <div id="entry-container">
#
# <TMPL_INCLUDE NAME="../plugins/MediaManager/tmpl/mm-toolbar.tmpl">

sub post_save {
    my ($callback, $obj, $original) = @_;
    require MediaManager::Util;
    MediaManager::Util::debug("In post_save");
    eval {
	require MT::Request;
	MediaManager::Util::debug("Retrieving cached mm_entry");
	my $mm_entry = MT::Request->instance->stash('mm_entry');
	if ($mm_entry) { # = MediaManager::Entry->load( { id => $mm_entry_id } )) {
	    MediaManager::Util::debug("Found cached mm_entry");
	    $mm_entry->entry_id($obj->id);
	    $mm_entry->finished_on($mm_entry->finished_on); # HACK!
#	    MediaManager::Util::debug("Finished On: ".$mm_entry->finished_on);
	    unless ($mm_entry->save) {
		MediaManager::Util::debug($mm_entry->error("Error linking mt_entry to mm_entry: " . $mm_entry->errstr));
		return $mm_entry->error("Error linking mt_entry to mm_entry: " . $mm_entry->errstr);
	    }
	} else {
	    MediaManager::Util::debug("Did not find cached MediaManager::Entry");
	}
    };
    if ($@) {
	# I do this otherwise it will fail too silently and I have no
	# idea what is going wrong.
	print STDERR $@."\n";
    }
}

sub pre_save {
    my ($callback, $obj, $original) = @_;
    require MediaManager::Util;
    eval {
	require MT::Request;
        require MTAmazon3::Plugin;
        require MTAmazon3::Util;
	my $mm_entry = MT::Request->instance->stash('mm_entry');
	if ($mm_entry) { 
	    MediaManager::Util::debug("mm_entry found: adding markup");
	      
	    my $app = MT::App->instance;
	    my $static = $app->{cfg}->StaticWebPath;
	    my $review = MT::Request->instance->stash('mm_review');

            my $config;
            eval {
	      MediaManager::Util::debug("Loading MTAmazon config for blog id: ".$obj->blog_id);
              $config = MTAmazon3::Util::readconfig($obj->blog_id);
            };
            if ($@) {
		print STDERR "Error loading Amazon config: $@";
	    }

	    my $content_tree;
	    eval {
		MediaManager::Util::debug("Loading cached MTAmazon data for entry ".$mm_entry->isbn);
	        $content_tree = MTAmazon3::Plugin::ItemLookupHelper(
                    $config,{
		        ItemId        => $mm_entry->isbn,
		        ResponseGroup => 'Small,Images,OfferSummary',
                });
            };
            if ($@) {
		print STDERR "Error loading data from Amazon: $@";
	    }

            my $item   = $content_tree->{'Items'}->{'Item'};
	    my $imgurl = $review->image_url;
	    my $rating = $review->rating;
	    my $title  = $mm_entry->title;

	    my $artist;
	    if (defined($item->{ItemAttributes}->{Author})) {
		if (ref $item->{ItemAttributes}->{Author} eq "ARRAY") {
		    $artist = join(", ", @{ $item->{ItemAttributes}->{Author} });
		} else {
		    $artist = $item->{ItemAttributes}->{Author};
		}
	    } elsif (defined($item->{ItemAttributes}->{Artist})) {
		if (ref $item->{ItemAttributes}->{Artist} eq "ARRAY") {
		    $artist = join(", ", @{ $item->{ItemAttributes}->{Artist} });
		} else {
		    $artist = $item->{ItemAttributes}->{Artist};
		}
	    } elsif (defined($item->{ItemAttributes}->{Manufacturer})) {
		$artist = $item->{ItemAttributes}->{Manufacturer};
	    }

	    my $layout_str;
	    if ($review->layout eq "Left") {
		$layout_str = "left";
	    } elsif ($review->layout eq "Right") {
		$layout_str = "right";
	    } else {
		$layout_str = "center";
	    }

	    my $text = '<!-- BEGIN Media Manager Post Header -->';
	    $text .= '<div class="mmanager-post-header '.$layout_str.'">';
	    $text .= '<div class="mmanager-post-image"><a href="'.$item->{DetailPageURL}.'"><img src="'.$imgurl.'" /></a></div>';
	    $text .= '<div class="mmanager-post-rating"><img src="'.$static.'/plugins/MediaManager/images/stars-'.$rating.'-0.gif" border="0" height="12" width="64" /></div>' if $review->show_rating && $rating > 0;
	    $text .= '<div class="mmanager-post-title"><a href="'.$item->{DetailPageURL}.'">'.$title.'</a></div>';
	    $text .= '<div class="mmanager-byline">by '.$artist.'</div>' if $artist;
	    $text .= '</div>';
	    $text .= '<!-- END Media Manager Post Header -->'."\n";
            $text .= $obj->text;
	    if ($review->show_price || $review->show_buynow) {
                my $price = $item->{'OfferSummary'}->{'LowestNewPrice'}->{'FormattedPrice'};
		$text .= '<!-- BEGIN Media Manager Post Footer --><div class="mmanager-post-footer '.$layout_str.' pkg">';
		$text .= '<div class="mmanager-post-price">'.$price.'</div>' if $review->show_price;
		$text .= '<div class="mmanager-post-buynow"><a href="'.$item->{DetailPageURL}.'"><img src="'.$static.'/plugins/MediaManager/images/buy-from-tan.gif" border="0" height="28" width="90" /></a></div>' if $review->show_buynow;
		$text .= '</div><!-- END Media Manager Post Footer -->';
	    }
            $obj->text($text);
        }
    };
    if ($@) {
	# I do this otherwise it will fail too silently and I have no
	# idea what is going wrong.
	print STDERR $@."\n";
    }
}

sub post_load {
    my ($callback, $args, $obj) = @_;
    # Break out if we are rebuilding
    require MT::App;
    my $app = MT::App->instance;
    if (ref $app ne "MT::App::CMS" || ($app && $app->mode ne 'view')) {
	return;
    }
    eval {
	my $text = $obj->text;
	require MediaManager::Util;
	MediaManager::Util::debug("Before: $text");
	$text =~ s/\s*<!-- BEGIN Media Manager Post Header -->\s*(.*)\s*<!-- END Media Manager Post Header -->\n?\s*//mg;
	$text =~ s/\s*<!-- BEGIN Media Manager Post Footer -->(.*)<!-- END Media Manager Post Footer -->//m;
	MediaManager::Util::debug("After: $text");
	$obj->text($text);
    };
    if ($@) {
	# I do this otherwise it will fail too silently and I have no
	# idea what is going wrong.
	print STDERR $@."\n";
    }
}

1;
