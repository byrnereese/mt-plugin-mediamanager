# Copyright 2001-2007 Six Apart. This code cannot be redistributed without
# permission from www.sixapart.com.  For more information, consult your
# Movable Type license.
#
# $Id: $

package MT::Asset::Amazon;

use strict;
use base qw( MT::Asset );

__PACKAGE__->install_properties( { class_type => 'amazon', } );
__PACKAGE__->install_meta( { columns => [ 'original_title', 'artist', 'asin', 'product_group' ], } );

sub class_label { MT->translate('Amazon Item'); }
sub class_label_plural { MT->translate('Amazon Items'); }
sub file_name { my $asset   = shift; return $asset->original_title; }
sub file_path { my $asset   = shift; return undef; }
sub on_upload { my $asset   = shift; my ($param) = @_; 1; }
sub has_thumbnail { 1; }

sub thumbnail_url {
    my $asset = shift;
    my (%param) = @_;

    $param{'width'} = $param{'Width'} if ($param{'Width'});
    $param{'height'} = $param{'Height'} if ($param{'Height'});

    my $img_base = 'http://images.amazon.com/images/P/'.$asset->asin.'.01.';
    my @options;
    if (! %param) {
	push(@options,'SCLZZZZZZZ');
	push(@options,'SX175');
    } else {
	if ($param{'size_abs'}) {
	    push(@options,'SCLZZZZZZZ');
	    push(@options,'SX'.$param{'size_abs'});
	} elsif ($param{'size'}) {
	    push(@options,'TZZZZZZZ') if ($param{'size'} eq "default");
	    push(@options,'THUMBZZZ') if ($param{'size'} eq "small");
	    push(@options,'MZZZZZZZ') if ($param{'size'} eq "medium");
	    push(@options,'LZZZZZZZ') if ($param{'size'} eq "large");
	} elsif ($param{'width'}) {
	    push(@options,'SCLZZZZZZZ');
	    push(@options,'SX' . $param{'width'});
	} elsif ($param{'height'}) {
	    push(@options,'SCLZZZZZZZ');
	    push(@options,'SY' . $param{'height'});
	} elsif ($param{'square'}) {
	    push(@options,'SCLZZZZZZZ');
	    push(@options,'SS' . $param{'square'});
	} else {
	    push(@options,'TZZZZZZZ');
	}
	if ($param{'rotation'}) {
	    push(@options,'PU' . $param{'rotation'});
	}
	if ($param{'blur'}) {
	    push(@options,'BL' . $param{'blur'});
	}
	if ($param{'drop_shadow'}) {
	    push(@options,'PC') if ($param{'drop_shadow'} eq "right");
	    push(@options,'PB') if ($param{'drop_shadow'} eq "left");
	}
	if ($param{'disc'}) {
	    push(@options,'PF');
	}
    }
    return $img_base .'_' . join('_',@options) . "_.jpg";
}


sub as_html {
    my $asset   = shift;
    my ($param) = @_;
    my $text    = '';

    require MT::Util;
    if ( $param->{'include'} ) { # always true
        my $wrap_style = '';
        if ( $param->{'align'} ) {
            $wrap_style = 'class="mt-image-' . $param->{align} . '" ';
            if ( $param->{'align'} eq 'left' ) {
                $wrap_style .= q{style="float: left; margin: 0 20px 20px 0;"};
            }
            elsif ( $param->{'align'} eq 'right' ) {
                $wrap_style .= q{style="float: right; margin: 0 0 20px 20px;"};
            }
            elsif ( $param->{'align'} eq 'center' ) {
                $wrap_style .=
		    q{style="text-align: center; display: block; margin: 0 auto 20px;"};
            }
        }
	my $thumb = $asset->thumbnail_url( 
					   size_abs => $param->{'size_abs'},
					   rotation => $param->{'img_rot'},
					   img_drop => $param->{'img_drop'},
					   );
	$text = sprintf(
			'<a href="%s"><img alt="%s" src="%s" %s/></a>',
			MT::Util::encode_html( $asset->url ),
			MT::Util::encode_html( $asset->label ),
			MT::Util::encode_html( $thumb ),
			$wrap_style,
			);
	return $asset->enclose($text);
    }
}

sub insert_options {
    my $asset = shift;
    my ($param) = @_;

    my $app   = MT->instance;
    my $perms = $app->{perms};
    my $blog  = $asset->blog or return;

    $param->{thumbnail} = $asset->thumbnail_url;
    $param->{asin} = $asset->asin;
    $param->{align_left} = 1;
    $param->{html_head} = '<link rel="stylesheet" href="'.$app->static_path.'plugins/MediaManager/styles/app.css" type="text/css" />';

    my @drop_data;
    for (qw( None Left Right )) {
      push @drop_data, { drop => lc($_) };
    }
    $param->{'drop_loop'} = \@drop_data;
    
    return $app->build_page( '../plugins/MediaManager/tmpl/amazon/dialog/asset_options.tmpl', $param );
}

1;
__END__

=head1 NAME

MT::Asset::Amazon

=head1 AUTHOR & COPYRIGHT

Please see the L<MT/"AUTHOR & COPYRIGHT"> for author, copyright, and
license information.

=cut
