package Log::Dispatch::Email;

use strict;

use Log::Dispatch::Output;

use base qw( Log::Dispatch::Output );

use Params::Validate qw(validate SCALAR ARRAYREF BOOLEAN);
Params::Validate::validation_options( allow_extra => 1 );

use vars qw[ $VERSION ];

$VERSION = '1.19';

1;

sub new
{
    my $proto = shift;
    my $class = ref $proto || $proto;

    my %p = validate( @_, { subject  => { type => SCALAR,
					  default => "$0: log email" },
			    to       => { type => SCALAR | ARRAYREF },
			    from     => { type => SCALAR,
					  optional => 1 },
			    buffered => { type => BOOLEAN,
					  default => 1 },
			  } );

    my $self = bless {}, $class;

    $self->_basic_init(%p);

    $self->{subject} = $p{subject} || "$0: log email";
    $self->{to} = ref $p{to} ? $p{to} : [$p{to}];
    $self->{from} = $p{from};

    # Default to buffered for obvious reasons!
    $self->{buffered} = $p{buffered};

    $self->{buffer} = [] if $self->{buffered};

    return $self;
}

sub log_message
{
    my $self = shift;
    my %p = @_;

    if ($self->{buffered})
    {
	push @{ $self->{buffer} }, $p{message};
    }
    else
    {
	$self->send_email(@_);
    }
}

sub send_email
{
    my $self = shift;
    my $class = ref $self;

    die "The send_email method must be overridden in the $class subclass";
}

sub flush
{
    my $self = shift;

    if ($self->{buffered} && @{ $self->{buffer} })
    {
	my $message = join '', @{ $self->{buffer} };

	$self->send_email( message => $message );
        $self->{buffer} = [];
    }
}

sub DESTROY
{
    my $self = shift;

    $self->flush;
}

__END__

=head1 NAME

Log::Dispatch::Email - Base class for objects that send log messages
via email

=head1 SYNOPSIS

  package Log::Dispatch::Email::MySender

  use Log::Dispatch::Email;
  use base qw( Log::Dispatch::Email );

  sub send_email
  {
      my $self = shift;
      my %p = @_;

      # Send email somehow.  Message is in $p{message}
  }

=head1 DESCRIPTION

This module should be used as a base class to implement
Log::Dispatch::* objects that send their log messages via email.
Implementing a subclass simply requires the code shown in the
L<SYNOPSIS> with a real implementation of the C<send_email()> method.

=head1 METHODS

=over 4

=item * new(%p)

This method takes a hash of parameters.  The following options are
valid:

=over 8

=item * name ($)

The name of the object (not the filename!).  Required.

=item * min_level ($)

The minimum logging level this object will accept.  See the
Log::Dispatch documentation on L<Log Levels|Log::Dispatch/"Log Levels"> for more information.  Required.

=item * max_level ($)

The maximum logging level this obejct will accept.  See the
Log::Dispatch documentation on L<Log Levels|Log::Dispatch/"Log Levels"> for more information.  This is not
required.  By default the maximum is the highest possible level (which
means functionally that the object has no maximum).

=item * subject ($)

The subject of the email messages which are sent.  Defaults to "$0:
log email"

=item * to ($ or \@)

Either a string or a list reference of strings containing email
addresses.  Required.

=item * from ($)

A string containing an email address.  This is optional and may not
work with all mail sending methods.

=item * buffered (0 or 1)

This determines whether the object sends one email per message it is
given or whether it stores them up and sends them all at once.  The
default is to buffer messages.

=item * callbacks( \& or [ \&, \&, ... ] )

This parameter may be a single subroutine reference or an array
reference of subroutine references.  These callbacks will be called in
the order they are given and passed a hash containing the following keys:

 ( message => $log_message, level => $log_level )

The callbacks are expected to modify the message and then return a
single scalar containing that modified message.  These callbacks will
be called when either the C<log> or C<log_to> methods are called and
will only be applied to a given message once.

=back

=item * log_message( message => $ )

Sends a message to the appropriate output.  Generally this shouldn't
be called directly but should be called through the C<log()> method
(in Log::Dispatch::Output).

=item * send_email(%p)

This is the method that must be subclassed.  For now the only
parameter in the hash is 'message'.

=item * flush

If the object is buffered, then this method will call the
C<send_email()> method to send the contents of the buffer and then
clear the buffer.

=item * DESTROY

On destruction, the object will call C<flush()> to send any pending
email.

=back

=head1 AUTHOR

Dave Rolsky, <autarch@urth.org>

=cut
