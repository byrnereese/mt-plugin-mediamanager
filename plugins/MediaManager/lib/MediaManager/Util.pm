# Media Manager Movable Type Plugin
# This software is licensed under the GPL
# Copyright (C) 2005-2007, Six Apart, Ltd.

package MediaManager::Util;

use strict;

use LWP::Simple;
use MT::Util qw( format_ts offset_time_list );
use XML::Simple;

#####################################################################
# UTILITY SUBROUTINES
#####################################################################

sub trim {
    my($string)=@_;
    for ($string) {
	s/^\s+//;
	s/\s+$//;
    }
    return $string;
}

sub format_img_url
{
    my ($item,$s) = @_;
    if (!defined($s)) { $s = "Small"; }
    my $size = $s."Image";
    if (defined($item->{$size})) {
	return $item->{$size}->{URL};
    }
}

sub format_img_tag
{
    my ($item,$s) = @_;
    if (!defined($s)) { $s = "Small"; }
    my $size = $s."Image";
    if (defined($item->{$size})) {
	my $url    = $item->{DetailPageURL};
	my $img    = $item->{$size}->{URL};
	my $w      = $item->{$size}->{Width};
	my $h      = $item->{$size}->{Height};
	my $title  = $item->{ItemAttributes}->{Title};
	return "" unless $url && $img;
	$title  ||= '[title unavailable]';
	return qq!<a href="$url"><img width="$w" height="$h" src="$img" alt="$title" border="0" /></a>!;
    } else {
	if (!defined($size)) { $size = "Small"; }
	my $url    = $item->{url};
	my $img    = $item->{"ImageUrl$size"};
	my $title  = $item->{ProductName};
	my $author = ref $item->{Authors}->{Author} eq "ARRAY"
	    ? join(", ", @{ $item->{Authors}->{Author} })
	    : $item->{Authors}->{Author};
	return "" unless $url && $img;
	$title  ||= '[title unavailable]';
	$author ||= '[author unavailable]';
	return qq!<a href="$url"><img src="$img" alt="$title by $author" border="0" /></a>!;
    }
}

sub ean2isbn
{
    # algorithm: http://www.bisg.org/booklanean.htm
    my @digits = split //, $_[0];
    my $sum = 0;
    $sum += $digits[$_] * (10 - $_) for (0 .. $#digits);
    my $check = 11 - $sum % 11;
    $check =  0  if $check == 11;
    $check = 'X' if $check == 10;
    join '', (@digits, $check);
}

sub decue
{
    # tatooable decue code compliments of Larry Wall
    # http://www.beau.lib.la.us/~jmorris/linux/cuecat/
    (map {
        tr/a-zA-Z0-9+-/ -_/;
        $_ = unpack 'u', chr(32 + length()*3/4) . $_;
        s/\0+$//;
        $_ ^= "C" x length;
    } (my $str = $_[0]) )[0];
}

1;
