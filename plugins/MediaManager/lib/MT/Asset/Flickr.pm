# Copyright 2001-2007 Six Apart. This code cannot be redistributed without
# permission from www.sixapart.com.  For more information, consult your
# Movable Type license.
#
# $Id: $

package MT::Asset::Flickr;

use strict;
use base qw( MT::Asset );

__PACKAGE__->install_properties( { class_type => 'flickr', } );
__PACKAGE__->install_meta( { columns => [ 'photo_id',
					  'photo_owner',
					  'photo_secret',
					  'photo_server',
					  'photo_farm',
					  'photo_is_public',
					  'original_title' ], } );

sub class_label { MT->translate('Flickr Photo'); }
sub class_label_plural { MT->translate('Flickr Photos'); }
sub file_name { my $asset   = shift; return $asset->original_title; }
sub file_path { my $asset   = shift; return undef; }
sub on_upload { my $asset   = shift; my ($param) = @_; 1; }
sub has_thumbnail { 1; }

sub thumbnail_url {
    my $asset = shift;
    my (%param) = @_;

    my $thumb = 'http://farm' . $asset->photo_farm() . '.static.flickr.com/'.$asset->photo_server().'/'.$asset->photo_id().'_'.$asset->photo_secret().'_m.jpg';

    return $thumb;
}


sub as_html {
    my $asset   = shift;
    my ($param) = @_;
    my $text = '';
    if ( $param->{include} ) {

        my $fname = $asset->file_name;
        require MT::Util;

        my $thumb = undef;
        my $wrap_style = '';
        if ( $param->{wrap_text} && $param->{align} ) {
            $wrap_style = 'class="mt-image-' . $param->{align} . '" ';
            if ( $param->{align} eq 'left' ) {
                $wrap_style .= q{style="float: left; margin: 0 20px 20px 0;"};
            }
            elsif ( $param->{align} eq 'right' ) {
                $wrap_style .= q{style="float: right; margin: 0 0 20px 20px;"};
            }
            elsif ( $param->{align} eq 'center' ) {
                $wrap_style .=
q{style="text-align: center; display: block; margin: 0 auto 20px;"};
            }
        }

        if ( $param->{popup} ) {
            my $popup = MT::Asset->load( $param->{popup_asset_id} )
              || return $asset->error(
                MT->translate(
                    "Can't load image #[_1]",
                    $param->{popup_asset_id}
                )
              );
            my $link =
              $thumb
              ? sprintf(
                '<img src="%s" alt="%s" %s />',
                MT::Util::encode_html( $asset->label ), $wrap_style
              )
              : MT->translate('View image');
            $text = sprintf(
q|<a href="%s" onclick="window.open('%s','popup','width=%d,height=%d,scrollbars=no,resizable=no,toolbar=no,directories=no,location=no,menubar=no,status=no,left=0,top=0'); return false">%s</a>|,
                MT::Util::encode_html( $popup->url ),
                MT::Util::encode_html( $popup->url ),
                $asset->image_width,
                $asset->image_height,
                $link,
            );
        }
        else {
            if ( $param->{thumb} ) {
                $text = sprintf(
                    '<a href="%s"><img alt="%s" src="%s" %s/></a>',
                    MT::Util::encode_html( $asset->url ),
                    MT::Util::encode_html( $asset->label ),
                    MT::Util::encode_html( $thumb->url ),
                    $wrap_style,
                );
            }
            else {
                $text = sprintf(
                    '<img alt="%s" src="%s" %s />',
                    MT::Util::encode_html( $asset->label ),
                    MT::Util::encode_html( $asset->url ),
                    $wrap_style,
                );
            }
        }
    }
    else {
        $text = sprintf(
            '<a href="%s">%s</a>',
            MT::Util::encode_html( $asset->url ),
            MT->translate('View image'),
        );
    }

    return $asset->enclose($text);
}

sub insert_options {
    my $asset = shift;
    my ($param) = @_;

    my $app   = MT->instance;
    my $perms = $app->{perms};
    my $blog  = $asset->blog or return;

    $param->{thumbnail}  = $asset->thumbnail_url;
    $param->{align_left} = 1;
    $param->{html_head}  = '<link rel="stylesheet" href="'.$app->static_path.'plugins/MediaManager/styles/app.css" type="text/css" />';

    return $app->build_page( '../plugins/MediaManager/tmpl/flickr/dialog/asset_options.tmpl', $param );
}

1;
__END__

=head1 NAME

MT::Asset::YouTube

=head1 AUTHOR & COPYRIGHT

Please see the L<MT/"AUTHOR & COPYRIGHT"> for author, copyright, and
license information.

=cut
