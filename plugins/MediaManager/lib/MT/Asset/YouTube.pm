# Copyright 2001-2007 Six Apart. This code cannot be redistributed without
# permission from www.sixapart.com.  For more information, consult your
# Movable Type license.
#
# $Id: $

package MT::Asset::YouTube;

use strict;
use base qw( MT::Asset );

__PACKAGE__->install_properties( { class_type => 'youtube', } );
__PACKAGE__->install_meta( { columns => [ 'video_id',
					  'original_title',
					  'content_url',
					  'content_type',
					  'content_duration',
					  'player_url',
					  'yt_thumbnail_url',
					  'yt_thumbnail_height',
					  'yt_thumbnail_width' ], } );

sub class_label { MT->translate('YouTube Video'); }
sub class_label_plural { MT->translate('YouTube Videos'); }
sub file_name { my $asset   = shift; return $asset->original_title; }
sub file_path { my $asset   = shift; return undef; }
sub on_upload { my $asset   = shift; my ($param) = @_; 1; }
sub has_thumbnail { 1; }

sub thumbnail_url {
    my $asset = shift;
    my (%param) = @_;

# YouTube's Thumbnails are not resizable
#    $param{'width'} = $param{'Width'} if ($param{'Width'});
#    $param{'height'} = $param{'Height'} if ($param{'Height'});

    return $asset->yt_thumbnail_url;
}


sub as_html {
    my $asset   = shift;
    my ($param) = @_;
    my $width  = '425';
    my $height = '355';
    my $text = sprintf(
		    '<object width="%1$d" height="%2$d"><param name="movie" value="http://www.youtube.com/v/%3$s&rel=1"></param><param name="wmode" value="transparent"></param><embed src="http://www.youtube.com/v/%3$s&rel=1" type="application/x-shockwave-flash" wmode="transparent" width="%1$d" height="%2$d"></embed></object>',
		    $width,
		    $height,
		    $asset->video_id,
		    );
    return $asset->enclose($text);
}

sub insert_options {
    my $asset = shift;
    my ($param) = @_;

    my $app   = MT->instance;
    my $perms = $app->{perms};
    my $blog  = $asset->blog or return;

    $param->{thumbnail}  = $asset->thumbnail_url;
    $param->{video_id}   = $asset->video_id;
    $param->{align_left} = 1;
    $param->{html_head}  = '<link rel="stylesheet" href="'.$app->static_path.'plugins/MediaManager/styles/app.css" type="text/css" />';

    return $app->build_page( '../plugins/MediaManager/tmpl/youtube/dialog/asset_options.tmpl', $param );
}

1;
__END__

=head1 NAME

MT::Asset::YouTube

=head1 AUTHOR & COPYRIGHT

Please see the L<MT/"AUTHOR & COPYRIGHT"> for author, copyright, and
license information.

=cut
