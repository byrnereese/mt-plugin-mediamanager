package XML::Parser::Lite::Tree;

use 5.006;
use strict;
use warnings;
use XML::Parser::Lite;

our $VERSION = '0.03';

use vars qw( $parser );

my $next_tag;
my @tag_stack;

sub instance {
	return $parser if $parser;
	$parser = __PACKAGE__->new;
}

sub new {
	my $parser = bless { __parser => undef }, $_[0];
	$parser->init;
	$parser;
}

sub init {
	my $parser = shift;
	$parser->{__parser} = new XML::Parser::Lite
		Handlers => {
			Start => \&_start_tag,
			Char => \&_do_char,
			End => \&_end_tag,
		};
}

sub parse {
	my ($parser, $content) = @_;

	$next_tag = {
		'type' => 'root',
		'children' => [],
	};
	@tag_stack = ($next_tag);

	$parser->{__parser}->parse($content);

	return $next_tag;
}

sub _start_tag {
	shift;

	my $new_tag = {
		'type' => 'tag',
		'name' => shift,
		'attributes' => {},
		'children' => [],
	};
	while(my $a_name = shift @_){
		my $a_value = shift @_;
		$new_tag->{attributes}->{$a_name} = $a_value;
	}

	push @{$next_tag->{children}}, $new_tag;

	push @tag_stack, $new_tag;
	$next_tag = $new_tag;
}

sub _do_char {
	shift;
	for my $content(@_){
		my $new_tag = {
			'type' => 'data',
			'content' => $content,
		};
		push @{$next_tag->{children}}, $new_tag;
	}
}

sub _end_tag {
	pop @tag_stack;
	$next_tag = $tag_stack[$#tag_stack];
}

1;
__END__

=head1 NAME

XML::Parser::Lite::Tree - Lightweight XML tree builder

=head1 SYNOPSIS

  use XML::Parser::Lite::Tree;

  my $tree_parser = XML::Parser::Lite::Tree::instance();
  my $tree = $tree_parser->parse($xml_data);

    OR

  my $tree = XML::Parser::Lite::Tree::instance()->parse($xml_data);

=head1 DESCRIPTION

This is a singleton class for parsing XML into a tree structure. How does this
differ from other XML tree generators? By using XML::Parser::Lite, which is a
pure perl XML parser. Using this module you can tree-ify simple XML without
having to compile any C.


For example, the following XML:

  <foo woo="yay"><bar a="b" c="d" />hoopla</foo>


Parses into the following tree:

          'children' => [
                          {
                            'children' => [
                                            {
                                              'children' => [],
                                              'attributes' => {
                                                                'a' => 'b',
                                                                'c' => 'd'
                                                              },
                                              'type' => 'tag',
                                              'name' => 'bar'
                                            },
                                            {
                                              'content' => 'hoopla',
                                              'type' => 'data'
                                            }
                                          ],
                            'attributes' => {
                                              'woo' => 'yay'
                                            },
                            'type' => 'tag',
                            'name' => 'foo'
                          }
                        ],
          'type' => 'root'
        };


Each node contains a C<type> key, one of C<root>, C<tag> and C<data>. C<root> is the 
document root, and only contains an array ref C<children>. C<tag> represents a normal
tag, and contains an array ref C<children>, a hash ref C<attributes> and a string C<name>.
C<data> nodes contain only a C<content> string.


=head1 METHODS

=over 4

=item C<instance()>

Returns an instance of the tree parser.

=item C<parse($xml)>

Parses the xml in C<$xml> and returns the tree as a hash ref.

=back


=head1 AUTHOR

Copyright (C) 2004, Cal Henderson, E<lt>cal@iamcal.comE<gt>


=head1 SEE ALSO

L<XML::Parser::Lite>.

=cut
