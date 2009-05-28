# Media Manager Movable Type Plugin
#
# $Id: $
#
# Copyright (C) 2005 Byrne Reese
#

package MediaManager::Entry;
use strict;

use MT::Object;
@MediaManager::Entry::ISA = qw( MT::Object MT::Taggable);
__PACKAGE__->install_properties({
    column_defs => {
		'id'          => 'integer not null auto_increment', 
		'blog_id'     => 'integer not null', 
		'title'       => 'string(150) not null',
		'catalog'     => 'string(50) not null', 
		'isbn'        => 'string(50) not null', 
		'status'      => 'string(50) not null', 
		'finished_on' => 'datetime', 
		'entry_id'    => 'integer' 
    },
    indexes => {
	blog_id => 1,
	created_on => 1,
	finished_on => 1,
	status => 1,
	catalog => 1
    },
    audit => 1,
    datasource => 'mediamanager',
    primary_key => 'id',
});

sub save {
    my $entry = shift;
    unless ($entry->SUPER::save(@_)) {
        print STDERR "error during save: " . $entry->errstr . "\n";
        die $entry->errstr;
    }
    # synchronize tags if necessary
    $entry->save_tags;
    1;
}
sub remove {
    my $entry = shift;
    $entry->remove_tags;
    $entry->SUPER::remove;
}

sub title_short {
    my $self = shift;
    $self->title =~ /^(.{1,30})/;
    if (length($1) == 30) {
	return $1 . "...";
    }
    return $1;
}

# Finished On: 2005-09-30 00:00:00

sub finished_on {
    my $self = shift;
    if (@_) {
	my ($date) = @_;
	if ($date =~ /^(\d\d\d\d)-(\d\d)-(\d\d)/) {
	    $date = $1.$2.$3."000000";
	}
	return $self->SUPER::finished_on($date);
    }
    if ($self->SUPER::finished_on &&
	$self->SUPER::finished_on =~ /^(\d\d\d\d)-(\d\d)-(\d\d)/) {
	return $1.$2.$3."000000";
    } else {
	return $self->SUPER::finished_on;
    }
}

sub created_on_str {
    my $self = shift;
    return to_date_str($self->created_on);
}
sub modified_on_str {
    my $self = shift;
    return to_date_str($self->modified_on);
}
sub finished_on_str {
    my $self = shift;
    return to_date_str($self->finished_on);
}

sub to_date_str {
    my ($date) = @_;
    if (my ($y,$m,$d) = ($date =~ /^(\d\d\d\d)(\d\d)(\d\d)/)) {
	return "$m-$d-$y";
    } else {
	return undef;
    }
}

1;
